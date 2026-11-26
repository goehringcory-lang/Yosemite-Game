#!/usr/bin/env bash
# Builds corridor areas (tools/hubs/build_corridor.gd) from their specs in
# tools/hubs/corridors/<id>.json, onto the 32px grid: runs the 16px builder,
# upgrades its generated ground PNG, migrates the scene to 32px, restores
# shared art untouched, paints native 32px ground, dresses wild ground
# clutter, makes normal maps and water cells, and re-imports. Then run
# tests/stream_test.tscn to check both ends meet their neighbors.
#
#   GODOT=~/godot/godot tools/hubs/rebuild_corridors.sh pohono_trail_east [more ids]
set -eu
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
PYTHON="${PYTHON:-python3}"
if [ $# -eq 0 ]; then
	echo "usage: $0 <corridor id>..." >&2
	exit 1
fi
ids=("$@")
stamp="$(mktemp)"
tmp="$(mktemp -d)"
trap 'rm -f "$stamp" "$stamp.cells"; rm -rf "$tmp"' EXIT
sleep 1

"$GODOT" --headless --path . res://tools/hubs/build_corridor.tscn -- "${ids[@]}"

mine=()
scenes=()
for id in "${ids[@]}"; do
	mine+=("assets/sprites/ahwahnee/ground_${id}.png")
	scenes+=("scenes/regions/${id}.tscn")
done
mapfile -t fresh < <(find assets -name '*.png' -newer "$stamp")
"$PYTHON" tools/art32/upgrade.py --fresh "${mine[@]}"
for scene in "${scenes[@]}"; do
	"$PYTHON" tools/art32/migrate_built.py "$scene" --fresh "${mine[@]}"
done

# Restore any shared art redrawn by load_flora().
for f in "${fresh[@]}"; do
	case " ${mine[*]} " in *" $f "*) ;; *) git checkout -q -- "$f" "$f.import" 2>/dev/null || git checkout -q -- "$f" 2>/dev/null || true ;; esac
done

"$GODOT" --headless --path . --import > /dev/null 2>&1 || true

"$GODOT" --headless --path . res://tools/art32/ground32/dump.tscn -- "$tmp/dump" "${ids[@]}"
"$PYTHON" tools/art32/ground32/paint.py "$tmp/dump" "${ids[@]}"
"$GODOT" --headless --path . res://tools/hubs/dress_wilds.tscn -- "${ids[@]}"
"$PYTHON" tools/normals/normals.py "${mine[@]}"

# water_cells.json: only these grounds change.
cp data/park/water_cells.json "$stamp.cells"
"$PYTHON" tools/perf/water_cells.py
"$PYTHON" - "$stamp.cells" "${mine[@]}" <<'PY'
import json, sys
keys = ["res://" + p for p in sys.argv[2:]]
new = json.load(open("data/park/water_cells.json"))
old = json.load(open(sys.argv[1]))
for key in keys:
	if key in new["grounds"]:
		old["grounds"][key] = new["grounds"][key]
old["grounds"] = dict(sorted(old["grounds"].items()))
open("data/park/water_cells.json", "w").write(json.dumps(old, separators=(",", ":")) + "\n")
PY

"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
echo "== Done building corridors: ${ids[*]}"
