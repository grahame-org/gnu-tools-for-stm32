#!/usr/bin/env bash
# Unit tests for build-prerequisites.sh argument validation.
#
# Run with: bash tests/test-build-prerequisites.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/build-prerequisites.sh"

# shellcheck source=tests/test-helpers.sh
. "$SCRIPT_DIR/test-helpers.sh"

# Flags that skip all build work: passing both native and mingw to --skip_steps
# causes build-prerequisites.sh to exit 0 immediately after the native section
# (line ~226) without touching any build directories.  These flags are embedded
# directly in each assert call so each test is self-contained.

# ---------------------------------------------------------------------------
# Test group 1: --help / -h → exit 1 with usage
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 1: --help / -h ==="

assert_exit_status "--help exits with status 1" 1 \
    bash "$SCRIPT" --help

_out=$(bash "$SCRIPT" --help 2>&1) || true
assert_contains "--help output contains 'skip_steps'" \
    "$_out" "--skip_steps="

assert_exit_status "-h exits with status 1" 1 \
    bash "$SCRIPT" -h

# ---------------------------------------------------------------------------
# Test group 2: Unknown arguments → exit 1
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 2: Unknown arguments ==="

assert_exit_status "unknown flag exits with status 1" 1 \
    bash "$SCRIPT" --unknown-flag

assert_exit_status "bare positional arg exits with status 1" 1 \
    bash "$SCRIPT" somepositionalarg

# ---------------------------------------------------------------------------
# Test group 3: Unknown skip steps → exit 1 with error message
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 3: Unknown --skip_steps value ==="

_status=0
_out=$(bash "$SCRIPT" --skip_steps=bogus 2>&1) || _status=$?
assert_eq "--skip_steps=bogus exits with status 1" "1" "$_status"
assert_contains "--skip_steps=bogus: error names the unknown step" \
    "$_out" "Unknown build steps: bogus"

_status=0
_out=$(bash "$SCRIPT" --skip_steps=native,bogus 2>&1) || _status=$?
assert_eq "--skip_steps=native,bogus exits with status 1" "1" "$_status"
assert_contains "--skip_steps=native,bogus: error names the unknown step" \
    "$_out" "Unknown build steps: bogus"

# ---------------------------------------------------------------------------
# Test group 4: Valid skip steps accepted (exit 0, no build work)
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 4: Valid --skip_steps values accepted ==="

assert_zero_exit "--skip_steps=native,mingw accepted" \
    bash "$SCRIPT" --skip_steps=native,mingw

assert_zero_exit "--skip_steps=native,mingw32 accepted (mingw32 alias)" \
    bash "$SCRIPT" --skip_steps=native,mingw32

assert_zero_exit "--skip_steps=howto,native,mingw accepted" \
    bash "$SCRIPT" --skip_steps=howto,native,mingw

assert_zero_exit "--skip_steps=package_bins,native,mingw accepted" \
    bash "$SCRIPT" --skip_steps=package_bins,native,mingw

assert_zero_exit "--skip_steps=package_sources,native,mingw accepted" \
    bash "$SCRIPT" --skip_steps=package_sources,native,mingw

assert_zero_exit "--skip_steps=md5_checksum,native,mingw accepted" \
    bash "$SCRIPT" --skip_steps=md5_checksum,native,mingw

assert_zero_exit "--skip_steps=strip,native,mingw accepted" \
    bash "$SCRIPT" --skip_steps=strip,native,mingw

print_test_results
