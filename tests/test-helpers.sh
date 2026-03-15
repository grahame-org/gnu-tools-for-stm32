# shellcheck shell=bash
# Shared test helper functions sourced by the tests/*.sh unit test scripts.
# This file is sourced (not executed directly), so it has no shebang line.
# Callers are responsible for setting their own shell options (e.g. set -e).

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

assert_unset() {
    local desc="$1" varname="$2"
    if eval "[ \"\${${varname}+set}\" != \"set\" ]"; then
        _PASS=$((_PASS + 1))
        echo "  PASS: $desc"
    else
        _FAIL=$((_FAIL + 1))
        echo "  FAIL: $desc (expected unset, got [${!varname}])"
    fi
}

print_test_results() {
    echo ""
    echo "Results: $_PASS passed, $_FAIL failed"
    if [ "$_FAIL" -ne 0 ]; then
        exit 1
    fi
}
