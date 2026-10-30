#!/usr/bin/env bash
# Takes the renderer tour (tools/shots/renderer_tour.tscn) under the
# Compatibility renderer and under Forward+, with the sprites unlit (the real
# light LitSprites adds on Forward+ is meant to change the look), then
# compares them picture by picture (tools/shots/compare_shots.gd). Needs a display (or xvfb-run) and
# a Vulkan driver for Forward+ (lavapipe will do: mesa-vulkan-drivers).
#
#   tools/shots/renderer_compare.sh [OUT_DIR]
#   GODOT=/path/to/godot SHOT_REGIONS=curry_village tools/shots/renderer_compare.sh
#
# OUT_DIR (default /tmp/renderer_compare) gets gl_compatibility/,
# gl_compatibility_again/ (a second run, to measure how much animation alone
# changes the pictures), forward_plus/ and diff/. Exits non-zero if the tour
# fails under either renderer or Forward+ differs by more than that, plus
# MAX_SHARE (default 1%).
set -u
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
OUT="${1:-/tmp/renderer_compare}"
RUN=()
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run > /dev/null; then
	RUN=(xvfb-run -a -s "-screen 0 1920x1080x24")
fi

status=0
for run in gl_compatibility gl_compatibility_again forward_plus; do
	method="${run%_again}"
	dir="$OUT/$run"
	rm -rf "$dir"
	mkdir -p "$dir"
	echo "== Tour under $method ($run)"
	SHOT_DIR="$dir" SHOT_RENDERER="$method" SHOT_UNLIT=1 "${RUN[@]}" "$GODOT" --path . --rendering-method "$method" \
		res://tools/shots/renderer_tour.tscn > "$OUT/$run.log" 2>&1
	grep -E "^Renderer|ERROR" "$OUT/$run.log" | head -20
	if [ "$(ls "$dir" | wc -l)" -eq 0 ]; then
		echo "No pictures from the $run tour (log: $OUT/$run.log)"
		status=1
	fi
done
[ $status -eq 0 ] || exit $status

echo "== Comparing"
"$GODOT" --headless --path . --script res://tools/shots/compare_shots.gd -- \
	"$OUT/gl_compatibility" "$OUT/forward_plus" "$OUT/diff" "${MAX_SHARE:-0.01}" "$OUT/gl_compatibility_again"
