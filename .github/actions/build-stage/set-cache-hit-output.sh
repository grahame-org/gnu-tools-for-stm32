#!/usr/bin/env bash
# Set the cache-hit composite action output based on the computed cache-miss value.
#
# Environment variables (set by the composite action step):
#   CACHE_MISS – cache-miss output from the compute-cache-miss step
#                ('true' when the stage needs to be built, 'false' otherwise)

set -euo pipefail

if [[ "${CACHE_MISS}" != "true" ]]; then
    echo "cache-hit=true" >> "${GITHUB_OUTPUT}"
else
    echo "cache-hit=" >> "${GITHUB_OUTPUT}"
fi
