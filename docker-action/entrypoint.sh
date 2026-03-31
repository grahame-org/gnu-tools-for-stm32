#!/bin/sh
# Entrypoint for the GNU Tools for STM32 container action.
# Usage: entrypoint.sh [SOURCE_DIR [BUILD_DIR]]
#   SOURCE_DIR  Path to a CMake project with arm-none-eabi-gcc.cmake (default: .)
#   BUILD_DIR   CMake binary directory (default: SOURCE_DIR/build)
set -e
SOURCE_DIR="${1:-.}"
BUILD_DIR="${2:-${SOURCE_DIR}/build}"
if [ ! -d "${SOURCE_DIR}" ]; then
    echo "Error: SOURCE_DIR '${SOURCE_DIR}' does not exist or is not a directory" >&2
    exit 1
fi
if [ ! -f "${SOURCE_DIR}/arm-none-eabi-gcc.cmake" ]; then
    echo "Error: ${SOURCE_DIR}/arm-none-eabi-gcc.cmake not found" >&2
    exit 1
fi
cmake -G "Unix Makefiles" \
    -DCMAKE_TOOLCHAIN_FILE="${SOURCE_DIR}/arm-none-eabi-gcc.cmake" \
    -B "${BUILD_DIR}" \
    -S "${SOURCE_DIR}"
cmake --build "${BUILD_DIR}" -- -j"$(nproc)"
