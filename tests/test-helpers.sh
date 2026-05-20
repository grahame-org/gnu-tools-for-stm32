# shellcheck shell=bash
# Shared test helper functions sourced by the tests/*.sh unit test scripts.
# This file is sourced (not executed directly), so it has no shebang line.
# Callers are responsible for setting their own shell options (e.g. set -e).

_PASS=${_PASS:-0}
_FAIL=${_FAIL:-0}

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
    if [ $# -lt 2 ]; then
        _FAIL=$((_FAIL + 1))
        echo "  FAIL: $desc (no command provided to assert_nonzero_exit)"
        return
    fi
    shift
    local _diag
    if _diag=$("$@" 2>&1); then
        _FAIL=$((_FAIL + 1))
        echo "  FAIL: $desc (expected non-zero exit)"
        [ -n "$_diag" ] && echo "        output: $_diag"
    else
        _PASS=$((_PASS + 1))
        echo "  PASS: $desc"
    fi
}

assert_zero_exit() {
    local desc="$1"
    if [ $# -lt 2 ]; then
        _FAIL=$((_FAIL + 1))
        echo "  FAIL: $desc (no command provided to assert_zero_exit)"
        return
    fi
    shift
    local _diag _status=0
    _diag=$("$@" 2>&1) || _status=$?
    if [ "$_status" -eq 0 ]; then
        _PASS=$((_PASS + 1))
        echo "  PASS: $desc"
    else
        _FAIL=$((_FAIL + 1))
        echo "  FAIL: $desc (expected zero exit, got status $_status)"
        [ -n "$_diag" ] && echo "        output: $_diag"
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

assert_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if printf '%s\n' "${haystack}" | grep -Fq -- "${needle}"; then
        _PASS=$((_PASS + 1))
        echo "  PASS: $desc"
    else
        _FAIL=$((_FAIL + 1))
        echo "  FAIL: $desc"
        echo "        expected to contain: [${needle}]"
        echo "        in:                  [${haystack}]"
    fi
}

assert_not_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if printf '%s\n' "${haystack}" | grep -Fq -- "${needle}"; then
        _FAIL=$((_FAIL + 1))
        echo "  FAIL: $desc"
        echo "        expected NOT to contain: [${needle}]"
        echo "        in:                      [${haystack}]"
    else
        _PASS=$((_PASS + 1))
        echo "  PASS: $desc"
    fi
}

assert_matches() {
    local desc="$1" haystack="$2" pattern="$3"
    local grep_stderr grep_status=0
    grep_stderr=$(grep -Eq -- "${pattern}" <<< "${haystack}" 2>&1) || grep_status=$?
    if [ "${grep_status}" -eq 0 ]; then
        _PASS=$((_PASS + 1))
        echo "  PASS: $desc"
    elif [ "${grep_status}" -eq 1 ]; then
        _FAIL=$((_FAIL + 1))
        echo "  FAIL: $desc"
        echo "        expected to match: [${pattern}]"
        echo "        in:                [${haystack}]"
    else
        _FAIL=$((_FAIL + 1))
        echo "  FAIL: $desc"
        echo "        grep error (status ${grep_status}): ${grep_stderr}"
        echo "        pattern: [${pattern}]"
    fi
}

assert_not_matches() {
    local desc="$1" haystack="$2" pattern="$3"
    local grep_stderr grep_status=0
    grep_stderr=$(grep -Eq -- "${pattern}" <<< "${haystack}" 2>&1) || grep_status=$?
    if [ "${grep_status}" -eq 1 ]; then
        _PASS=$((_PASS + 1))
        echo "  PASS: $desc"
    elif [ "${grep_status}" -eq 0 ]; then
        _FAIL=$((_FAIL + 1))
        echo "  FAIL: $desc"
        echo "        expected NOT to match: [${pattern}]"
        echo "        in:                    [${haystack}]"
    else
        _FAIL=$((_FAIL + 1))
        echo "  FAIL: $desc"
        echo "        grep error (status ${grep_status}): ${grep_stderr}"
        echo "        pattern: [${pattern}]"
    fi
}

assert_exit_status() {
    local desc="$1" expected_status="$2"
    if [ $# -lt 3 ]; then
        _FAIL=$((_FAIL + 1))
        echo "  FAIL: $desc (no command provided to assert_exit_status)"
        return
    fi
    shift 2
    local actual_status=0 _diag
    _diag=$("$@" 2>&1) || actual_status=$?
    if [ "$actual_status" -eq "$expected_status" ]; then
        _PASS=$((_PASS + 1))
        echo "  PASS: $desc"
    else
        _FAIL=$((_FAIL + 1))
        echo "  FAIL: $desc"
        echo "        expected exit status: [$expected_status]"
        echo "        actual exit status:   [$actual_status]"
        [ -n "$_diag" ] && echo "        output: $_diag"
    fi
}

assert_unset() {
    local desc="$1" varname="$2"
    if [ $# -lt 2 ]; then
        _FAIL=$((_FAIL + 1))
        echo "  FAIL: $desc (no variable name provided to assert_unset)"
        return
    fi
    if ! declare -p "$varname" >/dev/null 2>&1; then
        _PASS=$((_PASS + 1))
        echo "  PASS: $desc"
    else
        _FAIL=$((_FAIL + 1))
        echo "  FAIL: $desc (expected unset, got $(declare -p "$varname"))"
    fi
}

print_test_results() {
    echo ""
    echo "Results: $_PASS passed, $_FAIL failed"
    if [ "$_FAIL" -ne 0 ]; then
        exit 1
    fi
}
