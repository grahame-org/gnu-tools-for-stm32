#!/usr/bin/env bash
# Compare built test_project artifacts byte-for-byte against reference binaries.
# Only .bin files are compared; .elf, .map, and .hex are skipped as non-portable
# across platforms and toolchain versions.
#
# Environment variables:
#   REFERENCE_DIR  Path to reference artifacts directory (default: test_project/reference)
#   BUILD_DIR      Path to built artifacts directory    (default: test_project/build)

set -euo pipefail

REFERENCE_DIR="${REFERENCE_DIR:-test_project/reference}"
BUILD_DIR="${BUILD_DIR:-test_project/build}"

if [ ! -d "${REFERENCE_DIR}" ]; then
  echo "ERROR: Reference directory '${REFERENCE_DIR}' does not exist."
  exit 1
fi

PASS=true
compared=0
for ref_file in "${REFERENCE_DIR}"/*; do
  [ -f "${ref_file}" ] || continue
  # Skip documentation files
  case "${ref_file}" in *.md) continue ;; esac
  # Skip files known to differ between the Windows/CubeIDE reference
  # build and a Linux CI build:
  #   .elf — DWARF debug-info sections embed absolute source/toolchain paths.
  #   .map — linker map contains absolute paths to toolchain library archives.
  #   .hex — Intel HEX encoding can vary between objcopy versions/platforms.
  # Only .bin (raw binary dump of load segments) is a meaningful
  # byte-for-byte check across platforms.
  case "${ref_file}" in *.elf | *.map | *.hex) continue ;; esac
  artifact_name=$(basename "${ref_file}")
  built_file="${BUILD_DIR}/${artifact_name}"
  if [ ! -f "${built_file}" ]; then
    echo "FAIL: ${artifact_name} not found in build output"
    PASS=false
  elif cmp --silent "${ref_file}" "${built_file}"; then
    echo "PASS: ${artifact_name} matches reference"
  else
    echo "FAIL: ${artifact_name} differs from reference"
    echo "  reference size : $(wc -c < "${ref_file}") bytes"
    echo "  built size     : $(wc -c < "${built_file}") bytes"
    PASS=false
  fi
  compared=$((compared + 1))
done

if [ "${compared}" -eq 0 ]; then
  echo "ERROR: No reference artifacts found to compare."
  exit 1
fi
if [ "${PASS}" != "true" ]; then
  echo "One or more artifacts differ from the reference binaries."
  exit 1
fi
echo "All artifacts match reference binaries."
