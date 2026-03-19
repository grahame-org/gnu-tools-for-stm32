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
