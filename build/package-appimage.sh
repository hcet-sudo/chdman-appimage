#!/usr/bin/env bash
# Package a static CLI binary as a minimal AppImage using appimagetool.
# Usage: package-appimage.sh <name> <binary> <summary> <homepage> <output-appimage>
#
# Env overrides:
#   APPIMAGETOOL   path to an existing appimagetool binary (downloaded otherwise)
#   SKIP_DOWNLOAD  set non-empty to fail instead of downloading appimagetool
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$REPO_DIR/dist"
mkdir -p "$DIST"

NAME="$1"
BIN="$(readlink -f "$2")"
SUMMARY="$3"
HOMEPAGE="$4"
OUT="$DIST/$5"
METAINFO_ID="${METAINFO_ID:-io.github.chdman-appimage.$NAME}"

APPDIR="$DIST/${NAME}.AppDir"
TOOL="${APPIMAGETOOL:-$DIST/appimagetool-x86_64.AppImage}"

if [ ! -x "$TOOL" ]; then
  if [ -n "${SKIP_DOWNLOAD:-}" ]; then
    echo "appimagetool not found at $TOOL" >&2
    exit 1
  fi
  echo "[pkg] downloading appimagetool"
  curl -fsSL --retry 3 -o "$TOOL" \
    "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
  chmod +x "$TOOL"
fi

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" \
         "$APPDIR/usr/share/applications" \
         "$APPDIR/usr/share/metainfo" \
         "$APPDIR/usr/share/icons/hicolor/256x256/apps"

install -m 755 "$BIN" "$APPDIR/usr/bin/$NAME"
install -m 644 "$REPO_DIR/assets/icons/$NAME.png" "$APPDIR/$NAME.png"
install -m 644 "$REPO_DIR/assets/icons/$NAME.png" \
  "$APPDIR/usr/share/icons/hicolor/256x256/apps/$NAME.png"
ln -sf "$NAME.png" "$APPDIR/.DirIcon"

cat > "$APPDIR/$NAME.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$NAME
GenericName=$SUMMARY
Exec=$NAME
Icon=$NAME
Terminal=true
NoDisplay=true
Categories=Utility;ConsoleOnly;
EOF
install -m 644 "$APPDIR/$NAME.desktop" \
  "$APPDIR/usr/share/applications/$NAME.desktop"

cat > "$APPDIR/usr/share/metainfo/$NAME.appdata.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<component type="console-application">
  <id>$METAINFO_ID</id>
  <name>$NAME</name>
  <summary>$SUMMARY</summary>
  <metadata_license>MIT</metadata_license>
  <project_license>GPL-2.0-or-later</project_license>
  <developer_name>Unofficial AppImage build (chdman-unecm-appimage)</developer_name>
  <url type="homepage">$HOMEPAGE</url>
  <provides>
    <binary>$NAME</binary>
  </provides>
</component>
EOF

cat > "$APPDIR/AppRun" <<EOF
#!/bin/sh
HERE=\$(dirname "\$(readlink -f "\$0")")
exec "\$HERE/usr/bin/$NAME" "\$@"
EOF
chmod 755 "$APPDIR/AppRun"

# refuse to package a dynamically linked binary (these AppImages must run anywhere)
if ldd "$BIN" 2>/dev/null | grep -q "dynamic"; then
  echo "ERROR: $BIN is dynamically linked — AppImages in this repo must be static" >&2
  exit 1
fi

cd "$DIST"
APPIMAGE_EXTRACT_AND_RUN=1 ARCH=x86_64 "$TOOL" "$APPDIR" "$OUT"
echo "[pkg] OK: $OUT"
