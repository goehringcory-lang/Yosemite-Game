#!/usr/bin/env bash
# Rebuilds the rim country around Glacier Point onto the 32px grid:
#
# - Union Point (the upper Four Mile Trail) and Illilouette Gorge (the
#   Panorama Trail), in Glacier Point's look (its trees and painted drop):
#   their 16px builders, then the
#   PNGs they own upgraded to the 32px palette art (tools/art32/upgrade.py)
#   and their scenes moved onto the 32px grid (tools/art32/migrate_built.py).
# - Bridalveil Creek on Glacier Point Road, like Taft Point: its builder,
#   upgrade and migrate, and wild ground clutter (dress_wilds).
# - Native 32px ground for all three (tools/art32/ground32).
#
# Then normal maps for all three, water cells for their grounds only, any
# shared flora art load_flora() redrew put back, and a re-import.
#
#   GODOT=~/godot/godot PYTHON=/usr/bin/python3 tools/hubs/rebuild_rim_country.sh
#
# The Python steps need Pillow and numpy.
set -eu
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
PYTHON="${PYTHON:-python3}"
stamp="$(mktemp)"
tmp="$(mktemp -d)"
trap 'rm -f "$stamp" "$stamp.cells"; rm -rf "$tmp"' EXIT
sleep 1

"$GODOT" --headless --path . res://tools/hubs/build_union_point.tscn
"$GODOT" --headless --path . res://tools/hubs/build_illilouette.tscn
"$GODOT" --headless --path . res://tools/hubs/build_bridalveil_creek.tscn

grounds=(
	assets/sprites/ahwahnee/ground_union_point.png
	assets/sprites/ahwahnee/ground_illilouette.png
	assets/sprites/ahwahnee/ground_bridalveil_creek.png
)
mine=(
	"${grounds[@]}"
	assets/sprites/glacier/union_point_view.png
	assets/sprites/glacier/illilouette_view.png
)
mapfile -t fresh < <(find assets -name '*.png' -newer "$stamp")
"$PYTHON" tools/art32/upgrade.py --fresh "${mine[@]}"
for scene in scenes/regions/union_point.tscn scenes/regions/illilouette.tscn scenes/regions/bridalveil_creek.tscn; do
	"$PYTHON" tools/art32/migrate_built.py "$scene" --fresh "${mine[@]}"
done

# Put back any shared art redrawn by load_flora().
for f in "${fresh[@]}"; do
	case " ${mine[*]} " in *" $f "*) ;; *) git checkout -q -- "$f" "$f.import" 2>/dev/null || git checkout -q -- "$f" 2>/dev/null || true ;; esac
done

"$GODOT" --headless --path . --import > /dev/null 2>&1 || true

# Native 32px ground for all three, and wild clutter for Bridalveil Creek.
"$GODOT" --headless --path . res://tools/art32/ground32/dump.tscn -- "$tmp/dump" union_point illilouette bridalveil_creek
"$PYTHON" tools/art32/ground32/paint.py "$tmp/dump" union_point illilouette bridalveil_creek
"$GODOT" --headless --path . res://tools/hubs/dress_wilds.tscn -- bridalveil_creek

"$PYTHON" tools/normals/normals.py "${mine[@]}"

# Water cells for these grounds only.
cp data/park/water_cells.json "$stamp.cells"
"$PYTHON" tools/perf/water_cells.py
"$PYTHON" - "$stamp.cells" "${grounds[@]}" <<'PY'
import json, sys
new = json.load(open("data/park/water_cells.json"))
old = json.load(open(sys.argv[1]))
for path in sys.argv[2:]:
	key = "res://" + path
	old["grounds"][key] = new["grounds"].get(key, [])
old["grounds"] = dict(sorted(old["grounds"].items()))
open("data/park/water_cells.json", "w").write(json.dumps(old, separators=(",", ":")) + "\n")
PY

"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
echo "== Done rebuilding the rim country"
