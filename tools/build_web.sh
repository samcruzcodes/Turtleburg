#!/bin/bash
# Repeatable Turtleburg browser build (Godot 3.6.3 + the *regular* web export template installed).
#   tools/build_web.sh /path/to/Godot.app/Contents/MacOS/Godot
# Output: dist/Turtleburg-web.zip  (index.html at the ZIP root, plus index.js/.wasm/.pck and the other runtime files)
# Set HOME to the folder holding Library/Application Support/Godot/templates if templates live elsewhere.
set -euo pipefail
GODOT="${1:?usage: tools/build_web.sh /path/to/Godot}"
cd "$(dirname "$0")/.."
rm -rf build/web dist/Turtleburg-web.zip; mkdir -p build/web dist

"$GODOT" --path . --export "Turtleburg Web" build/web/index.html
(cd build/web && zip -9 -q ../../dist/Turtleburg-web.zip index.*)
unzip -l dist/Turtleburg-web.zip
shasum -a 256 dist/Turtleburg-web.zip
