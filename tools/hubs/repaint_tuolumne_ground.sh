#!/usr/bin/env bash
# Paints Tuolumne Meadows' ground again (tools/hubs/tuolumne_ground.gd) without
# rebuilding the rest of the area, upgrades it to the 32px palette art, draws
# its normal map (tools/normals) and re-imports it.
#
#   tools/hubs/repaint_tuolumne_ground.sh
#   GODOT=/path/to/godot PYTHON=/path/to/python3 tools/hubs/repaint_tuolumne_ground.sh
#
# The Python steps need Pillow and numpy.
set -eu
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
PYTHON="${PYTHON:-python3}"
"$GODOT" --headless --path . res://tools/hubs/paint_tuolumne_ground.tscn
"$PYTHON" tools/art32/upgrade.py --fresh assets/sprites/ahwahnee/ground_tuolumne_meadows.png
"$PYTHON" tools/normals/normals.py assets/sprites/ahwahnee/ground_tuolumne_meadows.png
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
