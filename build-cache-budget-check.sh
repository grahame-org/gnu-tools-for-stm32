#!/usr/bin/env bash
# build-cache-budget-check.sh: Validates that CI cache directories stay within
# configured size budgets.  Called from the build-final job in
# build-toolchain.yml.
#
# Checks two directories relative to the current working directory:
#   install-native/           – the final toolchain installation
#   build-native/target-libs/ – the newlib-nano/gcc-size intermediate sysroot
#
# Thresholds (configurable via environment variables):
#   INSTALL_NATIVE_WARN_GB  warn threshold for install-native/          (default: 3)
#   INSTALL_NATIVE_MAX_GB   fail threshold for install-native/          (default: 4)
#   TARGET_LIBS_WARN_GB     warn threshold for build-native/target-libs (default: 1)
#   TARGET_LIBS_MAX_GB      fail threshold for build-native/target-libs (default: 1.5)
#
# Outputs a Markdown table to $GITHUB_STEP_SUMMARY (when set) and to stdout.
# Exits non-zero when a fail threshold is exceeded.
#
# Usage:
#   ./build-cache-budget-check.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Thresholds
# ---------------------------------------------------------------------------
INSTALL_NATIVE_WARN_GB=${INSTALL_NATIVE_WARN_GB:-3}
INSTALL_NATIVE_MAX_GB=${INSTALL_NATIVE_MAX_GB:-4}
TARGET_LIBS_WARN_GB=${TARGET_LIBS_WARN_GB:-1}
TARGET_LIBS_MAX_GB=${TARGET_LIBS_MAX_GB:-1.5}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Print the byte count of a directory, or 0 if it does not exist.
measure_bytes() {
    local dir="$1"
    if [ -d "${dir}" ]; then
        du -sb "${dir}" | cut -f1
    else
        echo "0"
    fi
}

# Print a human-readable size of a directory, or "(not found)" if it does not exist.
measure_human() {
    local dir="$1"
    if [ -d "${dir}" ]; then
        du -sh "${dir}" | cut -f1
    else
        echo "(not found)"
    fi
}

# Exit 0 if the given byte count exceeds the threshold expressed in gigabytes,
# exit 1 otherwise.
exceeds_gb() {
    local bytes="$1"
    local threshold_gb="$2"
    awk -v b="${bytes}" -v t="${threshold_gb}" \
        'BEGIN { exit (b > t * 1073741824) ? 0 : 1 }'
}

# Print a status string (OK, WARNING, OVER BUDGET, or not found) for a
# directory given its measured byte count and warn/fail thresholds in GB.
status_for() {
    local bytes="$1"
    local warn_gb="$2"
    local max_gb="$3"
    if [ "${bytes}" -eq 0 ]; then
        echo "not found"
    elif exceeds_gb "${bytes}" "${max_gb}"; then
        echo "OVER BUDGET"
    elif exceeds_gb "${bytes}" "${warn_gb}"; then
        echo "WARNING"
    else
        echo "OK"
    fi
}

# ---------------------------------------------------------------------------
# Measure
# ---------------------------------------------------------------------------
install_bytes=$(measure_bytes "install-native")
install_human=$(measure_human "install-native")
target_bytes=$(measure_bytes "build-native/target-libs")
target_human=$(measure_human "build-native/target-libs")

install_status=$(status_for "${install_bytes}" "${INSTALL_NATIVE_WARN_GB}" "${INSTALL_NATIVE_MAX_GB}")
target_status=$(status_for "${target_bytes}" "${TARGET_LIBS_WARN_GB}" "${TARGET_LIBS_MAX_GB}")

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
print_report() {
    echo "## Cache Budget Validation"
    echo ""
    echo "| Directory | Size | Bytes | Warn (GB) | Fail (GB) | Status |"
    echo "|-----------|------|-------|-----------|-----------|--------|"
    echo "| \`install-native/\` | ${install_human} | ${install_bytes} | ${INSTALL_NATIVE_WARN_GB} | ${INSTALL_NATIVE_MAX_GB} | ${install_status} |"
    echo "| \`build-native/target-libs/\` | ${target_human} | ${target_bytes} | ${TARGET_LIBS_WARN_GB} | ${TARGET_LIBS_MAX_GB} | ${target_status} |"
}

print_report
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    print_report >> "${GITHUB_STEP_SUMMARY}"
fi

# ---------------------------------------------------------------------------
# Validate
# ---------------------------------------------------------------------------
exit_code=0

if exceeds_gb "${install_bytes}" "${INSTALL_NATIVE_MAX_GB}"; then
    echo "ERROR: install-native/ (${install_human}, ${install_bytes} bytes) exceeds the ${INSTALL_NATIVE_MAX_GB} GB budget." >&2
    exit_code=1
fi

if exceeds_gb "${target_bytes}" "${TARGET_LIBS_MAX_GB}"; then
    echo "ERROR: build-native/target-libs/ (${target_human}, ${target_bytes} bytes) exceeds the ${TARGET_LIBS_MAX_GB} GB budget." >&2
    exit_code=1
fi

exit "${exit_code}"
