"""Pytest tests for .github/actions/build-stage/action.yml structure.

Validates:
  - YAML syntax and style via yamllint
  - Top-level structure (name, runs.using, runs.steps)
  - Required inputs (stage-name, cache-paths, cache-key, build-script)
  - Optional inputs (pre-cache-hit, save-in-merge-group)
  - Outputs (cache-hit, build-time-seconds)
"""

import pathlib
import subprocess

import pytest
import yaml

REPO_ROOT = pathlib.Path(__file__).parent.parent.resolve()
ACTION_YML = REPO_ROOT / ".github" / "actions" / "build-stage" / "action.yml"
YAMLLINT_CFG = REPO_ROOT / ".yamllint"


@pytest.fixture(scope="module")
def action_data():
    """Load and return the parsed action.yml as a dict."""
    with ACTION_YML.open() as fh:
        return yaml.safe_load(fh)


# ---------------------------------------------------------------------------
# Group 1: YAML syntax and style (yamllint)
# ---------------------------------------------------------------------------


def test_yamllint_clean():
    """action.yml must pass yamllint with the project configuration."""
    result = subprocess.run(
        ["yamllint", "-c", str(YAMLLINT_CFG), str(ACTION_YML)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, (
        f"yamllint reported issues:\n{result.stdout}{result.stderr}"
    )


# ---------------------------------------------------------------------------
# Group 2: Top-level structure
# ---------------------------------------------------------------------------


def test_name_non_empty(action_data):
    """action.yml must have a non-empty 'name' field."""
    assert action_data.get("name", "").strip(), (
        "action 'name' is missing or empty"
    )


def test_runs_using_composite(action_data):
    """runs.using must be 'composite'."""
    assert action_data["runs"]["using"] == "composite"


def test_runs_steps_non_empty_list(action_data):
    """runs.steps must be a non-empty list."""
    steps = action_data["runs"]["steps"]
    assert isinstance(steps, list) and len(steps) > 0


# ---------------------------------------------------------------------------
# Group 3: Required inputs
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "input_name",
    ["stage-name", "cache-paths", "cache-key", "build-script"],
)
def test_required_input_exists(action_data, input_name):
    """Each required input must be declared in the inputs section."""
    assert input_name in action_data["inputs"], (
        f"required input '{input_name}' not found in inputs"
    )


# ---------------------------------------------------------------------------
# Group 4: Optional inputs
# ---------------------------------------------------------------------------


def test_optional_input_pre_cache_hit_exists(action_data):
    """Optional input 'pre-cache-hit' must be declared."""
    assert "pre-cache-hit" in action_data["inputs"]


def test_optional_input_pre_cache_hit_not_required(action_data):
    """Optional input 'pre-cache-hit' must have required: false."""
    assert action_data["inputs"]["pre-cache-hit"].get("required") is False


def test_optional_input_save_in_merge_group_exists(action_data):
    """Optional input 'save-in-merge-group' must be declared."""
    assert "save-in-merge-group" in action_data["inputs"]


def test_optional_input_save_in_merge_group_not_required(action_data):
    """Optional input 'save-in-merge-group' must have required: false."""
    assert (
        action_data["inputs"]["save-in-merge-group"].get("required") is False
    )


# ---------------------------------------------------------------------------
# Group 5: Outputs
# ---------------------------------------------------------------------------


def test_output_cache_hit_exists(action_data):
    """Output 'cache-hit' must be declared."""
    assert "cache-hit" in action_data["outputs"]


def test_output_build_time_seconds_exists(action_data):
    """Output 'build-time-seconds' must be declared."""
    assert "build-time-seconds" in action_data["outputs"]
