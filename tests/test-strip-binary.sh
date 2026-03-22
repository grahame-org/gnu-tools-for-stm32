#!/usr/bin/env bash
# Unit tests for strip_binary() in build-common.sh.
#
# Run with: bash tests/test-strip-binary.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=test-helpers.sh
. "$SCRIPT_DIR/test-helpers.sh"

# Source build-common.sh.  The script guards against running build-phase
# initialisation when the calling script name does not match "build-*", so
# sourcing from here is safe.
# shellcheck source=../build-common.sh
. "$REPO_ROOT/build-common.sh"

# ---------------------------------------------------------------------------
# Shared temporary directory and mock strip script
# ---------------------------------------------------------------------------

_SB_TMPDIR=$(mktemp -d)
trap 'rm -rf "$_SB_TMPDIR"' EXIT

# Mock strip: records the argument it was called with into a file so tests can
# inspect whether it was invoked and with what path.
_MOCK_STRIP="$_SB_TMPDIR/mock-strip"
_STRIP_LOG="$_SB_TMPDIR/strip-calls"
cat > "$_MOCK_STRIP" <<'EOF'
#!/usr/bin/env bash
echo "$1" >> "${STRIP_LOG}"
EOF
chmod +x "$_MOCK_STRIP"

# Failing mock strip: always exits non-zero (to test the || true guard).
_MOCK_STRIP_FAIL="$_SB_TMPDIR/mock-strip-fail"
cat > "$_MOCK_STRIP_FAIL" <<'EOF'
#!/usr/bin/env bash
echo "$1" >> "${STRIP_LOG}"
exit 1
EOF
chmod +x "$_MOCK_STRIP_FAIL"

reset_strip_log() {
    rm -f "$_STRIP_LOG"
}

strip_was_called() {
    [ -f "$_STRIP_LOG" ]
}

strip_called_with() {
    [ -f "$_STRIP_LOG" ] && grep -qxF "$1" "$_STRIP_LOG"
}

# ---------------------------------------------------------------------------
# Test group 1: Wrong argument counts → return 0, strip never called
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 1: Wrong argument counts ==="

reset_strip_log
STRIP_LOG="$_STRIP_LOG" strip_binary 2>/dev/null; _ret=$?
assert_eq "0 args: returns 0" "0" "$_ret"
assert_eq "0 args: strip not called" "" "$([ -f "$_STRIP_LOG" ] && echo called || true)"

reset_strip_log
STRIP_LOG="$_STRIP_LOG" strip_binary "$_MOCK_STRIP" 2>/dev/null; _ret=$?
assert_eq "1 arg: returns 0" "0" "$_ret"
assert_eq "1 arg: strip not called" "" "$([ -f "$_STRIP_LOG" ] && echo called || true)"

reset_strip_log
STRIP_LOG="$_STRIP_LOG" strip_binary "$_MOCK_STRIP" /some/file extra_arg 2>/dev/null; _ret=$?
assert_eq "3 args: returns 0" "0" "$_ret"
assert_eq "3 args: strip not called" "" "$([ -f "$_STRIP_LOG" ] && echo called || true)"

# ---------------------------------------------------------------------------
# Test group 2: Non-binary files → strip not called
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 2: Non-binary files ==="

_TEXT_FILE="$_SB_TMPDIR/plain.txt"
echo "hello world" > "$_TEXT_FILE"

reset_strip_log
STRIP_LOG="$_STRIP_LOG" strip_binary "$_MOCK_STRIP" "$_TEXT_FILE"
assert_eq "plain text file: strip not called" "" "$([ -f "$_STRIP_LOG" ] && echo called || true)"

_EMPTY_FILE="$_SB_TMPDIR/empty"
: > "$_EMPTY_FILE"

reset_strip_log
STRIP_LOG="$_STRIP_LOG" strip_binary "$_MOCK_STRIP" "$_EMPTY_FILE"
assert_eq "empty file: strip not called" "" "$([ -f "$_STRIP_LOG" ] && echo called || true)"

# ---------------------------------------------------------------------------
# Test group 3: ELF binary → strip is called with correct path
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 3: ELF binary ==="

_ELF_FILE="$_SB_TMPDIR/fake.elf"
# Write the 4-byte ELF magic followed by minimal padding so file(1) identifies
# it as ELF data.
printf '\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00' > "$_ELF_FILE"

reset_strip_log
STRIP_LOG="$_STRIP_LOG" strip_binary "$_MOCK_STRIP" "$_ELF_FILE"
assert_eq "ELF file: strip is called" "called" "$([ -f "$_STRIP_LOG" ] && echo called || true)"
assert_eq "ELF file: strip called with correct path" "called" "$(strip_called_with "$_ELF_FILE" && echo called || true)"

# ---------------------------------------------------------------------------
# Test group 4: Non-existent file → strip not called
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 4: Non-existent file ==="

_NOEXIST="$_SB_TMPDIR/no_such_file"

reset_strip_log
STRIP_LOG="$_STRIP_LOG" strip_binary "$_MOCK_STRIP" "$_NOEXIST" 2>/dev/null
assert_eq "non-existent file: strip not called" "" "$([ -f "$_STRIP_LOG" ] && echo called || true)"

# ---------------------------------------------------------------------------
# Test group 5: Strip command exits non-zero → silently ignored (|| true)
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 5: Strip failure is silently ignored ==="

reset_strip_log
STRIP_LOG="$_STRIP_LOG" strip_binary "$_MOCK_STRIP_FAIL" "$_ELF_FILE"; _ret=$?
assert_eq "failing strip: strip_binary still returns 0" "0" "$_ret"
assert_eq "failing strip: strip was attempted" "called" "$([ -f "$_STRIP_LOG" ] && echo called || true)"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

print_test_results
