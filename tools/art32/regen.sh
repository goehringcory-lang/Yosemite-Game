#!/usr/bin/env bash
# Runs a 16px art generator, then upgrades what it wrote to the 32px palette
# art. Example:
#   tools/art32/regen.sh res://tools/npcgen/npcgen.gd
#   tools/art32/regen.sh res://tools/mapgen/mapgen.tscn
set -eu
cd "$(dirname "$0")/../.."
scene_or_script="$1"
if [[ "$scene_or_script" == *.gd ]]; then
	godot --headless --path . --script "$scene_or_script"
else
	godot --headless --path . "$scene_or_script"
fi
python3 tools/art32/upgrade.py
