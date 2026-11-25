#!/bin/bash
# Run the regression tests against an *exported* macOS build, never touching real saves.
#   tests/run_app_tests.sh /path/to/Turtleburg.app <doors|saves|saves_unit|blur|layering|playthrough> [more...]
# Extra engine flags (e.g. TB_GODOT_ARGS="--fixed-fps 30") are passed through.
# The .app is copied to a temp folder, a test hook is injected through override.cfg next to the
# executable (re-signed ad hoc), and HOME points at a throw-away profile.
set -u
APP="$1"; shift
HERE="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${TB_WORK:-$(mktemp -d)}"
FAKE_HOME="${TB_HOME:-$WORK/home}"; mkdir -p "$FAKE_HOME"
OUT="${TB_OUT:-$WORK/results/}"; mkdir -p "$OUT"
rm -rf "$WORK/Turtleburg.app"; ditto "$APP" "$WORK/Turtleburg.app"
EXE="$WORK/Turtleburg.app/Contents/MacOS/Turtleburg"
export TB_OUT="$OUT" TB_SHOT="${TB_SHOT:-1}"
run() {  # run <TB_TEST> <hook script>
  local test="$1" script="$2"
  printf '[autoload]\n\nT="*%s"\n' "$HERE/tests/$script" > "$WORK/Turtleburg.app/Contents/MacOS/override.cfg"
  codesign --force --deep --sign - "$WORK/Turtleburg.app" >/dev/null 2>&1
  # the app writes to a file (not a pipe) so a slow reader can never stall it; filtered afterwards
  TB_TEST="$test" HOME="$FAKE_HOME" "$EXE" ${TB_GODOT_ARGS:-} > "$OUT/$test.raw" 2>&1
  sed 's/\x1b\[[0-9;]*m//g' "$OUT/$test.raw" > "$OUT/$test.log"
  grep -E "\[TEST\]|\[LAYER\] (SUMMARY|scene)|\[BOT\] (PASS|\*\*\*|RESULT)|SCRIPT ERROR" "$OUT/$test.log"
}
for t in "$@"; do
  case "$t" in
    saves) rm -rf "$FAKE_HOME/Library/Application Support/Turtleburg"; for p in saves_p1 saves_p2 saves_p3; do run $p tb_tests.gd; done ;;
    layering) for s in townhall Jaysonhome brockhome; do TB_LOCAL=1 TB_SCENE=res://Scenes/$s.tscn TB_MODE=after TB_TAG=$s TB_EXPOSED_ONLY=1 run layering_$s layering_test.gd; done ;;
    playthrough) rm -rf "$FAKE_HOME/Library/Application Support/Turtleburg"; run playthrough "../tests/playthrough_bot.gd" ;;
    *) rm -rf "$FAKE_HOME/Library/Application Support/Turtleburg"; run "$t" tb_tests.gd ;;
  esac
done
echo "results: $OUT"
