#!/usr/bin/env bash
# Unit tests for build-toolchain.sh argument validation.
# Covers --skip_stages, --skip_steps, --build_type, and unknown flags via
# subprocess execution so integration with parse_toolchain_args() is tested.
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
# Test group 2: Invalid/typo stage names → exit 1 + error message
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 2: Invalid stage names rejected ==="

_status=0; _out=$(bash "$SCRIPT" "${SKIP_ALL[@]}" --skip_stages=binutis 2>&1) || _status=$?
assert_eq "binutis (typo): exits with status 1" "1" "$_status"
assert_contains "binutis (typo): error message names the unknown stage" \
    "$_out" "Unknown build stage: binutis"

_status=0; _out=$(bash "$SCRIPT" "${SKIP_ALL[@]}" --skip_stages=nosuchthing 2>&1) || _status=$?
assert_eq "nosuchthing: exits with status 1" "1" "$_status"
assert_contains "nosuchthing: error message names the unknown stage" \
    "$_out" "Unknown build stage: nosuchthing"

_status=0; _out=$(bash "$SCRIPT" "${SKIP_ALL[@]}" --skip_stages=Binutils 2>&1) || _status=$?
assert_eq "wrong capitalisation (Binutils): exits with status 1" "1" "$_status"

_status=0; _out=$(bash "$SCRIPT" "${SKIP_ALL[@]}" --skip_stages=gcc 2>&1) || _status=$?
assert_eq "prefix only (gcc): exits with status 1" "1" "$_status"

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

_status=0; _out=$(bash "$SCRIPT" "${SKIP_ALL[@]}" --skip_stages=binutils,binutis 2>&1) || _status=$?
assert_eq "binutils,binutis (valid+invalid): exits with status 1" "1" "$_status"
assert_contains "valid+invalid mix: error message names the invalid stage" \
    "$_out" "Unknown build stage: binutis"

_status=0; _out=$(bash "$SCRIPT" "${SKIP_ALL[@]}" --skip_stages=binutis,binutils 2>&1) || _status=$?
assert_eq "binutis,binutils (invalid+valid): exits with status 1" "1" "$_status"

# ---------------------------------------------------------------------------
# Test group 5: Invalid --skip_steps value → exit 1 + error message
# ---------------------------------------------------------------------------
# These tests run WITHOUT the SKIP_ALL guard so that parse_toolchain_args()
# hits the error path before any build work begins.

echo ""
echo "=== Group 5: Invalid --skip_steps values rejected ==="

_status=0; _out=$(bash "$SCRIPT" --skip_steps=nosuchstep 2>&1) || _status=$?
assert_eq "nosuchstep: exits with status 1" "1" "$_status"
assert_contains "nosuchstep: error names the unknown step" \
    "$_out" "Unknown build steps: nosuchstep"

_status=0; _out=$(bash "$SCRIPT" --skip_steps=STRIP 2>&1) || _status=$?
assert_eq "STRIP (wrong case): exits with status 1" "1" "$_status"
assert_contains "STRIP: error names the unknown step" \
    "$_out" "Unknown build steps: STRIP"

_status=0; _out=$(bash "$SCRIPT" --skip_steps=manual,nosuchstep 2>&1) || _status=$?
assert_eq "manual,nosuchstep (valid+invalid): exits with status 1" "1" "$_status"
assert_contains "manual,nosuchstep: error names the invalid step" \
    "$_out" "Unknown build steps: nosuchstep"

# ---------------------------------------------------------------------------
# Test group 6: Invalid --build_type value → exit 1 + error message
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 6: Invalid --build_type values rejected ==="

_status=0; _out=$(bash "$SCRIPT" "${SKIP_ALL[@]}" --build_type=badtype 2>&1) || _status=$?
assert_eq "badtype: exits with status 1" "1" "$_status"
assert_contains "badtype: error names the unknown type" \
    "$_out" "Unknown build type: badtype"

_status=0; _out=$(bash "$SCRIPT" "${SKIP_ALL[@]}" --build_type=Native 2>&1) || _status=$?
assert_eq "Native (wrong case): exits with status 1" "1" "$_status"
assert_contains "Native: error names the unknown type" \
    "$_out" "Unknown build type: Native"

_status=0; _out=$(bash "$SCRIPT" "${SKIP_ALL[@]}" --build_type=native,badtype 2>&1) || _status=$?
assert_eq "native,badtype (valid+invalid): exits with status 1" "1" "$_status"
assert_contains "native,badtype: error names the bad type" \
    "$_out" "Unknown build type: badtype"

# ---------------------------------------------------------------------------
# Test group 7: Unknown flags → exit 1
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 7: Unknown flags rejected ==="

_status=0; _out=$(bash "$SCRIPT" --unknown-flag 2>&1) || _status=$?
assert_eq "--unknown-flag: exits with status 1" "1" "$_status"

_status=0; _out=$(bash "$SCRIPT" "${SKIP_ALL[@]}" --no-such-option=value 2>&1) || _status=$?
assert_eq "--no-such-option=value: exits with status 1" "1" "$_status"

print_test_results
