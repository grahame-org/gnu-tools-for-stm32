"""Pytest tests for .github/actions/build-stage/action.yml structure.

Validates the semantic structure of the composite action: required inputs,
optional inputs with correct metadata, outputs, and top-level fields.
"""

import pathlib

import pytest
import yaml

ACTION_YML = (
    pathlib.Path(__file__).parent.parent
    / ".github"
    / "actions"
    / "build-stage"
    / "action.yml"
)


@pytest.fixture(scope="module")
def action():
    """Load and parse action.yml once for all tests in this module."""
    with ACTION_YML.open(encoding="utf-8") as f:
        return yaml.safe_load(f)


# ---------------------------------------------------------------------------
# Group 2: Top-level structure
# ---------------------------------------------------------------------------


def test_action_has_non_empty_name(action):
    assert action.get("name", "").strip()


def test_runs_using_is_composite(action):
    assert action["runs"]["using"] == "composite"


def test_runs_steps_is_non_empty_list(action):
    assert isinstance(action["runs"]["steps"], list) and len(action["runs"]["steps"]) > 0


# ---------------------------------------------------------------------------
# Group 3: Required inputs
# ---------------------------------------------------------------------------


def test_required_input_stage_name_exists(action):
    assert "stage-name" in action["inputs"]


def test_required_input_cache_paths_exists(action):
    assert "cache-paths" in action["inputs"]


def test_required_input_cache_key_exists(action):
    assert "cache-key" in action["inputs"]


def test_required_input_build_script_exists(action):
    assert "build-script" in action["inputs"]


# ---------------------------------------------------------------------------
# Group 4: Optional inputs
# ---------------------------------------------------------------------------


def test_optional_input_pre_cache_hit_exists(action):
    assert "pre-cache-hit" in action["inputs"]


def test_pre_cache_hit_has_required_false(action):
    assert action["inputs"]["pre-cache-hit"].get("required") is False


def test_optional_input_save_in_merge_group_exists(action):
    assert "save-in-merge-group" in action["inputs"]


def test_save_in_merge_group_has_required_false(action):
    assert action["inputs"]["save-in-merge-group"].get("required") is False


# ---------------------------------------------------------------------------
# Group 5: Outputs
# ---------------------------------------------------------------------------


def test_output_cache_hit_exists(action):
    assert "cache-hit" in action["outputs"]


def test_output_build_time_seconds_exists(action):
    assert "build-time-seconds" in action["outputs"]
