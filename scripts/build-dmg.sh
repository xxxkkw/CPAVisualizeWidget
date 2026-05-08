#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/CPAVisualize.xcodeproj"
SCHEME="CPAVisualize"
CONFIGURATION="Release"
DERIVED_DATA_PATH="$ROOT_DIR/.cursor-build-signed"
BUILT_APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/CPAVisualize.app"
DIST_DIR="$ROOT_DIR/dist"
DMG_ROOT="$DIST_DIR/dmg-root"
DMG_PATH="$DIST_DIR/CPAVisualize.dmg"
VOLUME_NAME="CPA Visualize"
ICON_PATH="$ROOT_DIR/Assets/CPAVisualize.icns"

rm -rf "$DERIVED_DATA_PATH" "$DMG_ROOT" "$DMG_PATH"
mkdir -p "$DMG_ROOT" "$DIST_DIR"

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

cp -R "$BUILT_APP_PATH" "$DMG_ROOT/CPAVisualize.app"
ln -s /Applications "$DMG_ROOT/Applications"
cp "$ICON_PATH" "$DMG_ROOT/.VolumeIcon.icns"
SetFile -a C "$DMG_ROOT"
SetFile -a V "$DMG_ROOT/.VolumeIcon.icns"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG_PATH"

printf '%s\n' "$DMG_PATH"
