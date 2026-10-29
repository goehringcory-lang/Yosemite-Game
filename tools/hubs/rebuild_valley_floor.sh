#!/usr/bin/env bash
# Rebuilds the Valley floor's small areas and the trail scenes between the
# hand-made areas (tools/hubs/build_valley_floor.gd) onto the 32px grid in one
# go: runs the 16px builder, upgrades every PNG it drew to the 32px palette
# art (tools/art32/upgrade.py --fresh), moves the scenes it wrote onto the
# 32px grid (tools/art32/migrate_built.py), and re-imports.
#
#   tools/hubs/rebuild_valley_floor.sh
#   GODOT=/path/to/godot PYTHON=/path/to/python3 tools/hubs/rebuild_valley_floor.sh
#   ONLY=mirror_lake,crows_camp tools/hubs/rebuild_valley_floor.sh   # just these
#
# The Python steps need Pillow and numpy.
set -eu
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
PYTHON="${PYTHON:-python3}"
SCENES=(el_capitan_meadow tunnel_view happy_isles mirror_lake leidig_meadow four_mile_trailhead
	bridalveil_fall housekeeping_camp ahwahnee_meadow upper_pines tenaya_creek crows_camp big_oak_flat_junction crane_flat)
stamp="$(mktemp)"
trap 'rm -f "$stamp"' EXIT
sleep 1
"$GODOT" --headless --path . res://tools/hubs/build_valley_floor.tscn
mapfile -t fresh < <(find assets -name '*.png' -newer "$stamp")
"$PYTHON" tools/art32/upgrade.py --fresh "${fresh[@]}"
if [[ -n "${ONLY:-}" ]]; then
	IFS=, read -ra SCENES <<< "$ONLY"
fi
"$PYTHON" tools/art32/migrate_built.py $(printf "scenes/regions/%s.tscn " "${SCENES[@]}") --fresh "${fresh[@]}"
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
