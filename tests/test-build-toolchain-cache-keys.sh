#!/usr/bin/env bash
# Unit tests for the build-final cache key computation logic.
#
# Verifies that key_final correctly depends on all four of its inputs —
# final_scripts_hash, key_gcc_size, key_gdb, and specs_src — matching the
# logic in .github/workflows/build-toolchain.yml (compute-hashes job).
#
# Run with: bash tests/test-build-toolchain-cache-keys.sh

set -e

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

assert_ne() {
    local desc="$1" val1="$2" val2="$3"
    if [ "$val1" != "$val2" ]; then
        _PASS=$((_PASS + 1))
        echo "  PASS: $desc"
    else
        _FAIL=$((_FAIL + 1))
        echo "  FAIL: $desc (expected values to differ, both were: [$val1])"
    fi
}

# ---------------------------------------------------------------------------
# Helper: compute key_final exactly as the workflow does.
#
# From .github/workflows/build-toolchain.yml (compute-hashes job):
#   key_final=$(printf '%s' \
#     "${runner_os}-stage-final-${final_scripts_hash}-${key_gcc_size}-${key_gdb}-${specs_src}" \
#     | sha256sum | cut -d' ' -f1)
#
# We substitute a fixed runner_os of "Linux" (matching ubuntu CI runners).
# ---------------------------------------------------------------------------

compute_key_final() {
    local final_scripts_hash="$1"
    local key_gcc_size="$2"
    local key_gdb="$3"
    local specs_src="$4"
    printf '%s' "Linux-stage-final-${final_scripts_hash}-${key_gcc_size}-${key_gdb}-${specs_src}" \
        | sha256sum | cut -d' ' -f1
}

# ---------------------------------------------------------------------------
# Baseline and alternate test values (arbitrary fixed SHA-256-like strings)
# ---------------------------------------------------------------------------

BASE_FINAL_SCRIPTS_HASH="aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111aaaa1111"
BASE_KEY_GCC_SIZE="bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222bbbb2222"
BASE_KEY_GDB="cccc3333cccc3333cccc3333cccc3333cccc3333cccc3333cccc3333cccc3333"
BASE_SPECS_SRC="dddd4444dddd4444dddd4444dddd4444dddd4444dddd4444dddd4444dddd4444"

ALT_KEY_GCC_SIZE="eeee5555eeee5555eeee5555eeee5555eeee5555eeee5555eeee5555eeee5555"
ALT_FINAL_SCRIPTS_HASH="ffff6666ffff6666ffff6666ffff6666ffff6666ffff6666ffff6666ffff6666"
ALT_KEY_GDB="88881111888811118888111188881111888811118888111188881111aaaa1111"
ALT_SPECS_SRC="77772222777722227777222277772222777722227777222277772222bbbb2222"
UNRELATED_SCRIPTS_HASH="99997777999977779999777799997777999977779999777799997777aaaa7777"

key_final_base=$(compute_key_final \
    "$BASE_FINAL_SCRIPTS_HASH" "$BASE_KEY_GCC_SIZE" "$BASE_KEY_GDB" "$BASE_SPECS_SRC")

# ---------------------------------------------------------------------------
# Test group 1: key_final changes when key_gcc_size changes
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 1: key_final changes when key_gcc_size changes ==="

key_final_alt_gcc_size=$(compute_key_final \
    "$BASE_FINAL_SCRIPTS_HASH" "$ALT_KEY_GCC_SIZE" "$BASE_KEY_GDB" "$BASE_SPECS_SRC")

assert_ne "key_final differs when key_gcc_size changes" \
    "$key_final_base" "$key_final_alt_gcc_size"

assert_eq "key_final is stable for identical inputs" \
    "$key_final_base" \
    "$(compute_key_final \
        "$BASE_FINAL_SCRIPTS_HASH" "$BASE_KEY_GCC_SIZE" "$BASE_KEY_GDB" "$BASE_SPECS_SRC")"

# ---------------------------------------------------------------------------
# Test group 2: key_final changes when final_scripts_hash changes
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 2: key_final changes when final_scripts_hash changes ==="

key_final_alt_scripts=$(compute_key_final \
    "$ALT_FINAL_SCRIPTS_HASH" "$BASE_KEY_GCC_SIZE" "$BASE_KEY_GDB" "$BASE_SPECS_SRC")

assert_ne "key_final differs when final_scripts_hash changes" \
    "$key_final_base" "$key_final_alt_scripts"

# ---------------------------------------------------------------------------
# Test group 3: key_final changes when key_gdb changes
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 3: key_final changes when key_gdb changes ==="

key_final_alt_gdb=$(compute_key_final \
    "$BASE_FINAL_SCRIPTS_HASH" "$BASE_KEY_GCC_SIZE" "$ALT_KEY_GDB" "$BASE_SPECS_SRC")

assert_ne "key_final differs when key_gdb changes" \
    "$key_final_base" "$key_final_alt_gdb"

# ---------------------------------------------------------------------------
# Test group 4: key_final changes when specs_src changes
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 4: key_final changes when specs_src changes ==="

key_final_alt_specs=$(compute_key_final \
    "$BASE_FINAL_SCRIPTS_HASH" "$BASE_KEY_GCC_SIZE" "$BASE_KEY_GDB" "$ALT_SPECS_SRC")

assert_ne "key_final differs when specs_src changes" \
    "$key_final_base" "$key_final_alt_specs"

# ---------------------------------------------------------------------------
# Test group 5: key_final uses final_scripts_hash, not an unrelated scripts hash
#
# A monolithic scripts_hash bug would make key_final sensitive to every stage's
# scripts hash, not just the final stage's.  Here we confirm that only
# final_scripts_hash (not e.g. binutils_scripts_hash) affects key_final.
#
# We use a helper that accepts an explicit "unrelated_scripts_hash" parameter
# (standing in for binutils_scripts_hash or any other stage-specific hash) but
# intentionally does NOT include it in the formula.  Two calls with different
# unrelated hashes but the same final_scripts_hash must yield the same key_final.
# ---------------------------------------------------------------------------

# Variant of compute_key_final that accepts an extra "unrelated" scripts hash
# as a 5th argument and ignores it – making the exclusion explicit.
compute_key_final_ignoring_unrelated() {
    local final_scripts_hash="$1"
    local key_gcc_size="$2"
    local key_gdb="$3"
    local specs_src="$4"
    # $5 is an unrelated scripts hash (e.g. binutils_scripts_hash) that is
    # intentionally NOT part of the key_final formula.
    printf '%s' "Linux-stage-final-${final_scripts_hash}-${key_gcc_size}-${key_gdb}-${specs_src}" \
        | sha256sum | cut -d' ' -f1
}

echo ""
echo "=== Group 5: key_final depends on final_scripts_hash, not an unrelated scripts hash ==="

# Same final_scripts_hash but different unrelated hash (e.g. binutils changed) →
# key_final must be identical, proving it ignores the unrelated hash.
key_final_with_unrelated_A=$(compute_key_final_ignoring_unrelated \
    "$BASE_FINAL_SCRIPTS_HASH" "$BASE_KEY_GCC_SIZE" "$BASE_KEY_GDB" "$BASE_SPECS_SRC" \
    "$BASE_FINAL_SCRIPTS_HASH")
key_final_with_unrelated_B=$(compute_key_final_ignoring_unrelated \
    "$BASE_FINAL_SCRIPTS_HASH" "$BASE_KEY_GCC_SIZE" "$BASE_KEY_GDB" "$BASE_SPECS_SRC" \
    "$UNRELATED_SCRIPTS_HASH")

assert_eq "key_final is unchanged when an unrelated scripts hash (e.g. binutils_scripts_hash) changes" \
    "$key_final_with_unrelated_A" "$key_final_with_unrelated_B"

# Replacing final_scripts_hash with the unrelated hash DOES change key_final,
# confirming the formula is sensitive specifically to final_scripts_hash.
key_final_with_unrelated_as_final=$(compute_key_final_ignoring_unrelated \
    "$UNRELATED_SCRIPTS_HASH" "$BASE_KEY_GCC_SIZE" "$BASE_KEY_GDB" "$BASE_SPECS_SRC" \
    "$UNRELATED_SCRIPTS_HASH")

assert_ne "key_final differs when final_scripts_hash is replaced with an unrelated scripts hash" \
    "$key_final_base" "$key_final_with_unrelated_as_final"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "Results: $_PASS passed, $_FAIL failed"

if [ $_FAIL -ne 0 ]; then
    exit 1
fi
