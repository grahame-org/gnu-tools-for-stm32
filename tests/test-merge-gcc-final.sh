#!/usr/bin/env bash
# Unit tests for merge-gcc-final.sh argument validation.
#
# Run with: bash tests/test-merge-gcc-final.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/merge-gcc-final.sh"

# shellcheck source=test-helpers.sh
. "$SCRIPT_DIR/test-helpers.sh"

_TMPDIR=$(mktemp -d)
trap 'rm -rf "$_TMPDIR"' EXIT

# ---------------------------------------------------------------------------
# Test group 1: Missing required arguments → non-zero exit
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 1: Missing required arguments ==="

assert_nonzero_exit "no args: exits non-zero" bash "$SCRIPT"
assert_nonzero_exit "missing --aprofile-dir and --output-dir: exits non-zero" \
    bash "$SCRIPT" "--rmprofile-dir=$_TMPDIR"
assert_nonzero_exit "missing --output-dir: exits non-zero" \
    bash "$SCRIPT" "--rmprofile-dir=$_TMPDIR" "--aprofile-dir=$_TMPDIR"

# ---------------------------------------------------------------------------
# Test group 2: Non-existent input directories → non-zero exit with clear error
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 2: Non-existent input directories ==="

_OUTDIR="$_TMPDIR/out"
mkdir -p "$_OUTDIR"

_NOEXIST="$_TMPDIR/no_such_dir"

assert_nonzero_exit "non-existent rmprofile-dir: exits non-zero" \
    bash "$SCRIPT" \
        "--rmprofile-dir=$_NOEXIST" \
        "--aprofile-dir=$_TMPDIR" \
        "--output-dir=$_OUTDIR"

_stderr_rm=$(bash "$SCRIPT" \
    "--rmprofile-dir=$_NOEXIST" \
    "--aprofile-dir=$_TMPDIR" \
    "--output-dir=$_OUTDIR" 2>&1 || true)
assert_contains "non-existent rmprofile-dir: error names the missing path" \
    "$_stderr_rm" "$_NOEXIST"

assert_nonzero_exit "non-existent aprofile-dir: exits non-zero" \
    bash "$SCRIPT" \
        "--rmprofile-dir=$_TMPDIR" \
        "--aprofile-dir=$_NOEXIST" \
        "--output-dir=$_OUTDIR"

_stderr_ap=$(bash "$SCRIPT" \
    "--rmprofile-dir=$_TMPDIR" \
    "--aprofile-dir=$_NOEXIST" \
    "--output-dir=$_OUTDIR" 2>&1 || true)
assert_contains "non-existent aprofile-dir: error names the missing path" \
    "$_stderr_ap" "$_NOEXIST"

# ---------------------------------------------------------------------------
# Test group 3: output-dir collision with input directories → non-zero exit
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 3: output-dir collision with input directories ==="

_RMDIR="$_TMPDIR/rmprofile"
_APDIR="$_TMPDIR/aprofile"
mkdir -p "$_RMDIR" "$_APDIR"

assert_nonzero_exit "output-dir same as rmprofile-dir: exits non-zero" \
    bash "$SCRIPT" \
        "--rmprofile-dir=$_RMDIR" \
        "--aprofile-dir=$_APDIR" \
        "--output-dir=$_RMDIR"

assert_nonzero_exit "output-dir same as aprofile-dir: exits non-zero" \
    bash "$SCRIPT" \
        "--rmprofile-dir=$_RMDIR" \
        "--aprofile-dir=$_APDIR" \
        "--output-dir=$_APDIR"

_NESTED_IN_RM="$_RMDIR/nested"
assert_nonzero_exit "output-dir inside rmprofile-dir: exits non-zero" \
    bash "$SCRIPT" \
        "--rmprofile-dir=$_RMDIR" \
        "--aprofile-dir=$_APDIR" \
        "--output-dir=$_NESTED_IN_RM"

_NESTED_IN_AP="$_APDIR/nested"
assert_nonzero_exit "output-dir inside aprofile-dir: exits non-zero" \
    bash "$SCRIPT" \
        "--rmprofile-dir=$_RMDIR" \
        "--aprofile-dir=$_APDIR" \
        "--output-dir=$_NESTED_IN_AP"

# ---------------------------------------------------------------------------
# Test group 4: Unknown argument → non-zero exit
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 4: Unknown argument ==="

assert_nonzero_exit "unknown arg: exits non-zero" \
    bash "$SCRIPT" "--unknown-flag=value"

# ---------------------------------------------------------------------------
# Test group 5: --help → zero exit
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 5: --help ==="

assert_zero_exit "--help: exits 0" bash "$SCRIPT" "--help"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

print_test_results
