#!/usr/bin/env bash
# Redraws the town clutter (tools/hubs/town_clutter_art.gd) and upgrades it to
# the 32px palette art (tools/art32/upgrade.py --fresh), then re-imports.
# The towns' dressing scenes (scenes/regions/dressing/) place it.
#
#   tools/hubs/rebuild_clutter.sh
#   GODOT=/path/to/godot tools/hubs/rebuild_clutter.sh
set -eu
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . -s res://tools/hubs/build_clutter.gd
python3 tools/art32/upgrade.py --fresh assets/sprites/clutter/*.png
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
