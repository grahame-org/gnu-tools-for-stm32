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

# build-newlib.sh: Builds the newlib component (stage III-2) of the
# GNU Tools for STM32 toolchain.  This script is extracted from
# build-toolchain.sh so that changes to other parts of the toolchain build
# do not invalidate the newlib stage cache.
#
# Usage:
#   ./build-newlib.sh [--build_type=...] [--skip_steps=...]
#
# The script accepts the same --build_type and --skip_steps flags as
# build-toolchain.sh.  The --skip_stages flag is accepted but ignored (this
# script always builds the newlib stage).
#
# The gcc-first stage (III-1) output must already be present in install-native/
# before calling this script.

set -e
set -x
set -u
set -o pipefail

PS4='+$(date -u +%Y-%m-%d:%H:%M:%S) (${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

umask 022

exec < /dev/null

script_path=$(cd "$(dirname "$0")" && pwd -P)
cd "$script_path"
. "$script_path/build-common.sh"

. "$script_path/build-toolchain-args.sh"
parse_toolchain_args "$@"

if [ "x$is_ppa_release" != "xyes" ]; then
  NEWLIB_CONFIG_OPTS=" --build=$BUILD --host=$HOST_NATIVE "
fi

if [ "x$skip_native_build" != "xyes" ] ; then
    mkdir -p "$BUILDDIR_NATIVE"
    mkdir -p "$INSTALLDIR_NATIVE"
    mkdir -p "$PACKAGEDIR"
fi

cd "$SRCDIR"

if [ "x$skip_native_build" != "xyes" ] ; then
    echo Task [III-2] /"$HOST_NATIVE"/newlib/ | tee -a "$BUILDDIR_NATIVE/.stage"
    saveenv
    prepend_path PATH "$INSTALLDIR_NATIVE/bin"
    saveenvvar CFLAGS_FOR_TARGET '-g -Os -ffunction-sections -fdata-sections -fno-unroll-loops -DPREFER_SIZE_OVER_SPEED -D__OPTIMIZE_SIZE__ -DSMALL_MEMORY'
    rm -rf "$BUILDDIR_NATIVE/newlib" && mkdir -p "$BUILDDIR_NATIVE/newlib"
    pushd "$BUILDDIR_NATIVE/newlib"

    # shellcheck disable=SC2086  # NEWLIB_CONFIG_OPTS is a space-separated list of configure flags requiring word-splitting
    "$SRCDIR/$NEWLIB/configure"  \
        $NEWLIB_CONFIG_OPTS \
        --target="$TARGET" \
        --prefix="$INSTALLDIR_NATIVE" \
        --infodir="$INSTALLDIR_NATIVE_DOC/info" \
        --mandir="$INSTALLDIR_NATIVE_DOC/man" \
        --htmldir="$INSTALLDIR_NATIVE_DOC/html" \
        --pdfdir="$INSTALLDIR_NATIVE_DOC/pdf" \
        --enable-newlib-io-long-long \
        --enable-newlib-io-c99-formats \
        --enable-newlib-reent-check-verify \
        --enable-newlib-register-fini \
        --enable-newlib-retargetable-locking \
        --disable-newlib-supplied-syscalls \
        --disable-nls

    make -j"$JOBS"

    make install

    if [ "x$skip_manual" != "xyes" ]; then
        make pdf
        mkdir -p "$INSTALLDIR_NATIVE_DOC/pdf"
        cp "$BUILDDIR_NATIVE/newlib/arm-none-eabi/newlib/libc/libc.pdf" "$INSTALLDIR_NATIVE_DOC/pdf/libc.pdf"
        cp "$BUILDDIR_NATIVE/newlib/arm-none-eabi/newlib/libm/libm.pdf" "$INSTALLDIR_NATIVE_DOC/pdf/libm.pdf"

        make html
        mkdir -p "$INSTALLDIR_NATIVE_DOC/html"
        copy_dir "$BUILDDIR_NATIVE/newlib/arm-none-eabi/newlib/libc/libc.html" "$INSTALLDIR_NATIVE_DOC/html/libc"
        copy_dir "$BUILDDIR_NATIVE/newlib/arm-none-eabi/newlib/libm/libm.html" "$INSTALLDIR_NATIVE_DOC/html/libm"
    fi

    popd
    restoreenv
fi
