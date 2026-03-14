#!/usr/bin/env bash
# Determine whether the build stage cache missed and write the result to
# $GITHUB_OUTPUT as "cache-miss=true" or "cache-miss=false".
#
# Environment variables (set by the composite action step):
#   PRE_CACHE_HIT     – cache-hit value from a preceding inline restore step
#                       in the caller (empty string when not provided)
#   RESTORE_CACHE_HIT – cache-hit output from the action's own restore step
#                       (empty string when the restore step was skipped)

set -euo pipefail

if [[ "${PRE_CACHE_HIT}" == "true" ]] || \
   [[ -z "${PRE_CACHE_HIT}" && "${RESTORE_CACHE_HIT}" == "true" ]]; then
    echo "cache-miss=false" >> "${GITHUB_OUTPUT}"
else
    echo "cache-miss=true" >> "${GITHUB_OUTPUT}"
fi
