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
#
# These are uncompressed on-disk sizes as measured by `du -sb`.  They differ
# significantly from the compressed GitHub Actions cache archive sizes reported
# by `actions/cache/save` (see docs/cache-sizes.md).  The script also measures
# and reports a compressed-size estimate (tar + zstd --fast) alongside the
# uncompressed sizes so that both figures appear in the job summary.
#
# The script runs in build-final after the strip stages, so install-native/ is
# the fully-stripped final toolchain (~1.1 GB); build-native/target-libs/ is
# the unstripped nano sysroot left by the gcc-size-libstdcxx stage (~2.6 GB).
#
#   INSTALL_NATIVE_WARN_GB  warn threshold for install-native/          (default: 1.5)
#   INSTALL_NATIVE_MAX_GB   fail threshold for install-native/          (default: 2)
#   TARGET_LIBS_WARN_GB     warn threshold for build-native/target-libs (default: 3)
#   TARGET_LIBS_MAX_GB      fail threshold for build-native/target-libs (default: 4)
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
INSTALL_NATIVE_WARN_GB=${INSTALL_NATIVE_WARN_GB:-1.5}
INSTALL_NATIVE_MAX_GB=${INSTALL_NATIVE_MAX_GB:-2}
TARGET_LIBS_WARN_GB=${TARGET_LIBS_WARN_GB:-3}
TARGET_LIBS_MAX_GB=${TARGET_LIBS_MAX_GB:-4}

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

# Print the compressed byte count of a directory (tar piped through zstd --fast),
# or 0 if it does not exist.  This approximates the size that GitHub Actions
# cache/save would store and that counts against the 10 GB repository budget.
# Note: actual cache/save compression may differ slightly depending on zstd
# version and settings used by the actions/cache action.
measure_compressed_bytes() {
    local dir="$1"
    if [ -d "${dir}" ]; then
        tar -cf - "${dir}" 2>/dev/null | zstd -q --fast | wc -c | tr -d '[:space:]'
    else
        echo "0"
    fi
}

# Exit 0 if the given byte count exceeds the threshold expressed in gigabytes
# (1 GB = 1,000,000,000 bytes), exit 1 otherwise.
exceeds_gb() {
    local bytes="$1"
    local threshold_gb="$2"
    awk -v b="${bytes}" -v t="${threshold_gb}" \
        'BEGIN { exit (b > t * 1000000000) ? 0 : 1 }'
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
install_compressed_bytes=$(measure_compressed_bytes "install-native")
target_bytes=$(measure_bytes "build-native/target-libs")
target_human=$(measure_human "build-native/target-libs")
target_compressed_bytes=$(measure_compressed_bytes "build-native/target-libs")

install_status=$(status_for "${install_bytes}" "${INSTALL_NATIVE_WARN_GB}" "${INSTALL_NATIVE_MAX_GB}")
target_status=$(status_for "${target_bytes}" "${TARGET_LIBS_WARN_GB}" "${TARGET_LIBS_MAX_GB}")

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
print_report() {
    echo "## Cache Budget Validation"
    echo ""
    echo "| Directory | Size | Uncompressed bytes | Compressed bytes | Warn (GB) | Fail (GB) | Status |"
    echo "|-----------|------|-------------------|-----------------|-----------|-----------|--------|"
    echo "| \`install-native/\` | ${install_human} | ${install_bytes} | ${install_compressed_bytes} | ${INSTALL_NATIVE_WARN_GB} | ${INSTALL_NATIVE_MAX_GB} | ${install_status} |"
    echo "| \`build-native/target-libs/\` | ${target_human} | ${target_bytes} | ${target_compressed_bytes} | ${TARGET_LIBS_WARN_GB} | ${TARGET_LIBS_MAX_GB} | ${target_status} |"
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
