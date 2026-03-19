#!/usr/bin/env bash
# Unit tests for .github/actions/build-stage/action.yml structure.
#
# Validates YAML syntax and style with yamllint, and semantic structure
# (required inputs, outputs, composite type) via pytest.
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
# Tests groups 2–5: Semantic structure (pytest)
# ---------------------------------------------------------------------------

echo ""
echo "=== Groups 2–5: Semantic structure (pytest) ==="

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
# Test group 6: Clean before cache save step
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 6: Clean before cache save step ==="

py_assert "'Clean before cache save' step exists" \
    "import yaml, sys; f=open(sys.argv[1]); d=yaml.safe_load(f); f.close(); steps=d['runs']['steps']; assert any('Clean before cache save' in (s.get('name','')) for s in steps)"

py_assert "'Clean before cache save' step has same condition as 'Save cache' step" \
    "import yaml, sys; f=open(sys.argv[1]); d=yaml.safe_load(f); f.close(); steps=d['runs']['steps']; clean_step=next(s for s in steps if 'Clean before cache save' in s.get('name','')); save_step=next(s for s in steps if 'Save cache' in s.get('name','')); assert clean_step.get('if') == save_step.get('if'), f'clean: {clean_step.get(\"if\")!r} != save: {save_step.get(\"if\")!r}'"

py_assert "'Clean before cache save' step uses bash shell" \
    "import yaml, sys; f=open(sys.argv[1]); d=yaml.safe_load(f); f.close(); steps=d['runs']['steps']; step=next(s for s in steps if 'Clean before cache save' in s.get('name','')); assert step.get('shell')=='bash'"

py_assert "'Clean before cache save' step delegates to clean-before-cache-save.sh" \
    "import yaml, sys; f=open(sys.argv[1]); d=yaml.safe_load(f); f.close(); steps=d['runs']['steps']; step=next(s for s in steps if 'Clean before cache save' in s.get('name','')); assert 'clean-before-cache-save.sh' in step.get('run','')"

py_assert "'Clean before cache save' step run is a single script call (no inline logic)" \
    "import yaml, sys; f=open(sys.argv[1]); d=yaml.safe_load(f); f.close(); steps=d['runs']['steps']; step=next(s for s in steps if 'Clean before cache save' in s.get('name','')); run=step.get('run','').strip(); assert len(run.splitlines()) == 1"

py_assert "'Clean before cache save' step appears before 'Save cache' step" \
    "import yaml, sys; f=open(sys.argv[1]); d=yaml.safe_load(f); f.close(); steps=d['runs']['steps']; names=[s.get('name','') for s in steps]; clean_idx=next(i for i,n in enumerate(names) if 'Clean before cache save' in n); save_idx=next(i for i,n in enumerate(names) if 'Save cache' in n); assert clean_idx < save_idx"

py_assert "'Clean before cache save' step appears after 'Build stage' step" \
    "import yaml, sys; f=open(sys.argv[1]); d=yaml.safe_load(f); f.close(); steps=d['runs']['steps']; names=[s.get('name','') for s in steps]; build_idx=next(i for i,n in enumerate(names) if 'Build stage' in n); clean_idx=next(i for i,n in enumerate(names) if 'Clean before cache save' in n); assert build_idx < clean_idx"

py_assert "'Clean before cache save' step passes cache-paths via env (no template injection)" \
    "import yaml, sys; f=open(sys.argv[1]); d=yaml.safe_load(f); f.close(); steps=d['runs']['steps']; step=next(s for s in steps if 'Clean before cache save' in s.get('name','')); assert 'CACHE_PATHS' in step.get('env',{})"

py_assert "'Clean before cache save' step run does not embed template expressions" \
    "import yaml, sys; f=open(sys.argv[1]); d=yaml.safe_load(f); f.close(); steps=d['runs']['steps']; step=next(s for s in steps if 'Clean before cache save' in s.get('name','')); assert 'inputs.' not in step.get('run','')"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

print_test_results
