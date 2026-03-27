#!/usr/bin/env bash
# Unit tests for merge-gcc-final.sh.
#
# Run with: bash tests/test-merge-gcc-final.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/merge-gcc-final.sh"

# shellcheck source=tests/test-helpers.sh
. "$SCRIPT_DIR/test-helpers.sh"

# ---------------------------------------------------------------------------
# Shared temporary directory
# ---------------------------------------------------------------------------

_TMPDIR=$(mktemp -d)
trap 'rm -rf "$_TMPDIR"' EXIT

# ---------------------------------------------------------------------------
# Test group 1: Missing required arguments → non-zero exit
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 1: Missing required arguments ==="

assert_nonzero_exit "no args: exits non-zero" \
    bash "$SCRIPT"

assert_nonzero_exit "only --rmprofile-dir: exits non-zero (missing --aprofile-dir)" \
    bash "$SCRIPT" --rmprofile-dir=/tmp/fake-rmp

assert_nonzero_exit "only --rmprofile-dir and --aprofile-dir: exits non-zero (missing --output-dir)" \
    bash "$SCRIPT" --rmprofile-dir=/tmp/fake-rmp --aprofile-dir=/tmp/fake-ap

# ---------------------------------------------------------------------------
# Test group 2: Unknown argument → non-zero; --help → zero exit
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 2: Unknown argument / --help ==="

assert_nonzero_exit "unknown argument: exits non-zero" \
    bash "$SCRIPT" --unknown-option

assert_zero_exit "--help: exits zero" \
    bash "$SCRIPT" --help

# ---------------------------------------------------------------------------
# Test group 3: Non-existent input directories → non-zero exit
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 3: Non-existent input directories ==="

_APDIR3="$_TMPDIR/ap3"
_OUTDIR3="$_TMPDIR/out3"
mkdir -p "$_APDIR3" "$_OUTDIR3"

assert_nonzero_exit "non-existent rmprofile-dir: exits non-zero" \
    bash "$SCRIPT" \
        --rmprofile-dir="$_TMPDIR/no_such_rmprofile" \
        --aprofile-dir="$_APDIR3" \
        --output-dir="$_OUTDIR3"

_err3_rm=$(bash "$SCRIPT" \
    --rmprofile-dir="$_TMPDIR/no_such_rmprofile" \
    --aprofile-dir="$_APDIR3" \
    --output-dir="$_OUTDIR3" 2>&1 || true)
assert_contains "non-existent rmprofile-dir: error message names the path" \
    "$_err3_rm" "error: rmprofile-dir is not a directory: $_TMPDIR/no_such_rmprofile"

_RMDIR3="$_TMPDIR/rm3"
mkdir -p "$_RMDIR3"

assert_nonzero_exit "non-existent aprofile-dir: exits non-zero" \
    bash "$SCRIPT" \
        --rmprofile-dir="$_RMDIR3" \
        --aprofile-dir="$_TMPDIR/no_such_aprofile" \
        --output-dir="$_OUTDIR3"

_err3_ap=$(bash "$SCRIPT" \
    --rmprofile-dir="$_RMDIR3" \
    --aprofile-dir="$_TMPDIR/no_such_aprofile" \
    --output-dir="$_OUTDIR3" 2>&1 || true)
assert_contains "non-existent aprofile-dir: error message names the path" \
    "$_err3_ap" "error: aprofile-dir is not a directory: $_TMPDIR/no_such_aprofile"

# ---------------------------------------------------------------------------
# Test group 4: Output dir = input dir, or nested inside input dir → non-zero
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 4: Output dir safety guards ==="

_RM4="$_TMPDIR/rm4"
_AP4="$_TMPDIR/ap4"
mkdir -p "$_RM4" "$_AP4"

assert_nonzero_exit "output-dir = rmprofile-dir: exits non-zero" \
    bash "$SCRIPT" \
        --rmprofile-dir="$_RM4" \
        --aprofile-dir="$_AP4" \
        --output-dir="$_RM4"

assert_nonzero_exit "output-dir = aprofile-dir: exits non-zero" \
    bash "$SCRIPT" \
        --rmprofile-dir="$_RM4" \
        --aprofile-dir="$_AP4" \
        --output-dir="$_AP4"

assert_nonzero_exit "output-dir nested inside rmprofile-dir: exits non-zero" \
    bash "$SCRIPT" \
        --rmprofile-dir="$_RM4" \
        --aprofile-dir="$_AP4" \
        --output-dir="$_RM4/subdir"

assert_nonzero_exit "output-dir nested inside aprofile-dir: exits non-zero" \
    bash "$SCRIPT" \
        --rmprofile-dir="$_RM4" \
        --aprofile-dir="$_AP4" \
        --output-dir="$_AP4/subdir"

# ---------------------------------------------------------------------------
# Test group 5: aprofile tree missing arm-none-eabi/lib/ → non-zero + message
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 5: aprofile tree missing arm-none-eabi/lib/ ==="

_RM5="$_TMPDIR/rm5"
_AP5="$_TMPDIR/ap5"
_OUT5="$_TMPDIR/out5"
mkdir -p "$_RM5" "$_AP5" "$_OUT5"
# Give rmprofile tree a file so tar has something to copy.
echo "placeholder" > "$_RM5/placeholder"
# aprofile dir exists but has NO arm-none-eabi/lib/ subdirectory.

assert_nonzero_exit "missing aprofile arm-none-eabi/lib/: exits non-zero" \
    bash "$SCRIPT" \
        --rmprofile-dir="$_RM5" \
        --aprofile-dir="$_AP5" \
        --output-dir="$_OUT5" \
        --gcc-final-build-dir="$_TMPDIR/no-build-dir"

_err5=$(bash "$SCRIPT" \
    --rmprofile-dir="$_RM5" \
    --aprofile-dir="$_AP5" \
    --output-dir="$_OUT5" \
    --gcc-final-build-dir="$_TMPDIR/no-build-dir" 2>&1 || true)
assert_contains "missing arm-none-eabi/lib/: error message references path" \
    "$_err5" "error: aprofile tree is missing arm-none-eabi/lib/"

# ---------------------------------------------------------------------------
# Test group 6: Non-empty output dir → cleanup notice printed to stdout
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 6: Non-empty output dir cleanup notice ==="

_RM6="$_TMPDIR/rm6"
_AP6="$_TMPDIR/ap6"
_OUT6="$_TMPDIR/out6"
mkdir -p "$_RM6" "$_AP6" "$_OUT6"
echo "placeholder" > "$_RM6/placeholder"
mkdir -p "$_AP6/arm-none-eabi/lib"
echo "stale" > "$_OUT6/stale-file"

_stdout6=$(bash "$SCRIPT" \
    --rmprofile-dir="$_RM6" \
    --aprofile-dir="$_AP6" \
    --output-dir="$_OUT6" \
    --gcc-final-build-dir="$_TMPDIR/no-build-dir" 2>/dev/null || true)
assert_contains "non-empty output-dir: cleanup notice on stdout" \
    "$_stdout6" "output-dir is non-empty"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

print_test_results
