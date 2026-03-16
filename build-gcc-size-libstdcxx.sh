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

# build-gcc-size-libstdcxx.sh: Builds the gcc-size-libstdcxx component (stage
# III-5) of the GNU Tools for STM32 toolchain.  This script is extracted from
# build-toolchain.sh so that changes to other parts of the toolchain build
# do not invalidate the gcc-size-libstdcxx stage cache.
#
# Usage:
#   ./build-gcc-size-libstdcxx.sh [--build_type=...] [--skip_steps=...]
#
# The script accepts the same --build_type and --skip_steps flags as
# build-toolchain.sh.  The --skip_stages flag is accepted but ignored (this
# script always builds the gcc-size-libstdcxx stage).
#
# Prerequisites:
#   - gcc-final stage (III-4) output must already be present in install-native/
#   - newlib-nano stage (III-3) output must already be present in
#     build-native/target-libs/

set -e
set -x
set -u
set -o pipefail

PS4='+$(date -u +%Y-%m-%d:%H:%M:%S) (${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

umask 022

exec < /dev/null

script_path=$(cd $(dirname $0) && pwd -P)
cd "$script_path"
. $script_path/build-common.sh

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
    mkdir -p $BUILDDIR_NATIVE
    mkdir -p $INSTALLDIR_NATIVE
    mkdir -p $PACKAGEDIR
fi

cd $SRCDIR

if [ "x$skip_native_build" != "xyes" ] ; then
    echo Task [III-5] /$HOST_NATIVE/gcc-size-libstdcxx/ | tee -a "$BUILDDIR_NATIVE/.stage"
    rm -f $BUILDDIR_NATIVE/target-libs/arm-none-eabi/usr
    ln -s . $BUILDDIR_NATIVE/target-libs/arm-none-eabi/usr

    rm -rf $BUILDDIR_NATIVE/gcc-size-libstdcxx && mkdir -p $BUILDDIR_NATIVE/gcc-size-libstdcxx
    pushd $BUILDDIR_NATIVE/gcc-size-libstdcxx

    echo "[timing] gcc-size-libstdcxx configure start: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    $SRCDIR/$GCC/configure --target=$TARGET \
        --prefix=$BUILDDIR_NATIVE/target-libs \
        --enable-languages=c,c++ \
        --disable-decimal-float \
        --disable-libffi \
        --disable-libgomp \
        --disable-libmudflap \
        --disable-libquadmath \
        --disable-libssp \
        --disable-libstdcxx-pch \
        --disable-libstdcxx-verbose \
        --disable-nls \
        --disable-shared \
        --disable-threads \
        --disable-tls \
        --with-gnu-as \
        --with-gnu-ld \
        --with-newlib \
        --with-headers=yes \
        --with-python-dir=share/gcc-arm-none-eabi \
        --with-sysroot=$BUILDDIR_NATIVE/target-libs/arm-none-eabi \
        --with-zstd=no \
        $GCC_CONFIG_OPTS \
        "${GCC_CONFIG_OPTS_LCPP}"                              \
        "--with-pkgversion=$PKGVERSION" \
        ${MULTILIB_LIST}
    echo "[timing] gcc-size-libstdcxx configure end: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

    echo "[timing] gcc-size-libstdcxx make start: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    make -j$JOBS CCXXFLAGS="$BUILD_OPTIONS" \
            LDFLAGS_FOR_TARGET="--specs=nosys.specs" \
            CXXFLAGS_FOR_TARGET="-g -Os -ffunction-sections -fdata-sections -fno-exceptions"
    echo "[timing] gcc-size-libstdcxx make end: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

    echo "[timing] gcc-size-libstdcxx install start: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    make install
    echo "[timing] gcc-size-libstdcxx install end: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

    copy_multi_libs src_prefix="$BUILDDIR_NATIVE/target-libs/arm-none-eabi/lib" \
                    dst_prefix="$INSTALLDIR_NATIVE/arm-none-eabi/lib"           \
                    target_gcc="$BUILDDIR_NATIVE/target-libs/bin/arm-none-eabi-gcc"

    # Copy the nano configured newlib.h file into the location that nano.specs
    # expects it to be.
    mkdir -p $INSTALLDIR_NATIVE/arm-none-eabi/include/newlib-nano
    cp -f $BUILDDIR_NATIVE/target-libs/arm-none-eabi/include/newlib.h \
          $INSTALLDIR_NATIVE/arm-none-eabi/include/newlib-nano/newlib.h

    popd
fi
