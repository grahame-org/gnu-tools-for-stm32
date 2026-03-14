#!/usr/bin/env bash
# Run a toolchain build stage.
#
# Environment variables (set by the composite action step):
#   BUILD_STAGE_SCRIPT – path to the build script to execute
#   BUILD_STAGE_ARGS   – space-separated arguments to pass to the build script

set -euo pipefail

_start=$(date +%s)

JOBS=$(nproc)
export JOBS

# Read BUILD_STAGE_ARGS into an array so each whitespace-separated token
# becomes a distinct argument rather than a single quoted string.
read -ra build_args <<< "${BUILD_STAGE_ARGS}"
"${BUILD_STAGE_SCRIPT}" "${build_args[@]}"
echo "build-time-seconds=$(( $(date +%s) - _start ))" >> "${GITHUB_OUTPUT}"
