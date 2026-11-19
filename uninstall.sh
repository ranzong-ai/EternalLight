#!/bin/bash
# Remove 长明 (EternalLight).
# The login item was registered by the app itself (SMAppService); once the app
# is gone the entry is inert and macOS prunes it — you can also remove it right
# away under 系统设置 → 通用 → 登录时打开.
# NOTE: this does not change the current sleep setting. If you uninstall while
# always-on mode is active, restore normal sleep manually afterwards:
#   sudo pmset disablesleep 0
set -euo pipefail

pkill -f "长明.app/Contents/MacOS/EternalLight" 2>/dev/null || true
rm -rf "/Applications/长明.app"

echo "Uninstalled. If always-on mode was active, run:  sudo pmset disablesleep 0"
