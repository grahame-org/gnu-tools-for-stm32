# Parallel `gcc-final` Design

**Status:** Design (not yet implemented)

**Related issues:**
[#283 (implementation)](https://github.com/grahame-org/gnu-tools-for-stm32/issues/283) ·
[#301 (investigation)](https://github.com/grahame-org/gnu-tools-for-stm32/issues/301)

This document specifies the design for splitting the single `build-gcc-final` CI job
(stage III-4) into two parallel jobs plus a merge step. It synthesises the findings
from the preceding investigation sub-issues into a single implementable design.

Investigation findings referenced by this document:

- [Multilib variant catalog and `multilib.h` generation analysis](multilib-variants.md)
- [Cache size measurements and budget analysis](cache-sizes.md)
- [Build time reference](build-times.md)
- [Build stage dependencies and artifact catalog](build-stages.md)

---

## 1. Job Structure

### 1.1 Parallel build jobs

Two new parallel CI jobs replace the existing single `build-gcc-final` job:

| CI job | Stage | `--with-multilib-list` | Variants built | Outputs |
|--------|-------|------------------------|----------------|---------|
| `build-gcc-final-rmprofile` | III-4a | `rmprofile` | 20 M-profile + 8 base | (1) `install-native` → cache key `gcc-final-rmprofile`; (2) `build-native/gcc-final` → workflow artifact `gcc-final-rmprofile-builddir` |
| `build-gcc-final-aprofile` | III-4b | `aprofile` | 10 A-profile + 8 base | `install-native` → cache key `gcc-final-aprofile` |

Both jobs invoke the existing `build-gcc-final.sh` script, which already accepts the
`--with-multilib-list` flag via `build-toolchain-args.sh`:

```bash
# rmprofile job (III-4a)
./build-gcc-final.sh --with-multilib-list=rmprofile

# aprofile job (III-4b)
./build-gcc-final.sh --with-multilib-list=aprofile
```

Each job runs on a separate GitHub Actions runner and saves its output to a
separate profile-specific cache key (see [§4 Cache Key Scheme](#4-cache-key-scheme)).
The jobs share no state and can run completely in parallel once `build-newlib` completes.

> **Build-directory artifact:** The rmprofile job uploads the GCC build directory
> (`build-native/gcc-final`) as a **workflow artifact** (`gcc-final-rmprofile-builddir`),
> distinct from the install-tree cache (key `gcc-final-rmprofile`). Using an artifact
> rather than a cache entry ensures the build directory is always available to the merge
> job within the same workflow run regardless of `merge_group` cache-write restrictions,
> cache eviction, or first-time key scenarios. The build directory is required by the
> merge job to run `make s-mlib`, `make gcc.o`, and relink the driver executables with
> a combined `multilib.h` (see [§3](#3-multilibh-regeneration)). The aprofile job
> uploads no artifact; its build directory is not needed by any downstream step.

### 1.2 Merge job

A new CI job `build-gcc-final-merge` runs after both parallel builds complete:

| CI job | Stage | Description |
|--------|-------|-------------|
| `build-gcc-final-merge` | III-4-merge | Overlay install trees, regenerate `multilib.h`, save merged cache |

This job performs no full compilation. The only build work it does is recompiling a
single C++ translation unit (`gcc.cc` → `gcc.o`) and relinking three driver
executables. Its wall-clock time is approximately 1 minute
(see [build-times.md](build-times.md)).

---

## 2. Merge Job Steps

The merge job performs the following steps in order:

1. **Checkout repository** — needed for GCC source files (`genmultilib`, ARM profile
   makefiles) which are referenced by the `s-mlib` stamp target.
2. **Free disk space and install dependencies** — same packages as the parallel build
   jobs; a host C++ compiler is needed for `make gcc.o`.
3. **Restore cache – prerequisites** — restore `build-native/host-libs` (GMP, MPFR,
   MPC, ISL), which are linked into the host-side GCC build.
4. **Restore cache – gcc-final-rmprofile; download build-directory artifact** — restore
   `install-native` (the full rmprofile compiler install tree, which includes the newlib
   output) from the rmprofile install cache. Then download `build-native/gcc-final` from
   the `gcc-final-rmprofile-builddir` workflow artifact uploaded by
   `build-gcc-final-rmprofile`. The build directory contains the compiled objects
   required to relink the driver executables in step 6.
5. **Restore cache – gcc-final-aprofile** — overlay `install-native` with the
   aprofile install cache. The rmprofile and aprofile library subdirectories under
   `arm-none-eabi/lib/thumb/` are completely disjoint
   (see [multilib-variants.md §Disjointness](multilib-variants.md#disjointness)), so
   tar extraction adds the aprofile library directories without removing any rmprofile
   library files. However, the driver binaries at `install-native/bin/`
   (`arm-none-eabi-gcc`, `arm-none-eabi-g++`, `arm-none-eabi-cpp`) are present in
   both caches and will be overwritten by the aprofile versions during this restore.
   After this step `install-native/` contains the union of both profile library trees,
   with driver binaries encoding only the aprofile multilib tables. Step 6 replaces
   those drivers with correctly merged versions.
6. **Regenerate `multilib.h` and relink drivers** — run the concrete shell commands
   from [§3](#3-multilibh-regeneration) to produce combined-profile driver binaries.
7. **Save cache – gcc-final (merged)** — save `install-native` under the shared
   `${{ runner.os }}-stage-v3-${{ needs.compute-hashes.outputs['gcc-final'] }}` key.
   Since the merge job cannot use the `build-stage` composite action (it has multiple
   independent restore steps preceding this save), the save is implemented as a direct
   `actions/cache/save` step. The step is gated on a `lookup-only` pre-check at the
   start of the job so that on a cache hit the entire merge job body is skipped without
   downloading the large `install-native` tree:

   ```yaml
   - name: Restore cache – gcc-final (merged, pre-check)
     id: pre-restore-merged
     uses: actions/cache/restore@...
     with:
       path: install-native
       key: ${{ runner.os }}-stage-v3-${{ needs.compute-hashes.outputs['gcc-final'] }}
       lookup-only: true

   # ... (all other steps are skipped when pre-restore-merged is a cache hit) ...

   - name: Save cache – gcc-final (merged)
     if: steps.pre-restore-merged.outputs.cache-hit != 'true'
     uses: actions/cache/save@...
     with:
       path: install-native
       key: ${{ runner.os }}-stage-v3-${{ needs.compute-hashes.outputs['gcc-final'] }}
   ```

---

## 3. `multilib.h` Regeneration

After step 5 above the `install-native/bin/` driver binaries contain multilib
routing tables for only one profile (aprofile, since the aprofile cache was restored
last in step 5 and overwrote the rmprofile driver binaries). They must be replaced
by drivers compiled with a combined `multilib.h` covering both profiles.

The following commands are executed inside the merge job. `BUILDDIR_NATIVE` and
`INSTALLDIR_NATIVE` are set by `build-common.sh` to `build-native` and
`install-native` respectively.

In a GitHub Actions inline `run:` step, `build-common.sh` is sourced via
`${GITHUB_WORKSPACE}` (the repository root). If these steps are extracted into a
dedicated `build-gcc-final-merge.sh` script instead (consistent with how other
stages are implemented), then `script_path=$(cd "$(dirname "$0")" && pwd -P)`
resolves correctly and `"${script_path}/build-common.sh"` is used instead.

```bash
# Source build-common.sh to set BUILDDIR_NATIVE, INSTALLDIR_NATIVE, and other
# shared build variables.  build-common.sh is a sourced script (no shebang).
# Use ${GITHUB_WORKSPACE} in an inline run: step; in a standalone script,
# use: script_path=$(cd "$(dirname "$0")" && pwd -P)
. "${GITHUB_WORKSPACE}/build-common.sh"

# Move into the gcc/ subdirectory of the GCC build tree.
# TM_MULTILIB_CONFIG, the s-mlib stamp target, gcc.o, xgcc, xg++, and cpp all
# live in this subdirectory.
cd "${BUILDDIR_NATIVE}/gcc-final/gcc"

# 1. Override TM_MULTILIB_CONFIG in the gcc/ Makefile to cover both profiles.
#    build-gcc-final.sh configured this directory with --with-multilib-list=rmprofile,
#    so TM_MULTILIB_CONFIG currently reads "rmprofile".  This sed command changes
#    it to "rmprofile,aprofile" so that the s-mlib recipe generates the combined
#    multilib tables.
sed -i 's|^TM_MULTILIB_CONFIG=.*|TM_MULTILIB_CONFIG=rmprofile,aprofile|' Makefile

# 2. Regenerate multilib.h for the combined profile list.
#    This step performs no compilation.  It runs the genmultilib POSIX shell
#    script (src/gcc/gcc/genmultilib) to emit a new multilib.h that encodes
#    both rmprofile and aprofile multilib routing tables.
make s-mlib

# 3. Recompile the driver translation unit gcc.cc → gcc.o.
#    gcc.cc #includes multilib.h (src/gcc/gcc/gcc.cc line 34), so it must be
#    recompiled to embed the new combined tables.  This is a single-file C++
#    compilation; all other GCC objects are unchanged.
make gcc.o

# 4. Relink all driver executables that embed gcc.o:
#    - xgcc  (C driver;  src/gcc/gcc/Makefile.in line 2163)
#    - xg++  (C++ driver; GXX_OBJS includes all of GCC_OBJS — cp/Make-lang.in:80)
#    - cpp   (preprocessor driver; src/gcc/gcc/Makefile.in line 2173)
make xgcc xg++ cpp

# 5. Install the C driver (arm-none-eabi-gcc, versioned alias, and target symlinks).
#    The build Makefile's --prefix was set to $INSTALLDIR_NATIVE at configure time,
#    so no DESTDIR override is needed.
make install-driver

# 6. Install the C++ driver (arm-none-eabi-g++, arm-none-eabi-c++, and symlinks).
make c++.install-common

# 7. Install the preprocessor driver (arm-none-eabi-cpp).
make install-cpp
```

**Why only these three drivers?** `multilib.h` is not installed as a standalone
header — it exists only as compiled-in data inside the three driver executables
listed above. All other installed files — `cc1`, `cc1plus`, `lto1`, `collect2`,
all target libraries under `arm-none-eabi/lib/`, documentation — are
profile-independent and require no change. See
[multilib-variants.md §Conclusion](multilib-variants.md#conclusion-conflicting-files)
for the full file classification.

> **Prerequisite check:** Verify that `srcdir` in the GCC build `Makefile` still
> points to the checked-out source tree before running the above commands:
>
> ```bash
> grep '^srcdir' "${BUILDDIR_NATIVE}/gcc-final/gcc/Makefile"
> ```
>
> The `build-stage` composite action performs a fresh `actions/checkout` on each
> runner, so the source tree is always present in CI.

These commands are derived from the analysis in
[multilib-variants.md §Recommended merge approach](multilib-variants.md#recommended-merge-approach-for-multilibh),
which contains the full rationale and references to the relevant GCC source files.

---

## 4. Cache Key Scheme

### 4.1 New outputs added to `compute-hashes`

Two new outputs are added to the `compute-hashes` job alongside the existing
`gcc-final` output:

```bash
# Per-profile install cache keys — same inputs as gcc-final but with a profile
# discriminator prepended to the key material before hashing.
key_gcc_final_rmprofile=$(printf '%s' \
    "${{ runner.os }}-stage-gcc-final-rmprofile-${gcc_final_scripts_hash}-${key_newlib}-${gcc_src}" \
  | sha256sum | cut -d' ' -f1)

key_gcc_final_aprofile=$(printf '%s' \
    "${{ runner.os }}-stage-gcc-final-aprofile-${gcc_final_scripts_hash}-${key_newlib}-${gcc_src}" \
  | sha256sum | cut -d' ' -f1)
```

The rmprofile GCC build directory (`build-native/gcc-final`) is transferred to the
merge job via a **workflow artifact** (`gcc-final-rmprofile-builddir`) rather than a
cache entry; see §1.1 above. No additional `compute-hashes` output is needed for the
artifact.

These two new outputs are added alongside the existing `gcc-final` output in
the `echo` block that writes to `$GITHUB_OUTPUT`. The existing `gcc-final`
computation must be updated to include `build-gcc-final-merge.sh` in
`gcc_final_scripts_hash`, so that any change to the merge job logic
invalidates the merged `install-native` cache:

```bash
# Updated computation — gcc_final_scripts_hash now includes build-gcc-final-merge.sh
# so that changes to the merge logic (multilib.h regeneration, driver relink/install)
# invalidate the merged gcc-final cache entry.
gcc_final_scripts_hash=$(
  printf '%s\n' \
    "$(hash_dir build-gcc-final.sh)" \
    "$(hash_dir build-gcc-final-merge.sh)" \
    "$(hash_dir build-toolchain-args.sh)" \
    "$(hash_dir build-common.sh)" \
  | sha256sum | cut -d' ' -f1
)

key_gcc_final=$(printf '%s' \
    "${{ runner.os }}-stage-gcc-final-${gcc_final_scripts_hash}-${key_newlib}-${gcc_src}" \
  | sha256sum | cut -d' ' -f1)
```

This is the only change required to `compute-hashes`. The `key_gcc_final` formula
itself is otherwise unchanged; the merge script's hash flows into
`gcc_final_scripts_hash`, which is already an input to `key_gcc_final`.

### 4.2 What changes each key

| Input | `gcc-final-rmprofile` | `gcc-final-aprofile` | `gcc-final` (merged) |
|-------|-----------------------|----------------------|-----------------------|
| `runner.os` | ✓ | ✓ | ✓ |
| `gcc_final_scripts_hash` (incl. `build-gcc-final-merge.sh`) | ✓ | ✓ | ✓ |
| `key_newlib` | ✓ | ✓ | ✓ |
| `gcc_src` (git tree hash of `src/gcc/`) | ✓ | ✓ | ✓ |
| Profile discriminator string | `rmprofile` | `aprofile` | _(none)_ |

Because `build-gcc-final-merge.sh` is included in `gcc_final_scripts_hash`, any
change to the merge script (e.g., altered `multilib.h` regeneration commands,
additional driver installation steps) will change `gcc_final_scripts_hash` and
therefore invalidate all three keys: `gcc-final-rmprofile`, `gcc-final-aprofile`,
and the merged `gcc-final`.  This is intentional — a merge logic change requires
both parallel jobs to re-run with the new merge behaviour.

The per-profile keys are also invalidated by the same source changes that
invalidate the merged key. The profile discriminator in the key string ensures
the two parallel jobs never collide in the cache store while sharing identical
invalidation logic.

### 4.3 Cache key format in `actions/cache`

All stage caches use the `stage-v3-` prefix in the `key:` field of
`actions/cache/save` and `actions/cache/restore`:

| `needs.compute-hashes` output | `key:` used in workflow |
|-------------------------------|------------------------|
| `gcc-final-rmprofile` | `${{ runner.os }}-stage-v3-${{ needs.compute-hashes.outputs['gcc-final-rmprofile'] }}` |
| `gcc-final-aprofile` | `${{ runner.os }}-stage-v3-${{ needs.compute-hashes.outputs['gcc-final-aprofile'] }}` |
| `gcc-final` (existing) | `${{ runner.os }}-stage-v3-${{ needs.compute-hashes.outputs['gcc-final'] }}` |

### 4.4 Summary of cache and artifact outputs

| Output | Kind | Written by | Consumed by | Saved in `merge_group`? |
|--------|------|------------|-------------|-------------------------|
| `stage-v3-<gcc-final-rmprofile-hash>` | Cache | `build-gcc-final-rmprofile` | `build-gcc-final-merge` | Yes |
| `stage-v3-<gcc-final-aprofile-hash>` | Cache | `build-gcc-final-aprofile` | `build-gcc-final-merge` | Yes |
| `gcc-final-rmprofile-builddir` | Workflow artifact | `build-gcc-final-rmprofile` | `build-gcc-final-merge` | N/A (always available within the same run) |
| `stage-v3-<gcc-final-hash>` _(existing)_ | Cache | `build-gcc-final-merge` | `build-gcc-size-libstdcxx`, `build-final` | Yes |

The `stage-v3-<gcc-final-hash>` entry is now written by the merge job rather than
a build job. Its key formula is otherwise unchanged — the addition of
`build-gcc-final-merge.sh` to `gcc_final_scripts_hash` is the only modification
(see §4.1). All downstream restore steps that reference
`needs.compute-hashes.outputs['gcc-final']` are **unchanged**.

The rmprofile GCC build directory is transferred via a workflow artifact rather than
a cache entry so that the merge job can always retrieve it regardless of
`merge_group` cache-write restrictions, cache eviction, or first-time key scenarios.
Workflow artifacts are guaranteed to be available for the duration of the workflow run
in which they were uploaded.

---

## 5. Downstream Impact

### 5.1 Current jobs that depend on `build-gcc-final`

| CI job | Dependency |
|--------|------------|
| `build-gcc-size-libstdcxx` | Direct: listed in `needs:` |
| `build-final` | Direct: listed in `needs:` |

All remaining jobs (`build-gdb`, `build-binutils`, etc.) are unaffected — they do
not depend on `build-gcc-final`.

### 5.2 Updated `needs:` clauses

**`build-gcc-size-libstdcxx`:**

```yaml
# Before:
needs: [check-changes, compute-hashes, build-gcc-final, build-newlib-nano]

# After:
needs: [check-changes, compute-hashes, build-gcc-final-merge, build-newlib-nano]
```

**`build-final`:**

```yaml
# Before:
needs: [check-changes, compute-hashes, build-binutils, build-gdb, build-gcc-first,
        build-newlib, build-newlib-nano, build-gcc-final, build-gcc-size-libstdcxx]

# After:
needs: [check-changes, compute-hashes, build-binutils, build-gdb, build-gcc-first,
        build-newlib, build-newlib-nano, build-gcc-final-merge, build-gcc-size-libstdcxx]
```

No other workflow changes are required in those jobs. Their cache restore steps
continue to reference `needs.compute-hashes.outputs['gcc-final']`, which is the
key under which the merge job saves the combined result.

### 5.3 Changes to `compute-hashes`

**New outputs:**

| New output | Used by |
|------------|---------|
| `gcc-final-rmprofile` | `build-gcc-final-rmprofile` (save), `build-gcc-final-merge` (restore) |
| `gcc-final-aprofile` | `build-gcc-final-aprofile` (save), `build-gcc-final-merge` (restore) |

The rmprofile GCC build directory is handed off via the `gcc-final-rmprofile-builddir`
workflow artifact and does not require a new `compute-hashes` output.

**Modified computation:**

The `gcc_final_scripts_hash` variable must be updated to include
`build-gcc-final-merge.sh` alongside `build-gcc-final.sh`, so that changes to
the merge logic (i.e. `multilib.h` regeneration, driver relink/install commands)
invalidate the merged `gcc-final` cache — and by extension both per-profile caches
which share the same `gcc_final_scripts_hash`. See §4.1 for the updated shell
fragment.

The existing `gcc-final` output is retained and continues to be used by
`build-gcc-size-libstdcxx` and `build-final` (unchanged).

### 5.4 `build-toolchain-status` job

The existing `build-toolchain-status` job (the always-runs required-checks gate) must
add `build-gcc-final-rmprofile`, `build-gcc-final-aprofile`, and
`build-gcc-final-merge` to its `needs:` list, and remove `build-gcc-final`.

---

## 6. Validation

Correctness of the parallel build and merge is confirmed by comparing the
`test_project` build output against the reference binary stored in
`test_project/reference/`.

The existing `build-final` job already performs this validation as its final step:

1. Build the `test_project` STM32 CMake project using the installed toolchain in
   `install-native/`.
2. Compare `test_project/build/nucleo-u083rc.bin` byte-for-byte against
   `test_project/reference/nucleo-u083rc.bin`.

No changes to the validation step are required; the merged `install-native/` tree
is written under the same cache key as the old single-job output, so `build-final`
already restores and validates it.

**Why the `.bin` comparison is authoritative:** A raw binary image is a direct
product of the multilib routing decisions made by the compiler. A byte-for-byte
match confirms that:

- Both rmprofile and aprofile multilib variants are present in the merged toolchain.
- The re-linked driver binaries correctly encode combined multilib routing tables
  so that M-profile (`-mcpu=cortex-m*`) and A-profile (`-mcpu=cortex-a*`) flags
  are each routed to their correct library subdirectory.
- The merge step has not silently altered or corrupted any library content.

The `.elf` and `.map` reference files are excluded from comparison because they
embed absolute host paths; only the `.bin` comparison is authoritative
(see `test_project/BUILD.md` for the full CI comparison rules).

If the parallel split introduces any regression in multilib routing — for example,
a Cortex-M compiler flag being routed to the wrong library directory because the
merged `multilib.h` was incorrectly generated — the `test_project` build will
either fail to link or produce a `.bin` that differs from the reference, causing
the workflow to fail.

---

*Related: [Build stages reference](build-stages.md) · [Multilib variant catalog](multilib-variants.md) · [Cache sizes reference](cache-sizes.md) · [Build times reference](build-times.md)*
