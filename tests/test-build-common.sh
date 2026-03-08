#!/usr/bin/env bash
# Unit tests for saveenv/restoreenv/saveenvvar/prependenvvar/prepend_path
# in build-common.sh.
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
    if [[ ! -v "$varname" ]]; then
        _PASS=$((_PASS + 1))
        echo "  PASS: $desc"
    else
        _FAIL=$((_FAIL + 1))
        echo "  FAIL: $desc (expected unset, got [${!varname}])"
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
# Test group 10: Values containing shell metacharacters are preserved verbatim
#
# The old eval-based implementation interpolated $newval and $oldval directly
# into eval strings without quoting, meaning:
#   - double quotes in a value were consumed as shell string delimiters
#   - backslashes were consumed as escape characters
#   - unquoted expansion caused word-splitting on spaces and newlines
# The ${!var} / printf -v '%s' idioms treat values as opaque data so none of
# those characters are interpreted.
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 10: Metacharacter value preservation ==="

reset_stack

TEST_A='plain'
saveenv
saveenvvar TEST_A 'value with spaces'
assert_eq "saveenvvar preserves embedded spaces" "value with spaces" "$TEST_A"
restoreenv
assert_eq "restoreenv restores after space-containing value" "plain" "$TEST_A"

reset_stack

TEST_A='plain'
saveenv
saveenvvar TEST_A 'value with "double quotes"'
assert_eq "saveenvvar preserves double quotes" 'value with "double quotes"' "$TEST_A"
restoreenv
assert_eq "restoreenv restores after double-quote value" "plain" "$TEST_A"

reset_stack

TEST_A='plain'
saveenv
saveenvvar TEST_A 'back\slash and $dollar and `backtick`'
assert_eq "saveenvvar preserves backslash, dollar, backtick" \
    'back\slash and $dollar and `backtick`' "$TEST_A"
restoreenv
assert_eq "restoreenv restores after backslash/dollar/backtick value" "plain" "$TEST_A"

reset_stack

TEST_A='plain'
saveenv
saveenvvar TEST_A 'semi;colon and |pipe and &amp'
assert_eq "saveenvvar preserves shell command separators" \
    'semi;colon and |pipe and &amp' "$TEST_A"
restoreenv
assert_eq "restoreenv restores after command-separator value" "plain" "$TEST_A"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "Results: $_PASS passed, $_FAIL failed"

if [ $_FAIL -ne 0 ]; then
    exit 1
fi
