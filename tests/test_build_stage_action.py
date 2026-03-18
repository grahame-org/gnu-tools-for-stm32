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
    with open(ACTION_YML) as f:
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

    def test_build_time_seconds_output_exists(self, action_data):
        """Output 'build-time-seconds' must be defined."""
        assert "build-time-seconds" in action_data["outputs"]
