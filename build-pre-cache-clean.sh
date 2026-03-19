#! /usr/bin/env bash
# Copyright (c) 2011-2020, ARM Limited
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of Arm nor the names of its contributors may be used
#       to endorse or promote products derived from this software without
#       specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

# build-pre-cache-clean.sh: Strips ELF binaries and removes non-essential files
# from a given directory tree, suitable for running immediately before a CI
# stage cache is saved to reduce cache size by 30–50%.
#
# Usage:
#   ./build-pre-cache-clean.sh <root-directory>
#
# Arguments:
#   <root-directory>  Path to the directory to clean (e.g. install-native or
#                     build-native/target-libs).  If the directory does not
#                     exist the script exits 0 with a warning.

set -e
set -x
set -u
set -o pipefail

PS4='+$(date -u +%Y-%m-%d:%H:%M:%S) (${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

umask 022

exec < /dev/null

# ---------------------------------------------------------------------------
# Argument handling
# ---------------------------------------------------------------------------

if [ $# -ne 1 ]; then
    echo "Usage: $(basename "$0") <root-directory>" >&2
    exit 1
fi

root_dir="$1"

if [ ! -d "$root_dir" ]; then
    echo "Warning: directory '$root_dir' does not exist – nothing to clean." >&2
    exit 0
fi

# ---------------------------------------------------------------------------
# Before size
# ---------------------------------------------------------------------------

echo "=== Size before cleaning ==="
du -sh "$root_dir"

# ---------------------------------------------------------------------------
# Helper: strip a single ELF binary (--strip-unneeded)
# ---------------------------------------------------------------------------

strip_elf_file() {
    local file="$1"
    # Check first 4 bytes for ELF magic: 0x7f 'E' 'L' 'F'
    local magic
    magic=$(dd if="$file" bs=1 count=4 2>/dev/null | od -An -tx1 | tr -d ' \n') || return 0
    if [ "$magic" = "7f454c46" ]; then
        strip --strip-unneeded "$file" 2>/dev/null || true
    fi
}

# ---------------------------------------------------------------------------
# Strip ELF binaries in bin/, libexec/, arm-none-eabi/bin/
# ---------------------------------------------------------------------------

# bin/ and arm-none-eabi/bin/ are flat; strip only direct children.
for bin_dir in \
    "$root_dir/bin" \
    "$root_dir/arm-none-eabi/bin"
do
    if [ -d "$bin_dir" ]; then
        while IFS= read -r -d '' file; do
            if [ -f "$file" ] && [ ! -L "$file" ]; then
                strip_elf_file "$file"
            fi
        done < <(find "$bin_dir" -maxdepth 1 -type f -print0)
    fi
done

# libexec/ is recursive: GCC installs binaries under
# libexec/gcc/<target>/<version>/ (cc1, cc1plus, lto1, …).
if [ -d "$root_dir/libexec" ]; then
    while IFS= read -r -d '' file; do
        if [ -f "$file" ] && [ ! -L "$file" ]; then
            strip_elf_file "$file"
        fi
    done < <(find "$root_dir/libexec" -type f -print0)
fi

# ---------------------------------------------------------------------------
# Strip .a static libraries anywhere under root_dir (--strip-debug)
# ---------------------------------------------------------------------------

while IFS= read -r -d '' lib; do
    strip --strip-debug "$lib" 2>/dev/null || true
done < <(find "$root_dir" -name '*.a' -type f -print0)

# ---------------------------------------------------------------------------
# Remove non-essential directories
# ---------------------------------------------------------------------------

for rm_dir in \
    "$root_dir/share/man" \
    "$root_dir/share/info" \
    "$root_dir/share/locale" \
    "$root_dir/share/doc" \
    "$root_dir/arm-none-eabi/share"
do
    if [ -d "$rm_dir" ]; then
        rm -rf "$rm_dir"
    fi
done

# ---------------------------------------------------------------------------
# Remove .la libtool metadata files
# ---------------------------------------------------------------------------

find "$root_dir" -name '*.la' -delete

# ---------------------------------------------------------------------------
# After size
# ---------------------------------------------------------------------------

echo "=== Size after cleaning ==="
du -sh "$root_dir"
