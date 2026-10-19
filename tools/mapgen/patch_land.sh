#!/usr/bin/env bash
# Applies a hub's land patches (tools/mapgen/land_patches.gd, listed in
# hub_content.gd) to its generated map as it stands, in one go: patches the
# scene and paints the ground (patch_land.tscn), upgrades the painting to the
# 32px art and pastes the patched part into the map's ground picture
# (patch_ground.py), and re-imports. Run it on the committed map: it plants
# trees each time, so running it twice plants twice.
#
#   tools/mapgen/patch_land.sh yosemite_valley
#   GODOT=/path/to/godot PYTHON=/path/to/python3 tools/mapgen/patch_land.sh yosemite_valley
#
# The Python step needs Pillow and numpy. Painting the whole Valley takes
# about five minutes.
set -eu
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
PYTHON="${PYTHON:-python3}"
hub="$1"
picture="$(mktemp --suffix=.png)"
trap 'rm -f "$picture"' EXIT
box="$("$GODOT" --headless --path . res://tools/mapgen/patch_land.tscn -- "$hub" "$picture" | tee /dev/stderr | sed -n 's/^PATCHED //p')"
# shellcheck disable=SC2086
"$PYTHON" tools/mapgen/patch_ground.py "$hub" "$picture" $box
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
