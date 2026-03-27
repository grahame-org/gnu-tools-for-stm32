#!/usr/bin/env bash
# Unit tests for merge-gcc-final.sh.
#
# Run with: bash tests/test-merge-gcc-final.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/merge-gcc-final.sh"

# shellcheck source=test-helpers.sh
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
# Test group 7: arm-none-eabi-gcc not present in merged output tree
#
# Steps 1 and 2 run successfully (rmprofile is copied, aprofile has
# arm-none-eabi/lib/ but no thumb/armv7-a* or armv8-a* dirs to overlay).
# Step 3 is skipped (no build dir).  Step 4 then fails because the output
# tree contains no arm-none-eabi-gcc binary.
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 7: arm-none-eabi-gcc missing from merged output tree ==="

_RM7="$_TMPDIR/rm7"
_AP7="$_TMPDIR/ap7"
_OUT7="$_TMPDIR/out7"
# Include lib/gcc/arm-none-eabi/ so the 'find' at Step 3 does not fail
# with a non-existent directory (set -e + pipefail would exit early).
mkdir -p "$_RM7/lib/gcc/arm-none-eabi" "$_AP7/arm-none-eabi/lib" "$_OUT7"
echo "placeholder" > "$_RM7/placeholder"

assert_nonzero_exit "no gcc binary in output: exits non-zero" \
    bash "$SCRIPT" \
        --rmprofile-dir="$_RM7" \
        --aprofile-dir="$_AP7" \
        --output-dir="$_OUT7" \
        --gcc-final-build-dir="$_TMPDIR/no-build-dir"

_err7=$(bash "$SCRIPT" \
    --rmprofile-dir="$_RM7" \
    --aprofile-dir="$_AP7" \
    --output-dir="$_OUT7" \
    --gcc-final-build-dir="$_TMPDIR/no-build-dir" 2>&1 || true)
assert_contains "no gcc binary in output: error message references output path" \
    "$_err7" "arm-none-eabi-gcc not found in output tree"

# ---------------------------------------------------------------------------
# Test group 8: Verification failures with mock arm-none-eabi-gcc
#
# A mock gcc binary in the rmprofile tree controls what --print-multi-lib
# returns.  Tests exercise both variant-check error paths in Step 4.
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 8: Verification failures with mock arm-none-eabi-gcc ==="

_RM8a="$_TMPDIR/rm8a"
_AP8a="$_TMPDIR/ap8a"
_OUT8a="$_TMPDIR/out8a"
mkdir -p "$_RM8a/bin" "$_RM8a/lib/gcc/arm-none-eabi" "$_AP8a/arm-none-eabi/lib" "$_OUT8a"
# Mock gcc: outputs only an aprofile line; rmprofile variant is absent.
cat > "$_RM8a/bin/arm-none-eabi-gcc" << 'MOCK'
#!/bin/sh
echo "thumb/armv7-a;@mthumb@march=armv7-a"
MOCK
chmod +x "$_RM8a/bin/arm-none-eabi-gcc"

assert_nonzero_exit "missing rmprofile variant: exits non-zero" \
    bash "$SCRIPT" \
        --rmprofile-dir="$_RM8a" \
        --aprofile-dir="$_AP8a" \
        --output-dir="$_OUT8a" \
        --gcc-final-build-dir="$_TMPDIR/no-build-dir"

_err8a=$(bash "$SCRIPT" \
    --rmprofile-dir="$_RM8a" \
    --aprofile-dir="$_AP8a" \
    --output-dir="$_OUT8a" \
    --gcc-final-build-dir="$_TMPDIR/no-build-dir" 2>&1 || true)
assert_contains "missing rmprofile variant: error names missing variant" \
    "$_err8a" "rmprofile variant 'thumb/v7e-m+fp/hard' not found"

_RM8b="$_TMPDIR/rm8b"
_AP8b="$_TMPDIR/ap8b"
_OUT8b="$_TMPDIR/out8b"
mkdir -p "$_RM8b/bin" "$_RM8b/lib/gcc/arm-none-eabi" "$_AP8b/arm-none-eabi/lib" "$_OUT8b"
# Mock gcc: outputs only an rmprofile line; aprofile variant is absent.
cat > "$_RM8b/bin/arm-none-eabi-gcc" << 'MOCK'
#!/bin/sh
echo "thumb/v7e-m+fp/hard;@mthumb@march=armv7e-m+fp@mfloat-abi=hard"
MOCK
chmod +x "$_RM8b/bin/arm-none-eabi-gcc"

assert_nonzero_exit "missing aprofile variant: exits non-zero" \
    bash "$SCRIPT" \
        --rmprofile-dir="$_RM8b" \
        --aprofile-dir="$_AP8b" \
        --output-dir="$_OUT8b" \
        --gcc-final-build-dir="$_TMPDIR/no-build-dir"

_err8b=$(bash "$SCRIPT" \
    --rmprofile-dir="$_RM8b" \
    --aprofile-dir="$_AP8b" \
    --output-dir="$_OUT8b" \
    --gcc-final-build-dir="$_TMPDIR/no-build-dir" 2>&1 || true)
assert_contains "missing aprofile variant: error names missing variant" \
    "$_err8b" "aprofile variant 'thumb/armv7-a' not found"

# ---------------------------------------------------------------------------
# Test group 9: Successful merge with mock arm-none-eabi-gcc
#
# Both rmprofile and aprofile trees are valid mock structures.  The mock gcc
# emits both expected multilib variants.  Verifies that Steps 1-4 all run
# to completion and the output tree contains the expected merged content.
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 9: Successful merge path ==="

_RM9="$_TMPDIR/rm9"
_AP9="$_TMPDIR/ap9"
_OUT9="$_TMPDIR/out9"
mkdir -p "$_RM9/bin" "$_RM9/lib/gcc/arm-none-eabi" "$_AP9/arm-none-eabi/lib/thumb/armv7-a" "$_OUT9"
# Sentinel file in rmprofile tree — must appear in output after Step 1 copy.
echo "rmprofile-content" > "$_RM9/rmprofile-sentinel.txt"
# Mock gcc: outputs both required multilib variant lines.
cat > "$_RM9/bin/arm-none-eabi-gcc" << 'MOCK'
#!/bin/sh
echo "thumb/v7e-m+fp/hard;@mthumb@march=armv7e-m+fp@mfloat-abi=hard"
echo "thumb/armv7-a;@mthumb@march=armv7-a"
MOCK
chmod +x "$_RM9/bin/arm-none-eabi-gcc"
# Sentinel file in aprofile overlay dir — must appear in output after Step 2.
echo "aprofile-content" > "$_AP9/arm-none-eabi/lib/thumb/armv7-a/aprofile-sentinel.txt"

assert_zero_exit "successful merge: exits zero" \
    bash "$SCRIPT" \
        --rmprofile-dir="$_RM9" \
        --aprofile-dir="$_AP9" \
        --output-dir="$_OUT9" \
        --gcc-final-build-dir="$_TMPDIR/no-build-dir" 2>/dev/null

assert_zero_exit "successful merge: rmprofile sentinel in output (Step 1 copy)" \
    test -f "$_OUT9/rmprofile-sentinel.txt"

assert_zero_exit "successful merge: aprofile sentinel in output (Step 2 overlay)" \
    test -f "$_OUT9/arm-none-eabi/lib/thumb/armv7-a/aprofile-sentinel.txt"

_warn9=$(bash "$SCRIPT" \
    --rmprofile-dir="$_RM9" \
    --aprofile-dir="$_AP9" \
    --output-dir="$_OUT9" \
    --gcc-final-build-dir="$_TMPDIR/no-build-dir" 2>&1 >/dev/null || true)
assert_contains "successful merge: gcc-final-build-dir absent warning on stderr" \
    "$_warn9" "gcc-final build dir not found"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

print_test_results
