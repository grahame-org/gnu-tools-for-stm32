#!/usr/bin/env bash
# Unit tests for build-pre-cache-clean.sh.
#
# Run with: bash tests/test-pre-cache-clean.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/build-pre-cache-clean.sh"

# shellcheck source=tests/test-helpers.sh
. "$SCRIPT_DIR/test-helpers.sh"

# ---------------------------------------------------------------------------
# Shared temporary directory
# ---------------------------------------------------------------------------

_TMPDIR=$(mktemp -d)
trap 'rm -rf "$_TMPDIR"' EXIT

# Helper: create a minimal fake ELF binary
make_elf() {
    printf '\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00' > "$1"
}

# Helper: create a minimal fake .a archive (just needs to exist as a regular file)
make_ar() {
    printf '!<arch>\n' > "$1"
}

# Helper: create a mock strip binary in the given directory that logs its
# arguments to the file referenced by ${STRIP_LOG}.
make_mock_strip() {
    local mock_dir="$1"
    mkdir -p "$mock_dir"
    cat > "$mock_dir/strip" <<'STRIPEOF'
#!/usr/bin/env bash
echo "$*" >> "${STRIP_LOG}"
STRIPEOF
    chmod +x "$mock_dir/strip"
}

# ---------------------------------------------------------------------------
# Test group 1: Missing argument → non-zero exit
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 1: Missing argument ==="

assert_nonzero_exit "no args: exits non-zero" bash "$SCRIPT"
assert_nonzero_exit "two args: exits non-zero" bash "$SCRIPT" /tmp /tmp

# ---------------------------------------------------------------------------
# Test group 2: Non-existent directory → exit 0 with warning
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 2: Non-existent directory ==="

_NOEXIST="$_TMPDIR/no_such_dir"
assert_zero_exit "non-existent dir: exits 0" bash "$SCRIPT" "$_NOEXIST"

# Verify warning is printed to stderr
_warn_out=$( bash "$SCRIPT" "$_NOEXIST" 2>&1 1>/dev/null )
assert_nonempty "non-existent dir: warning printed" "$_warn_out"

# ---------------------------------------------------------------------------
# Test group 3: ELF binaries in bin/ are stripped
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 3: ELF stripping ==="

_ROOT3="$_TMPDIR/root3"
mkdir -p "$_ROOT3/bin" "$_ROOT3/libexec/gcc/arm-none-eabi/14.3.1" "$_ROOT3/arm-none-eabi/bin"

_ELF_BIN="$_ROOT3/bin/mytool"
_ELF_LIBEXEC="$_ROOT3/libexec/cc1"
_ELF_LIBEXEC_NESTED="$_ROOT3/libexec/gcc/arm-none-eabi/14.3.1/cc1"
_ELF_CROSS="$_ROOT3/arm-none-eabi/bin/ld"
_TEXT_FILE="$_ROOT3/bin/script.sh"

make_elf "$_ELF_BIN"
make_elf "$_ELF_LIBEXEC"
make_elf "$_ELF_LIBEXEC_NESTED"
make_elf "$_ELF_CROSS"
echo "#!/bin/sh" > "$_TEXT_FILE"
chmod +x "$_TEXT_FILE"

# Capture invocations of strip via PATH override
_STRIP_LOG3="$_TMPDIR/strip-calls-3"
_MOCK_BIN3="$_TMPDIR/mockbin3"
make_mock_strip "$_MOCK_BIN3"

export STRIP_LOG="$_STRIP_LOG3"
_SAVED_PATH3="$PATH"
export PATH="$_MOCK_BIN3:$PATH"
assert_zero_exit "ELF stripping: script exits 0" \
    bash "$SCRIPT" "$_ROOT3"
export PATH="$_SAVED_PATH3"

assert_eq "bin/ ELF stripped" "called" \
    "$(grep -qF "$_ELF_BIN" "$_STRIP_LOG3" 2>/dev/null && echo called || echo not-called)"
assert_eq "libexec/ ELF stripped" "called" \
    "$(grep -qF "$_ELF_LIBEXEC" "$_STRIP_LOG3" 2>/dev/null && echo called || echo not-called)"
assert_eq "libexec/ nested ELF stripped" "called" \
    "$(grep -qF "$_ELF_LIBEXEC_NESTED" "$_STRIP_LOG3" 2>/dev/null && echo called || echo not-called)"
assert_eq "arm-none-eabi/bin/ ELF stripped" "called" \
    "$(grep -qF "$_ELF_CROSS" "$_STRIP_LOG3" 2>/dev/null && echo called || echo not-called)"
assert_eq "plain text file not stripped" "not-called" \
    "$(grep -qF "$_TEXT_FILE" "$_STRIP_LOG3" 2>/dev/null && echo called || echo not-called)"
assert_eq "ELF stripped with --strip-unneeded" "called" \
    "$(grep -qF -- "--strip-unneeded $_ELF_BIN" "$_STRIP_LOG3" 2>/dev/null && echo called || echo not-called)"

unset STRIP_LOG

# ---------------------------------------------------------------------------
# Test group 4: .a static libraries are stripped with --strip-debug
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 4: .a stripping ==="

_ROOT4="$_TMPDIR/root4"
mkdir -p "$_ROOT4/lib"
_AR="$_ROOT4/lib/libfoo.a"
make_ar "$_AR"

_STRIP_LOG4="$_TMPDIR/strip-calls-4"
_MOCK_BIN4="$_TMPDIR/mockbin4"
make_mock_strip "$_MOCK_BIN4"

export STRIP_LOG="$_STRIP_LOG4"
_SAVED_PATH4="$PATH"
export PATH="$_MOCK_BIN4:$PATH"
assert_zero_exit ".a stripping: script exits 0" \
    bash "$SCRIPT" "$_ROOT4"
export PATH="$_SAVED_PATH4"

assert_eq ".a stripped with --strip-debug --keep-section=.debug_frame" "called" \
    "$(grep -qF -- "--strip-debug --keep-section=.debug_frame $_AR" "$_STRIP_LOG4" 2>/dev/null && echo called || echo not-called)"

unset STRIP_LOG

# ---------------------------------------------------------------------------
# Test group 5: Non-essential directories are removed
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 5: Non-essential directory removal ==="

_ROOT5="$_TMPDIR/root5"
mkdir -p \
    "$_ROOT5/share/man/man1" \
    "$_ROOT5/share/info" \
    "$_ROOT5/share/locale/en" \
    "$_ROOT5/share/doc/gcc" \
    "$_ROOT5/arm-none-eabi/share" \
    "$_ROOT5/bin"
# A file we want to keep
echo "keep" > "$_ROOT5/bin/keep"

bash "$SCRIPT" "$_ROOT5" >/dev/null 2>&1

assert_eq "share/man removed" "absent" \
    "$([ -d "$_ROOT5/share/man" ] && echo present || echo absent)"
assert_eq "share/info removed" "absent" \
    "$([ -d "$_ROOT5/share/info" ] && echo present || echo absent)"
assert_eq "share/locale removed" "absent" \
    "$([ -d "$_ROOT5/share/locale" ] && echo present || echo absent)"
assert_eq "share/doc removed" "absent" \
    "$([ -d "$_ROOT5/share/doc" ] && echo present || echo absent)"
assert_eq "arm-none-eabi/share removed" "absent" \
    "$([ -d "$_ROOT5/arm-none-eabi/share" ] && echo present || echo absent)"
assert_eq "bin/keep not removed" "present" \
    "$([ -f "$_ROOT5/bin/keep" ] && echo present || echo absent)"

# ---------------------------------------------------------------------------
# Test group 6: .la files are removed
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 6: .la file removal ==="

_ROOT6="$_TMPDIR/root6"
mkdir -p "$_ROOT6/lib" "$_ROOT6/sub/dir"
echo "# libtool" > "$_ROOT6/lib/libfoo.la"
echo "# libtool" > "$_ROOT6/sub/dir/libbar.la"
echo "keep" > "$_ROOT6/lib/libfoo.a"

bash "$SCRIPT" "$_ROOT6" >/dev/null 2>&1

assert_eq "lib/libfoo.la removed" "absent" \
    "$([ -f "$_ROOT6/lib/libfoo.la" ] && echo present || echo absent)"
assert_eq "sub/dir/libbar.la removed" "absent" \
    "$([ -f "$_ROOT6/sub/dir/libbar.la" ] && echo present || echo absent)"
assert_eq "lib/libfoo.a kept" "present" \
    "$([ -f "$_ROOT6/lib/libfoo.a" ] && echo present || echo absent)"

# ---------------------------------------------------------------------------
# Test group 7: Before/after size output is printed
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 7: Before/after size summary ==="

_ROOT7="$_TMPDIR/root7"
mkdir -p "$_ROOT7"
echo "data" > "$_ROOT7/file"

_OUTPUT7=$(bash "$SCRIPT" "$_ROOT7" 2>&1)

assert_contains "before size line present" "$_OUTPUT7" "Size before cleaning"
assert_contains "after size line present" "$_OUTPUT7" "Size after cleaning"

# ---------------------------------------------------------------------------
# Test group 8: share/gcc-*/ directories are removed
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 8: share/gcc-*/ removal ==="

_ROOT8="$_TMPDIR/root8"
mkdir -p \
    "$_ROOT8/share/gcc-14.3.1" \
    "$_ROOT8/share/gcc-13.2.1" \
    "$_ROOT8/share/other" \
    "$_ROOT8/bin"
echo "keep" > "$_ROOT8/bin/keep"
echo "script" > "$_ROOT8/share/gcc-14.3.1/annotate.py"
echo "script" > "$_ROOT8/share/gcc-13.2.1/gdbinit.py"
echo "keep" > "$_ROOT8/share/other/file"

_root8_exit=0
bash "$SCRIPT" "$_ROOT8" >/dev/null 2>&1 || _root8_exit=$?
assert_eq "group 8: script exits 0" "0" "$_root8_exit"

assert_eq "share/gcc-14.3.1 removed" "absent" \
    "$([ -d "$_ROOT8/share/gcc-14.3.1" ] && echo present || echo absent)"
assert_eq "share/gcc-13.2.1 removed" "absent" \
    "$([ -d "$_ROOT8/share/gcc-13.2.1" ] && echo present || echo absent)"
assert_eq "share/other not removed" "present" \
    "$([ -d "$_ROOT8/share/other" ] && echo present || echo absent)"
assert_eq "bin/keep not removed" "present" \
    "$([ -f "$_ROOT8/bin/keep" ] && echo present || echo absent)"

# ---------------------------------------------------------------------------
# Test group 9: Safety check passes when arm-none-eabi-gcc is present
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 9: Safety check passes when arm-none-eabi-gcc is present ==="

_ROOT9="$_TMPDIR/root9"
mkdir -p "$_ROOT9/bin"
echo "fake-gcc" > "$_ROOT9/bin/arm-none-eabi-gcc"

_OUTPUT9=$(bash "$SCRIPT" "$_ROOT9" 2>&1)
assert_contains "safety check passed message present" "$_OUTPUT9" "Safety check passed"
assert_not_contains "safety check passed: no FAILED message emitted" "$_OUTPUT9" "Safety check FAILED"

# ---------------------------------------------------------------------------
# Test group 10: Safety check silent when arm-none-eabi-gcc was never present
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 10: Safety check silent when arm-none-eabi-gcc absent before cleanup ==="

_ROOT10="$_TMPDIR/root10"
mkdir -p "$_ROOT10/bin"
echo "fake-ld" > "$_ROOT10/bin/arm-none-eabi-ld"

_root10_exit=0
_OUTPUT10=$(bash "$SCRIPT" "$_ROOT10" 2>&1) || _root10_exit=$?
assert_eq "no gcc before: script exits 0" "0" "$_root10_exit"
assert_not_contains "no safety-check message when gcc absent before cleanup" "$_OUTPUT10" "Safety check"

# ---------------------------------------------------------------------------
# Test group 11: Safety check fails when arm-none-eabi-gcc was present before
#                cleanup but is gone afterwards (broken symlink scenario)
#
# Simulate a regression where a cleanup operation removes a target that the
# gcc binary symlink points to.  The safety check must detect this and exit 1.
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 11: Safety check FAILED when gcc missing after cleanup ==="

_ROOT11="$_TMPDIR/root11"
mkdir -p "$_ROOT11/bin"
mkdir -p "$_ROOT11/share/gcc-14.3.1"

# Place a "gcc" file inside share/gcc-14.3.1/ — a directory that
# remove_non_essential_dirs will delete — and point bin/arm-none-eabi-gcc at
# it via a symlink.  After the script removes share/gcc-14.3.1/ the symlink
# becomes broken, triggering the safety-check failure path.
echo "fake-gcc" > "$_ROOT11/share/gcc-14.3.1/arm-none-eabi-gcc"
ln -s "../share/gcc-14.3.1/arm-none-eabi-gcc" "$_ROOT11/bin/arm-none-eabi-gcc"

_root11_exit=0
_OUTPUT11=$(bash "$SCRIPT" "$_ROOT11" 2>&1) || _root11_exit=$?
assert_eq "safety check FAILED: script exits with status 1" "1" "$_root11_exit"
assert_contains "safety check FAILED message emitted" "$_OUTPUT11" "Safety check FAILED"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

print_test_results
