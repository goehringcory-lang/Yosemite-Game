#!/usr/bin/env bash
# Takes the renderer tour (tools/shots/renderer_tour.tscn) under the
# Compatibility renderer and under Forward+, then compares them picture by
# picture (tools/shots/compare_shots.gd). Needs a display (or xvfb-run) and
# a Vulkan driver for Forward+ (lavapipe will do: mesa-vulkan-drivers).
#
#   tools/shots/renderer_compare.sh [OUT_DIR]
#   GODOT=/path/to/godot SHOT_REGIONS=curry_village tools/shots/renderer_compare.sh
#
# OUT_DIR (default /tmp/renderer_compare) gets compatibility/, forward_plus/
# and diff/. Exits non-zero if the tour fails under either renderer or the
# pictures differ.
set -u
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
OUT="${1:-/tmp/renderer_compare}"
RUN=()
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run > /dev/null; then
	RUN=(xvfb-run -a -s "-screen 0 1920x1080x24")
fi

status=0
for method in gl_compatibility forward_plus; do
	dir="$OUT/$method"
	rm -rf "$dir"
	mkdir -p "$dir"
	echo "== Tour under $method"
	SHOT_DIR="$dir" SHOT_RENDERER="$method" "${RUN[@]}" "$GODOT" --path . --rendering-method "$method" \
		res://tools/shots/renderer_tour.tscn > "$OUT/$method.log" 2>&1
	grep -E "^Renderer|ERROR" "$OUT/$method.log" | head -20
	if [ "$(ls "$dir" | wc -l)" -eq 0 ]; then
		echo "No pictures from the $method tour (log: $OUT/$method.log)"
		status=1
	fi
done
[ $status -eq 0 ] || exit $status

echo "== Comparing"
"$GODOT" --headless --path . --script res://tools/shots/compare_shots.gd -- \
	"$OUT/gl_compatibility" "$OUT/forward_plus" "$OUT/diff" "${MAX_SHARE:-0.02}"
