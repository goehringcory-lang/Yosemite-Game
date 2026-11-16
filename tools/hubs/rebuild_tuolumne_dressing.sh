#!/usr/bin/env bash
# Redraws Tuolumne's buildings-and-props art without rebuilding the region:
# the store and lodge halls and the props round them (tuolumne_art.gd
# save_dressing), upgraded to the 32px art (tools/art32/upgrade.py --fresh),
# their normal maps (tools/normals/normals.py), then re-imports.
#
#   tools/hubs/rebuild_tuolumne_dressing.sh
#
# The Python steps need Pillow and numpy.
set -eu
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
PYTHON="${PYTHON:-python3}"
stamp="$(mktemp)"
trap 'rm -f "$stamp"' EXIT
sleep 1
"$GODOT" --headless --path . res://tools/hubs/build_tuolumne_dressing.tscn
mapfile -t fresh < <(find assets/sprites/tuolumne -name '*.png' -newer "$stamp")
"$PYTHON" tools/art32/upgrade.py --fresh "${fresh[@]}"
lit=()
for f in "${fresh[@]}"; do
	case "$f" in *_glow.png) ;; *) lit+=("$f") ;; esac
done
"$PYTHON" tools/normals/normals.py "${lit[@]}"
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
