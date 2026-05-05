#!/usr/bin/env bash
# Unit tests for .github/actions/compute-toolchain-src-hash/compute-toolchain-src-hash.sh.
#
# Run with: bash tests/test-compute-toolchain-src-hash.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="${REPO_ROOT}/.github/actions/compute-toolchain-src-hash/compute-toolchain-src-hash.sh"

# shellcheck source=tests/test-helpers.sh
. "$SCRIPT_DIR/test-helpers.sh"

_TMPDIR=$(mktemp -d)
trap 'rm -rf "$_TMPDIR"' EXIT

# ---------------------------------------------------------------------------
# Helper: run the script with GITHUB_OUTPUT pointing at a temp file.
# Returns the written hash value (the part after "toolchain-src=").
# ---------------------------------------------------------------------------

run_script_with_output() {
    local out
    out=$(mktemp "$_TMPDIR/github-output-XXXXXX")
    GITHUB_OUTPUT="$out" bash "$SCRIPT"
    grep '^toolchain-src=' "$out" | cut -d= -f2
}

# ---------------------------------------------------------------------------
# Test group 1: Script runs successfully and produces correct-format output
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 1: Successful execution ==="

assert_zero_exit "script exits 0 when GITHUB_OUTPUT is set" \
    bash -c "GITHUB_OUTPUT=\$(mktemp \"$_TMPDIR/go-XXXXXX\") bash \"$SCRIPT\""

_hash=$(run_script_with_output)

assert_eq "output contains exactly one toolchain-src line" "yes" \
    "$( [[ "$_hash" =~ ^[0-9a-f]{64}$ ]] && echo yes || echo no )"

# ---------------------------------------------------------------------------
# Test group 2: Output is deterministic across two runs
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 2: Deterministic output ==="

_hash2=$(run_script_with_output)

assert_eq "hash is same across two runs" "$_hash" "$_hash2"

# ---------------------------------------------------------------------------
# Test group 3: GITHUB_OUTPUT unset → script fails (set -u catches unbound var)
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 3: Missing GITHUB_OUTPUT ==="

_status=0
_out=$(env -i HOME="$HOME" PATH="$PATH" GIT_DIR="$REPO_ROOT/.git" GIT_WORK_TREE="$REPO_ROOT" \
    bash "$SCRIPT" 2>&1) || _status=$?
assert_ne "missing GITHUB_OUTPUT: exits non-zero" "0" "$_status"

# ---------------------------------------------------------------------------
# Test group 4: Script covers all expected source directories
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 4: Expected source directories present in script ==="

for _dir in src/binutils src/gcc src/gdb src/newlib; do
    assert_contains "script references ${_dir}" "$(cat "$SCRIPT")" "$_dir"
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

print_test_results
