#!/usr/bin/env bash
# Unit tests for docker-action/entrypoint.sh
#
# Run with: bash tests/test-entrypoint.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENTRYPOINT="${REPO_ROOT}/docker-action/entrypoint.sh"

# shellcheck source=tests/test-helpers.sh
. "$SCRIPT_DIR/test-helpers.sh"

_TMPDIR=$(mktemp -d)
trap 'rm -rf "$_TMPDIR"' EXIT

# ---------------------------------------------------------------------------
# Set up a mock cmake that records its arguments and exits 0.
# ---------------------------------------------------------------------------

_MOCK_BIN="${_TMPDIR}/mock-bin"
_CMAKE_LOG="${_TMPDIR}/cmake-calls.log"
mkdir -p "$_MOCK_BIN"
cat > "$_MOCK_BIN/cmake" <<'MOCKEOF'
#!/bin/sh
printf '%s\n' "$@" >> "${CMAKE_LOG}"
MOCKEOF
chmod +x "$_MOCK_BIN/cmake"

# Run entrypoint.sh with the mock cmake on PATH.
run_entrypoint() {
    CMAKE_LOG="$_CMAKE_LOG" PATH="${_MOCK_BIN}:${PATH}" sh "$ENTRYPOINT" "$@"
}

# Same, but discard stdout+stderr and return the exit status.
exit_status_of() {
    local status=0
    CMAKE_LOG="$_CMAKE_LOG" PATH="${_MOCK_BIN}:${PATH}" sh "$ENTRYPOINT" "$@" >/dev/null 2>&1 || status=$?
    echo "$status"
}

# Capture only stderr (stdout discarded).
stderr_of() {
    { CMAKE_LOG="$_CMAKE_LOG" PATH="${_MOCK_BIN}:${PATH}" sh "$ENTRYPOINT" "$@" 1>/dev/null; } 2>&1 || true
}

# ---------------------------------------------------------------------------
# Group 1: SOURCE_DIR does not exist
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 1: SOURCE_DIR does not exist ==="

_NOEXIST="${_TMPDIR}/no-such-dir"

assert_eq "missing SOURCE_DIR: exit status 1" "1" \
    "$(exit_status_of "$_NOEXIST")"

_ERR1=$(stderr_of "$_NOEXIST")
assert_contains "missing SOURCE_DIR: stderr mentions path" \
    "$_ERR1" "$_NOEXIST"

assert_contains "missing SOURCE_DIR: stderr contains 'Error'" \
    "$_ERR1" "Error"

# ---------------------------------------------------------------------------
# Group 2: arm-none-eabi-gcc.cmake missing from SOURCE_DIR
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 2: arm-none-eabi-gcc.cmake missing ==="

_SRC2="${_TMPDIR}/src-no-cmake"
mkdir -p "$_SRC2"

assert_eq "missing cmake file: exit status 1" "1" \
    "$(exit_status_of "$_SRC2")"

_ERR2=$(stderr_of "$_SRC2")
assert_contains "missing cmake file: stderr names the file" \
    "$_ERR2" "arm-none-eabi-gcc.cmake"

# ---------------------------------------------------------------------------
# Group 3: Happy path with explicit BUILD_DIR
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 3: Happy path with explicit BUILD_DIR ==="

_SRC3="${_TMPDIR}/src-happy"
_BUILD3="${_TMPDIR}/build-explicit"
mkdir -p "$_SRC3"
touch "$_SRC3/arm-none-eabi-gcc.cmake"

rm -f "$_CMAKE_LOG"
assert_eq "explicit BUILD_DIR: exit status 0" "0" \
    "$(exit_status_of "$_SRC3" "$_BUILD3")"

assert_contains "explicit BUILD_DIR: cmake configure uses -B BUILD_DIR" \
    "$(cat "$_CMAKE_LOG")" "$_BUILD3"

assert_contains "explicit BUILD_DIR: cmake --build is called" \
    "$(cat "$_CMAKE_LOG")" "--build"

# ---------------------------------------------------------------------------
# Group 4: Default BUILD_DIR = SOURCE_DIR/build
# ---------------------------------------------------------------------------

echo ""
echo "=== Group 4: Default BUILD_DIR = SOURCE_DIR/build ==="

_SRC4="${_TMPDIR}/src-default"
mkdir -p "$_SRC4"
touch "$_SRC4/arm-none-eabi-gcc.cmake"

rm -f "$_CMAKE_LOG"
assert_eq "default BUILD_DIR: exit status 0" "0" \
    "$(exit_status_of "$_SRC4")"

assert_contains "default BUILD_DIR: cmake uses SOURCE_DIR/build" \
    "$(cat "$_CMAKE_LOG")" "${_SRC4}/build"

print_test_results
