#!/bin/bash
# Turtleburg regression tests. Usage:
#   tests/run_tests.sh /path/to/Godot <doors|saves|saves_unit|blur|layering [scene]>  [more...]
# Extra engine flags (e.g. TB_GODOT_ARGS="--fixed-fps 30") are passed through.
# Every run uses a throw-away HOME so real player saves are never touched.
# For an exported macOS build set TB_APP=/path/to/Turtleburg.app (the test hook is injected via override.cfg).
set -u
GODOT="$1"; shift
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TB_OUT:-$HERE/tests/results/}"; mkdir -p "$OUT"
FAKE_HOME="${TB_HOME:-$(mktemp -d)}"
export TB_OUT="$OUT" TB_SHOT="${TB_SHOT:-1}"
run() {  # run <TB_TEST> <autoload script>
  local test="$1" script="$2"
  printf '[autoload]\n\nT="*res://tests/%s"\n' "$script" > "$HERE/override.cfg"
  TB_TEST="$test" HOME="$FAKE_HOME" "$GODOT" --path "$HERE" ${TB_GODOT_ARGS:-} 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | tee "$OUT/$test.log" | grep -E "\[TEST\]|\[LAYER\] (SUMMARY|scene)|SCRIPT ERROR"
  rm -f "$HERE/override.cfg"
}
for t in "$@"; do
  case "$t" in
    saves) rm -rf "$FAKE_HOME/Library/Application Support/Turtleburg"; for p in saves_p1 saves_p2 saves_p3; do run $p tb_tests.gd; done ;;
    layering) for s in townhall Jaysonhome brockhome; do TB_SCENE=res://Scenes/$s.tscn TB_MODE=after TB_TAG=$s TB_EXPOSED_ONLY=1 run layering_$s layering_test.gd; done ;;
    *) rm -rf "$FAKE_HOME/Library/Application Support/Turtleburg"; run "$t" tb_tests.gd ;;
  esac
done
