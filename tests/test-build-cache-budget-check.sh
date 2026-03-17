#!/usr/bin/env bash
# Unit tests for build-cache-budget-check.sh.
#
# Run with: bash tests/test-build-cache-budget-check.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=test-helpers.sh
. "$SCRIPT_DIR/test-helpers.sh"

# ---------------------------------------------------------------------------
# Shared temporary workspace with mock cache directories
# ---------------------------------------------------------------------------

_TMPDIR=$(mktemp -d)
trap 'rm -rf "$_TMPDIR"' EXIT

mkdir -p "${_TMPDIR}/install-native"
mkdir -p "${_TMPDIR}/build-native/target-libs"

# Create files of known sizes:
#   install-native/dummy      : 1 MiB
#   build-native/target-libs/dummy : 512 KiB
dd if=/dev/zero of="${_TMPDIR}/install-native/dummy" bs=1024 count=1024 2>/dev/null
dd if=/dev/zero of="${_TMPDIR}/build-native/target-libs/dummy" bs=1024 count=512 2>/dev/null

# run_check: run build-cache-budget-check.sh from _TMPDIR with the supplied
# environment variable overrides.  Extra arguments are passed as VAR=value
# pairs to env(1).  Stderr is captured and discarded so assert helpers only
# see the exit code.
run_check() {
    (
        cd "${_TMPDIR}"
        exec env "$@" bash "${REPO_ROOT}/build-cache-budget-check.sh"
    ) 2>/dev/null
}

# ---------------------------------------------------------------------------
# Group 1: Both directories within all thresholds — should exit 0
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 1: Directories within budget ==="

# Thresholds are well above the 1 MiB / 512 KiB test data.
assert_zero_exit "exits 0 when both directories are below fail threshold" \
    env -C "${_TMPDIR}" \
        INSTALL_NATIVE_MAX_GB=0.01 \
        INSTALL_NATIVE_WARN_GB=0.005 \
        TARGET_LIBS_MAX_GB=0.01 \
        TARGET_LIBS_WARN_GB=0.005 \
        bash "${REPO_ROOT}/build-cache-budget-check.sh"

# ---------------------------------------------------------------------------
# Group 2: install-native exceeds fail threshold — should exit non-zero
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 2: install-native exceeds fail threshold ==="

# 0.0001 GB ≈ 104 KiB  < 1 MiB, so the 1 MiB file will exceed the limit.
assert_nonzero_exit "exits non-zero when install-native exceeds max threshold" \
    env -C "${_TMPDIR}" \
        INSTALL_NATIVE_MAX_GB=0.0001 \
        INSTALL_NATIVE_WARN_GB=0.00005 \
        TARGET_LIBS_MAX_GB=0.01 \
        TARGET_LIBS_WARN_GB=0.005 \
        bash "${REPO_ROOT}/build-cache-budget-check.sh"

# ---------------------------------------------------------------------------
# Group 3: build-native/target-libs exceeds fail threshold — should exit non-zero
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 3: build-native/target-libs exceeds fail threshold ==="

# 0.0001 GB ≈ 104 KiB  < 512 KiB, so the 512 KiB file will exceed the limit.
assert_nonzero_exit "exits non-zero when target-libs exceeds max threshold" \
    env -C "${_TMPDIR}" \
        INSTALL_NATIVE_MAX_GB=0.01 \
        INSTALL_NATIVE_WARN_GB=0.005 \
        TARGET_LIBS_MAX_GB=0.0001 \
        TARGET_LIBS_WARN_GB=0.00005 \
        bash "${REPO_ROOT}/build-cache-budget-check.sh"

# ---------------------------------------------------------------------------
# Group 4: install-native exceeds warn threshold but not fail — should exit 0
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 4: install-native in warn zone ==="

# warn < 1 MiB (0.0005 GB ≈ 512 KiB), fail > 1 MiB (0.002 GB ≈ 2 MiB).
assert_zero_exit "exits 0 when install-native is in warn zone (above warn, below fail)" \
    env -C "${_TMPDIR}" \
        INSTALL_NATIVE_MAX_GB=0.002 \
        INSTALL_NATIVE_WARN_GB=0.0005 \
        TARGET_LIBS_MAX_GB=0.01 \
        TARGET_LIBS_WARN_GB=0.005 \
        bash "${REPO_ROOT}/build-cache-budget-check.sh"

# ---------------------------------------------------------------------------
# Group 5: Missing directories are treated as zero bytes — should exit 0
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 5: Missing cache directories ==="

_EMPTY_TMPDIR=$(mktemp -d)
trap 'rm -rf "$_EMPTY_TMPDIR"' EXIT

assert_zero_exit "exits 0 when cache directories do not exist" \
    env -C "${_EMPTY_TMPDIR}" \
        INSTALL_NATIVE_MAX_GB=0.0001 \
        INSTALL_NATIVE_WARN_GB=0.00005 \
        TARGET_LIBS_MAX_GB=0.0001 \
        TARGET_LIBS_WARN_GB=0.00005 \
        bash "${REPO_ROOT}/build-cache-budget-check.sh"

# ---------------------------------------------------------------------------
# Group 6: GITHUB_STEP_SUMMARY output
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 6: GITHUB_STEP_SUMMARY output ==="

_SUMMARY_FILE="${_TMPDIR}/step-summary.md"
rm -f "${_SUMMARY_FILE}"

(
    cd "${_TMPDIR}"
    INSTALL_NATIVE_MAX_GB=0.01 \
    INSTALL_NATIVE_WARN_GB=0.005 \
    TARGET_LIBS_MAX_GB=0.01 \
    TARGET_LIBS_WARN_GB=0.005 \
    GITHUB_STEP_SUMMARY="${_SUMMARY_FILE}" \
        bash "${REPO_ROOT}/build-cache-budget-check.sh" > /dev/null 2>&1
)

assert_zero_exit "GITHUB_STEP_SUMMARY file is created when variable is set" \
    test -f "${_SUMMARY_FILE}"

summary_content=$(cat "${_SUMMARY_FILE}")
assert_ne "GITHUB_STEP_SUMMARY is non-empty" "" "${summary_content}"

case "${summary_content}" in
    *"Cache Budget Validation"*)
        assert_eq "GITHUB_STEP_SUMMARY contains table heading" \
            "yes" "yes"
        ;;
    *)
        assert_eq "GITHUB_STEP_SUMMARY contains table heading" \
            "yes" "no"
        ;;
esac

case "${summary_content}" in
    *"install-native"*)
        assert_eq "GITHUB_STEP_SUMMARY mentions install-native" \
            "yes" "yes"
        ;;
    *)
        assert_eq "GITHUB_STEP_SUMMARY mentions install-native" \
            "yes" "no"
        ;;
esac

# ---------------------------------------------------------------------------
print_test_results
