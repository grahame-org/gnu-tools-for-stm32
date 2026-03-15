# shellcheck shell=bash
# build-toolchain-args.sh
# Sourceable helper: defines parse_toolchain_args() for build-toolchain.sh.
# Can be sourced from test scripts to unit-test argument parsing without
# triggering an actual toolchain build.

_toolchain_usage() {
cat<<EOF
Usage: build-toolchain.sh [--build_type=...] [--skip_steps=...] [--skip_stages=...]

This script will build GNU Tools Arm Embedded toolchain.

OPTIONS:
  --build_type=TYPE     specify build type to either ppa or native.
                        If followed by keyword debug, the produced binaries
                        will be debuggable.  The default case will be
                        non-debug native build.

                        Example usages are as:
                        --build_type=native
                        --build_type=ppa
                        --build_type=native,debug
                        --build_type=ppa,debug

  --with-multilib-list  specify list of multilibs included with the build.
                        For example:
                        --with-multilib-list=rmprofile
                        --with-multilib-list=rmprofile,aprofile  (Default value)

  --skip_steps=STEPS    specify which build steps you want to skip.  Concatenate
                        them with comma for skipping more than one steps.
                        Available steps are:
                            gdb-with-python
                            manual
                            md5_checksum
                            mingw[32]
                            mingw[32]-gdb-with-python
                            native
                            package_bins
                            package_sources
                            strip

  --skip_stages=STAGES  specify which individual native build stages to skip.
                        Provide a comma-separated list of stages to skip more
                        than one.  The caller is responsible for ensuring that
                        install-native/ contains the stage's artifacts before
                        calling this script; skipping a stage that has not
                        previously been built may silently corrupt the build.
                        Available stages are:
                            binutils
                            gcc-first
                            newlib
                            newlib-nano
                            gcc-final
                            gcc-size-libstdcxx
                            gdb
EOF
}

# parse_toolchain_args: parse command-line arguments for build-toolchain.sh.
# Sets global variables: skip_steps, skip_stages, build_type, MULTILIB_LIST,
# is_ppa_release, is_native_build, is_debug_build, skip_manual,
# skip_package_bins, skip_package_sources, skip_md5_checksum,
# skip_gdb_with_python, skip_mingw32_gdb_with_python, skip_native_build,
# skip_strip_target_libraries, skip_mingw32, BUILD_OPTIONS
parse_toolchain_args() {
    skip_mingw32=no
    BUILD_OPTIONS="-g -O2"
    is_ppa_release=no
    is_native_build=yes
    is_debug_build=no
    skip_manual=no
    skip_package_bins=no
    skip_package_sources=no
    skip_md5_checksum=no
    skip_steps=
    skip_stages=
    skip_gdb_with_python=yes
    skip_mingw32_gdb_with_python=yes
    skip_native_build=no
    skip_strip_target_libraries=no
    build_type=

    MULTILIB_LIST="--with-multilib-list=rmprofile,aprofile"

    for ac_arg in "$@"; do
        case $ac_arg in
            --skip_steps=*)
                skip_steps=${ac_arg#--skip_steps=}
                skip_steps=${skip_steps//,/ }
                ;;
            --skip_stages=*)
                skip_stages=${ac_arg#--skip_stages=}
                skip_stages=${skip_stages//,/ }
                ;;
            --build_type=*)
                build_type=${ac_arg#--build_type=}
                build_type=${build_type//,/ }
                ;;
            --with-multilib-list=*)
                # shellcheck disable=SC2034  # output variable; read by callers after parse_toolchain_args()
                MULTILIB_LIST="--with-multilib-list=${ac_arg##*=}"
                ;;
            *)
                _toolchain_usage
                exit 1
                ;;
        esac
    done

    for bt in $build_type; do
        case $bt in
            ppa)
                is_ppa_release=yes
                is_native_build=no
                skip_gdb_with_python=yes
                ;;
            native)
                # shellcheck disable=SC2034  # output variable; read by callers after parse_toolchain_args()
                is_native_build=yes
                # shellcheck disable=SC2034  # output variable; read by callers after parse_toolchain_args()
                is_ppa_release=no
                ;;
            debug)
                # shellcheck disable=SC2034  # output variable; read by callers after parse_toolchain_args()
                BUILD_OPTIONS="-g -O0"
                # shellcheck disable=SC2034  # output variable; read by callers after parse_toolchain_args()
                is_debug_build=yes
                ;;
            *)
                echo "Unknown build type: $bt" 1>&2
                _toolchain_usage
                exit 1
                ;;
        esac
    done

    for ss in $skip_steps; do
        case $ss in
            manual)
                # shellcheck disable=SC2034  # output variable; read by callers after parse_toolchain_args()
                skip_manual=yes
                ;;
            package_bins)
                # shellcheck disable=SC2034  # output variable; read by callers after parse_toolchain_args()
                skip_package_bins=yes
                ;;
            package_sources)
                # shellcheck disable=SC2034  # output variable; read by callers after parse_toolchain_args()
                skip_package_sources=yes
                ;;
            md5_checksum)
                # shellcheck disable=SC2034  # output variable; read by callers after parse_toolchain_args()
                skip_md5_checksum=yes
                ;;
            gdb-with-python)
                # shellcheck disable=SC2034  # output variable; read by callers after parse_toolchain_args()
                skip_gdb_with_python=yes
                ;;
            mingw|mingw32)
                # shellcheck disable=SC2034  # output variable; read by callers after parse_toolchain_args()
                skip_mingw32=yes
                skip_mingw32_gdb_with_python=yes
                ;;
            mingw-gdb-with-python|mingw32-gdb-with-python)
                # shellcheck disable=SC2034  # output variable; read by callers after parse_toolchain_args()
                skip_mingw32_gdb_with_python=yes
                ;;
            native)
                # shellcheck disable=SC2034  # output variable; read by callers after parse_toolchain_args()
                skip_native_build=yes
                ;;
            strip)
                # shellcheck disable=SC2034  # output variable; read by callers after parse_toolchain_args()
                skip_strip_target_libraries=yes
                ;;
            *)
                echo "Unknown build steps: $ss" 1>&2
                _toolchain_usage
                exit 1
                ;;
        esac
    done
}
