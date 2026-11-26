#!/usr/bin/env bash
# Rebuilds Taft Point and Cathedral Lakes onto the 32px grid (Hetch Hetchy
# has its own: tools/hubs/rebuild_hetch_hetchy.sh):
# runs their 16px builders, upgrades their generated PNGs, migrates the scenes
# to 32px, restores shared art untouched, paints native 32px ground with
# tools/art32/ground32/paint.py, dresses wild ground clutter, generates normal
# maps and water cells, and re-imports.
#
#   GODOT=~/godot/godot PYTHON=/usr/bin/python3 tools/hubs/rebuild_exploration_regions.sh
set -eu
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
PYTHON="${PYTHON:-python3}"
stamp="$(mktemp)"
tmp="$(mktemp -d)"
trap 'rm -f "$stamp" "$stamp.cells"; rm -rf "$tmp"' EXIT
sleep 1

"$GODOT" --headless --path . res://tools/hubs/build_taft_point.tscn
"$GODOT" --headless --path . res://tools/hubs/build_cathedral_lakes.tscn

mine=(
	assets/sprites/ahwahnee/ground_taft_point.png
	assets/sprites/valley/taft_point_wall.png
	assets/sprites/ahwahnee/ground_cathedral_lakes.png
	assets/sprites/valley/cathedral_lakes_wall.png
)
mapfile -t fresh < <(find assets -name '*.png' -newer "$stamp")
"$PYTHON" tools/art32/upgrade.py --fresh "${mine[@]}"
for scene in scenes/regions/taft_point.tscn scenes/regions/cathedral_lakes.tscn; do
	"$PYTHON" tools/art32/migrate_built.py "$scene" --fresh "${mine[@]}"
done

# Restore any shared art redrawn by load_flora().
for f in "${fresh[@]}"; do
	case " ${mine[*]} " in *" $f "*) ;; *) git checkout -q -- "$f" "$f.import" 2>/dev/null || git checkout -q -- "$f" 2>/dev/null || true ;; esac
done

"$GODOT" --headless --path . --import > /dev/null 2>&1 || true

# Paint native 32px ground for all three regions.
"$GODOT" --headless --path . res://tools/art32/ground32/dump.tscn -- "$tmp/dump" taft_point cathedral_lakes
"$PYTHON" tools/art32/ground32/paint.py "$tmp/dump" taft_point cathedral_lakes

# Dress wild ground clutter.
"$GODOT" --headless --path . res://tools/hubs/dress_wilds.tscn -- taft_point cathedral_lakes

# Paint normal maps for all generated region art.
"$PYTHON" tools/normals/normals.py "${mine[@]}"

# Update water_cells.json for the three new grounds only.
cp data/park/water_cells.json "$stamp.cells"
"$PYTHON" tools/perf/water_cells.py
"$PYTHON" - "$stamp.cells" <<'PY'
import json, sys
keys = [
	"res://assets/sprites/ahwahnee/ground_taft_point.png",
	"res://assets/sprites/ahwahnee/ground_cathedral_lakes.png",
]
new = json.load(open("data/park/water_cells.json"))
old = json.load(open(sys.argv[1]))
for key in keys:
	if key in new["grounds"]:
		old["grounds"][key] = new["grounds"][key]
old["grounds"] = dict(sorted(old["grounds"].items()))
open("data/park/water_cells.json", "w").write(json.dumps(old, separators=(",", ":")) + "\n")
PY

"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
echo "== Done rebuilding exploration regions"
