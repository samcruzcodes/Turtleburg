#!/bin/bash
# Repeatable Turtleburg release build (Godot 3.6.3 + export templates 3.6.3 must be installed).
#   tools/build_release.sh /path/to/Godot.app/Contents/MacOS/Godot
# Output: dist/Turtleburg-windows.zip  (Turtleburg.exe + Turtleburg.pck)
#         dist/Turtleburg-macos.zip    (Turtleburg.app, ad-hoc signed)
# Set HOME to the folder holding Library/Application Support/Godot/templates if templates live elsewhere.
set -euo pipefail
GODOT="${1:?usage: tools/build_release.sh /path/to/Godot}"
cd "$(dirname "$0")/.."
rm -rf build dist; mkdir -p build/windows build/macos dist

echo "== Windows"
"$GODOT" --path . --export "Turtleburg" build/windows/Turtleburg.exe
(cd build/windows && zip -9 -q ../../dist/Turtleburg-windows.zip Turtleburg.exe Turtleburg.pck)

echo "== macOS"
"$GODOT" --path . --export "Turtleburg macOS" build/macos/Turtleburg.zip
(cd build/macos && rm -rf app && mkdir app && unzip -q Turtleburg.zip -d app)
# Apple Silicon will not launch unsigned arm64 code; an ad-hoc signature is enough for local/itch distribution
codesign --force --deep --sign - build/macos/app/Turtleburg.app
codesign --verify --deep --strict build/macos/app/Turtleburg.app
(cd build/macos/app && ditto -c -k --sequesterRsrc --keepParent Turtleburg.app ../../../dist/Turtleburg-macos.zip)

echo "== done"; ls -la dist
shasum -a 256 dist/*.zip
