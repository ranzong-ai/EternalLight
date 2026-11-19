#!/bin/bash
# Install 长明 (EternalLight) to /Applications and launch it once.
# The app registers itself as a login item through SMAppService, so it shows
# up under 系统设置 → 通用 → 登录时打开 with its own name and icon.
set -euo pipefail
cd "$(dirname "$0")"

APP_DST="/Applications/长明.app"

[ -d "长明.app" ] || ./build.sh

rm -rf "$APP_DST"
cp -R "长明.app" "$APP_DST"
open "$APP_DST"

echo "Installed and launched. Look for the flame in your menu bar — solid means always-on, faded means normal sleep."
