#!/usr/bin/env bash
# Unit tests for build-gcc-size-libstdcxx.sh argument validation and the
# MULTILIB_LIST default-override logic.
#
# build-gcc-size-libstdcxx.sh narrows the default MULTILIB_LIST from
# "--with-multilib-list=rmprofile,aprofile" (set by parse_toolchain_args) to
# "--with-multilib-list=rmprofile" (Cortex-M only) when no explicit
# --with-multilib-list=* flag is passed.  An explicit flag bypasses that
# narrowing.
#
# Run with: bash tests/test-build-gcc-size-libstdcxx.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/build-gcc-size-libstdcxx.sh"

# shellcheck source=tests/test-helpers.sh
. "$SCRIPT_DIR/test-helpers.sh"

# Flags that suppress all real build work so tests focus on argument parsing
# and the MULTILIB_LIST override logic near the top of the script.
SKIP_ALL=("--skip_steps=native,mingw,package_sources,md5_checksum,package_bins,manual")

# ---------------------------------------------------------------------------
# Test group 1: Accepted flag combinations → exit 0
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 1: Accepted flag combinations ==="

assert_zero_exit "SKIP_ALL alone: exits cleanly" \
    bash "$SCRIPT" "${SKIP_ALL[@]}"

assert_zero_exit "--build_type=native accepted" \
    bash "$SCRIPT" "${SKIP_ALL[@]}" --build_type=native

assert_zero_exit "--build_type=ppa accepted" \
    bash "$SCRIPT" "${SKIP_ALL[@]}" --build_type=ppa

assert_zero_exit "--with-multilib-list=rmprofile accepted" \
    bash "$SCRIPT" "${SKIP_ALL[@]}" --with-multilib-list=rmprofile

assert_zero_exit "--with-multilib-list=rmprofile,aprofile accepted" \
    bash "$SCRIPT" "${SKIP_ALL[@]}" --with-multilib-list=rmprofile,aprofile

assert_zero_exit "--with-multilib-list=aprofile accepted" \
    bash "$SCRIPT" "${SKIP_ALL[@]}" --with-multilib-list=aprofile

# ---------------------------------------------------------------------------
# Test group 2: Rejected arguments → non-zero exit
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 2: Rejected arguments ==="

assert_nonzero_exit "unknown flag rejected" \
    bash "$SCRIPT" "${SKIP_ALL[@]}" --unknown-flag

assert_nonzero_exit "--build_type=badtype rejected" \
    bash "$SCRIPT" "${SKIP_ALL[@]}" --build_type=badtype

# ---------------------------------------------------------------------------
# Helper: run the script and return the last --with-multilib-list=VALUE seen
# in the set -x trace written to stderr.
# Captures stdout+stderr and checks the exit status before processing output,
# so a non-zero exit from the script is surfaced as a failure rather than
# being masked by the pipeline.
# The extraction pipeline uses || true so that a grep-no-match does not abort
# the test script under set -e; an empty result causes assert_eq to report
# a proper FAIL with the full trace shown for diagnosis.
# ---------------------------------------------------------------------------
_last_multilib() {
    local output exit_status=0 extracted
    output=$(bash "$SCRIPT" "${SKIP_ALL[@]}" "$@" 2>&1) || exit_status=$?
    if [ "$exit_status" -ne 0 ]; then
        echo "ERROR: $SCRIPT exited with status $exit_status" >&2
        return "$exit_status"
    fi
    extracted=$(printf '%s\n' "$output" | \
        grep 'MULTILIB_LIST=--with-multilib-list=' | \
        tail -1 | \
        grep -o -- '--with-multilib-list=[^[:space:]]*' || true)
    if [ -z "$extracted" ]; then
        echo "ERROR: no MULTILIB_LIST=--with-multilib-list= line found in trace; full output:" >&2
        printf '%s\n' "$output" >&2
    fi
    printf '%s\n' "$extracted"
}

# ---------------------------------------------------------------------------
# Test group 3: MULTILIB_LIST default-override logic
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 3: MULTILIB_LIST default-override logic ==="

multilib_val=$(_last_multilib)
assert_eq "no --with-multilib-list flag: MULTILIB_LIST narrowed to rmprofile only" \
    "--with-multilib-list=rmprofile" "$multilib_val"

multilib_val=$(_last_multilib --with-multilib-list=rmprofile,aprofile)
assert_eq "--with-multilib-list=rmprofile,aprofile explicit: override not applied" \
    "--with-multilib-list=rmprofile,aprofile" "$multilib_val"

multilib_val=$(_last_multilib --with-multilib-list=aprofile)
assert_eq "--with-multilib-list=aprofile explicit: override not applied" \
    "--with-multilib-list=aprofile" "$multilib_val"

multilib_val=$(_last_multilib --with-multilib-list=rmprofile)
assert_eq "--with-multilib-list=rmprofile explicit: last value is rmprofile" \
    "--with-multilib-list=rmprofile" "$multilib_val"

# ---------------------------------------------------------------------------
print_test_results
