#!/bin/bash
# Build 长明.app (EternalLight) from source. Requires Xcode Command Line Tools (swiftc, iconutil, sips).
set -euo pipefail
cd "$(dirname "$0")"

APP="长明.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp src/Info.plist "$APP/Contents/Info.plist"

echo "Compiling…"
swiftc -swift-version 5 -O -o "$APP/Contents/MacOS/EternalLight" src/main.swift

echo "Decoding menu-bar images…"
for f in menubar_on menubar_off; do
  base64 -d < "src/$f.png.b64" > "$APP/Contents/Resources/$f.png"
done

echo "Building icon…"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
base64 -d < src/AppIcon-1024.png.b64 > "$TMP/icon_1024.png"
ICONSET="$TMP/AppIcon.iconset"
mkdir "$ICONSET"
sips -z 16 16     "$TMP/icon_1024.png" --out "$ICONSET/icon_16x16.png"      >/dev/null
sips -z 32 32     "$TMP/icon_1024.png" --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
sips -z 32 32     "$TMP/icon_1024.png" --out "$ICONSET/icon_32x32.png"      >/dev/null
sips -z 64 64     "$TMP/icon_1024.png" --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
sips -z 128 128   "$TMP/icon_1024.png" --out "$ICONSET/icon_128x128.png"    >/dev/null
sips -z 256 256   "$TMP/icon_1024.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$TMP/icon_1024.png" --out "$ICONSET/icon_256x256.png"    >/dev/null
sips -z 512 512   "$TMP/icon_1024.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$TMP/icon_1024.png" --out "$ICONSET/icon_512x512.png"    >/dev/null
cp "$TMP/icon_1024.png" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "Signing (ad-hoc)…"
codesign --force -s - "$APP"

echo "Built ./$APP"
