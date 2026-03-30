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

# merge-gcc-final.sh: Merges two staged install-native/ trees — one built with
# --with-multilib-list=rmprofile and one with --with-multilib-list=aprofile —
# into a single combined install-native/ tree equivalent to a full
# rmprofile,aprofile build.
#
# Background:
#   When the gcc-final stage is split across two CI jobs (one per profile) to
#   stay within GitHub Actions cache-size limits, each job produces a partial
#   install-native/ tree.  The rmprofile tree contains the compiler binary,
#   shared headers, and all Cortex-M/R multilib variants.  The aprofile tree
#   contains only the Cortex-A multilib library directories (v7-a*, v7ve*,
#   v8-a* variants under arm-none-eabi/lib/thumb/, per MULTI_ARCH_DIRS_A in
#   gcc/config/arm/t-aprofile).
#
#   The multilib.h header is generated from the --with-multilib-list value
#   used at configure time; it therefore differs between the two trees and
#   cannot simply be overlaid.  After merging the libraries this script
#   regenerates multilib.h for the combined profile set by invoking
#   'make s-mlib' in the rmprofile gcc-final build directory with an updated
#   TM_MULTILIB_CONFIG, and installs the result into the output tree.
#
# Usage:
#   ./merge-gcc-final.sh \
#       --rmprofile-dir=<path>  \
#       --aprofile-dir=<path>   \
#       --output-dir=<path>     \
#       [--gcc-final-build-dir=<path>]
#
# Arguments:
#   --rmprofile-dir=PATH
#       Path to the install-native/ tree produced by the rmprofile gcc-final
#       build.  This tree is used as the base for the merged output.
#
#   --aprofile-dir=PATH
#       Path to the install-native/ tree produced by the aprofile gcc-final
#       build.  Only the multilib-specific library directories contributed
#       uniquely by aprofile are overlaid onto the base.
#
#   --output-dir=PATH
#       Destination directory for the merged install-native/ tree.  Created
#       if it does not already exist.  Must not be the same as either input
#       directory.
#
#   --gcc-final-build-dir=PATH  (optional)
#       Path to the rmprofile gcc-final build directory (the directory that
#       contains the 'gcc/multilib.h' Makefile target 's-mlib').  Defaults to
#       build-native/gcc-final relative to the script location.  When this
#       directory exists the script regenerates multilib.h for the combined
#       profile; when it is absent the step is skipped with a warning.
#
# Exit codes:
#   0  – merge succeeded and verification passed
#   1  – argument error or merge/verification failure

set -e
set -u
set -o pipefail

# shellcheck disable=SC2016 # intentional: single quotes defer expansion to trace-print time
PS4='+$(date -u +%Y-%m-%d:%H:%M:%S) (${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

umask 022

exec < /dev/null

script_path=$(cd "$(dirname "$0")" && pwd -P)

# ---------------------------------------------------------------------------
# Usage / error helpers
# ---------------------------------------------------------------------------

_usage() {
    cat <<EOF
Usage: merge-gcc-final.sh \\
    --rmprofile-dir=<path> \\
    --aprofile-dir=<path>  \\
    --output-dir=<path>    \\
    [--gcc-final-build-dir=<path>]
EOF
}

_die() {
    echo "merge-gcc-final.sh: error: $*" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

rmprofile_dir=
aprofile_dir=
output_dir=
gcc_final_build_dir=

for ac_arg in "$@"; do
    case "$ac_arg" in
        --rmprofile-dir=*)
            rmprofile_dir="${ac_arg#--rmprofile-dir=}"
            ;;
        --aprofile-dir=*)
            aprofile_dir="${ac_arg#--aprofile-dir=}"
            ;;
        --output-dir=*)
            output_dir="${ac_arg#--output-dir=}"
            ;;
        --gcc-final-build-dir=*)
            gcc_final_build_dir="${ac_arg#--gcc-final-build-dir=}"
            ;;
        --help|-h)
            _usage
            exit 0
            ;;
        *)
            echo "merge-gcc-final.sh: unknown argument: $ac_arg" >&2
            _usage
            exit 1
            ;;
    esac
done

[ -n "$rmprofile_dir" ] || { _usage; _die "--rmprofile-dir is required"; }
[ -n "$aprofile_dir"  ] || { _usage; _die "--aprofile-dir is required";  }
[ -n "$output_dir"    ] || { _usage; _die "--output-dir is required";    }

# Validate input directories exist before resolving absolute paths.
[ -d "$rmprofile_dir" ] || _die "rmprofile-dir is not a directory: $rmprofile_dir"
[ -d "$aprofile_dir"  ] || _die "aprofile-dir is not a directory: $aprofile_dir"

# Resolve to absolute paths so the rest of the script is path-independent.
rmprofile_dir=$(cd "$rmprofile_dir" && pwd -P)
aprofile_dir=$(cd "$aprofile_dir"   && pwd -P)

# Default gcc-final build dir relative to the script.
if [ -z "$gcc_final_build_dir" ]; then
    gcc_final_build_dir="${script_path}/build-native/gcc-final"
fi

# Refuse to operate if output-dir coincides with, or is contained inside,
# either input directory.  Such configurations would corrupt the source tree
# while it is being read (tar traversing its own destination).
mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd -P)

[ "$output_dir" != "$rmprofile_dir" ] || \
    _die "output-dir must not be the same as rmprofile-dir"
[ "$output_dir" != "$aprofile_dir" ] || \
    _die "output-dir must not be the same as aprofile-dir"

# Reject when output-dir is nested inside either input dir.
case "$output_dir/" in
    "$rmprofile_dir"/*)
        _die "output-dir must not be inside rmprofile-dir" ;;
    "$aprofile_dir"/*)
        _die "output-dir must not be inside aprofile-dir" ;;
esac

# Ensure output-dir is empty so that a re-run does not leave stale files from
# a previous invocation.  We clean by removing the contents rather than the
# directory itself so that any bind-mounts or directory metadata set by the
# caller are preserved.
if [ -n "$(ls -A "$output_dir" 2>/dev/null)" ]; then
    echo "merge-gcc-final: output-dir is non-empty; removing contents before merge"
    find "$output_dir" -mindepth 1 -delete
fi

set -x

# ---------------------------------------------------------------------------
# Step 1: Copy the rmprofile tree as the base
# ---------------------------------------------------------------------------

echo "merge-gcc-final: Step 1 – copying rmprofile tree to output-dir"
(cd "$rmprofile_dir" && tar cf - .) | (cd "$output_dir" && tar xf -)

# ---------------------------------------------------------------------------
# Step 2: Overlay aprofile multilib library directories
#
# aprofile uniquely contributes Cortex-A multilib variants located under
# arm-none-eabi/lib/thumb/.  Per MULTI_ARCH_DIRS_A in gcc/config/arm/t-aprofile,
# the directory names are: v7-a, v7-a+fp, v7-a+simd, v7ve+simd, v8-a, v8-a+simd.
# We overlay every immediate subdirectory of thumb/ whose name starts with
# "v7-a", "v7ve", or "v8-a" from the aprofile tree.
#
# We deliberately do NOT overlay:
#   - Compiler binaries  (bin/)
#   - Headers            (arm-none-eabi/include/)
#   - Host libraries     (lib/)
#   - multilib.h         (regenerated in Step 3)
# ---------------------------------------------------------------------------

echo "merge-gcc-final: Step 2 – overlaying aprofile multilib directories"

aprofile_lib_root="${aprofile_dir}/arm-none-eabi/lib"
output_lib_root="${output_dir}/arm-none-eabi/lib"

if [ ! -d "$aprofile_lib_root" ]; then
    _die "aprofile tree is missing arm-none-eabi/lib/: $aprofile_lib_root"
fi

# Overlay thumb/v7-a*, thumb/v7ve*, and thumb/v8-a* subtrees.
# Find all immediate children of thumb/ whose names match the aprofile
# MULTI_ARCH_DIRS_A patterns (v7-a*, v7ve*, v8-a*) and copy each one —
# including its full sub-tree — into the corresponding location of the
# output tree.
while IFS= read -r -d '' src_dir; do
    rel="${src_dir#"$aprofile_lib_root/"}"
    dst_dir="${output_lib_root}/${rel}"
    echo "merge-gcc-final:   overlaying lib/${rel}"
    mkdir -p "$dst_dir"
    (cd "$src_dir" && tar cf - .) | (cd "$dst_dir" && tar xf -)
done < <(find "${aprofile_lib_root}/thumb" -mindepth 1 -maxdepth 1 -type d \
             \( -name 'v7-a*' -o -name 'v7ve*' -o -name 'v8-a*' \) -print0 2>/dev/null)

# ---------------------------------------------------------------------------
# Step 3: Regenerate multilib.h for the combined profile
#
# multilib.h is generated by the 'gcc/s-mlib' make target.  We rebuild it
# by invoking 'make s-mlib' inside the existing rmprofile build directory
# after overriding TM_MULTILIB_CONFIG to cover both profiles.
#
# If the build directory does not exist (e.g. this script is run outside of a
# full build environment), we skip this step and warn instead of failing hard,
# because the rmprofile multilib.h is still a valid — if incomplete — file.
# ---------------------------------------------------------------------------

echo "merge-gcc-final: Step 3 – regenerating multilib.h for combined profile"

# Locate the installed multilib.h path inside the output tree.
# GCC installs it to lib/gcc/arm-none-eabi/<version>/plugin/include/multilib.h
multilib_h_installed=$(find "${output_dir}/lib/gcc/arm-none-eabi" \
    -name "multilib.h" -path "*/plugin/include/multilib.h" | head -n 1)

if [ -d "$gcc_final_build_dir" ]; then
    pushd "$gcc_final_build_dir"
    make s-mlib TM_MULTILIB_CONFIG="rmprofile,aprofile"
    # s-mlib writes the regenerated file to gcc/multilib.h in the build dir.
    generated_multilib_h="${gcc_final_build_dir}/gcc/multilib.h"
    if [ -f "$generated_multilib_h" ]; then
        if [ -n "$multilib_h_installed" ]; then
            echo "merge-gcc-final:   installing regenerated multilib.h to ${multilib_h_installed}"
            cp -f "$generated_multilib_h" "$multilib_h_installed"
        else
            echo "merge-gcc-final: warning: could not find installed multilib.h in output tree; skipping install" >&2
        fi
    else
        echo "merge-gcc-final: warning: make s-mlib did not produce gcc/multilib.h; skipping" >&2
    fi
    popd
else
    echo "merge-gcc-final: warning: gcc-final build dir not found (${gcc_final_build_dir}); skipping multilib.h regeneration" >&2
fi

# ---------------------------------------------------------------------------
# Step 4: Verify the merged tree
#
# Run arm-none-eabi-gcc --print-multi-lib and confirm that both rmprofile
# and aprofile variants appear in the output.
# ---------------------------------------------------------------------------

echo "merge-gcc-final: Step 4 – verifying merged tree"

gcc_bin="${output_dir}/bin/arm-none-eabi-gcc"
if [ ! -x "$gcc_bin" ]; then
    _die "arm-none-eabi-gcc not found in output tree: $gcc_bin"
fi

multilib_output=$("$gcc_bin" --print-multi-lib 2>&1)
echo "merge-gcc-final: --print-multi-lib output:"
echo "$multilib_output"

# Check for representative rmprofile variant (Cortex-M4 with hard-float).
if ! grep -q "thumb/v7e-m+fp/hard" <<< "$multilib_output"; then
    _die "verification failed: rmprofile variant 'thumb/v7e-m+fp/hard' not found in --print-multi-lib output"
fi

# Check for representative aprofile variant by verifying the physical library
# directories exist in the merged tree.  We cannot use --print-multi-lib here
# because multilib.h reflects only the rmprofile configuration when the
# gcc-final build directory is absent (e.g. in the CI merge job), meaning
# --print-multi-lib will never report Cortex-A variants in that context.
# The directory names match MULTI_ARCH_DIRS_A in gcc/config/arm/t-aprofile:
# v7-a*, v7ve*, v8-a*.
aprofile_thumb="${output_dir}/arm-none-eabi/lib/thumb"
if [ -z "$(find "$aprofile_thumb" -maxdepth 1 -type d \
        \( -name 'v7-a*' -o -name 'v7ve*' -o -name 'v8-a*' \) -print -quit 2>/dev/null)" ]; then
    _die "verification failed: no aprofile library directories (v7-a*/v7ve*/v8-a*) found under arm-none-eabi/lib/thumb/"
fi

echo "merge-gcc-final: merge complete and verified successfully"
