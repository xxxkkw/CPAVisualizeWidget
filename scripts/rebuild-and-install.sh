#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/CPAVisualize.xcodeproj"
SCHEME="CPAVisualize"
CONFIGURATION="Debug"
DERIVED_DATA_PATH="$ROOT_DIR/.cursor-build-signed"
BUILT_APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/CPAVisualize.app"
INSTALL_APP_PATH="/Applications/CPAVisualize.app"

APP_GROUP_PATH="$HOME/Library/Group Containers/group.com.example.CPAVisualize"
APP_CONTAINER_PATH="$HOME/Library/Containers/com.example.CPAVisualize"
WIDGET_CONTAINER_PATH="$HOME/Library/Containers/com.example.CPAVisualize.CPAWidgetExtension"
WIDGET_SCRIPTS_PATH="$HOME/Library/Application Scripts/com.example.CPAVisualize.CPAWidgetExtension"
HTTP_STORAGE_PATH="$HOME/Library/HTTPStorages/com.example.CPAVisualize"
SAVED_STATE_PATH="$HOME/Library/Saved Application State/com.example.CPAVisualize.savedState"
XCODE_DERIVED_DATA_ROOT="$HOME/Library/Developer/Xcode/DerivedData"

CLEAN_PATHS=(
  "$DERIVED_DATA_PATH"
  "$ROOT_DIR/DerivedData"
  "$APP_GROUP_PATH/SharedCache"
  "$APP_CONTAINER_PATH/Data/Library/Caches/com.example.CPAVisualize"
  "$WIDGET_CONTAINER_PATH"
  "$WIDGET_SCRIPTS_PATH"
  "$HTTP_STORAGE_PATH"
  "$SAVED_STATE_PATH"
)

printf '==> Stopping running app and widget processes\n'
pkill -x CPAVisualize || true
pkill -x CPAWidgetExtension || true
pkill -f '/DerivedData/.*/CPAVisualize.app/Contents/MacOS/CPAVisualize' || true
pkill -f '/DerivedData/.*/CPAWidgetExtension.appex/Contents/MacOS/CPAWidgetExtension' || true
killall NotificationCenter || true
killall chronod || true
killall UserNotificationCenter || true

printf '==> Removing installed app copies from /Applications\n'
find /Applications -maxdepth 2 -type d \( -name 'CPAVisualize.app' -o -name '*CPAVisualize*.app' \) -print -exec rm -rf {} +

printf '==> Removing app-specific Xcode DerivedData\n'
find "$XCODE_DERIVED_DATA_ROOT" -maxdepth 1 -type d -name 'CPAVisualize-*' -print -exec rm -rf {} + 2>/dev/null || true

# 保留偏好设置与 Keychain，只清理构建产物和 Widget 运行缓存。
printf '==> Cleaning old installs and runtime caches\n'
for path in "${CLEAN_PATHS[@]}"; do
  rm -rf "$path"
done

printf '==> Building %s\n' "$SCHEME"
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  clean build

if [ ! -d "$BUILT_APP_PATH" ]; then
  printf 'Built app not found: %s\n' "$BUILT_APP_PATH" >&2
  exit 1
fi

printf '==> Installing fresh app bundle\n'
ditto "$BUILT_APP_PATH" "$INSTALL_APP_PATH"

printf '==> Launching fresh install\n'
open "$INSTALL_APP_PATH"
sleep 3
killall NotificationCenter || true
killall chronod || true
sleep 3

printf '==> Installed app timestamps\n'
stat -f '%Sm %N' -t '%Y-%m-%d %H:%M:%S' "$INSTALL_APP_PATH" "$BUILT_APP_PATH"

printf '==> Active processes\n'
pgrep -fl 'CPAVisualize|CPAWidgetExtension|NotificationCenter|chronod|widget' || true

printf '==> Installed app copies after rebuild\n'
find /Applications -maxdepth 2 -type d \( -name 'CPAVisualize.app' -o -name '*CPAVisualize*.app' \) -print | sort || true
