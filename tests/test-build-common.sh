#!/usr/bin/env bash
# Unit tests for saveenv/restoreenv/saveenvvar/prependenvvar/prepend_path,
# break_hardlink, copy_dir, copy_dir_clean, pack_dir_clean, and copy_multi_libs
# in build-common.sh.
#
# Run with: bash tests/test-build-common.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=tests/test-helpers.sh
. "$SCRIPT_DIR/test-helpers.sh"

# Source build-common.sh.  The script guards against running build-phase
# initialisation when the calling script name does not match "build-*", so
# sourcing from here is safe.
# shellcheck source=../build-common.sh
. "$REPO_ROOT/build-common.sh"

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
assert_path_not_exists "copy_dir_clean excludes .git directory" \
    "$_CDC_TMPDIR/dst/.git"
assert_path_not_exists "copy_dir_clean excludes CVS directory" \
    "$_CDC_TMPDIR/dst/CVS"
assert_path_not_exists "copy_dir_clean excludes .svn directory" \
    "$_CDC_TMPDIR/dst/.svn"
assert_path_not_exists "copy_dir_clean excludes .pc directory" \
    "$_CDC_TMPDIR/dst/.pc"
assert_path_not_exists "copy_dir_clean excludes *~ backup files" \
    "$_CDC_TMPDIR/dst/file.txt~"
assert_path_not_exists "copy_dir_clean excludes *.orig files" \
    "$_CDC_TMPDIR/dst/patch.orig"
assert_path_not_exists "copy_dir_clean excludes *.rej files" \
    "$_CDC_TMPDIR/dst/patch.rej"
assert_path_not_exists "copy_dir_clean excludes .#* emacs lock files" \
    "$_CDC_TMPDIR/dst/.#lockfile"

rm -rf "$_CDC_TMPDIR"

# ---------------------------------------------------------------------------
# Test group 13: pack_dir_clean
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 13: pack_dir_clean ==="

_PDC_TMPDIR=$(mktemp -d)

mkdir -p "$_PDC_TMPDIR/src/.git"
mkdir -p "$_PDC_TMPDIR/src/CVS"
mkdir -p "$_PDC_TMPDIR/src/.svn"
mkdir -p "$_PDC_TMPDIR/src/.pc"
mkdir -p "$_PDC_TMPDIR/src/subdir"
echo "keep me" > "$_PDC_TMPDIR/src/normal.txt"
echo "nested" > "$_PDC_TMPDIR/src/subdir/child.txt"
echo "git object" > "$_PDC_TMPDIR/src/.git/object"
echo "cvs entry" > "$_PDC_TMPDIR/src/CVS/Entries"
echo "svn entry" > "$_PDC_TMPDIR/src/.svn/entries"
echo "quilt patch" > "$_PDC_TMPDIR/src/.pc/series"
echo "backup" > "$_PDC_TMPDIR/src/file.txt~"
echo "orig" > "$_PDC_TMPDIR/src/patch.orig"
echo "rej" > "$_PDC_TMPDIR/src/patch.rej"
echo "emacs lock" > "$_PDC_TMPDIR/src/.#lockfile"

_PDC_ARCHIVE="$_PDC_TMPDIR/out.tar.bz2"
pack_dir_clean "$_PDC_TMPDIR" "src" "$_PDC_ARCHIVE"

_PDC_CONTENTS=$(tar tjf "$_PDC_ARCHIVE")

# Use -Fx (fixed-string + full-line) so each assertion matches exactly one
# archive entry.  Plain grep with regex mode would treat '.' as a wildcard
# (matching src/normalXtxt etc.) and a substring match would pass if the
# target path appeared embedded in a longer entry.
# CLARIFY: tar is invoked with "-C $1 $2" so entries are expected to be
# listed as "src/normal.txt" (no leading "./" prefix); if the tar invocation
# or version changes to emit "./src/normal.txt" these patterns will need
# updating.
assert_eq "pack_dir_clean archives top-level file" \
    "src/normal.txt" "$(echo "$_PDC_CONTENTS" | grep -Fx "src/normal.txt" || true)"
assert_eq "pack_dir_clean archives nested file in regular subdir" \
    "src/subdir/child.txt" "$(echo "$_PDC_CONTENTS" | grep -Fx "src/subdir/child.txt" || true)"
# Use directory-boundary anchoring: (^|/)NAME(/|$) matches NAME only as an
# exact path component (with or without a trailing slash, as tar may omit it).
# Plain substring grep (e.g. grep "\.git") would false-fail on legitimately
# archived files whose names merely contain these strings, such as
# src/.gitignore, src/.gitattributes, or src/CVSroot.
# CLARIFY: if the test fixture is ever extended to include such files (e.g. a
# .gitignore that should be archived), verify these patterns still hold.
assert_not_matches "pack_dir_clean excludes .git directory" \
    "$_PDC_CONTENTS" '(^|/)\.git(/|$)'
assert_not_matches "pack_dir_clean excludes CVS directory" \
    "$_PDC_CONTENTS" '(^|/)CVS(/|$)'
assert_not_matches "pack_dir_clean excludes .svn directory" \
    "$_PDC_CONTENTS" '(^|/)\.svn(/|$)'
assert_not_matches "pack_dir_clean excludes .pc directory" \
    "$_PDC_CONTENTS" '(^|/)\.pc(/|$)'
assert_not_matches "pack_dir_clean excludes *~ backup files" \
    "$_PDC_CONTENTS" 'file\.txt~'
assert_not_matches "pack_dir_clean excludes *.orig files" \
    "$_PDC_CONTENTS" 'patch\.orig'
assert_not_matches "pack_dir_clean excludes *.rej files" \
    "$_PDC_CONTENTS" 'patch\.rej'
assert_not_matches "pack_dir_clean excludes .#* emacs lock files" \
    "$_PDC_CONTENTS" '\.#lockfile'

# Test that extra --exclude args (params 4+) are forwarded to tar
_PDC_EXTRA_ARCHIVE="$_PDC_TMPDIR/out-extra.tar.bz2"
echo "extra-excluded" > "$_PDC_TMPDIR/src/extra.txt"
pack_dir_clean "$_PDC_TMPDIR" "src" "$_PDC_EXTRA_ARCHIVE" --exclude="extra.txt"
_PDC_EXTRA_CONTENTS=$(tar tjf "$_PDC_EXTRA_ARCHIVE")
assert_eq "pack_dir_clean forwards extra --exclude args" \
    "" "$(echo "$_PDC_EXTRA_CONTENTS" | grep -Fx "src/extra.txt" || true)"
assert_eq "pack_dir_clean still archives normal files with extra excludes" \
    "src/normal.txt" "$(echo "$_PDC_EXTRA_CONTENTS" | grep -Fx "src/normal.txt" || true)"

rm -rf "$_PDC_TMPDIR"

# ---------------------------------------------------------------------------
# Test group 14: copy_multi_libs
# ---------------------------------------------------------------------------
# copy_multi_libs copies nano/specs/crt0 files for each multilib directory
# reported by the target GCC compiler.  It renames library files with a
# _nano suffix (e.g. libstdc++.a → libstdc++_nano.a) and copies specs and
# crt0 object files unchanged.
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 14: copy_multi_libs ==="

_CML_TMPDIR=$(mktemp -d)

# Build a mock GCC binary that emits two multilib entries when invoked with
# -print-multi-lib: the root directory (".") and one nested path.
cat > "${_CML_TMPDIR}/mock-gcc" << 'MOCK_GCC_EOF'
#!/usr/bin/env bash
if [ "$1" = "-print-multi-lib" ]; then
    printf '.\n'
    printf 'thumb/v8-m.main/fp;@mthumb@march=armv8-m.main+fp\n'
fi
MOCK_GCC_EOF
chmod +x "${_CML_TMPDIR}/mock-gcc"

# Create source and destination trees for each multilib directory.
for _mdir in "." "thumb/v8-m.main/fp"; do
    mkdir -p "${_CML_TMPDIR}/src/${_mdir}"
    mkdir -p "${_CML_TMPDIR}/dst/${_mdir}"
    # Libraries that get a _nano suffix.
    for _lib in libstdc++.a libsupc++.a libc.a libg.a librdimon.a librdimon-v2m.a; do
        printf '%s' "${_lib}" > "${_CML_TMPDIR}/src/${_mdir}/${_lib}"
    done
    # Spec files and crt0 object copied verbatim.
    for _spec in nano.specs rdimon.specs nosys.specs; do
        printf '%s' "${_spec}" > "${_CML_TMPDIR}/src/${_mdir}/${_spec}"
    done
    printf '%s' 'crt0' > "${_CML_TMPDIR}/src/${_mdir}/crt0.o"
done

copy_multi_libs \
    dst_prefix="${_CML_TMPDIR}/dst" \
    src_prefix="${_CML_TMPDIR}/src" \
    target_gcc="${_CML_TMPDIR}/mock-gcc"

# --- root multilib: renamed library files ---
assert_file_exists "copy_multi_libs root: libstdc++_nano.a created" \
    "${_CML_TMPDIR}/dst/libstdc++_nano.a"
assert_file_exists "copy_multi_libs root: libsupc++_nano.a created" \
    "${_CML_TMPDIR}/dst/libsupc++_nano.a"
assert_file_exists "copy_multi_libs root: libc_nano.a created" \
    "${_CML_TMPDIR}/dst/libc_nano.a"
assert_file_exists "copy_multi_libs root: libg_nano.a created" \
    "${_CML_TMPDIR}/dst/libg_nano.a"
assert_file_exists "copy_multi_libs root: librdimon_nano.a created" \
    "${_CML_TMPDIR}/dst/librdimon_nano.a"
assert_file_exists "copy_multi_libs root: librdimon-v2m_nano.a created" \
    "${_CML_TMPDIR}/dst/librdimon-v2m_nano.a"

# --- root multilib: spec files and crt0 ---
assert_file_exists "copy_multi_libs root: nano.specs copied" \
    "${_CML_TMPDIR}/dst/nano.specs"
assert_file_exists "copy_multi_libs root: rdimon.specs copied" \
    "${_CML_TMPDIR}/dst/rdimon.specs"
assert_file_exists "copy_multi_libs root: nosys.specs copied" \
    "${_CML_TMPDIR}/dst/nosys.specs"
assert_file_exists "copy_multi_libs root: crt0.o copied" \
    "${_CML_TMPDIR}/dst/crt0.o"

# --- root multilib: source content is preserved ---
assert_eq "copy_multi_libs root: libstdc++_nano.a preserves content" \
    "libstdc++.a" "$(cat "${_CML_TMPDIR}/dst/libstdc++_nano.a")"

# --- nested multilib ---
_CML_NESTED="thumb/v8-m.main/fp"
assert_file_exists "copy_multi_libs nested: libstdc++_nano.a created" \
    "${_CML_TMPDIR}/dst/${_CML_NESTED}/libstdc++_nano.a"
assert_file_exists "copy_multi_libs nested: libc_nano.a created" \
    "${_CML_TMPDIR}/dst/${_CML_NESTED}/libc_nano.a"
assert_file_exists "copy_multi_libs nested: nano.specs copied" \
    "${_CML_TMPDIR}/dst/${_CML_NESTED}/nano.specs"
assert_file_exists "copy_multi_libs nested: crt0.o copied" \
    "${_CML_TMPDIR}/dst/${_CML_NESTED}/crt0.o"

# --- empty print-multi-lib: function is a no-op (exits 0) ---
cat > "${_CML_TMPDIR}/empty-gcc" << 'EMPTY_GCC_EOF'
#!/usr/bin/env bash
exit 0
EMPTY_GCC_EOF
chmod +x "${_CML_TMPDIR}/empty-gcc"

_CML_NOOP_TMPDIR=$(mktemp -d)
assert_zero_exit "copy_multi_libs with empty print-multi-lib exits 0" \
    copy_multi_libs \
        dst_prefix="${_CML_NOOP_TMPDIR}/dst" \
        src_prefix="${_CML_NOOP_TMPDIR}/src" \
        target_gcc="${_CML_TMPDIR}/empty-gcc"
rm -rf "${_CML_NOOP_TMPDIR}"

rm -rf "$_CML_TMPDIR"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

print_test_results
