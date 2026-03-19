#!/usr/bin/env bash
# Run build-pre-cache-clean.sh on each path listed in CACHE_PATHS before
# the stage cache is saved, reducing cached artefact size by 30–50%.
#
# Environment variables (set by the composite action step):
#   CACHE_PATHS – newline-separated list of directory paths to clean

set -euo pipefail

while IFS= read -r cache_path; do
    [[ -z "${cache_path}" ]] && continue
    "${GITHUB_WORKSPACE}/build-pre-cache-clean.sh" "${cache_path}"
done <<< "${CACHE_PATHS}"
