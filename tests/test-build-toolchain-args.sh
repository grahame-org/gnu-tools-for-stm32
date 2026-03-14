#!/usr/bin/env bash
# Unit tests for parse_toolchain_args() in build-toolchain-args.sh.
#
# Run with: bash tests/test-build-toolchain-args.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source build-toolchain-args.sh to get parse_toolchain_args() and
# _toolchain_usage().  This does NOT trigger any build steps.
# shellcheck source=../build-toolchain-args.sh
. "$REPO_ROOT/build-toolchain-args.sh"

# ---------------------------------------------------------------------------
# Minimal test harness (same pattern as test-build-common.sh)
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

# ---------------------------------------------------------------------------
# Test group 1: --skip_steps parsing
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 1: --skip_steps parsing ==="

parse_toolchain_args --skip_steps=manual,strip
assert_eq "--skip_steps=manual,strip produces space-separated value" \
    "manual strip" "$skip_steps"

parse_toolchain_args --skip_steps=
assert_eq "--skip_steps= (empty) produces empty variable" "" "$skip_steps"

parse_toolchain_args --skip_steps=manual,package_bins,strip
assert_eq "--skip_steps=manual sets skip_manual=yes" "yes" "$skip_manual"
assert_eq "--skip_steps=package_bins sets skip_package_bins=yes" "yes" "$skip_package_bins"
assert_eq "--skip_steps=strip sets skip_strip_target_libraries=yes" "yes" "$skip_strip_target_libraries"

parse_toolchain_args --skip_steps=mingw
assert_eq "--skip_steps=mingw sets skip_mingw32=yes" "yes" "$skip_mingw32"
assert_eq "--skip_steps=mingw sets skip_mingw32_gdb_with_python=yes" "yes" "$skip_mingw32_gdb_with_python"

parse_toolchain_args --skip_steps=mingw32
assert_eq "--skip_steps=mingw32 sets skip_mingw32=yes" "yes" "$skip_mingw32"

parse_toolchain_args --skip_steps=mingw-gdb-with-python
assert_eq "--skip_steps=mingw-gdb-with-python sets skip_mingw32_gdb_with_python=yes" \
    "yes" "$skip_mingw32_gdb_with_python"

parse_toolchain_args --skip_steps=mingw32-gdb-with-python
assert_eq "--skip_steps=mingw32-gdb-with-python sets skip_mingw32_gdb_with_python=yes" \
    "yes" "$skip_mingw32_gdb_with_python"

parse_toolchain_args --skip_steps=native
assert_eq "--skip_steps=native sets skip_native_build=yes" "yes" "$skip_native_build"

parse_toolchain_args --skip_steps=package_sources
assert_eq "--skip_steps=package_sources sets skip_package_sources=yes" "yes" "$skip_package_sources"

parse_toolchain_args --skip_steps=md5_checksum
assert_eq "--skip_steps=md5_checksum sets skip_md5_checksum=yes" "yes" "$skip_md5_checksum"

parse_toolchain_args --skip_steps=gdb-with-python
assert_eq "--skip_steps=gdb-with-python sets skip_gdb_with_python=yes" "yes" "$skip_gdb_with_python"

# ---------------------------------------------------------------------------
# Test group 2: --skip_stages parsing
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 2: --skip_stages parsing ==="

parse_toolchain_args --skip_stages=binutils,gcc-first
assert_eq "--skip_stages=binutils,gcc-first produces space-separated value" \
    "binutils gcc-first" "$skip_stages"

parse_toolchain_args --skip_stages=
assert_eq "--skip_stages= (empty) produces empty variable" "" "$skip_stages"

parse_toolchain_args --skip_stages=newlib
assert_eq "--skip_stages=newlib sets skip_stages=newlib" "newlib" "$skip_stages"

parse_toolchain_args --skip_stages=gcc-final,gdb
assert_eq "--skip_stages=gcc-final,gdb sets skip_stages correctly" \
    "gcc-final gdb" "$skip_stages"

parse_toolchain_args --skip_stages=newlib-nano
assert_eq "--skip_stages=newlib-nano is accepted" "newlib-nano" "$skip_stages"

parse_toolchain_args --skip_stages=gcc-size-libstdcxx
assert_eq "--skip_stages=gcc-size-libstdcxx is accepted" "gcc-size-libstdcxx" "$skip_stages"

# ---------------------------------------------------------------------------
# Test group 3: --build_type parsing
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 3: --build_type parsing ==="

parse_toolchain_args --build_type=native
assert_eq "--build_type=native sets is_native_build=yes" "yes" "$is_native_build"
assert_eq "--build_type=native sets is_ppa_release=no" "no" "$is_ppa_release"

parse_toolchain_args --build_type=ppa
assert_eq "--build_type=ppa sets is_ppa_release=yes" "yes" "$is_ppa_release"
assert_eq "--build_type=ppa sets is_native_build=no" "no" "$is_native_build"

parse_toolchain_args --build_type=native,debug
assert_eq "--build_type=native,debug sets is_native_build=yes" "yes" "$is_native_build"
assert_eq "--build_type=native,debug sets is_debug_build=yes" "yes" "$is_debug_build"
assert_eq "--build_type=native,debug sets BUILD_OPTIONS=-g -O0" "-g -O0" "$BUILD_OPTIONS"

parse_toolchain_args --build_type=ppa,debug
assert_eq "--build_type=ppa,debug sets is_ppa_release=yes" "yes" "$is_ppa_release"
assert_eq "--build_type=ppa,debug sets is_debug_build=yes" "yes" "$is_debug_build"

# ---------------------------------------------------------------------------
# Test group 4: defaults when no flags given
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 4: defaults when no flags given ==="

parse_toolchain_args
assert_eq "default skip_steps is empty"       ""    "$skip_steps"
assert_eq "default skip_stages is empty"      ""    "$skip_stages"
assert_eq "default build_type is empty"       ""    "$build_type"
assert_eq "default is_native_build=yes"       "yes" "$is_native_build"
assert_eq "default is_ppa_release=no"         "no"  "$is_ppa_release"
assert_eq "default is_debug_build=no"         "no"  "$is_debug_build"
assert_eq "default BUILD_OPTIONS=-g -O2"      "-g -O2" "$BUILD_OPTIONS"
assert_eq "default skip_manual=no"            "no"  "$skip_manual"
assert_eq "default skip_package_bins=no"      "no"  "$skip_package_bins"
assert_eq "default skip_package_sources=no"   "no"  "$skip_package_sources"
assert_eq "default skip_md5_checksum=no"      "no"  "$skip_md5_checksum"
assert_eq "default skip_gdb_with_python=yes"  "yes" "$skip_gdb_with_python"
assert_eq "default skip_mingw32=no"           "no"  "$skip_mingw32"
assert_eq "default skip_native_build=no"      "no"  "$skip_native_build"
assert_eq "default skip_strip_target_libraries=no" "no" "$skip_strip_target_libraries"
assert_eq "default MULTILIB_LIST" \
    "--with-multilib-list=rmprofile,aprofile" "$MULTILIB_LIST"

# ---------------------------------------------------------------------------
# Test group 5: --with-multilib-list parsing
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 5: --with-multilib-list parsing ==="

parse_toolchain_args --with-multilib-list=rmprofile
assert_eq "--with-multilib-list=rmprofile sets MULTILIB_LIST" \
    "--with-multilib-list=rmprofile" "$MULTILIB_LIST"

parse_toolchain_args --with-multilib-list=rmprofile,aprofile
assert_eq "--with-multilib-list=rmprofile,aprofile preserves comma" \
    "--with-multilib-list=rmprofile,aprofile" "$MULTILIB_LIST"

# ---------------------------------------------------------------------------
# Test group 6: multiple flags combined
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 6: Multiple flags combined ==="

parse_toolchain_args --build_type=native --skip_steps=manual,strip
assert_eq "combined: is_native_build=yes"          "yes" "$is_native_build"
assert_eq "combined: skip_manual=yes"              "yes" "$skip_manual"
assert_eq "combined: skip_strip_target_libraries=yes" "yes" "$skip_strip_target_libraries"

parse_toolchain_args --build_type=ppa --skip_steps=package_sources --with-multilib-list=rmprofile
assert_eq "combined 3 flags: is_ppa_release=yes"      "yes" "$is_ppa_release"
assert_eq "combined 3 flags: skip_package_sources=yes" "yes" "$skip_package_sources"
assert_eq "combined 3 flags: MULTILIB_LIST" \
    "--with-multilib-list=rmprofile" "$MULTILIB_LIST"

parse_toolchain_args --build_type=native --skip_steps=strip --skip_stages=binutils,gdb
assert_eq "combined 4 flags: is_native_build=yes"      "yes" "$is_native_build"
assert_eq "combined 4 flags: skip_strip_target_libraries=yes" "yes" "$skip_strip_target_libraries"
assert_eq "combined 4 flags: skip_stages=binutils gdb" "binutils gdb" "$skip_stages"

# ---------------------------------------------------------------------------
# Test group 7: error conditions — unrecognised arguments exit non-zero
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 7: Error conditions ==="

assert_nonzero_exit "unrecognised flag exits non-zero" \
    bash -c '. "$1/build-toolchain-args.sh"; parse_toolchain_args --unknown-flag' _ "$REPO_ROOT"

assert_nonzero_exit "unknown --build_type value exits non-zero" \
    bash -c '. "$1/build-toolchain-args.sh"; parse_toolchain_args --build_type=badtype' _ "$REPO_ROOT"

assert_nonzero_exit "unknown --skip_steps value exits non-zero" \
    bash -c '. "$1/build-toolchain-args.sh"; parse_toolchain_args --skip_steps=nosuchstep' _ "$REPO_ROOT"

# ---------------------------------------------------------------------------
# Test group 8: variables reset on each call
# ---------------------------------------------------------------------------
# Each call to parse_toolchain_args must reset all state, so that calling it
# twice in the same process doesn't accumulate flags from previous calls.

echo ""
echo "=== Group 8: Reset behaviour (each call is idempotent) ==="

parse_toolchain_args --build_type=ppa,debug --skip_steps=manual,strip \
    --skip_stages=binutils --with-multilib-list=rmprofile
# Now call again with no args — everything should revert to defaults
parse_toolchain_args
assert_eq "reset: skip_steps is empty"              "" "$skip_steps"
assert_eq "reset: skip_stages is empty"             "" "$skip_stages"
assert_eq "reset: build_type is empty"              "" "$build_type"
assert_eq "reset: is_native_build=yes"              "yes" "$is_native_build"
assert_eq "reset: is_ppa_release=no"                "no" "$is_ppa_release"
assert_eq "reset: is_debug_build=no"                "no" "$is_debug_build"
assert_eq "reset: BUILD_OPTIONS=-g -O2"             "-g -O2" "$BUILD_OPTIONS"
assert_eq "reset: skip_manual=no"                   "no" "$skip_manual"
assert_eq "reset: skip_strip_target_libraries=no"   "no" "$skip_strip_target_libraries"
assert_eq "reset: skip_package_sources=no"          "no" "$skip_package_sources"
assert_eq "reset: skip_gdb_with_python=yes"         "yes" "$skip_gdb_with_python"
assert_eq "reset: skip_mingw32_gdb_with_python=yes" "yes" "$skip_mingw32_gdb_with_python"
assert_eq "reset: MULTILIB_LIST is default" \
    "--with-multilib-list=rmprofile,aprofile" "$MULTILIB_LIST"

# ---------------------------------------------------------------------------
# Test group 9: additional build_type combinations
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 9: Additional --build_type combinations ==="

# debug alone (no explicit native/ppa): sets debug flags but is_native_build stays yes
parse_toolchain_args --build_type=debug
assert_eq "--build_type=debug sets is_debug_build=yes"    "yes" "$is_debug_build"
assert_eq "--build_type=debug sets BUILD_OPTIONS=-g -O0"  "-g -O0" "$BUILD_OPTIONS"
assert_eq "--build_type=debug keeps is_native_build=yes"  "yes" "$is_native_build"
assert_eq "--build_type=debug keeps is_ppa_release=no"    "no"  "$is_ppa_release"

# ppa,debug: should also produce debug build options
parse_toolchain_args --build_type=ppa,debug
assert_eq "--build_type=ppa,debug sets is_ppa_release=yes"  "yes" "$is_ppa_release"
assert_eq "--build_type=ppa,debug sets is_debug_build=yes"  "yes" "$is_debug_build"
assert_eq "--build_type=ppa,debug sets BUILD_OPTIONS=-g -O0" "-g -O0" "$BUILD_OPTIONS"

# ---------------------------------------------------------------------------
# Test group 10: default skip_mingw32_gdb_with_python is yes
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 10: Default skip_mingw32_gdb_with_python ==="

parse_toolchain_args
assert_eq "default skip_mingw32_gdb_with_python=yes" "yes" "$skip_mingw32_gdb_with_python"

parse_toolchain_args --build_type=native
assert_eq "native build keeps skip_mingw32_gdb_with_python=yes" "yes" "$skip_mingw32_gdb_with_python"

parse_toolchain_args --build_type=ppa
assert_eq "ppa build keeps skip_mingw32_gdb_with_python=yes" "yes" "$skip_mingw32_gdb_with_python"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "Results: $_PASS passed, $_FAIL failed"

if [ $_FAIL -ne 0 ]; then
    exit 1
fi
