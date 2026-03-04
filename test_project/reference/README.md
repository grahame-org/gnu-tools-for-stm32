# Reference artefacts

The files contained in this directory have were built from the test_project, using the toolchain included in CubeIDE 1.19.0.

It is expected that when the test_project is built using the dockerised version of the toolchain the exact same binaries as these reference files be created.

## Artefacts compared in CI

Only `.bin` and `.hex` files are compared byte-for-byte in CI. The `.elf` and `.map` files are excluded from comparison because they embed build-system absolute paths that differ between the Windows/CubeIDE reference build and a Linux CI build:

- `.elf` — DWARF debug-info sections contain absolute source and toolchain paths.
- `.map` — linker map contains absolute paths to the toolchain library archives.

The `.bin` and `.hex` outputs are raw load-segment dumps and do not contain these paths, so they are suitable for a reproducible byte-for-byte check.
