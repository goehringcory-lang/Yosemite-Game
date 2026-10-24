#!/usr/bin/env bash
# Redraws the outdoor clutter (tools/hubs/wild_clutter_art.gd), upgrades it to
# the 32px palette art (tools/art32/upgrade.py --fresh), re-imports, and lays
# it out in every area outside the towns (tools/hubs/dress_wilds.gd, which
# writes scenes/regions/dressing/wild/). Region adds each area's layout when
# it loads.
#
#   tools/hubs/rebuild_wild_dressing.sh                 # every area
#   tools/hubs/rebuild_wild_dressing.sh tuolumne_meadows
#   GODOT=/path/to/godot tools/hubs/rebuild_wild_dressing.sh
set -eu
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
PYTHON="${PYTHON:-python3}"
"$GODOT" --headless --path . -s res://tools/hubs/build_wild_clutter.gd
"$PYTHON" tools/art32/upgrade.py --fresh assets/sprites/clutter/wild_*.png assets/sprites/clutter/camp_*.png
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
"$GODOT" --headless --path . res://tools/hubs/dress_wilds.tscn -- "$@"
