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

# build-gcc-first.sh: Builds the gcc-first component (stage III-1) of the
# GNU Tools for STM32 toolchain.  This script is extracted from
# build-toolchain.sh so that changes to other parts of the toolchain build
# do not invalidate the gcc-first stage cache.
#
# Usage:
#   ./build-gcc-first.sh [--build_type=...] [--skip_steps=...]
#
# The script accepts the same --build_type and --skip_steps flags as
# build-toolchain.sh.  The --skip_stages flag is accepted but ignored (this
# script always builds the gcc-first stage).
#
# The binutils stage (III-0) output must already be present in install-native/
# before calling this script.

set -e
set -x
set -u
set -o pipefail

# shellcheck disable=SC2016 # intentional: single quotes defer expansion to trace-print time
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
  GCC_CONFIG_OPTS=" --build=$BUILD --host=$HOST_NATIVE
                    --with-gmp=$BUILDDIR_NATIVE/host-libs/usr
                    --with-mpfr=$BUILDDIR_NATIVE/host-libs/usr
                    --with-mpc=$BUILDDIR_NATIVE/host-libs/usr
                    --with-isl=$BUILDDIR_NATIVE/host-libs/usr "
fi

if [ "x$skip_native_build" != "xyes" ] ; then
    mkdir -p "$BUILDDIR_NATIVE"
    mkdir -p "$INSTALLDIR_NATIVE"
    mkdir -p "$PACKAGEDIR"
fi

cd "$SRCDIR"

if [ "x$skip_native_build" != "xyes" ] ; then
    echo "Task [III-1] /$HOST_NATIVE/gcc-first/" | tee -a "$BUILDDIR_NATIVE/.stage"
    rm -rf "$BUILDDIR_NATIVE/gcc-first" && mkdir -p "$BUILDDIR_NATIVE/gcc-first"
    pushd "$BUILDDIR_NATIVE/gcc-first"
    # shellcheck disable=SC2086 # GCC_CONFIG_OPTS is an intentionally word-split list of configure flags
    "$SRCDIR/$GCC/configure" --target="$TARGET" \
        --prefix="$INSTALLDIR_NATIVE" \
        --libexecdir="$INSTALLDIR_NATIVE/lib" \
        --infodir="$INSTALLDIR_NATIVE_DOC/info" \
        --mandir="$INSTALLDIR_NATIVE_DOC/man" \
        --htmldir="$INSTALLDIR_NATIVE_DOC/html" \
        --pdfdir="$INSTALLDIR_NATIVE_DOC/pdf" \
        --enable-checking=release \
        --enable-languages=c \
        --disable-decimal-float \
        --disable-libffi \
        --disable-libgomp \
        --disable-libmudflap \
        --disable-libquadmath \
        --disable-libssp \
        --disable-libstdcxx-pch \
        --disable-nls \
        --disable-shared \
        --disable-threads \
        --disable-tls \
        --disable-libatomic \
        --disable-libsanitizer \
        --with-newlib \
        --without-headers \
        --with-gnu-as \
        --with-gnu-ld \
        --with-python-dir=share/gcc-arm-none-eabi \
        --with-sysroot="$INSTALLDIR_NATIVE/arm-none-eabi" \
        --with-zstd=no \
        ${GCC_CONFIG_OPTS}                              \
        "${GCC_CONFIG_OPTS_LCPP}"                              \
        "--with-pkgversion=$PKGVERSION" \
        "${MULTILIB_LIST}"

    make -j"$JOBS" CXXFLAGS="$BUILD_OPTIONS" all-gcc

    make install-gcc

    popd

    pushd "$INSTALLDIR_NATIVE"
    rm -rf bin/arm-none-eabi-gccbug
    rm -rf ./lib/libiberty.a
    rm -rf  include
    popd
fi
