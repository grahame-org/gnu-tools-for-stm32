#!/usr/bin/env bash
# Unit tests for
# .github/actions/compare-test-project-artifacts/compare-test-project-artifacts.sh
#
# Run with: bash tests/test-compare-test-project-artifacts.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/.github/actions/compare-test-project-artifacts/compare-test-project-artifacts.sh"

# shellcheck source=tests/test-helpers.sh
. "$SCRIPT_DIR/test-helpers.sh"

_TMPDIR=$(mktemp -d)
trap 'rm -rf "$_TMPDIR"' EXIT

# Run the script with explicit REFERENCE_DIR and BUILD_DIR.
run_compare() {
    local ref_dir="$1" build_dir="$2"
    REFERENCE_DIR="$ref_dir" BUILD_DIR="$build_dir" bash "$SCRIPT"
}

# ---------------------------------------------------------------------------
# Test group 1: Missing reference directory → exit 1 + error message
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 1: Missing reference directory ==="

_ref="${_TMPDIR}/no-such-ref"
_build="${_TMPDIR}/build1"
mkdir -p "$_build"

_status=0
_out=$(run_compare "$_ref" "$_build" 2>&1) || _status=$?
assert_eq "missing ref dir: exit 1" "1" "$_status"
assert_contains "missing ref dir: error mentions 'Reference directory'" \
    "$_out" "Reference directory"
assert_contains "missing ref dir: error includes the path" \
    "$_out" "$_ref"

# ---------------------------------------------------------------------------
# Test group 2: No .bin files in reference directory → exit 1
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 2: No .bin files in reference directory ==="

_ref="${_TMPDIR}/empty-ref"
_build="${_TMPDIR}/build2"
mkdir -p "$_ref" "$_build"

_status=0
_out=$(run_compare "$_ref" "$_build" 2>&1) || _status=$?
assert_eq "empty ref dir: exit 1" "1" "$_status"
assert_contains "empty ref dir: reports no artifacts found" \
    "$_out" "No reference artifacts found"

# Non-.bin files must NOT count as reference artifacts.
touch "$_ref/notes.txt" "$_ref/output.map" "$_ref/firmware.hex"
_status=0
_out=$(run_compare "$_ref" "$_build" 2>&1) || _status=$?
assert_eq "only non-bin files in ref: exit 1" "1" "$_status"
assert_contains "only non-bin files: reports no artifacts found" \
    "$_out" "No reference artifacts found"

# ---------------------------------------------------------------------------
# Test group 3: Single matching .bin file → exit 0
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 3: Single matching .bin file ==="

_ref="${_TMPDIR}/ref3"
_build="${_TMPDIR}/build3"
mkdir -p "$_ref" "$_build"
printf '\x00\x01\x02\x03' > "$_ref/firmware.bin"
cp "$_ref/firmware.bin" "$_build/firmware.bin"

_status=0
_out=$(run_compare "$_ref" "$_build" 2>&1) || _status=$?
assert_eq "single match: exit 0" "0" "$_status"
assert_contains "single match: PASS line for filename" \
    "$_out" "PASS: firmware.bin"
assert_contains "single match: overall success message" \
    "$_out" "All artifacts match"

# ---------------------------------------------------------------------------
# Test group 4: Built file missing → exit 1
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 4: Built file is absent ==="

_ref="${_TMPDIR}/ref4"
_build="${_TMPDIR}/build4"
mkdir -p "$_ref" "$_build"
printf '\x00\x01' > "$_ref/missing.bin"

_status=0
_out=$(run_compare "$_ref" "$_build" 2>&1) || _status=$?
assert_eq "missing built file: exit 1" "1" "$_status"
assert_contains "missing built file: FAIL message" \
    "$_out" "FAIL:"
assert_contains "missing built file: mentions filename" \
    "$_out" "missing.bin"

# ---------------------------------------------------------------------------
# Test group 5: Files differ (same name, different content) → exit 1
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 5: File content differs ==="

_ref="${_TMPDIR}/ref5"
_build="${_TMPDIR}/build5"
mkdir -p "$_ref" "$_build"
printf '\x00\x01\x02\x03' > "$_ref/firmware.bin"
printf '\x04\x05\x06\x07' > "$_build/firmware.bin"

_status=0
_out=$(run_compare "$_ref" "$_build" 2>&1) || _status=$?
assert_eq "different content: exit 1" "1" "$_status"
assert_contains "different content: FAIL line" \
    "$_out" "FAIL: firmware.bin"
assert_contains "different content: 'differs from reference' message" \
    "$_out" "differs from reference"

# The error report must include both sizes.
assert_contains "different content: reference size shown" \
    "$_out" "reference size"
assert_contains "different content: built size shown" \
    "$_out" "built size"

# ---------------------------------------------------------------------------
# Test group 6: Multiple files, partial failure → exit 1
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 6: Multiple files, partial failure ==="

_ref="${_TMPDIR}/ref6"
_build="${_TMPDIR}/build6"
mkdir -p "$_ref" "$_build"
printf '\x00\x01' > "$_ref/good.bin"
cp "$_ref/good.bin" "$_build/good.bin"
printf '\x00\x01\x02\x03' > "$_ref/bad.bin"
printf '\x04\x05\x06\x07' > "$_build/bad.bin"

_status=0
_out=$(run_compare "$_ref" "$_build" 2>&1) || _status=$?
assert_eq "partial failure: exit 1" "1" "$_status"
assert_contains "partial failure: PASS for good.bin" \
    "$_out" "PASS: good.bin"
assert_contains "partial failure: FAIL for bad.bin" \
    "$_out" "FAIL: bad.bin"

# ---------------------------------------------------------------------------
# Test group 7: Multiple files, all matching → exit 0
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 7: Multiple matching files ==="

_ref="${_TMPDIR}/ref7"
_build="${_TMPDIR}/build7"
mkdir -p "$_ref" "$_build"
printf '\x00\x01' > "$_ref/a.bin"
printf '\xAA\xBB\xCC' > "$_ref/b.bin"
cp "$_ref/a.bin" "$_build/a.bin"
cp "$_ref/b.bin" "$_build/b.bin"

_status=0
_out=$(run_compare "$_ref" "$_build" 2>&1) || _status=$?
assert_eq "all matching: exit 0" "0" "$_status"
assert_contains "all matching: PASS for a.bin" \
    "$_out" "PASS: a.bin"
assert_contains "all matching: PASS for b.bin" \
    "$_out" "PASS: b.bin"
assert_contains "all matching: overall success message" \
    "$_out" "All artifacts match"

# ---------------------------------------------------------------------------
# Test group 8: One match, one missing in build dir → exit 1
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 8: One match, one missing in build ==="

_ref="${_TMPDIR}/ref8"
_build="${_TMPDIR}/build8"
mkdir -p "$_ref" "$_build"
printf '\x00\x01' > "$_ref/present.bin"
cp "$_ref/present.bin" "$_build/present.bin"
printf '\x02\x03' > "$_ref/absent.bin"
# absent.bin not copied to build dir

_status=0
_out=$(run_compare "$_ref" "$_build" 2>&1) || _status=$?
assert_eq "one missing: exit 1" "1" "$_status"
assert_contains "one missing: PASS for present.bin" \
    "$_out" "PASS: present.bin"
assert_contains "one missing: FAIL for absent.bin" \
    "$_out" "FAIL:"
assert_contains "one missing: mentions absent.bin" \
    "$_out" "absent.bin"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

print_test_results
