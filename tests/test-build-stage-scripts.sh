#!/usr/bin/env bash
# Unit tests for .github/actions/build-stage/ helper scripts:
#   compute-cache-miss.sh, set-cache-hit-output.sh, clean-before-cache-save.sh
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
# Summary
# ---------------------------------------------------------------------------

print_test_results
