#!/usr/bin/env bash
# Unit tests for .github/actions/build-stage/action.yml structure.
#
# Validates YAML syntax and style with yamllint, and semantic structure
# (required inputs, outputs, composite type, clean-before-cache-save step)
# via pytest.
#
# Run with: bash tests/test-build-stage-action.sh
# Requires:  yamllint, pytest – install via: python3 -m pip install -r tests/requirements.txt

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ACTION_YML="${REPO_ROOT}/.github/actions/build-stage/action.yml"
YAMLLINT_CFG="${REPO_ROOT}/.yamllint"

# shellcheck source=test-helpers.sh
. "$SCRIPT_DIR/test-helpers.sh"

if [ ! -f "${ACTION_YML}" ]; then
    echo "ERROR: action.yml not found at ${ACTION_YML}" >&2
    exit 1
fi

if ! command -v yamllint > /dev/null 2>&1; then
    echo "ERROR: yamllint is required but not found; install with: pip3 install yamllint" >&2
    exit 1
fi

if ! command -v python3 > /dev/null 2>&1; then
    echo "ERROR: python3 is required but not found" >&2
    exit 1
fi

if ! python3 -m pytest --version > /dev/null 2>&1; then
    echo "ERROR: pytest is required but not found; install with: pip3 install -r tests/requirements.txt" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Test group 1: YAML syntax and style (yamllint)
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 1: YAML syntax and style (yamllint) ==="

yamllint_rc=0
yamllint_out=$(yamllint -c "${YAMLLINT_CFG}" "${ACTION_YML}" 2>&1) || yamllint_rc=$?
if [ "$yamllint_rc" -eq 0 ]; then
    _PASS=$((_PASS + 1))
    echo "  PASS: yamllint: action.yml is syntactically valid and well-formed"
else
    _FAIL=$((_FAIL + 1))
    echo "  FAIL: yamllint: action.yml has syntax or style issues"
    echo "$yamllint_out"
fi

# ---------------------------------------------------------------------------
# Tests groups 2–6: Semantic structure (pytest)
# ---------------------------------------------------------------------------

echo ""
echo "=== Groups 2–6: Semantic structure (pytest) ==="

pytest_rc=0
python3 -m pytest "${SCRIPT_DIR}/test_build_stage_action.py" -v || pytest_rc=$?
if [ "$pytest_rc" -eq 0 ]; then
    _PASS=$((_PASS + 1))
    echo "  PASS: pytest: all semantic structure tests passed"
else
    _FAIL=$((_FAIL + 1))
    echo "  FAIL: pytest: one or more semantic structure tests failed (see output above)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

print_test_results
