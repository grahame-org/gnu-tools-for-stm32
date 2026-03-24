#!/usr/bin/env bash
# measure-cache-compressed-size.sh: Print the compressed byte count of a
# directory (tar piped through zstd --fast) to stdout, or "0" if the
# directory does not exist.
#
# This approximates the size that GitHub Actions cache/save would store and
# that counts against the 10 GB repository cache budget.
#
# Note: actual cache/save compression may differ slightly depending on the
# zstd version and settings used by the actions/cache action.
#
# Usage:
#   ./measure-cache-compressed-size.sh <directory>

set -euo pipefail

dir="${1:?Usage: measure-cache-compressed-size.sh <directory>}"

if [ ! -d "${dir}" ]; then
    echo "0"
    exit 0
fi

# If tar or zstd are unavailable, treat the size as 0 but do not fail the build.
if ! command -v tar >/dev/null 2>&1 || ! command -v zstd >/dev/null 2>&1; then
    echo "Warning: tar and/or zstd not available; skipping compressed size measurement for '${dir}'" >&2
    echo "0"
    exit 0
fi

# Run the compression pipeline in a way that does not cause the script to exit
# on failure (due to set -euo pipefail). Any error measuring size falls back to 0.
if ! size=$(tar -cf - "${dir}" 2>/dev/null | zstd -q --fast | wc -c | tr -d '[:space:]'); then
    echo "Warning: failed to measure compressed size for '${dir}', treating as 0" >&2
    echo "0"
    exit 0
fi

echo "${size}"
