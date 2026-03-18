#!/usr/bin/env bash
# Unit tests for .github/actions/build-stage/action.yml structure.
#
# Validates YAML syntax and style with yamllint, and semantic structure
# (required inputs, outputs, composite type) with Python's yaml.safe_load.
#
# Run with: bash tests/test-build-stage-action.sh
# Requires:  yamllint – install via: python3 -m pip install -r tests/requirements.txt

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

# Run a Python one-liner against ACTION_YML; pass on exit 0, fail on non-zero.
# Stderr is captured and printed on failure to help diagnose assertion errors
# (e.g. AssertionError details or import failures).
py_assert() {
    local desc="$1" code="$2" py_stderr
    if py_stderr=$(python3 -c "$code" "${ACTION_YML}" 2>&1); then
        _PASS=$((_PASS + 1))
        echo "  PASS: $desc"
    else
        _FAIL=$((_FAIL + 1))
        echo "  FAIL: $desc"
        if [ -n "$py_stderr" ]; then
            echo "        $py_stderr"
        fi
    fi
}

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
# Test group 2: Top-level structure
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 2: Top-level structure ==="

py_assert "action has a non-empty name" \
    "import yaml, sys; f=open(sys.argv[1]); d=yaml.safe_load(f); f.close(); assert d.get('name','').strip()"

py_assert "runs.using is composite" \
    "import yaml, sys; f=open(sys.argv[1]); d=yaml.safe_load(f); f.close(); assert d['runs']['using']=='composite'"

py_assert "runs.steps is a non-empty list" \
    "import yaml, sys; f=open(sys.argv[1]); d=yaml.safe_load(f); f.close(); assert isinstance(d['runs']['steps'],list) and len(d['runs']['steps'])>0"

# ---------------------------------------------------------------------------
# Test group 3: Required inputs
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 3: Required inputs ==="

for input_name in 'stage-name' 'cache-paths' 'cache-key' 'build-script'; do
    py_assert "required input '${input_name}' exists" \
        "import yaml, sys; f=open(sys.argv[1]); d=yaml.safe_load(f); f.close(); assert '${input_name}' in d['inputs']"
done

# ---------------------------------------------------------------------------
# Test group 4: Optional inputs
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 4: Optional inputs ==="

py_assert "optional input 'pre-cache-hit' exists" \
    "import yaml, sys; f=open(sys.argv[1]); d=yaml.safe_load(f); f.close(); assert 'pre-cache-hit' in d['inputs']"

py_assert "pre-cache-hit has required: false" \
    "import yaml, sys; f=open(sys.argv[1]); d=yaml.safe_load(f); f.close(); assert d['inputs']['pre-cache-hit'].get('required') is False"

py_assert "optional input 'save-in-merge-group' exists" \
    "import yaml, sys; f=open(sys.argv[1]); d=yaml.safe_load(f); f.close(); assert 'save-in-merge-group' in d['inputs']"

py_assert "save-in-merge-group has required: false" \
    "import yaml, sys; f=open(sys.argv[1]); d=yaml.safe_load(f); f.close(); assert d['inputs']['save-in-merge-group'].get('required') is False"

# ---------------------------------------------------------------------------
# Test group 5: Outputs
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 5: Outputs ==="

py_assert "output 'cache-hit' exists" \
    "import yaml, sys; f=open(sys.argv[1]); d=yaml.safe_load(f); f.close(); assert 'cache-hit' in d['outputs']"

py_assert "output 'build-time-seconds' exists" \
    "import yaml, sys; f=open(sys.argv[1]); d=yaml.safe_load(f); f.close(); assert 'build-time-seconds' in d['outputs']"

# ---------------------------------------------------------------------------
# Test group 6: Clean before cache save step
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 6: Clean before cache save step ==="

py_assert "'Clean before cache save' step exists" \
    "import yaml, sys; f=open(sys.argv[1]); d=yaml.safe_load(f); f.close(); steps=d['runs']['steps']; assert any('Clean before cache save' in (s.get('name','')) for s in steps)"

py_assert "'Clean before cache save' step has cache-miss condition" \
    "import yaml, sys; f=open(sys.argv[1]); d=yaml.safe_load(f); f.close(); steps=d['runs']['steps']; step=next(s for s in steps if 'Clean before cache save' in s.get('name','')); assert \"steps.check.outputs.cache-miss == 'true'\" in step.get('if','')"

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
