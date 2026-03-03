# Toolchain Test Suite Documentation

This document describes the test infrastructure bundled with each toolchain
component (GCC, binutils, GDB, newlib), how to invoke each suite for the
`arm-none-eabi` target, and which suites can feasibly run in GitHub Actions CI.

## Summary

| Component | Suite | CI-feasible? | Estimated runtime | Dependencies |
|-----------|-------|:------------:|-------------------|--------------|
| binutils  | `check-gas` (ARM) | ✅ Yes | ~5–10 min | DejaGnu, `arm-none-eabi-as` |
| binutils  | `check-ld` (ARM)  | ✅ Yes | ~10–20 min | DejaGnu, `arm-none-eabi-ld` |
| binutils  | `check-binutils`  | ✅ Yes | ~5–10 min | DejaGnu, `arm-none-eabi-objdump` etc. |
| GCC       | `check-gcc` (ARM) | ⚠️ Partial | 2–6 h | QEMU for execution tests |
| GDB       | `check-gdb`       | ⚠️ Partial | 2–4 h | QEMU / gdbserver for target tests |
| newlib    | `check-target-newlib` | ❌ Hardware | N/A | Physical board or QEMU |

---

## 1. Binutils (`src/binutils/`)

The binutils source tree contains several independently testable sub-packages.
All of the following suites use [DejaGnu](https://www.gnu.org/software/dejagnu/)
and run entirely on the build host — they only invoke the cross-tools, not the
target hardware.

### 1.1 `make check-gas` — GNU Assembler

**Testsuite location:** `src/binutils/gas/testsuite/`

The assembler test suite is the most ARM-rich suite in the build. Under
`gas/testsuite/gas/arm/` there are **611 ARM assembly source files** (.s), each
paired with a `.d` expected-output file that `gas` and `objdump` compare
against. Additional general ELF tests live in `gas/testsuite/gas/elf/`.

**How to invoke (cross-target):**

```bash
cd <build-dir>
make check-gas RUNTESTFLAGS="--target arm-none-eabi gas/arm/arm.exp"
```

Run all ARM tests:

```bash
make check-gas RUNTESTFLAGS="gas/arm/arm.exp"
```

**CI feasibility:** ✅ Fully feasible. Tests only require the host-side
`arm-none-eabi-as` binary and `objdump`. No target hardware or QEMU needed.

**Estimated runtime:** 5–10 minutes on a GitHub-hosted `ubuntu-latest` runner.

**Key dependencies:** `dejagnu`, `expect`, `tcl`, `arm-none-eabi-as`,
`arm-none-eabi-objdump`.

---

### 1.2 `make check-ld` — GNU Linker

**Testsuite location:** `src/binutils/ld/testsuite/`

The linker test suite includes a dedicated `ld-arm/` directory with **680 ARM
test cases** covering Thumb interworking, relocations, CMSE, and more.
Tests run by invoking `arm-none-eabi-ld` (or `arm-none-eabi-gcc -nostdlib`) on
the host, then inspecting the resulting object files with `objdump` or `nm`.

**How to invoke:**

```bash
cd <build-dir>
make check-ld RUNTESTFLAGS="--target arm-none-eabi ld-arm/arm-elf.exp"
```

**CI feasibility:** ✅ Fully feasible. No target execution required.

**Estimated runtime:** 10–20 minutes on a GitHub-hosted runner (the ARM subset
alone is faster; full suite across all architectures takes longer).

**Key dependencies:** `dejagnu`, `expect`, `tcl`, `arm-none-eabi-ld`,
`arm-none-eabi-as`, `arm-none-eabi-objdump`, `arm-none-eabi-nm`.

---

### 1.3 `make check-binutils` — binutils utilities

**Testsuite location:** `src/binutils/binutils/testsuite/`

Tests `objdump`, `nm`, `ar`, `readelf`, `addr2line`, and related tools. An
`arm/` sub-directory contains ARM-specific disassembly golden-output tests.
The demangler tests (`binutils-all/`) are host-only and architecture-agnostic.

**How to invoke:**

```bash
cd <build-dir>
make check-binutils
```

**CI feasibility:** ✅ Fully feasible.

**Estimated runtime:** 5–10 minutes.

**Key dependencies:** `dejagnu`, `expect`, `tcl`, all `arm-none-eabi-*` binaries.

---

### 1.4 Other binutils test targets

| Make target | Location | Notes |
|-------------|----------|-------|
| `check-libiberty` | `libiberty/testsuite/` | Pure C unit tests for demangling, string utilities. Host-only, ~1 min. |
| `check-libctf` | `libctf/testsuite/` | Tests the CTF debugging format library. Host-only, ~2 min. |
| `check-libsframe` | `libsframe/testsuite/` | Tests the SFrame stack-trace library. Host-only, ~1 min. |

All of the above are CI-feasible with no special dependencies beyond a C
compiler and `dejagnu`.

---

## 2. GCC (`src/gcc/`)

### 2.1 `make check-gcc` — C compiler

**Testsuite location:** `src/gcc/gcc/testsuite/`

Relevant ARM sub-directories:

- `gcc.target/arm/` — **867 test files** covering architecture-specific code
  generation, instruction selection, Thumb, MVE, NEON, FPU options, etc.
- `gcc.dg/` — ~2 000 general C diagnostics and optimization tests; many are
  execution tests that require running the compiled binary.
- `c-c++-common/` — shared C/C++ tests.

**How to invoke (compile-only / non-execution tests):**

DejaGnu uses the concept of a *board* to decide whether to run produced
binaries. For a bare-metal cross-compiler use the `arm-none-eabi` board
without an execution engine to restrict the run to compile-and-assemble
tests only:

```bash
cd <build-dir>/gcc
make check-gcc RUNTESTFLAGS="--target_board=arm-none-eabi gcc.target/arm/arm.exp"
```

To also run execution tests via QEMU:

```bash
make check-gcc RUNTESTFLAGS="--target_board=qemu-m3 gcc.target/arm/arm.exp"
```

A suitable `qemu-m3.exp` board file must be written and placed in the
testsuite `boards/` directory (see §5 below).

**CI feasibility:**
- ⚠️ **Compile-only tests:** feasible; only the cross-compiler is needed.
- ⚠️ **Execution tests:** require QEMU (`qemu-system-arm`). Feasible in CI
  with the `qemu-system-arm` package, but the full suite is very large.

**Estimated runtime:**
- Compile-only ARM tests: ~30–60 minutes.
- Full execution suite: 2–6 hours (not recommended for every PR).

**Key dependencies:** `dejagnu`, `expect`, `tcl`, `arm-none-eabi-gcc`,
optionally `qemu-system-arm`.

---

### 2.2 Other GCC test targets

| Make target | Location | Notes |
|-------------|----------|-------|
| `check-c++` (`g++`) | `gcc.testsuite/g++.dg/` | C++ tests. Execution tests need QEMU or a native target. |
| `check-libiberty` | `libiberty/testsuite/` | Same host-only demangler tests as in binutils. ~1 min. |
| `check-libgomp` | `libgomp/testsuite/` | OpenMP tests. Not applicable to bare-metal. |
| `check-libffi` | `libffi/testsuite/` | FFI tests. Not applicable to bare-metal. |

---

## 3. GDB (`src/gdb/`)

### 3.1 `make check-gdb`

**Testsuite location:** `src/gdb/gdb/testsuite/`

The GDB testsuite uses DejaGnu with a *board* file that specifies how to
start a GDB session against a target. Available sub-suites relevant to ARM:

- `gdb.arch/` — **15 ARM-specific test files** (Thumb displacement stepping,
  CMSE, NEON, Cortex-M disassembly, etc.).
- `gdb.base/` — **1 285 test files** for general GDB functionality. Many
  require running a native or remote GDB session.
- `gdb.server/` — Tests for `gdbserver` remote connections (IPv4/IPv6, TCP).

**Existing config:** `src/gdb/gdb/testsuite/config/arm-ice.exp` delegates to
`monitor.exp` and is designed for JTAG/ICE hardware. It is **not** suitable
for CI without modification.

**Running against QEMU (gdbserver mode):**

The recommended CI approach is to use `gdbserver` together with QEMU (either
user-mode `qemu-arm` or system-mode `qemu-system-arm`). A board file such as
the following sketch would be placed in `gdb/testsuite/boards/arm-qemu.exp`:

```tcl
# boards/arm-qemu.exp — skeleton for QEMU-based GDB testing (replace values as needed)
load_lib gdbserver-support.exp
set_board_info gdb_protocol "remote"
set_board_info gdb_server_prog "gdbserver"
# Replace the host/port below with the actual connection endpoint:
set_board_info sockethost "localhost"
set_board_info gdb,socketport 1234
```

Then invoke:

```bash
cd <build-dir>
make check-gdb RUNTESTFLAGS="--target_board=arm-qemu gdb.arch/arm-*.exp"
```

**CI feasibility:**
- ⚠️ **Architecture-specific compile/disassembly tests:** feasible; can be
  scoped to `gdb.arch/arm-*.exp` files that do not need target execution.
- ⚠️ **gdb.base tests with gdbserver + QEMU:** feasible but complex; requires
  `qemu-arm` (user-mode) and carefully scoped test selection.
- ❌ **ICE/JTAG tests** (`config/arm-ice.exp`): require physical hardware —
  out of scope for CI.

**Estimated runtime:**
- ARM architecture tests only: ~10–20 minutes.
- Full `gdb.base` via QEMU: 2–4 hours.

**Key dependencies:** `dejagnu`, `expect`, `tcl`, `arm-none-eabi-gdb`,
`arm-none-eabi-gcc`, optionally `qemu-arm` / `qemu-system-arm`.

---

## 4. Newlib (`src/newlib/`)

### 4.1 `make check`

**Testsuite location:** `src/newlib/newlib/testsuite/`

Newlib's test suite consists of C programs that exercise the C library
functions (string, stdio, stdlib, math, etc.). The test runner uses DejaGnu
with a `passfail.exp` harness. Each sub-directory (e.g., `newlib.string/`,
`newlib.stdio/`, `newlib.stdlib/`) contains source files that are
cross-compiled and then **executed on the target**.

Because newlib is a bare-metal C library, executing the resulting binaries
requires either physical hardware or a QEMU system-mode emulator with
semihosting support.

**How to invoke:**

```bash
cd <build-dir>/arm-none-eabi/newlib
make check RUNTESTFLAGS="--target_board=arm-qemu-m3-semihosting"
```

A `qemu-m3-semihosting` board file would configure `qemu-system-arm` with:

```
-machine lm3s811evb -semihosting-config enable=on,target=native
```

**CI feasibility:** ❌ Requires QEMU system mode with semihosting or physical
hardware. While technically possible with `qemu-system-arm`, building newlib's
test binaries and booting them in QEMU system mode is complex and slow.
**Not recommended for initial CI workflows.**

**Estimated runtime:** Not estimated — substantial effort to set up.

**Key dependencies:** `dejagnu`, `expect`, `tcl`, `arm-none-eabi-gcc`,
`qemu-system-arm` with an appropriate Cortex-M machine, or physical hardware.

---

## 5. Recommended CI Priorities

Based on the analysis above, the following phased approach is recommended:

### Phase 1 — Host-only tests (implement first)

These suites run entirely on the CI host without QEMU or hardware. They are
fast, reliable, and give high confidence that the assembler, linker, and
utility programs produce correct output for ARM targets.

| Priority | Suite | Make target | Estimated runtime |
|:--------:|-------|-------------|-------------------|
| 1 | GNU Assembler (ARM) | `make check-gas` | ~5–10 min |
| 2 | GNU Linker (ARM) | `make check-ld` | ~10–20 min |
| 3 | binutils utilities | `make check-binutils` | ~5–10 min |
| 4 | libiberty | `make check-libiberty` | ~1 min |
| 5 | libctf / libsframe | `make check-libctf check-libsframe` | ~3 min |

Suggested total runtime for Phase 1: **~25–45 minutes**.

### Phase 2 — Compile-only GCC tests (after Phase 1 is stable)

Restrict the GCC test run to ARM compile-and-assemble tests (no execution),
which avoids needing QEMU while still covering code-generation correctness.

| Priority | Suite | Make target | Estimated runtime |
|:--------:|-------|-------------|-------------------|
| 6 | GCC ARM compile tests | `make check-gcc` (scoped) | ~30–60 min |

### Phase 3 — QEMU execution tests (optional, nightly only)

These require `qemu-system-arm` or `qemu-arm` (user-mode) and are recommended
only for scheduled/nightly runs, not every PR:

| Priority | Suite | Make target | Estimated runtime |
|:--------:|-------|-------------|-------------------|
| 7 | GCC ARM execution tests | `make check-gcc` (full) | 2–6 h |
| 8 | GDB ARM arch tests | `make check-gdb` (scoped) | ~20 min |

### Out of scope for CI

- **Newlib `check`** — requires system-mode QEMU with semihosting (high
  complexity, low return for initial CI investment).
- **GDB ICE/hardware tests** (`config/arm-ice.exp`) — require physical JTAG
  hardware.
- **OpenMP / libgomp tests** — not applicable to bare-metal toolchain.

---

## 6. Infrastructure Notes

### DejaGnu

All suites listed above use DejaGnu as the test framework. Install it on
Ubuntu with:

```bash
sudo apt-get install dejagnu
```

### QEMU

For Phase 2/3 execution tests, install `qemu-system-arm`:

```bash
sudo apt-get install qemu-system-arm
```

For GDB user-mode tests:

```bash
sudo apt-get install qemu-user
```

### Board files

A board file describes how DejaGnu compiles and runs test programs for a
given target. Custom board files for Cortex-M QEMU emulation should be placed
in the relevant `testsuite/boards/` directory and referenced via
`--target_board=<name>` when invoking `make check`.

---

*Related: [Issue #30](https://github.com/grahame-white/gnu-tools-for-stm32/issues/30)*
