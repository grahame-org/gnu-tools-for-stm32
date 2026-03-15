# Multilib Variant Catalog

This document catalogs all `MULTILIB_REQUIRED` directory paths for the `rmprofile`
and `aprofile` GCC multilib configurations, statically derived from the GCC ARM
multilib makefiles.

**Sources analyzed:**
- `src/gcc/gcc/config/arm/t-rmprofile`
- `src/gcc/gcc/config/arm/t-aprofile`
- `src/gcc/gcc/config/arm/t-multilib` (base/default variants)

The make-variable option form (e.g. `mthumb/march=armv7-m/mfloat-abi=soft`) is
translated to a filesystem path using the `MULTILIB_DIRNAMES` mappings defined in
these makefiles (e.g. `arm-none-eabi/lib/thumb/v7-m/nofp/`).

---

## Base variants (t-multilib — always built)

| Profile | Library path |
|---------|-------------|
| base | `arm-none-eabi/lib/thumb/nofp/` |
| base | `arm-none-eabi/lib/arm/v5te/softfp/` |
| base | `arm-none-eabi/lib/arm/v5te/hard/` |
| base | `arm-none-eabi/lib/thumb/v7/nofp/` |
| base | `arm-none-eabi/lib/thumb/v7+fp/softfp/` |
| base | `arm-none-eabi/lib/thumb/v7+fp/hard/` |
| base | `arm-none-eabi/lib/thumb/v7-r+fp.sp/softfp/` |
| base | `arm-none-eabi/lib/thumb/v7-r+fp.sp/hard/` |

**Total: 8 base variants**

---

## rmprofile variants (t-rmprofile — M-profile cores)

| Profile | Library path |
|---------|-------------|
| rmprofile | `arm-none-eabi/lib/thumb/v6-m/nofp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v7-m/nofp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v7e-m/nofp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8-m.base/nofp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8-m.main/nofp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v7e-m+fp/hard/` |
| rmprofile | `arm-none-eabi/lib/thumb/v7e-m+fp/softfp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v7e-m+dp/hard/` |
| rmprofile | `arm-none-eabi/lib/thumb/v7e-m+dp/softfp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8-m.main+fp/hard/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8-m.main+fp/softfp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8-m.main+dp/hard/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8-m.main+dp/softfp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8.1-m.main+mve/hard/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8.1-m.main+pacbti/bp/nofp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8.1-m.main+pacbti+fp/bp/softfp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8.1-m.main+pacbti+fp/bp/hard/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8.1-m.main+pacbti+dp/bp/softfp/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8.1-m.main+pacbti+dp/bp/hard/` |
| rmprofile | `arm-none-eabi/lib/thumb/v8.1-m.main+pacbti+mve/bp/hard/` |

**Total: 20 rmprofile variants**

---

## aprofile variants (t-aprofile — A-profile cores)

| Profile | Library path |
|---------|-------------|
| aprofile | `arm-none-eabi/lib/thumb/v7-a/nofp/` |
| aprofile | `arm-none-eabi/lib/thumb/v7-a+fp/hard/` |
| aprofile | `arm-none-eabi/lib/thumb/v7-a+fp/softfp/` |
| aprofile | `arm-none-eabi/lib/thumb/v7-a+simd/hard/` |
| aprofile | `arm-none-eabi/lib/thumb/v7-a+simd/softfp/` |
| aprofile | `arm-none-eabi/lib/thumb/v7ve+simd/hard/` |
| aprofile | `arm-none-eabi/lib/thumb/v7ve+simd/softfp/` |
| aprofile | `arm-none-eabi/lib/thumb/v8-a/nofp/` |
| aprofile | `arm-none-eabi/lib/thumb/v8-a+simd/hard/` |
| aprofile | `arm-none-eabi/lib/thumb/v8-a+simd/softfp/` |

**Total: 10 aprofile variants**

---

## Disjointness

**rmprofile and aprofile `MULTILIB_REQUIRED` sets are disjoint** — no library path
appears in both lists.

The sets are disjoint by design: rmprofile covers M-profile architectures
(`v6-m`, `v7-m`, `v7e-m`, `v8-m.*`, `v8.1-m.*`) while aprofile covers A-profile
architectures (`v7-a`, `v7ve`, `v8-a`). These are completely separate ARM
architecture families with no path overlap.

---

## MULTILIB_REQUIRED entries (make form)

For reference, the raw `MULTILIB_REQUIRED` entries from each file:

### t-multilib

```
mthumb/mfloat-abi=soft
marm/march=armv5te+fp/mfloat-abi=softfp
marm/march=armv5te+fp/mfloat-abi=hard
mthumb/march=armv7/mfloat-abi=soft
mthumb/march=armv7+fp/mfloat-abi=softfp
mthumb/march=armv7+fp/mfloat-abi=hard
mthumb/march=armv7-r+fp.sp/mfloat-abi=softfp
mthumb/march=armv7-r+fp.sp/mfloat-abi=hard
```

### t-rmprofile

```
mthumb/march=armv6s-m/mfloat-abi=soft
mthumb/march=armv7-m/mfloat-abi=soft
mthumb/march=armv7e-m/mfloat-abi=soft
mthumb/march=armv8-m.base/mfloat-abi=soft
mthumb/march=armv8-m.main/mfloat-abi=soft
mthumb/march=armv7e-m+fp/mfloat-abi=hard
mthumb/march=armv7e-m+fp/mfloat-abi=softfp
mthumb/march=armv7e-m+fp.dp/mfloat-abi=hard
mthumb/march=armv7e-m+fp.dp/mfloat-abi=softfp
mthumb/march=armv8-m.main+fp/mfloat-abi=hard
mthumb/march=armv8-m.main+fp/mfloat-abi=softfp
mthumb/march=armv8-m.main+fp.dp/mfloat-abi=hard
mthumb/march=armv8-m.main+fp.dp/mfloat-abi=softfp
mthumb/march=armv8.1-m.main+mve/mfloat-abi=hard
mthumb/march=armv8.1-m.main+pacbti/mbranch-protection=standard/mfloat-abi=soft
mthumb/march=armv8.1-m.main+pacbti+fp/mbranch-protection=standard/mfloat-abi=softfp
mthumb/march=armv8.1-m.main+pacbti+fp/mbranch-protection=standard/mfloat-abi=hard
mthumb/march=armv8.1-m.main+pacbti+fp.dp/mbranch-protection=standard/mfloat-abi=softfp
mthumb/march=armv8.1-m.main+pacbti+fp.dp/mbranch-protection=standard/mfloat-abi=hard
mthumb/march=armv8.1-m.main+pacbti+mve/mbranch-protection=standard/mfloat-abi=hard
```

### t-aprofile

```
mthumb/march=armv7-a/mfloat-abi=soft
mthumb/march=armv7-a+fp/mfloat-abi=hard
mthumb/march=armv7-a+fp/mfloat-abi=softfp
mthumb/march=armv7-a+simd/mfloat-abi=hard
mthumb/march=armv7-a+simd/mfloat-abi=softfp
mthumb/march=armv7ve+simd/mfloat-abi=hard
mthumb/march=armv7ve+simd/mfloat-abi=softfp
mthumb/march=armv8-a/mfloat-abi=soft
mthumb/march=armv8-a+simd/mfloat-abi=hard
mthumb/march=armv8-a+simd/mfloat-abi=softfp
```

---

## Dirnames mapping reference

The option form is translated to a directory name using these `MULTILIB_DIRNAMES`
mappings (from `t-multilib`, `t-rmprofile`, and `t-aprofile`):

| Option | Directory name |
|--------|---------------|
| `mthumb` | `thumb` |
| `marm` | `arm` |
| `mfloat-abi=soft` | `nofp` |
| `mfloat-abi=softfp` | `softfp` |
| `mfloat-abi=hard` | `hard` |
| `mbranch-protection=standard` | `bp` |
| `march=armv5te+fp` | `v5te` |
| `march=armv7` | `v7` |
| `march=armv7+fp` | `v7+fp` |
| `march=armv7-r+fp.sp` | `v7-r+fp.sp` |
| `march=armv6s-m` | `v6-m` |
| `march=armv7-m` | `v7-m` |
| `march=armv7e-m` | `v7e-m` |
| `march=armv7e-m+fp` | `v7e-m+fp` |
| `march=armv7e-m+fp.dp` | `v7e-m+dp` |
| `march=armv8-m.base` | `v8-m.base` |
| `march=armv8-m.main` | `v8-m.main` |
| `march=armv8-m.main+fp` | `v8-m.main+fp` |
| `march=armv8-m.main+fp.dp` | `v8-m.main+dp` |
| `march=armv8.1-m.main+mve` | `v8.1-m.main+mve` |
| `march=armv8.1-m.main+pacbti` | `v8.1-m.main+pacbti` |
| `march=armv8.1-m.main+pacbti+fp` | `v8.1-m.main+pacbti+fp` |
| `march=armv8.1-m.main+pacbti+fp.dp` | `v8.1-m.main+pacbti+dp` |
| `march=armv8.1-m.main+pacbti+mve` | `v8.1-m.main+pacbti+mve` |
| `march=armv7-a` | `v7-a` |
| `march=armv7-a+fp` | `v7-a+fp` |
| `march=armv7-a+simd` | `v7-a+simd` |
| `march=armv7ve+simd` | `v7ve+simd` |
| `march=armv8-a` | `v8-a` |
| `march=armv8-a+simd` | `v8-a+simd` |

---

## `multilib.h` generation pipeline analysis

This section documents the exact mechanism by which `multilib.h` is produced,
whether it can be regenerated without a full GCC rebuild, and the recommended
approach for producing a merged `multilib.h` that covers both `rmprofile` and
`aprofile`.

### Additional prerequisites declared in `t-multilib`

`src/gcc/gcc/config/arm/t-multilib` (line 27) adds these extra dependencies to
the `s-mlib` stamp target (shown here as a single source line):

```makefile
s-mlib: $(srcdir)/config/arm/t-multilib $(srcdir)/config/arm/t-aprofile $(srcdir)/config/arm/t-rmprofile
```

This ensures the stamp is invalidated whenever any of the ARM profile makefiles
change. The recipe itself lives in `src/gcc/gcc/Makefile.in`.

### `TM_MULTILIB_CONFIG` expansion

`TM_MULTILIB_CONFIG` is set at configure time via `--with-multilib-list=`
(e.g. `--with-multilib-list=rmprofile` or `--with-multilib-list=rmprofile,aprofile`).
The configure step substitutes the value into the build `Makefile` verbatim:

```makefile
TM_MULTILIB_CONFIG=@TM_MULTILIB_CONFIG@   # → e.g. rmprofile,aprofile
```

Inside `t-multilib` the value is split on commas and tested with `$(filter …)`:

```makefile
comma := ,
tm_multilib_list := $(subst $(comma), ,$(TM_MULTILIB_CONFIG))

HAS_APROFILE  := $(filter aprofile,$(tm_multilib_list))
HAS_RMPROFILE := $(filter rmprofile,$(tm_multilib_list))

ifneq (,$(HAS_APROFILE))
include $(srcdir)/config/arm/t-aprofile
endif
ifneq (,$(HAS_RMPROFILE))
include $(srcdir)/config/arm/t-rmprofile
endif
```

Each included profile file defines `MULTI_ARCH_OPTS_*` / `MULTI_ARCH_DIRS_*`
intermediaries and appends directly to `MULTILIB_REQUIRED` (and `MULTILIB_REUSE`
for A-profile). `t-multilib` then expands those intermediaries into
`MULTILIB_OPTIONS` and `MULTILIB_DIRNAMES` (lines 95–96):

```makefile
MULTILIB_OPTIONS += march=armv5te+fp/march=armv7/…/$(MULTI_ARCH_OPTS_A)$(SEP)$(MULTI_ARCH_OPTS_RM)
MULTILIB_DIRNAMES += v5te v7 … $(MULTI_ARCH_DIRS_A) $(MULTI_ARCH_DIRS_RM)
```

(The `…` represents additional fixed dimensions added by `t-multilib` itself,
not by the profile fragments.)

When only `rmprofile` is configured, `MULTI_ARCH_OPTS_A` and `MULTI_ARCH_DIRS_A`
are empty so only the M-profile entries appear; when both profiles are configured
the combined set is present.

### `s-mlib` recipe (`Makefile.in` lines 2218–2241)

The `s-mlib` stamp target is defined entirely in `src/gcc/gcc/Makefile.in`:

```makefile
multilib.h: s-mlib; @true
s-mlib: $(srcdir)/genmultilib Makefile
	if test @enable_multilib@ = yes \
	   || test -n "$(MULTILIB_OSDIRNAMES)"; then \
	  $(SHELL) $(srcdir)/genmultilib \
	    "$(MULTILIB_OPTIONS)" \
	    "$(MULTILIB_DIRNAMES)" \
	    "$(MULTILIB_MATCHES)" \
	    "$(MULTILIB_EXCEPTIONS)" \
	    "$(MULTILIB_EXTRA_OPTS)" \
	    "$(MULTILIB_EXCLUSIONS)" \
	    "$(MULTILIB_OSDIRNAMES)" \
	    "$(MULTILIB_REQUIRED)" \
	    "$(if $(MULTILIB_OSDIRNAMES),,$(MULTIARCH_DIRNAME))" \
	    "$(MULTILIB_REUSE)" \
	    "@enable_multilib@" \
	    > tmp-mlib.h; \
	else \
	  $(SHELL) $(srcdir)/genmultilib '' '' '' '' '' '' '' '' \
	    "$(MULTIARCH_DIRNAME)" '' no \
	    > tmp-mlib.h; \
	fi
	$(SHELL) $(srcdir)/../move-if-change tmp-mlib.h multilib.h
	$(STAMP) s-mlib
```

No C/C++ compiler is invoked by this recipe. The tools used are the POSIX
shell, the `genmultilib` script, `move-if-change` (which atomically replaces
`multilib.h` only when the content changes), and `$(STAMP)` (which writes the
`s-mlib` stamp file so Make knows the target is up to date).

### `genmultilib` script

`src/gcc/gcc/genmultilib` is a POSIX shell script (~560 lines). It receives
11 positional arguments: 9 `MULTILIB_*` make variables (`OPTIONS`, `DIRNAMES`,
`MATCHES`, `EXCEPTIONS`, `EXTRA_OPTS`, `EXCLUSIONS`, `OSDIRNAMES`, `REQUIRED`,
`REUSE`), the `MULTIARCH_DIRNAME` value (or empty string), and the
`@enable_multilib@` flag. It emits a C header containing:

```c
static const char *const multilib_raw[] = { /* one entry per required variant */ NULL };
static const char *const multilib_matches_raw[] = { /* option synonym rules */ NULL };
static const char *multilib_extra = "/* extra options string */";
static const char *const multilib_exclusions_raw[] = { /* runtime exclusions */ NULL };
static const char *const multilib_reuse_raw[] = { /* reuse mappings */ NULL };
static const char *multilib_options = "/* space-separated option groups */";
```

These arrays are consumed at **run time** by the GCC driver
(`src/gcc/gcc/gcc.cc`, which `#include "multilib.h"` at line 34) to resolve the
correct library subdirectory for a given set of compiler flags.

`multilib.h` is compiled into `gcc.o` and linked into the `arm-none-eabi-gcc`
driver binary. It is **not** installed as a standalone header file in the
toolchain output tree.

---

## Can `multilib.h` be regenerated for `rmprofile,aprofile` without recompiling GCC?

**Yes — with a small caveat.**

The `s-mlib` recipe itself performs no compilation. Running `make s-mlib` in an
existing build directory after editing `TM_MULTILIB_CONFIG` in the build
`Makefile` will regenerate `multilib.h` without touching any GCC source.

However, `gcc.cc` hard-codes `#include "multilib.h"`. Because `gcc.o` is linked
into **multiple** driver executables — `xgcc` (the C driver, `Makefile.in:2163`),
`xg++` (the C++ driver, whose `GXX_OBJS` includes all of `GCC_OBJS`,
`cp/Make-lang.in:80`), and `cpp` (`Makefile.in:2173`) — **all** of those must be
relinked. For the updated header to take effect in the installed toolchain, three
extra steps are required after `make s-mlib`:

1. Recompile `gcc.cc` → `gcc.o` (a **single-file recompile**).
2. Relink all affected driver executables: `xgcc`, `xg++`, and `cpp`.
3. Install the updated binaries via the GCC make install targets.

All steps together take seconds. They do **not** require recompiling the GCC
middle-end, back-end, or any runtime libraries.

**Mechanical combination of two separately-built `multilib.h` files is not
viable.** The output of `genmultilib` is a header fragment (included directly
into `gcc.cc` via `#include "multilib.h"`) containing uniquely-named static
arrays. Concatenating the outputs of an `rmprofile`-only build and an
`aprofile`-only build would produce duplicate symbol definitions in the
`gcc.cc` translation unit.
The script must be invoked **once** with the combined `MULTILIB_*` variable
values so that it can emit a single self-consistent header.

---

## Recommended merge approach for `multilib.h`

**Re-run `make s-mlib` in one of the parallel GCC build directories after
overriding `TM_MULTILIB_CONFIG` to `rmprofile,aprofile`.**

In the CI merge step, after the rmprofile and aprofile GCC builds have been
combined into `install-native/`, do the following inside one of the GCC build
directories (either the rmprofile or aprofile build dir works):

```bash
# Load BUILDDIR_NATIVE and INSTALLDIR_NATIVE (and other shared variables)
source ./build-common.sh

# The TM_MULTILIB_CONFIG variable and the s-mlib/gcc.o/xgcc targets all live
# in the gcc/ subdirectory of the GCC build tree:
cd "$BUILDDIR_NATIVE/gcc-final/gcc"

# 1. Override TM_MULTILIB_CONFIG in the gcc/ Makefile:
sed -i 's|^TM_MULTILIB_CONFIG=.*|TM_MULTILIB_CONFIG=rmprofile,aprofile|' Makefile

# 2. Regenerate multilib.h for the combined profile list
#    (no compilation, only runs genmultilib):
make s-mlib

# 3. Recompile only the driver translation unit:
make gcc.o

# 4. Relink all driver executables that include gcc.o
#    (xgcc/C driver, xg++/C++ driver, and cpp all link GCC_OBJS):
make xgcc xg++ cpp

# 5. Install the C driver (arm-none-eabi-gcc and versioned/target symlinks).
#    The build Makefile's --prefix was set to $INSTALLDIR_NATIVE at configure
#    time, so no DESTDIR override is needed:
make install-driver

# 6. Install the C++ driver (arm-none-eabi-g++, arm-none-eabi-c++ and symlinks):
make c++.install-common

# 7. Install the cpp preprocessor driver:
make install-cpp
```

> **Prerequisite:** `srcdir` in the `gcc/Makefile` must point to the
> checked-out GCC source tree, and the source tree must be present. Verify
> with `grep '^srcdir' gcc/Makefile` from the build root before running the
> steps above. `BUILDDIR_NATIVE` and `INSTALLDIR_NATIVE` are defined by the
> repo's `build-common.sh`.

This approach is safe because:
- `genmultilib` is deterministic and stateless — given the same input variables
  it always produces the same output.
- Only `gcc.o` and the driver binaries (`xgcc`, `xg++`, `cpp`) change; all
  other compiled objects and installed libraries remain untouched.
- The resulting `arm-none-eabi-gcc` and `arm-none-eabi-g++` drivers will
  correctly route both M-profile and A-profile flag combinations to their
  respective library subdirectories.
