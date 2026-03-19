"""Tests for .github/actions/build-stage/action.yml structure.

Validates semantic structure (required inputs, outputs, composite type)
using Python's yaml.safe_load.

YAML syntax and style validation (group 1) is handled by yamllint in
tests/test-build-stage-action.sh.

Run with: pytest tests/test_build_stage_action.py
Requires:  pytest, pyyaml – install via: python3 -m pip install -r tests/requirements.txt
"""

import pathlib

import pytest
import yaml

REPO_ROOT = pathlib.Path(__file__).parent.parent
ACTION_YML = REPO_ROOT / ".github" / "actions" / "build-stage" / "action.yml"


@pytest.fixture(scope="module")
def action_data():
    """Load and parse the build-stage action.yml file."""
    with open(ACTION_YML, encoding="utf-8") as f:
        return yaml.safe_load(f)


class TestTopLevelStructure:
    """Test top-level structure of the action."""

    def test_action_has_nonempty_name(self, action_data):
        """Action must have a non-empty name field."""
        assert action_data.get("name", "").strip()

    def test_runs_using_is_composite(self, action_data):
        """runs.using must be 'composite'."""
        assert action_data["runs"]["using"] == "composite"

    def test_runs_steps_is_nonempty_list(self, action_data):
        """runs.steps must be a non-empty list."""
        steps = action_data["runs"]["steps"]
        assert isinstance(steps, list) and len(steps) > 0


class TestRequiredInputs:
    """Test required inputs of the action."""

    @pytest.mark.parametrize("input_name", [
        "stage-name",
        "cache-paths",
        "cache-key",
        "build-script",
    ])
    def test_required_input_exists(self, action_data, input_name):
        """Each required input must be defined in the action."""
        assert input_name in action_data["inputs"]


class TestOptionalInputs:
    """Test optional inputs of the action."""

    def test_pre_cache_hit_exists(self, action_data):
        """Optional input 'pre-cache-hit' must exist."""
        assert "pre-cache-hit" in action_data["inputs"]

    def test_pre_cache_hit_not_required(self, action_data):
        """Optional input 'pre-cache-hit' must have required: false."""
        assert action_data["inputs"]["pre-cache-hit"].get("required") is False

    def test_save_in_merge_group_exists(self, action_data):
        """Optional input 'save-in-merge-group' must exist."""
        assert "save-in-merge-group" in action_data["inputs"]

    def test_save_in_merge_group_not_required(self, action_data):
        """Optional input 'save-in-merge-group' must have required: false."""
        assert action_data["inputs"]["save-in-merge-group"].get("required") is False


class TestOutputs:
    """Test outputs of the action."""

    def test_cache_hit_output_exists(self, action_data):
        """Output 'cache-hit' must be defined."""
        assert "cache-hit" in action_data["outputs"]

def test_output_build_time_seconds_exists(action):
    assert "build-time-seconds" in action["outputs"]


# ---------------------------------------------------------------------------
# Group 6: Clean before cache save step
# ---------------------------------------------------------------------------


@pytest.fixture(scope="module")
def steps(action):
    """Return the list of steps from the composite action."""
    return action["runs"]["steps"]


@pytest.fixture(scope="module")
def clean_step(steps):
    """Return the 'Clean before cache save' step."""
    return next(
        s for s in steps if "Clean before cache save" in s.get("name", "")
    )


@pytest.fixture(scope="module")
def save_step(steps):
    """Return the 'Save cache' step."""
    return next(s for s in steps if "Save cache" in s.get("name", ""))


def test_clean_before_cache_save_step_exists(steps):
    assert any("Clean before cache save" in s.get("name", "") for s in steps)


def test_clean_before_cache_save_condition_matches_save_cache(
    clean_step, save_step
):
    assert clean_step.get("if") == save_step.get("if"), (
        f"clean: {clean_step.get('if')!r} != save: {save_step.get('if')!r}"
    )


def test_clean_before_cache_save_uses_bash_shell(clean_step):
    assert clean_step.get("shell") == "bash"


def test_clean_before_cache_save_delegates_to_script(clean_step):
    assert "clean-before-cache-save.sh" in clean_step.get("run", "")


def test_clean_before_cache_save_run_is_single_line(clean_step):
    run = clean_step.get("run", "").strip()
    assert len(run.splitlines()) == 1


def test_clean_before_cache_save_before_save_cache(steps):
    names = [s.get("name", "") for s in steps]
    clean_idx = next(
        i for i, n in enumerate(names) if "Clean before cache save" in n
    )
    save_idx = next(i for i, n in enumerate(names) if "Save cache" in n)
    assert clean_idx < save_idx


def test_clean_before_cache_save_after_build_stage(steps):
    names = [s.get("name", "") for s in steps]
    build_idx = next(i for i, n in enumerate(names) if "Build stage" in n)
    clean_idx = next(
        i for i, n in enumerate(names) if "Clean before cache save" in n
    )
    assert build_idx < clean_idx


def test_clean_before_cache_save_passes_cache_paths_via_env(clean_step):
    assert "CACHE_PATHS" in clean_step.get("env", {})


def test_clean_before_cache_save_run_has_no_template_expressions(clean_step):
    assert "inputs." not in clean_step.get("run", "")
    def test_build_time_seconds_output_exists(self, action_data):
        """Output 'build-time-seconds' must be defined."""
        assert "build-time-seconds" in action_data["outputs"]
