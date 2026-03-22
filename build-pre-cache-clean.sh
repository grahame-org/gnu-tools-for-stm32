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
# Note presence of essential binary before any modifications
# ---------------------------------------------------------------------------

_gcc_binary="$root_dir/bin/arm-none-eabi-gcc"
_gcc_present_before=false
if [ -e "$_gcc_binary" ]; then
    _gcc_present_before=true
fi

# ---------------------------------------------------------------------------
# Strip ELF binaries in bin/, libexec/, arm-none-eabi/bin/
#
# Downstream build stages invoke these executables directly (compiler, linker,
# assembler, etc.) and do not inspect their symbol tables.  Stripping with
# --strip-unneeded removes debug info and unreferenced symbols without
# affecting runtime behaviour.
# ---------------------------------------------------------------------------

# bin/ and arm-none-eabi/bin/ are flat; strip only direct children.
for bin_dir in \
    "$root_dir/bin" \
    "$root_dir/arm-none-eabi/bin"
do
    if [ -d "$bin_dir" ]; then
        while IFS= read -r -d '' file; do
            strip_elf_file "$file"
        done < <(find "$bin_dir" -maxdepth 1 -type f -print0)
    fi
done

# libexec/ is recursive (e.g. GDB may install helpers there).  With
# --libexecdir=$INSTALLDIR_NATIVE/lib the GCC internal binaries (cc1,
# cc1plus, lto1) live under lib/gcc/<target>/<version>/ rather than
# libexec/; they are stripped by build-toolchain.sh strip_host_objects
# during the final assembly step.
if [ -d "$root_dir/libexec" ]; then
    while IFS= read -r -d '' file; do
        strip_elf_file "$file"
    done < <(find "$root_dir/libexec" -type f -print0)
fi

# ---------------------------------------------------------------------------
# Strip .a static libraries anywhere under root_dir
#
# Downstream build stages link against these libraries.  --strip-debug
# removes DWARF debug sections but preserves all code and symbol tables, so
# linking works correctly.
#
# .debug_frame is explicitly kept: it is DWARF debug-time unwind metadata
# that some post-mortem tooling may consume.  Runtime unwinding is driven by
# .eh_frame/.ARM.exidx; keeping .debug_frame here simply ensures we do not
# pre-remove it before the final assembly has a chance to decide what to keep.
# ---------------------------------------------------------------------------

while IFS= read -r -d '' lib; do
    strip --strip-debug --keep-section=.debug_frame "$lib" 2>/dev/null || true
done < <(find "$root_dir" -name '*.a' -type f -print0)

# ---------------------------------------------------------------------------
# Remove non-essential directories
#
# Safety for downstream build stages and license compliance
# ─────────────────────────────────────────────────────────
# None of the directories removed below are read by any subsequent build
# stage in the pipeline.  All downstream stages use only the executables in
# bin/, the sysroot headers/libraries in arm-none-eabi/include/ and
# arm-none-eabi/lib/, and the GCC runtime objects in lib/gcc/.
#
# share/gcc-*/  – GCC Python pretty-printer scripts (libstdc++ debugger
#   support).  This build configures --with-python-dir=share/gcc-arm-none-eabi
#   so the actual installed directory is share/gcc-arm-none-eabi/python/.
#   These are installed by gcc-final and gcc-size-libstdcxx but are not
#   consumed during compilation or linking by any downstream stage.  They are part of the end-user
#   toolchain experience (GDB pretty-printing), but a release build from
#   source regenerates them; removing them from CI intermediate caches does
#   not affect correctness or license compliance since CI caches are not
#   distributed.
#
# arm-none-eabi/share/  – GDB Python data files (auto-load scripts,
#   pretty-printers for target libraries).  Installed by the gdb stage.
#   Not required during compilation or linking.  Same reasoning as above.
#
# License note: Removing GPL/LGPL-licensed documentation and script files
# from CI build caches does not constitute redistribution of an incomplete
# toolchain.  The source code is preserved in src/; a full build from source
# produces all required files.  These caches exist solely to accelerate CI
# pipelines and are never distributed to end users.
# ---------------------------------------------------------------------------

remove_non_essential_dirs() {
    local root="$1"
    local rm_dir

    for rm_dir in \
        "$root/share/man" \
        "$root/share/info" \
        "$root/share/locale" \
        "$root/share/doc" \
        "$root/arm-none-eabi/share"
    do
        if [ -d "$rm_dir" ]; then
            rm -rf "$rm_dir"
        fi
    done

    # share/gcc-*/ may expand to multiple versioned directories; use glob.
    # nullglob ensures the loop body is skipped when no directories match.
    (
        shopt -s nullglob
        for rm_dir in "$root"/share/gcc-*/; do
            rm -rf "$rm_dir"
        done
    )
}

remove_non_essential_dirs "$root_dir"

# ---------------------------------------------------------------------------
# Safety check: essential binaries must survive cleanup
# ---------------------------------------------------------------------------

if [ "$_gcc_present_before" = true ]; then
    if [ ! -e "$_gcc_binary" ]; then
        echo "Safety check FAILED: $_gcc_binary missing after cleanup!" >&2
        exit 1
    fi
    echo "Safety check passed: $_gcc_binary still present after cleanup."
fi

# ---------------------------------------------------------------------------
# Remove .la libtool metadata files
# ---------------------------------------------------------------------------

find "$root_dir" -name '*.la' -delete

# ---------------------------------------------------------------------------
# After size
# ---------------------------------------------------------------------------

echo "=== Size after cleaning ==="
du -sh "$root_dir"
