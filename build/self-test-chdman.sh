#!/usr/bin/env bash
# Self-test for the chdman AppImage:
#   generate a valid MODE1/2352 test image -> createcd -> extractcd -> bit-compare
#   plus verify + info on the resulting CHD.
# Usage: self-test-chdman.sh <chdman-appimage-path>
set -euo pipefail

CHDMAN_APP="$(readlink -f "$1")"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
cd "$T"

# EMU_PREFIX (optional): command prefix for every invocation, e.g.
#   EMU_PREFIX="qemu-x86_64-static -cpu qemu64"  -> run on an emulated
# baseline x86-64-v1 CPU; the test then fails if the binary contains any
# instruction a v1 CPU rejects (SIGILL). Pass the extracted inner binary as
# $1 when using this (nested execs would otherwise escape the emulator).
run() { APPIMAGE_EXTRACT_AND_RUN=1 ${EMU_PREFIX:-} "$CHDMAN_APP" "$@"; }

echo "--- banner ---"
run 2>&1 | head -1 || true

echo "--- generate test image ---"
python3 "$REPO_DIR/build/make-testbin.py" test.bin
ls -la test.bin test.cue

echo "--- createcd ---"
run createcd -i test.cue -o test.chd
ls -la test.chd

echo "--- extractcd (roundtrip) ---"
run extractcd -i test.chd -o out.cue
ls -la out.bin out.cue

if cmp test.bin out.bin; then
  echo "CHD ROUNDTRIP: OK (bit-perfect)"
else
  echo "CHD ROUNDTRIP: FAILED" >&2
  exit 1
fi

echo "--- verify ---"
run verify -i test.chd

echo "--- info ---"
run info -i test.chd

echo "CHDMAN SELF-TEST PASSED"
