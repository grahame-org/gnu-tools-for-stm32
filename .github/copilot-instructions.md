# Copilot Instructions for gnu-tools-for-stm32

## Overview

This repository builds the **GNU Tools for STM32** bare-metal C/C++ toolchain
(`arm-none-eabi` target) that ships inside STM32CubeIDE. It is based on the
[ARM GNU Toolchain](https://developer.arm.com/Tools%20and%20Software/GNU%20Toolchain)
sources with STM32-specific patches and backports.

**Components in `src/`:**

| Directory | Component |
|-----------|-----------|
| `src/binutils/` | GNU Binutils (`as`, `ld`, `ar`, `nm`, `objcopy`, `objdump`, …) |
| `src/gcc/` | GCC C/C++ compiler |
| `src/gdb/` | GDB debugger |
| `src/newlib/` | Newlib C library |
| `src/specs/` | Extra GCC spec files for nano/standard library mixing |
| `src/gmp/`, `src/mpfr/`, `src/mpc/`, `src/isl/` | GCC math prerequisites |
| `src/expat/`, `src/zlib-*/`, `src/libiconv/` | GDB/host library prerequisites |
| `src/liblongpath-win32/` | Windows long-path patch library |

---

## Repository Structure

```
.
├── build-common.sh          # Shared shell utilities (copy_dir, copy_multi_libs, etc.)
├── build-prerequisites.sh   # Builds GCC math prereqs (GMP, MPFR, MPC, ISL, …)
├── build-toolchain.sh       # Main toolchain build script (all stages III-0 … III-14)
├── docs/
│   ├── build-stages.md      # Detailed stage-by-stage build reference
│   └── testing.md           # Test suite guide for all components
├── src/                     # All upstream + patched source trees
├── test_project/            # STM32 CMake test project (built to validate the toolchain)
│   ├── reference/           # Reference artifacts (see below)
│   └── BUILD.md
├── .github/
│   ├── workflows/           # All CI workflows
│   └── pull_request_template.md
├── CONTRIBUTING.md          # Conventional Commits requirements
└── package.json             # commitlint config anchor (Node.js tooling only for linting)
```

---

## Build System

### Prerequisites

Build the prerequisite host libraries once before building the toolchain:

```bash
export JOBS=$(nproc)
./build-prerequisites.sh --skip_steps=mingw,howto,package_sources
```

Output: `build-native/host-libs/`

### Full Toolchain Build

```bash
export JOBS=$(nproc)
./build-toolchain.sh --skip_steps=mingw,mingw-gdb-with-python,gdb-with-python,manual,package_sources
```

Output: `install-native/` (the complete `arm-none-eabi` toolchain)

### Build Stages (III-0 through III-14)

The build progresses through ordered stages. See `docs/build-stages.md` for the
complete reference. Key stages:

| ID | Stage | Notes |
|----|-------|-------|
| III-0 | `binutils` | First stage; output copied to `build-native/target-libs/` |
| III-1 | `gcc-first` | Minimal C-only compiler to bootstrap newlib |
| III-2 | `newlib` | Standard newlib → `install-native/arm-none-eabi/` |
| III-3 | `newlib-nano` | Size-optimised newlib → `build-native/target-libs/` (staging only) |
| III-4 | `gcc-final` | Full C/C++ compiler with runtime libraries |
| III-5 | `gcc-size-libstdcxx` | Size-optimised libstdc++ (`_nano` variants) |
| III-6 | `gdb` | `arm-none-eabi-gdb` (no-Python for native builds) |
| III-8–10 | `pretidy`/`strip` | Post-install cleanup and symbol stripping |
| III-11 | `specs` | Extra `.specs` files for nano/standard mixing |
| III-12–14 | `package_*` | Tarball packaging and macOS validation |

**Important quirk:** For native builds, `skip_gdb_with_python` is hardcoded to
`yes` and no CLI option sets it to `no`. The Python-enabled GDB build path in
`build-toolchain.sh` is currently unreachable for native builds (only PPA builds
use Python-enabled GDB).

### Intermediate Directories

| Directory | Contents |
|-----------|----------|
| `build-native/host-libs/` | Prerequisite libraries (GMP, MPFR, etc.) |
| `build-native/target-libs/` | Snapshot of `install-native/` after binutils; used as sysroot for newlib-nano and gcc-size-libstdcxx |
| `install-native/` | Live toolchain installation (final output) |
| `pkg/` | Packaged tarballs |

---

## Test Infrastructure

### CI Workflows

All workflows follow the same structural pattern:

```
check-changes job (dorny/paths-filter)
  └── main test/build job (skipped if no relevant changes on pull_request)
        └── <name>-status job (always() — keeps required checks green when skipped)
```

Each `check-changes` job exposes a boolean output named after the action it gates
(`should-build` in `build-toolchain.yml`; `should-test` in all test workflows),
and the main job's `if:` condition references that output.

| Workflow file | Purpose | Triggers on |
|---------------|---------|-------------|
| `build-toolchain.yml` | Build full toolchain + validate test_project | `src/**`, build scripts, `test_project/**` |
| `binutils-tests.yml` | DejaGnu regression tests (gas, ld, binutils) | `src/binutils/**`, build scripts |
| `gcc-selftests.yml` | GCC internal selftests (`-fself-test`) | `src/gcc/**`, build scripts |
| `gdb-selftests.yml` | GDB `maintenance selftest` | `src/gdb/**`, build scripts |
| `libiberty-tests.yml` | libiberty unit tests (`make check`) | `src/binutils/**`, build scripts |
| `commitlint.yml` | Conventional Commits lint on PR titles | pull_request |

### Running Tests Locally

**Binutils regression tests:**
```bash
mkdir -p build/binutils && cd build/binutils
../../src/binutils/configure --target=arm-none-eabi --disable-nls --disable-werror \
  --disable-sim --disable-gdb --enable-interwork --enable-plugins --with-zstd=no
make -j$(nproc)
make check-gas check-ld check-binutils
```

**GDB selftests:**
```bash
mkdir -p build/gdb && cd build/gdb
../../src/gdb/configure --disable-nls --disable-werror --enable-unit-tests --with-python=no
make all-gdb -j$(nproc)
./gdb/gdb --batch -ex "maintenance selftest" 2>&1 | tee gdb-selftest.log
if grep -q "Self test failed:" gdb-selftest.log; then echo "GDB selftests FAILED"; exit 1; fi
```
Note: GDB selftest output is `Self test failed: <msg>` per failure and
`Ran N unit tests, M failed` as summary. It does **not** output `FAIL:` lines.

**GCC selftests:**
```bash
mkdir -p build/gcc && cd build/gcc
../../src/gcc/configure --enable-languages=c,c++ --disable-multilib \
  --disable-nls --disable-werror --enable-checking=yes
make all-gcc -j$(nproc)
gcc/xgcc -B gcc -xc -S -o /dev/null -nostdinc \
  -fself-test=../../src/gcc/gcc/testsuite/selftests /dev/null
```

**libiberty tests:**
```bash
mkdir -p build/libiberty && cd build/libiberty
../../src/binutils/libiberty/configure
make -j$(nproc)
make check
```
Note: `make check` for libiberty only runs tests when `configure` sets
`CHECK=really-check`. Target-library configurations leave `CHECK` empty, so
`make check` is a no-op in those cases.

**test_project build (requires a built toolchain in `install-native/`):**
```bash
export PATH="${PWD}/install-native/bin:${PATH}"
rm -rf test_project/build && mkdir -p test_project/build
cmake -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="${PWD}/test_project/arm-none-eabi-gcc.cmake" \
  -DCMAKE_C_COMPILER="${PWD}/install-native/bin/arm-none-eabi-gcc" \
  -DCMAKE_CXX_COMPILER="${PWD}/install-native/bin/arm-none-eabi-g++" \
  -B test_project/build -S test_project
cmake --build test_project/build --verbose -- -j$(nproc)
```

### test_project Reference Artifacts

`test_project/reference/` contains reference build outputs
(`nucleo-u083rc.{elf,bin,hex,map}`) built on Windows with CubeIDE 1.19.0.

**CI comparison rules:**
- `.bin` — compared byte-for-byte (this is the meaningful cross-platform check)
- `.elf` — **excluded** (DWARF sections embed absolute source/toolchain paths)
- `.map` — **excluded** (linker map contains Windows absolute paths like `C:/ST/STM32CubeIDE_1.19.0/…`)
- `.hex` — **excluded** (Intel HEX encoding can vary between objcopy versions/platforms)

---

## CI / Caching Strategies

### Toolchain Cache Key

The toolchain build uses `git rev-parse HEAD:<dir> | sha256sum` to derive cache
keys for the ~217k-file `src/` tree. This avoids the 120-second `hashFiles()`
timeout that would occur scanning `src/**` directly.

```yaml
- name: Compute source tree hashes
  run: |
    toolchain_src_hash=$(
      printf '%s\n' src/binutils src/gcc src/gdb src/newlib ... \
      | while read -r dir; do git rev-parse "HEAD:${dir}"; done \
      | sha256sum | cut -d' ' -f1
    )
    echo "toolchain-src=${toolchain_src_hash}" >> "${GITHUB_OUTPUT}"
```

### Adding a New CI Workflow

When creating a new workflow:
1. Add a `check-changes` job using `dorny/paths-filter` to gate on relevant
   file paths and expose a boolean output (e.g., `should-test` or `should-build`).
2. Make the main job `needs: check-changes` with an `if:` condition referencing
   the output name you defined (e.g.,
   `if: needs.check-changes.outputs.should-test == 'true'` or
   `if: needs.check-changes.outputs.should-build == 'true'`).
3. Add a `<name>-status` job with `needs: [check-changes, <main-job>]` and
   `if: always()` so required checks stay green when the job is skipped.
4. Pin all third-party actions to a full commit SHA with a version comment,
   e.g. `uses: actions/checkout@<sha> # v6.0.2`.
5. Set `permissions: {}` at the workflow level; grant only what each job needs.

---

## Commit Message Convention

**PR titles** (which become the squash commit message) must follow
[Conventional Commits](https://www.conventionalcommits.org/):

```
<type>[(optional scope)][!]: <description>
```

| Type | When to use |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Whitespace/formatting |
| `refactor` | Code restructuring |
| `test` | Adding/updating tests |
| `chore` | Maintenance (deps, tooling) |
| `ci` | CI/CD configuration changes |
| `build` | Build system changes |
| `perf` | Performance improvements |
| `revert` | Reverts a previous commit |

Examples: `feat: add ARMv8-M support`, `fix: correct stack calculation`, `ci: add linting workflow`

A `commitlint` CI check enforces this on every PR. Individual commits within a
PR do **not** need to follow this format — only the PR title matters (it becomes
the squash commit message).

---

## Known Quirks and Gotchas

- **GDB Python build is unreachable for native builds.** `skip_gdb_with_python`
  defaults to `yes` in `build-toolchain.sh` and no CLI argument sets it to `no`.
  Python-enabled GDB is only produced in PPA builds.

- **`newlib-nano` does not write to `install-native/`.** Its output lands in
  `build-native/target-libs/` and is only merged into `install-native/` by
  stage III-5 (`gcc-size-libstdcxx`) via `copy_multi_libs`.

- **`build-native/target-libs/` is populated immediately after binutils** (stage
  III-0) by a `copy_dir` call. It is used as the sysroot for newlib-nano and
  gcc-size-libstdcxx builds.

- **`libiberty.a` is intentionally deleted** at multiple points (after
  gcc-first, after gcc-final, and again in pretidy). This is expected; do not
  treat these deletions as errors.

- **macOS-only stage `validate_tool_deps` (III-14)** checks that no Mach-O
  binary in `install-native/` links against `/usr/local/` (Homebrew) libraries.
  It only runs on macOS builds.

- **`dorny/paths-filter` is pinned to a full SHA.** When updating this action,
  update both the SHA and the version comment together.

- **`agentics-maintenance.yml` and `*.lock.yml` / `*.md` agentic workflow files**
  under `.github/workflows/` are managed by automated agents. Treat them as
  infrastructure you should not manually edit without understanding the agent
  framework in `.github/aw/`.

- **`daily-test-improver.lock.yml` contains two intentional manual edits** that
  must be re-applied after every `gh aw compile`:
  1. **`push_repo_memory` job**: an "Ensure memory branch exists" step added
     before the push step. Required because gh-aw v0.53.6 provides no frontmatter
     mechanism for this, and on this large repo (~217k files) the orphan-branch
     creation path in `push_repo_memory.cjs` fails with `spawnSync git ENOBUFS`.
  2. **`safe_outputs` job**: `"base_branch":"${{ github.ref_name }}"` added to the
     `create_pull_request` and `push_to_pull_request_branch` handler configs inside
     `GH_AW_SAFE_OUTPUTS_HANDLER_CONFIG`. This cannot be expressed in the `.md`
     frontmatter because `github.ref_name` is not in gh-aw's allowed expressions
     list (only numeric/ID/SHA-type context expressions are allowed). The expression
     is valid GitHub Actions YAML and is evaluated correctly at runtime in the
     lock.yml. Must be re-applied manually after `gh aw compile`.

---

## Development Workflow Summary

1. Make changes to source files under `src/`, build scripts, workflows, or
   `test_project/`.
2. Run relevant tests locally (see above).
3. Open a PR — the PR title must be a valid Conventional Commits message.
4. CI will run only the workflows relevant to the files you changed (via
   `check-changes` path filters).
5. The full toolchain build takes up to 6 hours; it is cached per source tree
   hash to avoid rebuilding when only unrelated files change.
