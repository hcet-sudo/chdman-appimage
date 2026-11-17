#!/usr/bin/env bash
# Build a static chdman AppImage from a MAME release tag.
# Usage: build-chdman.sh <mame-tag>     e.g. mame0289
#
# Builds ONLY chdman (no emulator, no bgfx, no Qt) in two steps:
#   1) generate the genie project files with tools-only params
#   2) build just the chdman target from the generated solution
# USE_QTDEBUG=0 skips the Qt debugger (genie would otherwise require Qt's moc
# even for a tools-only build); LDOPTS="-static" makes the binary self-contained.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$REPO_DIR/dist"
mkdir -p "$DIST"

TAG="$1"
VER="0.${TAG#mame0}"   # mame0289 -> 0.289
BUILD="$DIST/mame-src"
SRCDIR="$BUILD/mame-$TAG"

if [ ! -d "$SRCDIR" ]; then
  mkdir -p "$BUILD"
  echo "[chdman] downloading MAME source ($TAG)"
  curl -fsSL --retry 3 -o "$BUILD/$TAG.tar.gz" \
    "https://github.com/mamedev/mame/archive/refs/tags/$TAG.tar.gz"
  echo "[chdman] extracting"
  tar xf "$BUILD/$TAG.tar.gz" -C "$BUILD"
fi

cd "$SRCDIR"
# Requires SDL2 + fontconfig development headers (CI: apt-get install
# libsdl2-dev libfontconfig1-dev). Rootless alternative: extract headers to a
# prefix and point SDL_INSTALL_ROOT at it (needs a sdl2-config shim there).
MAKEFLAGS="TOOLS=1 EMULATOR=0 USE_QTDEBUG=0 NO_USE_MIDI=1 NOWERROR=1"

# MAME's osd core references four SDL clipboard symbols that chdman never
# calls. With -static, linking real libSDL2 would drag in X11, so provide
# correct no-op stubs. They must be linked as an OBJECT (not an archive):
# objects contribute their symbols to the table regardless of position,
# archives only resolve refs pending at their scan point.
STUBDIR="$DIST/sdl-stub"
mkdir -p "$STUBDIR"
cat > "$STUBDIR/sdl-clipboard-stubs.c" <<'EOF'
/* No-op SDL clipboard stubs: satisfies MAME's osd core (osdlib_unix.cpp)
   without linking libSDL2. chdman is headless and never reads/writes the
   clipboard, so these paths are unreachable in practice. */
#include <stdlib.h>
int SDL_HasClipboardText(void) { return 0; }
char *SDL_GetClipboardText(void) { return NULL; }
void SDL_free(void *p) { free(p); }
int SDL_SetClipboardText(const char *text) { (void)text; return -1; }
EOF
gcc -c -O2 -fPIE -o "$STUBDIR/sdl-clipboard-stubs.o" "$STUBDIR/sdl-clipboard-stubs.c"

echo "[chdman] generating projects (tools-only, no emulator/bgfx/Qt/midi)"
rm -rf "$SRCDIR/build/projects"
make -j"$(nproc)" $MAKEFLAGS LDOPTS="-static $STUBDIR/sdl-clipboard-stubs.o" generate
make $MAKEFLAGS LDOPTS="-static $STUBDIR/sdl-clipboard-stubs.o" build/projects/sdl/mame/gmake-linux/Makefile

echo "[chdman] compiling chdman (static) — takes several minutes"
make -j"$(nproc)" -C build/projects/sdl/mame/gmake-linux config=release64 chdman

CHDMAN_BIN="$SRCDIR/chdman"
if [ ! -x "$CHDMAN_BIN" ]; then
  CHDMAN_BIN="$(find "$SRCDIR/build" -type f -name chdman -perm -u+x | head -1)"
fi
if [ ! -x "$CHDMAN_BIN" ]; then
  echo "ERROR: chdman binary not found after build" >&2
  exit 1
fi
echo "[chdman] built: $CHDMAN_BIN"
file "$CHDMAN_BIN"

echo "[chdman] packaging AppImage"
"$REPO_DIR/build/package-appimage.sh" \
  chdman "$CHDMAN_BIN" \
  "MAME Compressed Hunks of Data (CHD) manager" \
  "https://www.mamedev.org" \
  "chdman-x86_64.AppImage"

echo "$VER" > "$DIST/chdman.version"
echo "[chdman] done (v$VER)"
