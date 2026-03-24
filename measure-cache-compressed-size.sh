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

if [ -d "${dir}" ]; then
    tar -cf - "${dir}" 2>/dev/null | zstd -q --fast | wc -c | tr -d '[:space:]'
else
    echo "0"
fi
