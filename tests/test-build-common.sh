#!/usr/bin/env bash
# Unit tests for saveenv/restoreenv/saveenvvar/prependenvvar/prepend_path,
# break_hardlink, copy_dir, and copy_dir_clean in build-common.sh.
#
# Run with: bash tests/test-build-common.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source build-common.sh.  The script guards against running build-phase
# initialisation when the calling script name does not match "build-*", so
# sourcing from here is safe.
# shellcheck source=../build-common.sh
. "$REPO_ROOT/build-common.sh"

# ---------------------------------------------------------------------------
# Minimal test harness
# ---------------------------------------------------------------------------

_PASS=0
_FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        _PASS=$((_PASS + 1))
        echo "  PASS: $desc"
    else
        _FAIL=$((_FAIL + 1))
        echo "  FAIL: $desc"
        echo "        expected: [$expected]"
        echo "        actual:   [$actual]"
    fi
}

assert_unset() {
    local desc="$1" varname="$2"
    if eval "[ \"\${${varname}+set}\" != \"set\" ]"; then
        _PASS=$((_PASS + 1))
        echo "  PASS: $desc"
    else
        _FAIL=$((_FAIL + 1))
        echo "  FAIL: $desc (expected unset, got [$(eval echo \"\$$varname\")])"
    fi
}

assert_nonzero_exit() {
    local desc="$1"
    shift
    if "$@" 2>/dev/null; then
        _FAIL=$((_FAIL + 1))
        echo "  FAIL: $desc (expected non-zero exit)"
    else
        _PASS=$((_PASS + 1))
        echo "  PASS: $desc"
    fi
}

assert_zero_exit() {
    local desc="$1"
    shift
    if "$@" 2>/dev/null; then
        _PASS=$((_PASS + 1))
        echo "  PASS: $desc"
    else
        _FAIL=$((_FAIL + 1))
        echo "  FAIL: $desc (expected zero exit)"
    fi
}

reset_stack() {
    # Reset global stack state between test groups
    stack_level=0
    unset TEST_A TEST_B TEST_C
}

# ---------------------------------------------------------------------------
# Test group 1: saveenv / restoreenv stack bookkeeping
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 1: Stack bookkeeping ==="

reset_stack

saveenv
assert_eq "saveenv increments stack_level to 1" "1" "$stack_level"

saveenv
assert_eq "saveenv increments stack_level to 2" "2" "$stack_level"

restoreenv
assert_eq "restoreenv decrements stack_level to 1" "1" "$stack_level"

restoreenv
assert_eq "restoreenv decrements stack_level to 0" "0" "$stack_level"

# ---------------------------------------------------------------------------
# Test group 2: saveenvvar sets new value, restoreenv restores original
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 2: saveenvvar / restoreenv basic behavior ==="

reset_stack

TEST_A=original
saveenv
saveenvvar TEST_A newval
assert_eq "saveenvvar sets new value" "newval" "$TEST_A"
restoreenv
assert_eq "restoreenv restores original value" "original" "$TEST_A"

# ---------------------------------------------------------------------------
# Test group 3: Variables that were unset before save are unset after restore
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 3: Unset variable handling ==="

reset_stack
unset TEST_A

saveenv
saveenvvar TEST_A introduced_value
assert_eq "saveenvvar sets value for previously-unset variable" "introduced_value" "$TEST_A"
restoreenv
assert_unset "restoreenv unsets a variable that was originally unset" TEST_A

# ---------------------------------------------------------------------------
# Test group 4: Multiple variables per stack level
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 4: Multiple variables per stack level ==="

reset_stack

TEST_A=alpha
TEST_B=beta
saveenv
saveenvvar TEST_A new_alpha
saveenvvar TEST_B new_beta
assert_eq "saveenvvar sets TEST_A" "new_alpha" "$TEST_A"
assert_eq "saveenvvar sets TEST_B" "new_beta" "$TEST_B"
restoreenv
assert_eq "restoreenv restores TEST_A" "alpha" "$TEST_A"
assert_eq "restoreenv restores TEST_B" "beta" "$TEST_B"

# ---------------------------------------------------------------------------
# Test group 5: Double-save idempotency — original value is preserved
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 5: Double-save idempotency ==="

reset_stack

TEST_A=first_original
saveenv
saveenvvar TEST_A intermediate
saveenvvar TEST_A final_value  # second save in same level — original must be kept
assert_eq "second saveenvvar sets new value" "final_value" "$TEST_A"
restoreenv
assert_eq "restoreenv restores to first original after double save" "first_original" "$TEST_A"

# ---------------------------------------------------------------------------
# Test group 6: Nested stack levels
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 6: Nested stack levels ==="

reset_stack

TEST_A=outer_original
saveenv
saveenvvar TEST_A outer_new
    saveenv
    saveenvvar TEST_A inner_new
    assert_eq "inner level sees inner_new" "inner_new" "$TEST_A"
    restoreenv
assert_eq "after inner restoreenv, TEST_A is outer_new" "outer_new" "$TEST_A"
restoreenv
assert_eq "after outer restoreenv, TEST_A is outer_original" "outer_original" "$TEST_A"
assert_eq "stack_level is 0 after balanced push/pop" "0" "$stack_level"

# ---------------------------------------------------------------------------
# Test group 7: prependenvvar
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 7: prependenvvar ==="

reset_stack

TEST_A=suffix
saveenv
prependenvvar TEST_A "prefix_"
assert_eq "prependenvvar prepends to existing value" "prefix_suffix" "$TEST_A"
restoreenv
assert_eq "restoreenv restores after prependenvvar" "suffix" "$TEST_A"

reset_stack
unset TEST_A
saveenv
prependenvvar TEST_A "only_value"
assert_eq "prependenvvar with empty variable sets value directly" "only_value" "$TEST_A"
restoreenv
assert_unset "restoreenv unsets after prependenvvar on previously-unset var" TEST_A

# ---------------------------------------------------------------------------
# Test group 8: prepend_path
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 8: prepend_path ==="

reset_stack

TEST_A=/existing/path
saveenv
prepend_path TEST_A /new/dir
assert_eq "prepend_path inserts colon separator" "/new/dir:/existing/path" "$TEST_A"
restoreenv
assert_eq "restoreenv restores path" "/existing/path" "$TEST_A"

reset_stack
unset TEST_A
saveenv
prepend_path TEST_A /only/dir
assert_eq "prepend_path with empty var: no leading colon" "/only/dir" "$TEST_A"
restoreenv
assert_unset "restoreenv unsets path var that was originally unset" TEST_A

# ---------------------------------------------------------------------------
# Test group 9: Error conditions
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 9: Error conditions ==="

reset_stack

assert_nonzero_exit "saveenvvar before saveenv exits non-zero" \
    bash -c '. "$1/build-common.sh"; stack_level=0; saveenvvar SOME_VAR value' _ "$REPO_ROOT"

assert_nonzero_exit "restoreenv on empty stack exits non-zero" \
    bash -c '. "$1/build-common.sh"; stack_level=0; restoreenv' _ "$REPO_ROOT"

# ---------------------------------------------------------------------------
# Test group 10: break_hardlink
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 10: break_hardlink ==="

_BHL_TMPDIR=$(mktemp -d)
trap 'rm -rf "$_BHL_TMPDIR"' EXIT

# Subshell wrappers are required for tests that expect break_hardlink to call
# error() (which calls exit 1) so the exit doesn't abort this test script.

assert_zero_exit "break_hardlink with no args returns 0 (warns but continues)" \
    bash -c '. "$1/build-common.sh"; break_hardlink' _ "$REPO_ROOT"

assert_nonzero_exit "break_hardlink with non-existent file returns 1" \
    bash -c '. "$1/build-common.sh"; break_hardlink "$2/no_such_file"' _ "$REPO_ROOT" "$_BHL_TMPDIR"

# Regular file: should succeed and leave the file intact
echo "original content" > "$_BHL_TMPDIR/solo"
assert_zero_exit "break_hardlink on a regular file returns 0" \
    bash -c '. "$1/build-common.sh"; break_hardlink "$2/solo"' _ "$REPO_ROOT" "$_BHL_TMPDIR"
assert_eq "file still exists after break_hardlink on regular file" \
    "original content" "$(cat "$_BHL_TMPDIR/solo")"

# File with a hard link: break_hardlink should reduce the link count to 1
echo "shared content" > "$_BHL_TMPDIR/original"
ln "$_BHL_TMPDIR/original" "$_BHL_TMPDIR/hardlink"
assert_eq "hard link count is 2 before break_hardlink" \
    "2" "$(stat -c '%h' "$_BHL_TMPDIR/original")"
assert_zero_exit "break_hardlink on file with a hard link returns 0" \
    break_hardlink "$_BHL_TMPDIR/original"
assert_eq "break_hardlink reduces link count to 1" \
    "1" "$(stat -c '%h' "$_BHL_TMPDIR/original")"
assert_eq "file content preserved after break_hardlink" \
    "shared content" "$(cat "$_BHL_TMPDIR/original")"

# ---------------------------------------------------------------------------
# Test group 11: copy_dir
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 11: copy_dir ==="

_CD_TMPDIR=$(mktemp -d)

# Create source tree: top-level file + subdir with file
mkdir -p "$_CD_TMPDIR/src/subdir"
echo "top" > "$_CD_TMPDIR/src/top.txt"
echo "nested" > "$_CD_TMPDIR/src/subdir/nested.txt"

copy_dir "$_CD_TMPDIR/src" "$_CD_TMPDIR/dst"

assert_eq "copy_dir copies top-level file" \
    "top" "$(cat "$_CD_TMPDIR/dst/top.txt")"
assert_eq "copy_dir copies nested file" \
    "nested" "$(cat "$_CD_TMPDIR/dst/subdir/nested.txt")"

# copy_dir should create the destination directory when it does not exist
copy_dir "$_CD_TMPDIR/src" "$_CD_TMPDIR/dst2/inner"
assert_eq "copy_dir creates destination directory if absent" \
    "top" "$(cat "$_CD_TMPDIR/dst2/inner/top.txt")"

rm -rf "$_CD_TMPDIR"

# ---------------------------------------------------------------------------
# Test group 12: copy_dir_clean
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 12: copy_dir_clean ==="

_CDC_TMPDIR=$(mktemp -d)

mkdir -p "$_CDC_TMPDIR/src/.git"
mkdir -p "$_CDC_TMPDIR/src/CVS"
mkdir -p "$_CDC_TMPDIR/src/.svn"
mkdir -p "$_CDC_TMPDIR/src/.pc"
mkdir -p "$_CDC_TMPDIR/src/normal_subdir"
echo "keep me" > "$_CDC_TMPDIR/src/normal.txt"
echo "keep me too" > "$_CDC_TMPDIR/src/normal_subdir/child.txt"
echo "git object" > "$_CDC_TMPDIR/src/.git/object"
echo "cvs entry" > "$_CDC_TMPDIR/src/CVS/Entries"
echo "svn entry" > "$_CDC_TMPDIR/src/.svn/entries"
echo "quilt patch" > "$_CDC_TMPDIR/src/.pc/series"
echo "backup" > "$_CDC_TMPDIR/src/file.txt~"
echo "orig" > "$_CDC_TMPDIR/src/patch.orig"
echo "rej" > "$_CDC_TMPDIR/src/patch.rej"
echo "emacs lock" > "$_CDC_TMPDIR/src/.#lockfile"

copy_dir_clean "$_CDC_TMPDIR/src" "$_CDC_TMPDIR/dst"

assert_eq "copy_dir_clean copies regular file" \
    "keep me" "$(cat "$_CDC_TMPDIR/dst/normal.txt")"
assert_eq "copy_dir_clean copies nested file in regular subdir" \
    "keep me too" "$(cat "$_CDC_TMPDIR/dst/normal_subdir/child.txt")"
assert_eq "copy_dir_clean excludes .git directory" \
    "" "$(ls "$_CDC_TMPDIR/dst/.git" 2>/dev/null || true)"
assert_eq "copy_dir_clean excludes CVS directory" \
    "" "$(ls "$_CDC_TMPDIR/dst/CVS" 2>/dev/null || true)"
assert_eq "copy_dir_clean excludes .svn directory" \
    "" "$(ls "$_CDC_TMPDIR/dst/.svn" 2>/dev/null || true)"
assert_eq "copy_dir_clean excludes .pc directory" \
    "" "$(ls "$_CDC_TMPDIR/dst/.pc" 2>/dev/null || true)"
assert_eq "copy_dir_clean excludes *~ backup files" \
    "" "$(ls "$_CDC_TMPDIR/dst/file.txt~" 2>/dev/null || true)"
assert_eq "copy_dir_clean excludes *.orig files" \
    "" "$(ls "$_CDC_TMPDIR/dst/patch.orig" 2>/dev/null || true)"
assert_eq "copy_dir_clean excludes *.rej files" \
    "" "$(ls "$_CDC_TMPDIR/dst/patch.rej" 2>/dev/null || true)"
assert_eq "copy_dir_clean excludes .#* emacs lock files" \
    "" "$(ls "$_CDC_TMPDIR/dst/.#lockfile" 2>/dev/null || true)"

rm -rf "$_CDC_TMPDIR"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "Results: $_PASS passed, $_FAIL failed"

if [ $_FAIL -ne 0 ]; then
    exit 1
fi
