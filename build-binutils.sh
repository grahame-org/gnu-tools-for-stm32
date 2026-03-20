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

# build-binutils.sh: Builds the binutils component (stage III-0) of the
# GNU Tools for STM32 toolchain.  This script is extracted from
# build-toolchain.sh so that changes to other parts of the toolchain build
# do not invalidate the binutils stage cache.
#
# Usage:
#   ./build-binutils.sh [--build_type=...] [--skip_steps=...]
#
# The script accepts the same --build_type and --skip_steps flags as
# build-toolchain.sh.  The --skip_stages flag is accepted but ignored (only
# the binutils stage is handled here; skipping is still controlled by --skip_steps).

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

if [ "x$BUILD" == "xx86_64-apple-darwin10" ] || [ "x$is_ppa_release" == "xyes" ]; then
    BUILD_OPTIONS="$BUILD_OPTIONS -fbracket-depth=512"
fi

if [ "x$is_ppa_release" != "xyes" ]; then
  ENV_CFLAGS=" -I$BUILDDIR_NATIVE/host-libs/zlib/include $BUILD_OPTIONS "
  ENV_CPPFLAGS=" -I$BUILDDIR_NATIVE/host-libs/zlib/include "
  ENV_LDFLAGS=" -L$BUILDDIR_NATIVE/host-libs/zlib/lib
                -L$BUILDDIR_NATIVE/host-libs/usr/lib "

  BINUTILS_CONFIG_OPTS=" --build=$BUILD --host=$HOST_NATIVE "
fi

if [ "x$skip_native_build" != "xyes" ] ; then
    mkdir -p "$BUILDDIR_NATIVE"
    mkdir -p "$INSTALLDIR_NATIVE"
    mkdir -p "$PACKAGEDIR"
fi

cd "$SRCDIR"

if [ "x$skip_native_build" != "xyes" ] ; then
    echo "Task [III-0] /$HOST_NATIVE/binutils/" | tee -a "$BUILDDIR_NATIVE/.stage"
    rm -rf "$BUILDDIR_NATIVE/binutils" && mkdir -p "$BUILDDIR_NATIVE/binutils"
    pushd "$BUILDDIR_NATIVE/binutils"
    saveenv
    saveenvvar CFLAGS "$ENV_CFLAGS"
    saveenvvar CPPFLAGS "$ENV_CPPFLAGS"
    saveenvvar LDFLAGS "$ENV_LDFLAGS"
    # shellcheck disable=SC2086 # BINUTILS_CONFIG_OPTS is intentionally word-split (multiple --build/--host flags)
    "$SRCDIR/$BINUTILS/configure"  \
        ${BINUTILS_CONFIG_OPTS} \
        --target="$TARGET" \
        --prefix="$INSTALLDIR_NATIVE" \
        --infodir="$INSTALLDIR_NATIVE_DOC/info" \
        --mandir="$INSTALLDIR_NATIVE_DOC/man" \
        --htmldir="$INSTALLDIR_NATIVE_DOC/html" \
        --pdfdir="$INSTALLDIR_NATIVE_DOC/pdf" \
        --disable-nls \
        --disable-werror \
        --disable-sim \
        --disable-gdb \
        --enable-interwork \
        --enable-plugins \
        --with-sysroot="$INSTALLDIR_NATIVE/arm-none-eabi" \
        --with-zstd=no \
        "--with-pkgversion=$PKGVERSION"

    make -j"$JOBS"

    make install

    if [ "x$skip_manual" != "xyes" ]; then
        make install-html install-pdf
    fi

    copy_dir "$INSTALLDIR_NATIVE" "$BUILDDIR_NATIVE/target-libs"
    restoreenv
    popd

    pushd "$INSTALLDIR_NATIVE"
    rm -rf ./lib
    popd
fi
