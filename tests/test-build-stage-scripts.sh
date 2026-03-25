#!/usr/bin/env bash
# Unit tests for .github/actions/build-stage/ helper scripts:
#   compute-cache-miss.sh, set-cache-hit-output.sh, clean-before-cache-save.sh,
#   run-build-stage.sh
#
# Run with: bash tests/test-build-stage-scripts.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ACTION_DIR="${REPO_ROOT}/.github/actions/build-stage"

# shellcheck source=test-helpers.sh
. "$SCRIPT_DIR/test-helpers.sh"

_TMPDIR=$(mktemp -d)
trap 'rm -rf "$_TMPDIR"' EXIT

_COMPUTE_SCRIPT="${ACTION_DIR}/compute-cache-miss.sh"
_SET_OUTPUT_SCRIPT="${ACTION_DIR}/set-cache-hit-output.sh"
_CLEAN_SCRIPT="${ACTION_DIR}/clean-before-cache-save.sh"
_RUN_SCRIPT="${ACTION_DIR}/run-build-stage.sh"

# Run compute-cache-miss.sh with the given env values and return the written value.
run_compute_cache_miss() {
    local pre_cache_hit="$1" restore_cache_hit="$2" out
    out=$(mktemp "$_TMPDIR/github-output-XXXXXX")
    PRE_CACHE_HIT="$pre_cache_hit" \
    RESTORE_CACHE_HIT="$restore_cache_hit" \
    GITHUB_OUTPUT="$out" \
    bash "$_COMPUTE_SCRIPT"
    grep '^cache-miss=' "$out" | cut -d= -f2
}

# Run set-cache-hit-output.sh with the given CACHE_MISS value and return the written value.
run_set_cache_hit_output() {
    local cache_miss="$1" out
    out=$(mktemp "$_TMPDIR/github-output-XXXXXX")
    CACHE_MISS="$cache_miss" \
    GITHUB_OUTPUT="$out" \
    bash "$_SET_OUTPUT_SCRIPT"
    grep '^cache-hit=' "$out" | cut -d= -f2
}

# ---------------------------------------------------------------------------
# Create mock workspace: build-pre-cache-clean.sh records its argument.
# ---------------------------------------------------------------------------

_MOCK_WS="${_TMPDIR}/mock-workspace"
_CALL_LOG="${_TMPDIR}/clean-calls.log"
mkdir -p "$_MOCK_WS"
cat > "$_MOCK_WS/build-pre-cache-clean.sh" <<'MOCKEOF'
#!/usr/bin/env bash
echo "$1" >> "${CALL_LOG}"
MOCKEOF
chmod +x "$_MOCK_WS/build-pre-cache-clean.sh"

# Run clean-before-cache-save.sh with CACHE_PATHS; resets the call log first.
run_clean_before_cache_save() {
    local cache_paths="$1"
    rm -f "$_CALL_LOG"
    GITHUB_WORKSPACE="$_MOCK_WS" \
    CACHE_PATHS="$cache_paths" \
    CALL_LOG="$_CALL_LOG" \
    bash "$_CLEAN_SCRIPT"
}

# ---------------------------------------------------------------------------
# Group 1: compute-cache-miss.sh — PRE_CACHE_HIT=true
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 1: compute-cache-miss.sh — PRE_CACHE_HIT=true ==="

assert_eq "PRE_CACHE_HIT=true → cache-miss=false" "false" \
    "$(run_compute_cache_miss "true" "")"
assert_eq "PRE_CACHE_HIT=true ignores RESTORE_CACHE_HIT=false → cache-miss=false" "false" \
    "$(run_compute_cache_miss "true" "false")"

# ---------------------------------------------------------------------------
# Group 2: compute-cache-miss.sh — PRE_CACHE_HIT empty + RESTORE_CACHE_HIT
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 2: compute-cache-miss.sh — PRE_CACHE_HIT empty + RESTORE_CACHE_HIT ==="

assert_eq "PRE_CACHE_HIT='' RESTORE_CACHE_HIT=true → cache-miss=false" "false" \
    "$(run_compute_cache_miss "" "true")"
assert_eq "PRE_CACHE_HIT='' RESTORE_CACHE_HIT='' → cache-miss=true" "true" \
    "$(run_compute_cache_miss "" "")"

# ---------------------------------------------------------------------------
# Group 3: compute-cache-miss.sh — non-empty non-true PRE_CACHE_HIT
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 3: compute-cache-miss.sh — non-empty non-true PRE_CACHE_HIT ==="

assert_eq "PRE_CACHE_HIT=false → cache-miss=true" "true" \
    "$(run_compute_cache_miss "false" "")"
assert_eq "PRE_CACHE_HIT='' RESTORE_CACHE_HIT=false → cache-miss=true" "true" \
    "$(run_compute_cache_miss "" "false")"

# ---------------------------------------------------------------------------
# Group 4: set-cache-hit-output.sh
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 4: set-cache-hit-output.sh ==="

assert_eq "CACHE_MISS=false → cache-hit=true" "true" \
    "$(run_set_cache_hit_output "false")"
assert_eq "CACHE_MISS='' → cache-hit=true" "true" \
    "$(run_set_cache_hit_output "")"
assert_eq "CACHE_MISS=true → cache-hit='' (empty)" "" \
    "$(run_set_cache_hit_output "true")"

# ---------------------------------------------------------------------------
# Group 5: clean-before-cache-save.sh
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 5: clean-before-cache-save.sh ==="

run_clean_before_cache_save "/cache/path/one"
assert_eq "single path: invoked once" "1" \
    "$(wc -l < "$_CALL_LOG")"
assert_eq "single path: correct argument" "/cache/path/one" \
    "$(cat "$_CALL_LOG")"

run_clean_before_cache_save "$(printf '/cache/path/one\n/cache/path/two')"
assert_eq "two paths: invoked twice" "2" \
    "$(wc -l < "$_CALL_LOG")"

run_clean_before_cache_save ""
_clean_empty_count=0
if [ -f "$_CALL_LOG" ]; then
    _clean_empty_count=$(wc -l < "$_CALL_LOG")
fi
assert_eq "empty CACHE_PATHS: not invoked" "0" "$_clean_empty_count"

# ---------------------------------------------------------------------------
# Group 6: run-build-stage.sh
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 6: run-build-stage.sh ==="

# Create a mock build script that records argv[1..] to a log file.
_MOCK_BUILD="${_TMPDIR}/mock-build.sh"
_ARG_LOG="${_TMPDIR}/build-args.log"
cat > "$_MOCK_BUILD" <<'BUILDMOCK'
#!/usr/bin/env bash
for arg in "$@"; do printf '%s\n' "$arg"; done > "${ARG_LOG}"
BUILDMOCK
chmod +x "$_MOCK_BUILD"

# Run run-build-stage.sh with the given BUILD_STAGE_ARGS and return the
# build-time-seconds value written to GITHUB_OUTPUT.
run_build_stage() {
    local stage_args="$1" gh_out
    gh_out=$(mktemp "$_TMPDIR/github-output-XXXXXX")
    rm -f "$_ARG_LOG"
    BUILD_STAGE_SCRIPT="$_MOCK_BUILD" \
    BUILD_STAGE_ARGS="$stage_args" \
    ARG_LOG="$_ARG_LOG" \
    GITHUB_OUTPUT="$gh_out" \
    bash "$_RUN_SCRIPT"
    grep '^build-time-seconds=' "$gh_out" | cut -d= -f2
}

# build-time-seconds is written to GITHUB_OUTPUT.
_bts=$(run_build_stage "")
assert_ne "empty args: build-time-seconds written to GITHUB_OUTPUT" "" "$_bts"

# build-time-seconds is an integer.
case "$_bts" in
    ''|*[!0-9]*) assert_eq "empty args: build-time-seconds is numeric" "numeric" "non-numeric" ;;
    *)           assert_eq "empty args: build-time-seconds is numeric" "numeric" "numeric" ;;
esac

# No arguments passed when BUILD_STAGE_ARGS is empty.
run_build_stage "" > /dev/null
assert_eq "empty args: mock script receives no arguments" "0" \
    "$(wc -l < "$_ARG_LOG")"

# Single argument is passed through unchanged.
run_build_stage "--skip_steps=mingw" > /dev/null
assert_eq "single arg: passed to build script" "--skip_steps=mingw" \
    "$(cat "$_ARG_LOG")"

# Two space-separated arguments are split into two distinct arguments.
run_build_stage "--skip_steps=mingw --jobs=4" > /dev/null
assert_eq "two args: correct count" "2" \
    "$(wc -l < "$_ARG_LOG")"
assert_eq "two args: first arg correct" "--skip_steps=mingw" \
    "$(sed -n '1p' "$_ARG_LOG")"
assert_eq "two args: second arg correct" "--jobs=4" \
    "$(sed -n '2p' "$_ARG_LOG")"

# JOBS is exported to the build script.
_JOBS_BUILD="${_TMPDIR}/mock-jobs.sh"
_JOBS_LOG="${_TMPDIR}/jobs.log"
cat > "$_JOBS_BUILD" <<'JOBSMOCK'
#!/usr/bin/env bash
echo "${JOBS:-unset}" > "${JOBS_LOG}"
JOBSMOCK
chmod +x "$_JOBS_BUILD"
_gh_out=$(mktemp "$_TMPDIR/github-output-XXXXXX")
BUILD_STAGE_SCRIPT="$_JOBS_BUILD" \
BUILD_STAGE_ARGS="" \
JOBS_LOG="$_JOBS_LOG" \
GITHUB_OUTPUT="$_gh_out" \
bash "$_RUN_SCRIPT"
_jobs_val=$(cat "$_JOBS_LOG")
assert_ne "JOBS exported to build script and non-empty" "" "$_jobs_val"
case "$_jobs_val" in
    ''|*[!0-9]*) assert_eq "JOBS exported to build script is numeric" "numeric" "non-numeric" ;;
    *)           assert_eq "JOBS exported to build script is numeric" "numeric" "numeric" ;;
esac

# Failure propagation: non-zero exit from build script propagates.
_FAIL_BUILD="${_TMPDIR}/mock-fail.sh"
cat > "$_FAIL_BUILD" <<'FAILMOCK'
#!/usr/bin/env bash
exit 1
FAILMOCK
chmod +x "$_FAIL_BUILD"
_gh_out2=$(mktemp "$_TMPDIR/github-output-XXXXXX")
_rc=0
BUILD_STAGE_SCRIPT="$_FAIL_BUILD" \
BUILD_STAGE_ARGS="" \
GITHUB_OUTPUT="$_gh_out2" \
bash "$_RUN_SCRIPT" 2>/dev/null || _rc=$?
assert_ne "failing build script: exit code propagated (non-zero)" "0" "$_rc"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

print_test_results
