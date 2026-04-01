#!/bin/sh
# Entrypoint for the GNU Tools for STM32 container action.
# Usage: entrypoint.sh [SOURCE_DIR [BUILD_DIR]]
#   SOURCE_DIR  Path to a CMake project with arm-none-eabi-gcc.cmake (default: .)
#   BUILD_DIR   CMake binary directory (default: SOURCE_DIR/build)
set -e
SOURCE_DIR="${1:-.}"
if [ ! -d "${SOURCE_DIR}" ]; then
    echo "Error: SOURCE_DIR '${SOURCE_DIR}' does not exist or is not a directory" >&2
    exit 1
fi
if [ ! -f "${SOURCE_DIR}/arm-none-eabi-gcc.cmake" ]; then
    echo "Error: ${SOURCE_DIR}/arm-none-eabi-gcc.cmake not found" >&2
    exit 1
fi
# Convert to absolute path so cmake resolves CMAKE_TOOLCHAIN_FILE correctly
# regardless of how CMake resolves relative paths (behaviour varies by version).
SOURCE_DIR="$(cd "${SOURCE_DIR}" && pwd)"
BUILD_DIR="${2:-${SOURCE_DIR}/build}"
cmake -G "Unix Makefiles" \
    -DCMAKE_TOOLCHAIN_FILE="${SOURCE_DIR}/arm-none-eabi-gcc.cmake" \
    -DCMAKE_C_COMPILER=arm-none-eabi-gcc \
    -DCMAKE_CXX_COMPILER=arm-none-eabi-g++ \
    -B "${BUILD_DIR}" \
    -S "${SOURCE_DIR}"
cmake --build "${BUILD_DIR}" -- -j"$(nproc)"
