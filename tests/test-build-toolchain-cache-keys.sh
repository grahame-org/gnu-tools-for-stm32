#!/usr/bin/env bash
# Unit tests for the build-toolchain.yml cache key computation logic.
#
# Verifies that each stage's cache key correctly depends on all of its inputs,
# matching the logic in .github/workflows/build-toolchain.yml (compute-hashes
# job).  Key relationships tested:
#
#   key_binutils    ← binutils_scripts_hash, prereqs_key, binutils_src
#   key_gcc_first   ← gcc_first_scripts_hash, key_binutils, gcc_src
#   key_newlib      ← newlib_scripts_hash, key_gcc_first, newlib_src
#   key_newlib_nano ← newlib_nano_scripts_hash, key_gcc_first, newlib_src
#   key_gcc_final   ← gcc_final_scripts_hash, key_newlib, gcc_src
#                     (does NOT depend on key_newlib_nano)
#   key_gcc_size    ← gcc_size_scripts_hash, key_gcc_final, key_newlib_nano, gcc_src
#                     (depends on BOTH key_gcc_final AND key_newlib_nano)
#   key_gdb         ← gdb_scripts_hash, key_binutils, gdb_src
#   key_final       ← final_scripts_hash, key_gcc_size, key_gdb, specs_src
#
# Run with: bash tests/test-build-toolchain-cache-keys.sh

set -euo pipefail

# shellcheck source=test-helpers.sh
. "$(dirname "$0")/test-helpers.sh"

# ---------------------------------------------------------------------------
# Helpers: compute each cache key exactly as the workflow does.
#
# From .github/workflows/build-toolchain.yml (compute-hashes job).
# We substitute a fixed runner_os of "Linux" (matching ubuntu CI runners).
# ---------------------------------------------------------------------------

_sha256() { printf '%s' "$1" | sha256sum | cut -d' ' -f1; }

compute_key_binutils() {
    local binutils_scripts_hash="$1" prereqs_key="$2" binutils_src="$3"
    _sha256 "Linux-stage-binutils-${binutils_scripts_hash}-${prereqs_key}-${binutils_src}"
}

compute_key_gcc_first() {
    local gcc_first_scripts_hash="$1" key_binutils="$2" gcc_src="$3"
    _sha256 "Linux-stage-gcc-first-${gcc_first_scripts_hash}-${key_binutils}-${gcc_src}"
}

compute_key_newlib() {
    local newlib_scripts_hash="$1" key_gcc_first="$2" newlib_src="$3"
    _sha256 "Linux-stage-newlib-${newlib_scripts_hash}-${key_gcc_first}-${newlib_src}"
}

compute_key_newlib_nano() {
    local newlib_nano_scripts_hash="$1" key_gcc_first="$2" newlib_src="$3"
    _sha256 "Linux-stage-newlib-nano-${newlib_nano_scripts_hash}-${key_gcc_first}-${newlib_src}"
}

compute_key_gcc_final() {
    local gcc_final_scripts_hash="$1" key_newlib="$2" gcc_src="$3"
    _sha256 "Linux-stage-gcc-final-${gcc_final_scripts_hash}-${key_newlib}-${gcc_src}"
}

compute_key_gcc_size() {
    local gcc_size_scripts_hash="$1" key_gcc_final="$2" key_newlib_nano="$3" gcc_src="$4"
    _sha256 "Linux-stage-gcc-size-libstdcxx-${gcc_size_scripts_hash}-${key_gcc_final}-${key_newlib_nano}-${gcc_src}"
}

compute_key_gdb() {
    local gdb_scripts_hash="$1" key_binutils="$2" gdb_src="$3"
    _sha256 "Linux-stage-gdb-${gdb_scripts_hash}-${key_binutils}-${gdb_src}"
}

compute_key_final() {
    local final_scripts_hash="$1"
    local key_gcc_size="$2"
    local key_gdb="$3"
    local specs_src="$4"
    _sha256 "Linux-stage-final-${final_scripts_hash}-${key_gcc_size}-${key_gdb}-${specs_src}"
}

# ---------------------------------------------------------------------------
# Baseline and alternate test values (arbitrary fixed SHA-256-like strings)
# ---------------------------------------------------------------------------

BASE_BINUTILS_SCRIPTS_HASH="aaaa0000aaaa0000aaaa0000aaaa0000aaaa0000aaaa0000aaaa0000aaaa0000"
BASE_GCC_FIRST_SCRIPTS_HASH="aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111"
BASE_NEWLIB_SCRIPTS_HASH="aaaa2222aaaa2222aaaa2222aaaa2222aaaa2222aaaa2222aaaa2222aaaa2222"
BASE_NEWLIB_NANO_SCRIPTS_HASH="aaaa3333aaaa3333aaaa3333aaaa3333aaaa3333aaaa3333aaaa3333aaaa3333"
BASE_GCC_FINAL_SCRIPTS_HASH="aaaa4444aaaa4444aaaa4444aaaa4444aaaa4444aaaa4444aaaa4444aaaa4444"
BASE_GCC_SIZE_SCRIPTS_HASH="aaaa5555aaaa5555aaaa5555aaaa5555aaaa5555aaaa5555aaaa5555aaaa5555"
BASE_GDB_SCRIPTS_HASH="aaaa6666aaaa6666aaaa6666aaaa6666aaaa6666aaaa6666aaaa6666aaaa6666"
BASE_FINAL_SCRIPTS_HASH="aaaa7777aaaa7777aaaa7777aaaa7777aaaa7777aaaa7777aaaa7777aaaa7777"

BASE_PREREQS_KEY="bbbb0000bbbb0000bbbb0000bbbb0000bbbb0000bbbb0000bbbb0000bbbb0000"
BASE_BINUTILS_SRC="bbbb1111bbbb1111bbbb1111bbbb1111bbbb1111bbbb1111bbbb1111bbbb1111"
BASE_GCC_SRC="bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222"
BASE_NEWLIB_SRC="bbbb3333bbbb3333bbbb3333bbbb3333bbbb3333bbbb3333bbbb3333bbbb3333"
BASE_GDB_SRC="bbbb4444bbbb4444bbbb4444bbbb4444bbbb4444bbbb4444bbbb4444bbbb4444"
BASE_SPECS_SRC="bbbb5555bbbb5555bbbb5555bbbb5555bbbb5555bbbb5555bbbb5555bbbb5555"

ALT_BINUTILS_SCRIPTS_HASH="cccc0000cccc0000cccc0000cccc0000cccc0000cccc0000cccc0000cccc0000"
ALT_GCC_FIRST_SCRIPTS_HASH="cccc1111cccc1111cccc1111cccc1111cccc1111cccc1111cccc1111cccc1111"
ALT_NEWLIB_SCRIPTS_HASH="cccc2222cccc2222cccc2222cccc2222cccc2222cccc2222cccc2222cccc2222"
ALT_NEWLIB_NANO_SCRIPTS_HASH="cccc3333cccc3333cccc3333cccc3333cccc3333cccc3333cccc3333cccc3333"
ALT_GCC_FINAL_SCRIPTS_HASH="cccc4444cccc4444cccc4444cccc4444cccc4444cccc4444cccc4444cccc4444"
ALT_GCC_SIZE_SCRIPTS_HASH="cccc5555cccc5555cccc5555cccc5555cccc5555cccc5555cccc5555cccc5555"
ALT_GDB_SCRIPTS_HASH="cccc6666cccc6666cccc6666cccc6666cccc6666cccc6666cccc6666cccc6666"
ALT_FINAL_SCRIPTS_HASH="cccc7777cccc7777cccc7777cccc7777cccc7777cccc7777cccc7777cccc7777"

ALT_BINUTILS_SRC="dddd1111dddd1111dddd1111dddd1111dddd1111dddd1111dddd1111dddd1111"
ALT_GCC_SRC="dddd2222dddd2222dddd2222dddd2222dddd2222dddd2222dddd2222dddd2222"
ALT_NEWLIB_SRC="dddd3333dddd3333dddd3333dddd3333dddd3333dddd3333dddd3333dddd3333"
ALT_GDB_SRC="dddd4444dddd4444dddd4444dddd4444dddd4444dddd4444dddd4444dddd4444"
ALT_SPECS_SRC="dddd5555dddd5555dddd5555dddd5555dddd5555dddd5555dddd5555dddd5555"

# Pre-compute baseline keys for the full chain.
BASE_KEY_BINUTILS=$(compute_key_binutils \
    "$BASE_BINUTILS_SCRIPTS_HASH" "$BASE_PREREQS_KEY" "$BASE_BINUTILS_SRC")
BASE_KEY_GCC_FIRST=$(compute_key_gcc_first \
    "$BASE_GCC_FIRST_SCRIPTS_HASH" "$BASE_KEY_BINUTILS" "$BASE_GCC_SRC")
BASE_KEY_NEWLIB=$(compute_key_newlib \
    "$BASE_NEWLIB_SCRIPTS_HASH" "$BASE_KEY_GCC_FIRST" "$BASE_NEWLIB_SRC")
BASE_KEY_NEWLIB_NANO=$(compute_key_newlib_nano \
    "$BASE_NEWLIB_NANO_SCRIPTS_HASH" "$BASE_KEY_GCC_FIRST" "$BASE_NEWLIB_SRC")
BASE_KEY_GCC_FINAL=$(compute_key_gcc_final \
    "$BASE_GCC_FINAL_SCRIPTS_HASH" "$BASE_KEY_NEWLIB" "$BASE_GCC_SRC")
BASE_KEY_GCC_SIZE=$(compute_key_gcc_size \
    "$BASE_GCC_SIZE_SCRIPTS_HASH" "$BASE_KEY_GCC_FINAL" "$BASE_KEY_NEWLIB_NANO" "$BASE_GCC_SRC")
BASE_KEY_GDB=$(compute_key_gdb \
    "$BASE_GDB_SCRIPTS_HASH" "$BASE_KEY_BINUTILS" "$BASE_GDB_SRC")

key_final_base=$(compute_key_final \
    "$BASE_FINAL_SCRIPTS_HASH" "$BASE_KEY_GCC_SIZE" "$BASE_KEY_GDB" "$BASE_SPECS_SRC")

# ---------------------------------------------------------------------------
# Test group 1: key_final changes when any of its four inputs change
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 1: key_final responds to each of its four inputs ==="

assert_eq "key_final is stable for identical inputs" \
    "$key_final_base" \
    "$(compute_key_final \
        "$BASE_FINAL_SCRIPTS_HASH" "$BASE_KEY_GCC_SIZE" "$BASE_KEY_GDB" "$BASE_SPECS_SRC")"

assert_ne "key_final differs when key_gcc_size changes" \
    "$key_final_base" \
    "$(compute_key_final \
        "$BASE_FINAL_SCRIPTS_HASH" \
        "$(compute_key_gcc_size \
            "$ALT_GCC_SIZE_SCRIPTS_HASH" "$BASE_KEY_GCC_FINAL" "$BASE_KEY_NEWLIB_NANO" "$BASE_GCC_SRC")" \
        "$BASE_KEY_GDB" "$BASE_SPECS_SRC")"

assert_ne "key_final differs when final_scripts_hash changes" \
    "$key_final_base" \
    "$(compute_key_final \
        "$ALT_FINAL_SCRIPTS_HASH" "$BASE_KEY_GCC_SIZE" "$BASE_KEY_GDB" "$BASE_SPECS_SRC")"

assert_ne "key_final differs when key_gdb changes" \
    "$key_final_base" \
    "$(compute_key_final \
        "$BASE_FINAL_SCRIPTS_HASH" "$BASE_KEY_GCC_SIZE" \
        "$(compute_key_gdb \
            "$ALT_GDB_SCRIPTS_HASH" "$BASE_KEY_BINUTILS" "$BASE_GDB_SRC")" \
        "$BASE_SPECS_SRC")"

assert_ne "key_final differs when specs_src changes" \
    "$key_final_base" \
    "$(compute_key_final \
        "$BASE_FINAL_SCRIPTS_HASH" "$BASE_KEY_GCC_SIZE" "$BASE_KEY_GDB" "$ALT_SPECS_SRC")"

# ---------------------------------------------------------------------------
# Test group 2: key_gcc_size depends on BOTH key_gcc_final AND key_newlib_nano
#
# This is the critical architectural constraint: changing newlib-nano must
# invalidate the gcc-size-libstdcxx cache even when gcc-final is unchanged,
# and vice versa.
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 2: key_gcc_size depends on both key_gcc_final and key_newlib_nano ==="

key_gcc_size_alt_final=$(compute_key_gcc_size \
    "$BASE_GCC_SIZE_SCRIPTS_HASH" \
    "$(compute_key_gcc_final \
        "$ALT_GCC_FINAL_SCRIPTS_HASH" "$BASE_KEY_NEWLIB" "$BASE_GCC_SRC")" \
    "$BASE_KEY_NEWLIB_NANO" "$BASE_GCC_SRC")

key_gcc_size_alt_newlib_nano=$(compute_key_gcc_size \
    "$BASE_GCC_SIZE_SCRIPTS_HASH" "$BASE_KEY_GCC_FINAL" \
    "$(compute_key_newlib_nano \
        "$ALT_NEWLIB_NANO_SCRIPTS_HASH" "$BASE_KEY_GCC_FIRST" "$BASE_NEWLIB_SRC")" \
    "$BASE_GCC_SRC")

assert_ne "key_gcc_size changes when key_gcc_final changes" \
    "$BASE_KEY_GCC_SIZE" "$key_gcc_size_alt_final"

assert_ne "key_gcc_size changes when key_newlib_nano changes" \
    "$BASE_KEY_GCC_SIZE" "$key_gcc_size_alt_newlib_nano"

assert_ne "key_gcc_size changes independently for each upstream" \
    "$key_gcc_size_alt_final" "$key_gcc_size_alt_newlib_nano"

# ---------------------------------------------------------------------------
# Test group 3: key_gcc_final does NOT depend on key_newlib_nano
#
# key_gcc_final chains through key_newlib, not key_newlib_nano.  A change to
# only newlib-nano scripts must not invalidate the gcc-final cache.
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 3: key_gcc_final depends on key_newlib but not key_newlib_nano ==="

# Changing newlib_nano_scripts_hash changes key_newlib_nano but not key_gcc_final.
alt_key_newlib_nano=$(compute_key_newlib_nano \
    "$ALT_NEWLIB_NANO_SCRIPTS_HASH" "$BASE_KEY_GCC_FIRST" "$BASE_NEWLIB_SRC")

# key_gcc_final is computed from key_newlib (not key_newlib_nano), so it must
# be unchanged when only newlib-nano's scripts hash changes.
assert_eq "key_gcc_final unchanged when only newlib-nano scripts change" \
    "$BASE_KEY_GCC_FINAL" \
    "$(compute_key_gcc_final \
        "$BASE_GCC_FINAL_SCRIPTS_HASH" "$BASE_KEY_NEWLIB" "$BASE_GCC_SRC")"

# Sanity: key_newlib_nano did actually change.
assert_ne "key_newlib_nano changes when its scripts hash changes" \
    "$BASE_KEY_NEWLIB_NANO" "$alt_key_newlib_nano"

# Changing newlib scripts does change key_gcc_final (via key_newlib).
assert_ne "key_gcc_final changes when newlib_src changes (via key_newlib)" \
    "$BASE_KEY_GCC_FINAL" \
    "$(compute_key_gcc_final \
        "$BASE_GCC_FINAL_SCRIPTS_HASH" \
        "$(compute_key_newlib \
            "$BASE_NEWLIB_SCRIPTS_HASH" "$BASE_KEY_GCC_FIRST" "$ALT_NEWLIB_SRC")" \
        "$BASE_GCC_SRC")"

# ---------------------------------------------------------------------------
# Test group 4: key_newlib and key_newlib_nano share source and gcc_first inputs
#               but differ because they use distinct stage-name prefixes
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 4: key_newlib and key_newlib_nano differ despite shared inputs ==="

# When both use the same scripts hash they must still differ due to stage-name prefix.
key_newlib_same_hash=$(compute_key_newlib \
    "$BASE_NEWLIB_SCRIPTS_HASH" "$BASE_KEY_GCC_FIRST" "$BASE_NEWLIB_SRC")
key_newlib_nano_same_hash=$(compute_key_newlib_nano \
    "$BASE_NEWLIB_SCRIPTS_HASH" "$BASE_KEY_GCC_FIRST" "$BASE_NEWLIB_SRC")

assert_ne "key_newlib ≠ key_newlib_nano even when scripts hashes are equal" \
    "$key_newlib_same_hash" "$key_newlib_nano_same_hash"

assert_ne "key_newlib changes when newlib_src changes" \
    "$BASE_KEY_NEWLIB" \
    "$(compute_key_newlib \
        "$BASE_NEWLIB_SCRIPTS_HASH" "$BASE_KEY_GCC_FIRST" "$ALT_NEWLIB_SRC")"

assert_ne "key_newlib_nano changes when newlib_src changes" \
    "$BASE_KEY_NEWLIB_NANO" \
    "$(compute_key_newlib_nano \
        "$BASE_NEWLIB_NANO_SCRIPTS_HASH" "$BASE_KEY_GCC_FIRST" "$ALT_NEWLIB_SRC")"

# ---------------------------------------------------------------------------
# Test group 5: transitivity — binutils change propagates through the chain
#
# A change in binutils_src must eventually reach key_final via key_gcc_size
# (through key_gcc_first → key_newlib → key_gcc_final → key_gcc_size).
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 5: binutils change propagates transitively to key_final ==="

alt_key_binutils=$(compute_key_binutils \
    "$BASE_BINUTILS_SCRIPTS_HASH" "$BASE_PREREQS_KEY" "$ALT_BINUTILS_SRC")
alt_key_gcc_first=$(compute_key_gcc_first \
    "$BASE_GCC_FIRST_SCRIPTS_HASH" "$alt_key_binutils" "$BASE_GCC_SRC")
alt_key_newlib=$(compute_key_newlib \
    "$BASE_NEWLIB_SCRIPTS_HASH" "$alt_key_gcc_first" "$BASE_NEWLIB_SRC")
alt_key_newlib_nano=$(compute_key_newlib_nano \
    "$BASE_NEWLIB_NANO_SCRIPTS_HASH" "$alt_key_gcc_first" "$BASE_NEWLIB_SRC")
alt_key_gcc_final=$(compute_key_gcc_final \
    "$BASE_GCC_FINAL_SCRIPTS_HASH" "$alt_key_newlib" "$BASE_GCC_SRC")
alt_key_gcc_size=$(compute_key_gcc_size \
    "$BASE_GCC_SIZE_SCRIPTS_HASH" "$alt_key_gcc_final" "$alt_key_newlib_nano" "$BASE_GCC_SRC")
alt_key_gdb=$(compute_key_gdb \
    "$BASE_GDB_SCRIPTS_HASH" "$alt_key_binutils" "$BASE_GDB_SRC")

assert_ne "key_binutils changes when binutils_src changes" \
    "$BASE_KEY_BINUTILS" "$alt_key_binutils"
assert_ne "key_gcc_first propagates binutils_src change" \
    "$BASE_KEY_GCC_FIRST" "$alt_key_gcc_first"
assert_ne "key_gcc_size propagates binutils_src change transitively" \
    "$BASE_KEY_GCC_SIZE" "$alt_key_gcc_size"
assert_ne "key_gdb propagates binutils change (key_gdb chains through key_binutils)" \
    "$BASE_KEY_GDB" "$alt_key_gdb"
assert_ne "key_final propagates binutils_src change end-to-end" \
    "$key_final_base" \
    "$(compute_key_final \
        "$BASE_FINAL_SCRIPTS_HASH" "$alt_key_gcc_size" "$alt_key_gdb" "$BASE_SPECS_SRC")"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

print_test_results
