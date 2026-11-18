#!/usr/bin/env bash
# Rebuilds Tenaya Lake and Olmsted Point onto the 32px grid in one go: runs
# the 16px builder (build_tenaya_lake.tscn), upgrades the PNGs it drew for
# this area to the 32px palette art (tools/art32/upgrade.py --fresh), moves the
# scene onto the 32px grid (tools/art32/migrate_built.py), puts back the
# shared flora it redrew on the way (load_flora draws every tree; the game's
# trees were repainted since by tools/art32/trees32), paints the lake bed and
# its normal map, notes where its water is (tools/perf/water_cells.py), and
# re-imports.
#
#   tools/hubs/rebuild_tenaya_lake.sh
#   GODOT=/path/to/godot PYTHON=/path/to/python3 tools/hubs/rebuild_tenaya_lake.sh
#
# The Python steps need Pillow and numpy.
set -eu
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
PYTHON="${PYTHON:-python3}"
stamp="$(mktemp)"
trap 'rm -f "$stamp"' EXIT
sleep 1
"$GODOT" --headless --path . res://tools/hubs/build_tenaya_lake.tscn
mine=(assets/sprites/ahwahnee/ground_tenaya_lake.png assets/sprites/valley/tenaya_lake_wall.png)
mapfile -t fresh < <(find assets -name '*.png' -newer "$stamp")
"$PYTHON" tools/art32/upgrade.py --fresh "${mine[@]}"
"$PYTHON" tools/art32/migrate_built.py scenes/regions/tenaya_lake.tscn --fresh "${mine[@]}"
# Everything else it drew is shared art that is already on the 32px grid.
for f in "${fresh[@]}"; do
	case " ${mine[*]} " in *" $f "*) ;; *) git checkout -q -- "$f" "$f.import" 2>/dev/null || git checkout -q -- "$f" 2>/dev/null || true ;; esac
done
"$PYTHON" tools/art32/ground32/tenaya_water.py
"$PYTHON" tools/normals/normals.py "${mine[@]}"
# Note where its water is, and leave every other ground's entry as it was.
cp data/park/water_cells.json "$stamp.cells"
"$PYTHON" tools/perf/water_cells.py
"$PYTHON" - "$stamp.cells" <<'PY'
import json, sys
key = "res://assets/sprites/ahwahnee/ground_tenaya_lake.png"
new = json.load(open("data/park/water_cells.json"))
old = json.load(open(sys.argv[1]))
old["grounds"][key] = new["grounds"][key]
old["grounds"] = dict(sorted(old["grounds"].items()))
open("data/park/water_cells.json", "w").write(json.dumps(old, separators=(",", ":")) + "\n")
PY
rm -f "$stamp.cells"
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
git status --short
