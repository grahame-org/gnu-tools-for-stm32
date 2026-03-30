#!/usr/bin/env bash
# Unit tests for build-toolchain.sh --skip_stages validation.
#
# Run with: bash tests/test-build-toolchain.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/build-toolchain.sh"

# shellcheck source=tests/test-helpers.sh
. "$SCRIPT_DIR/test-helpers.sh"

# Flags that suppress all real build work so tests focus on the validation
# block at the top of the script.
SKIP_ALL=("--skip_steps=native,mingw,package_sources,md5_checksum,package_bins,manual")

# ---------------------------------------------------------------------------
# Test group 1: All seven valid stage names → exit 0
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 1: Valid stage names accepted ==="

assert_zero_exit "binutils: valid stage name accepted" \
    bash "$SCRIPT" "${SKIP_ALL[@]}" --skip_stages=binutils

assert_zero_exit "gcc-first: valid stage name accepted" \
    bash "$SCRIPT" "${SKIP_ALL[@]}" --skip_stages=gcc-first

assert_zero_exit "newlib: valid stage name accepted" \
    bash "$SCRIPT" "${SKIP_ALL[@]}" --skip_stages=newlib

assert_zero_exit "newlib-nano: valid stage name accepted" \
    bash "$SCRIPT" "${SKIP_ALL[@]}" --skip_stages=newlib-nano

assert_zero_exit "gcc-final: valid stage name accepted" \
    bash "$SCRIPT" "${SKIP_ALL[@]}" --skip_stages=gcc-final

assert_zero_exit "gcc-size-libstdcxx: valid stage name accepted" \
    bash "$SCRIPT" "${SKIP_ALL[@]}" --skip_stages=gcc-size-libstdcxx

assert_zero_exit "gdb: valid stage name accepted" \
    bash "$SCRIPT" "${SKIP_ALL[@]}" --skip_stages=gdb

# ---------------------------------------------------------------------------
# Test group 2: Invalid/typo stage names → exit 1 + error message on stderr
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 2: Invalid stage names rejected ==="

assert_nonzero_exit "binutis (typo): exits non-zero" \
    bash "$SCRIPT" "${SKIP_ALL[@]}" --skip_stages=binutis

_err2a=$(bash "$SCRIPT" "${SKIP_ALL[@]}" --skip_stages=binutis 2>&1 || true)
assert_contains "binutis (typo): error message names the unknown stage" \
    "$_err2a" "Unknown build stage: binutis"

assert_nonzero_exit "nosuchthing: exits non-zero" \
    bash "$SCRIPT" "${SKIP_ALL[@]}" --skip_stages=nosuchthing

_err2b=$(bash "$SCRIPT" "${SKIP_ALL[@]}" --skip_stages=nosuchthing 2>&1 || true)
assert_contains "nosuchthing: error message names the unknown stage" \
    "$_err2b" "Unknown build stage: nosuchthing"

assert_nonzero_exit "wrong capitalisation (Binutils): exits non-zero" \
    bash "$SCRIPT" "${SKIP_ALL[@]}" --skip_stages=Binutils

assert_nonzero_exit "prefix only (gcc): exits non-zero" \
    bash "$SCRIPT" "${SKIP_ALL[@]}" --skip_stages=gcc

# ---------------------------------------------------------------------------
# Test group 3: Multiple valid stages together → exit 0
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 3: Multiple valid stages accepted ==="

assert_zero_exit "binutils,gcc-first: two valid stages accepted" \
    bash "$SCRIPT" "${SKIP_ALL[@]}" --skip_stages=binutils,gcc-first

assert_zero_exit "all seven stages: all valid stages together accepted" \
    bash "$SCRIPT" "${SKIP_ALL[@]}" \
    --skip_stages=binutils,gcc-first,newlib,newlib-nano,gcc-final,gcc-size-libstdcxx,gdb

# ---------------------------------------------------------------------------
# Test group 4: Mix of valid and invalid stages → exit 1
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 4: Mixed valid and invalid stages rejected ==="

assert_nonzero_exit "binutils,binutis (valid+invalid): exits non-zero" \
    bash "$SCRIPT" "${SKIP_ALL[@]}" --skip_stages=binutils,binutis

_err4a=$(bash "$SCRIPT" "${SKIP_ALL[@]}" --skip_stages=binutils,binutis 2>&1 || true)
assert_contains "valid+invalid mix: error message names the invalid stage" \
    "$_err4a" "Unknown build stage: binutis"

assert_nonzero_exit "binutis,binutils (invalid+valid): exits non-zero" \
    bash "$SCRIPT" "${SKIP_ALL[@]}" --skip_stages=binutis,binutils

print_test_results
