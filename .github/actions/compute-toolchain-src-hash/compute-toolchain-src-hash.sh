#!/usr/bin/env bash
# Compute a combined SHA-256 hash of the toolchain source trees and write it
# to $GITHUB_OUTPUT as "toolchain-src=<hash>".
#
# The hash covers the git tree objects for all source directories that affect
# the final toolchain binary.  It is used to construct the toolchain cache key
# in build-toolchain.yml and docker-dry-run.yml, ensuring both workflows key on
# the same value without duplicating the computation.

set -euo pipefail

toolchain_src_hash=$(
  printf '%s\n' \
    src/binutils \
    src/gcc \
    src/gdb \
    src/newlib \
    src/libiconv \
    src/liblongpath-win32 \
    src/specs \
  | while read -r dir; do
      git rev-parse "HEAD:${dir}"
    done \
  | sha256sum \
  | cut -d' ' -f1
)
echo "toolchain-src=${toolchain_src_hash}" >> "${GITHUB_OUTPUT}"
