# Reference artefacts

The files contained in this directory have were built from the test_project, using the toolchain included in CubeIDE 1.19.0.

It is expected that when the test_project is built using the dockerised version of the toolchain the exact same binaries as these reference files be created.

## Artefacts compared in CI

Only `.bin` files are compared byte-for-byte in CI. The `.elf`, `.map`, and `.hex` files are excluded from comparison:

- `.elf` — DWARF debug-info sections contain absolute source and toolchain paths that differ between Windows and Linux builds.
- `.map` — linker map contains absolute paths to the toolchain library archives.
- `.hex` — Intel HEX encoding can vary between `objcopy` versions and platforms.

The `.bin` output is a raw binary dump of the load segments and does not contain build-system paths, making it the only artifact suitable for a reproducible byte-for-byte check across platforms.
