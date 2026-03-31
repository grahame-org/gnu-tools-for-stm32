# STM32 Toolchain Action

Run CMake configure and build for a bare-metal STM32 project inside the pre-built `arm-none-eabi` GNU toolchain container.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `src-path` | No | `.` | Path to the CMake project directory containing `arm-none-eabi-gcc.cmake` |
| `build-dir` | No | `<src-path>/build` | CMake binary directory |

## Usage

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: grahame-org/gnu-tools-for-stm32/docker-action@v0.0.0  # x-release-please-version
    with:
      src-path: .
```

The action automatically runs:

```sh
cmake -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE=arm-none-eabi-gcc.cmake \
  -DCMAKE_C_COMPILER=arm-none-eabi-gcc \
  -DCMAKE_CXX_COMPILER=arm-none-eabi-g++ \
  -B build -S .
cmake --build build -- -j$(nproc)
```

## Notes

- `arm-none-eabi-gcc` and all related toolchain binaries are on `$PATH` inside the container.
- The GitHub Actions workspace is mounted and available as the working directory.
- Your project must have an `arm-none-eabi-gcc.cmake` toolchain file at the root of `src-path`.
- For full documentation see `docs/docker-action.md` (forthcoming).
