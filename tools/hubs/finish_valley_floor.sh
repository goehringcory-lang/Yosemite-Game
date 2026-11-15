#!/usr/bin/env bash
# Finishes Valley floor areas after their builders have run
# (rebuild_valley_floor.sh, rebuild_village.sh). The builders paint a 16px
# ground and lay each area's river out on its own, so a rebuilt area is left
# with blotchy grass, brown roads with no lines, pale water, and a river that
# misses the next area's at the seam. This puts the finish back:
#
#   1. bends the rivers, creeks and roads at the areas' edges to meet across
#      the seams again (tools/seams/morph_seams.py), until nothing more bends;
#   2. paints the named areas' ground natively at 32px
#      (tools/art32/ground32/dump.tscn and paint.py);
#   3. paints their fishing holes back into the new river
#      (tools/fishing/river_pools.py --repaint);
#   4. refreshes the grounds' normal maps (tools/normals/normals.py), the
#      water cells (tools/perf/water_cells.py) and the seams' nudges
#      (tools/seams/measure_seams.tscn), and re-imports.
#
#   tools/hubs/finish_valley_floor.sh yosemite_village leidig_meadow ...
#   GODOT=/path/to/godot PYTHON=/path/to/python3 tools/hubs/finish_valley_floor.sh AREA...
#
# Name every area the builders rebuilt. Running it again changes nothing.
# Afterwards, if a road or a trail moved, measure the travelers' walks again
# (tools/travelers/measure_walks.tscn). tests/ground_art_test.tscn fails
# while any area still has a builder's ground. The Python steps need Pillow
# and numpy.
set -eu
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
PYTHON="${PYTHON:-python3}"
if [ $# -eq 0 ]; then
	echo "usage: tools/hubs/finish_valley_floor.sh AREA..." >&2
	exit 1
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "== Seams"
for pass in 1 2 3 4; do
	"$GODOT" --headless --path . res://tools/seams/export_seams.tscn -- "$tmp/seams.json" > /dev/null 2>&1
	if ! "$PYTHON" tools/seams/morph_seams.py "$tmp/seams.json" --plan | grep -q " tiles"; then
		break
	fi
	GODOT="$GODOT" "$PYTHON" tools/seams/morph_seams.py "$tmp/seams.json" | grep -v "nothing to bend" || true
done

echo "== Ground"
"$GODOT" --headless --path . res://tools/art32/ground32/dump.tscn -- "$tmp/dump" "$@" 2> /dev/null | grep dumped
"$PYTHON" tools/art32/ground32/paint.py "$tmp/dump" "$@" | grep wrote
"$PYTHON" tools/fishing/river_pools.py --repaint "$@"

echo "== Normal maps, water cells and seam nudges"
mapfile -t grounds < <("$PYTHON" -c 'import glob, json, sys
for f in sorted(glob.glob(sys.argv[1] + "/*.json")):
    print(json.load(open(f))["ground"].replace("res://", ""))' "$tmp/dump")
"$PYTHON" tools/normals/normals.py "${grounds[@]}"
"$PYTHON" tools/perf/water_cells.py
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
"$GODOT" --headless --path . res://tools/seams/measure_seams.tscn > /dev/null 2>&1
git status --short -- assets/sprites/ahwahnee assets/normals/ahwahnee data/park scenes/regions | sed 's/^/  /'
