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
_EMPTY_TMPDIR=$(mktemp -d)
_cleanup() { rm -rf "${_TMPDIR}" "${_EMPTY_TMPDIR}"; }
trap '_cleanup' EXIT

mkdir -p "${_TMPDIR}/install-native"
mkdir -p "${_TMPDIR}/build-native/target-libs"

# Create files of known sizes:
#   install-native/dummy      : 1 MiB
#   build-native/target-libs/dummy : 512 KiB
dd if=/dev/zero of="${_TMPDIR}/install-native/dummy" bs=1024 count=1024 2>/dev/null
dd if=/dev/zero of="${_TMPDIR}/build-native/target-libs/dummy" bs=1024 count=512 2>/dev/null

# run_check: run build-cache-budget-check.sh from a given directory with the
# supplied environment variable overrides.  Arguments are VAR=value pairs
# passed to env(1).  Uses a portable subshell+cd rather than GNU env -C so the
# tests work on macOS/BSD as well as Linux.
#
# GITHUB_STEP_SUMMARY is always cleared so that the script does not try to
# append to the CI runner's summary file (which may not be writable or may not
# exist when running tests in a different subprocess context).
run_check() {
    local dir="$1"
    shift
    (cd "${dir}" && exec env GITHUB_STEP_SUMMARY="" "$@" bash "${REPO_ROOT}/build-cache-budget-check.sh")
}

# ---------------------------------------------------------------------------
# Group 1: Both directories within all thresholds — should exit 0
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 1: Directories within budget ==="

# Thresholds are well above the 1 MiB / 512 KiB test data.
assert_zero_exit "exits 0 when both directories are below fail threshold" \
    run_check "${_TMPDIR}" \
        INSTALL_NATIVE_MAX_GB=0.01 \
        INSTALL_NATIVE_WARN_GB=0.005 \
        TARGET_LIBS_MAX_GB=0.01 \
        TARGET_LIBS_WARN_GB=0.005

# ---------------------------------------------------------------------------
# Group 2: install-native exceeds fail threshold — should exit non-zero
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 2: install-native exceeds fail threshold ==="

# 0.0001 GB ≈ 104 KiB  < 1 MiB, so the 1 MiB file will exceed the limit.
assert_nonzero_exit "exits non-zero when install-native exceeds max threshold" \
    run_check "${_TMPDIR}" \
        INSTALL_NATIVE_MAX_GB=0.0001 \
        INSTALL_NATIVE_WARN_GB=0.00005 \
        TARGET_LIBS_MAX_GB=0.01 \
        TARGET_LIBS_WARN_GB=0.005

# ---------------------------------------------------------------------------
# Group 3: build-native/target-libs exceeds fail threshold — should exit non-zero
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 3: build-native/target-libs exceeds fail threshold ==="

# 0.0001 GB ≈ 104 KiB  < 512 KiB, so the 512 KiB file will exceed the limit.
assert_nonzero_exit "exits non-zero when target-libs exceeds max threshold" \
    run_check "${_TMPDIR}" \
        INSTALL_NATIVE_MAX_GB=0.01 \
        INSTALL_NATIVE_WARN_GB=0.005 \
        TARGET_LIBS_MAX_GB=0.0001 \
        TARGET_LIBS_WARN_GB=0.00005

# ---------------------------------------------------------------------------
# Group 4: install-native exceeds warn threshold but not fail — should exit 0
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 4: install-native in warn zone ==="

# warn < 1 MiB (0.0005 GB ≈ 512 KiB), fail > 1 MiB (0.002 GB ≈ 2 MiB).
assert_zero_exit "exits 0 when install-native is in warn zone (above warn, below fail)" \
    run_check "${_TMPDIR}" \
        INSTALL_NATIVE_MAX_GB=0.002 \
        INSTALL_NATIVE_WARN_GB=0.0005 \
        TARGET_LIBS_MAX_GB=0.01 \
        TARGET_LIBS_WARN_GB=0.005

# ---------------------------------------------------------------------------
# Group 5: Missing directories are treated as zero bytes — should exit 0
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 5: Missing cache directories ==="

assert_zero_exit "exits 0 when cache directories do not exist" \
    run_check "${_EMPTY_TMPDIR}" \
        INSTALL_NATIVE_MAX_GB=0.0001 \
        INSTALL_NATIVE_WARN_GB=0.00005 \
        TARGET_LIBS_MAX_GB=0.0001 \
        TARGET_LIBS_WARN_GB=0.00005

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
assert_contains "GITHUB_STEP_SUMMARY contains table heading" \
    "${summary_content}" "Cache Budget Validation"
assert_contains "GITHUB_STEP_SUMMARY mentions install-native" \
    "${summary_content}" "install-native"

# ---------------------------------------------------------------------------
print_test_results
