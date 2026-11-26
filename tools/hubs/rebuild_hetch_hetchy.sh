#!/usr/bin/env bash
# Rebuilds Hetch Hetchy alone onto the 32px grid (the same steps as
# rebuild_exploration_regions.sh, for one region): paints the gorge under the
# dam, runs the 16px builder, upgrades its own PNGs, migrates the scene to
# 32px, restores shared art load_flora() redrew, paints native 32px ground,
# dresses wild clutter, and makes normal maps and water cells.
#
#   GODOT=~/godot/godot PYTHON=/usr/bin/python3 tools/hubs/rebuild_hetch_hetchy.sh
set -eu
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
PYTHON="${PYTHON:-python3}"
stamp="$(mktemp)"
tmp="$(mktemp -d)"
trap 'rm -f "$stamp" "$stamp.cells"; rm -rf "$tmp"' EXIT
sleep 1

"$PYTHON" tools/hubs/hetch_hetchy_gorge.py
"$PYTHON" tools/hubs/hetch_hetchy_entrance.py
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
"$GODOT" --headless --path . res://tools/hubs/build_hetch_hetchy.tscn

mine=(
	assets/sprites/ahwahnee/ground_hetch_hetchy.png
	assets/sprites/valley/hetch_hetchy_wall.png
	assets/sprites/valley/hetch_hetchy_below.png
	assets/sprites/valley/hetch_hetchy_fall_*.png
	assets/sprites/valley/hetch_hetchy_mist_*.png
)
mapfile -t fresh < <(find assets -name '*.png' -newer "$stamp")
"$PYTHON" tools/art32/upgrade.py --fresh "${mine[@]}"
"$PYTHON" tools/art32/migrate_built.py scenes/regions/hetch_hetchy.tscn --fresh "${mine[@]}"

# Restore any shared art redrawn by load_flora().
for f in "${fresh[@]}"; do
	case " ${mine[*]} assets/sprites/valley/hetch_hetchy_gorge.png assets/sprites/valley/hetch_hetchy_entrance.png assets/sprites/valley/hetch_hetchy_entrance_glow.png assets/sprites/valley/hetch_hetchy_tunnel_roof.png assets/sprites/valley/hetch_hetchy_tunnel_floor.png " in *" $f "*) ;; *) git checkout -q -- "$f" "$f.import" 2>/dev/null || git checkout -q -- "$f" 2>/dev/null || true ;; esac
done

"$GODOT" --headless --path . --import > /dev/null 2>&1 || true

"$GODOT" --headless --path . res://tools/art32/ground32/dump.tscn -- "$tmp/dump" hetch_hetchy
"$PYTHON" tools/art32/ground32/paint.py "$tmp/dump" hetch_hetchy
"$GODOT" --headless --path . res://tools/hubs/dress_wilds.tscn -- hetch_hetchy
"$PYTHON" tools/hubs/hetch_hetchy_tunnel.py
"$PYTHON" tools/normals/normals.py "${mine[@]}" assets/sprites/valley/hetch_hetchy_entrance.png assets/sprites/valley/hetch_hetchy_tunnel_roof.png assets/sprites/valley/hetch_hetchy_tunnel_floor.png

cp data/park/water_cells.json "$stamp.cells"
"$PYTHON" tools/perf/water_cells.py
"$PYTHON" - "$stamp.cells" <<'PY'
import json, sys
key = "res://assets/sprites/ahwahnee/ground_hetch_hetchy.png"
new = json.load(open("data/park/water_cells.json"))
old = json.load(open(sys.argv[1]))
if key in new["grounds"]:
	old["grounds"][key] = new["grounds"][key]
old["grounds"] = dict(sorted(old["grounds"].items()))
open("data/park/water_cells.json", "w").write(json.dumps(old, separators=(",", ":")) + "\n")
PY

"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
echo "== Done rebuilding Hetch Hetchy"
