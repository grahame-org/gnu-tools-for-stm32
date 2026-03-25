#!/usr/bin/env bash
# Unit tests for measure-cache-compressed-size.sh.
#
# Run with: bash tests/test-measure-cache-compressed-size.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/measure-cache-compressed-size.sh"

# shellcheck source=test-helpers.sh
. "$SCRIPT_DIR/test-helpers.sh"

# ---------------------------------------------------------------------------
# Shared temporary directory
# ---------------------------------------------------------------------------

_TMPDIR=$(mktemp -d)
trap 'rm -rf "$_TMPDIR"' EXIT

# ---------------------------------------------------------------------------
# Test group 1: Missing argument → non-zero exit
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 1: Missing argument ==="

assert_nonzero_exit "no args: exits non-zero" bash "$SCRIPT"

# ---------------------------------------------------------------------------
# Test group 2: Directory does not exist → outputs "0", exits 0
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 2: Directory does not exist ==="

_NOEXIST="$_TMPDIR/no_such_dir"

assert_zero_exit "non-existent dir: exits 0" bash "$SCRIPT" "$_NOEXIST"

_output_missing=$(bash "$SCRIPT" "$_NOEXIST" 2>/dev/null)
assert_eq "non-existent dir: outputs 0" "0" "$_output_missing"

# ---------------------------------------------------------------------------
# Test group 3: Directory exists, tar+zstd available → positive integer, exits 0
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 3: Directory exists, tar+zstd available ==="

_DIR3="$_TMPDIR/dir3"
mkdir -p "$_DIR3"
echo "some content" > "$_DIR3/file.txt"

assert_zero_exit "existing dir: exits 0" bash "$SCRIPT" "$_DIR3"

_output3=$(bash "$SCRIPT" "$_DIR3" 2>/dev/null)
assert_eq "existing dir: output is a positive integer" "yes" \
    "$([[ "$_output3" =~ ^[0-9]+$ ]] && (( _output3 > 0 )) && echo yes || echo no)"

# ---------------------------------------------------------------------------
# Test group 4: tar/zstd absent from PATH → outputs "0", warning to stderr, exits 0
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 4: tar/zstd absent from PATH ==="

_DIR4="$_TMPDIR/dir4"
mkdir -p "$_DIR4"
echo "data" > "$_DIR4/file.txt"

_EMPTYBIN="$_TMPDIR/emptybin"
mkdir -p "$_EMPTYBIN"

_output4=$(PATH="$_EMPTYBIN" "${BASH}" "$SCRIPT" "$_DIR4" 2>/dev/null)
assert_eq "tools absent: outputs 0" "0" "$_output4"

_exit4=0
PATH="$_EMPTYBIN" "${BASH}" "$SCRIPT" "$_DIR4" >/dev/null 2>/dev/null || _exit4=$?
assert_eq "tools absent: exits 0" "0" "$_exit4"

_stderr4=$(PATH="$_EMPTYBIN" "${BASH}" "$SCRIPT" "$_DIR4" 2>&1 1>/dev/null)
assert_ne "tools absent: warning printed to stderr" "" "$_stderr4"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

print_test_results
