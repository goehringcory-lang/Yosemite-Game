#!/usr/bin/env bash
# Rebuilds Yosemite Village and Camp 4 onto the 32px grid in one go: runs the
# 16px hub builder (build_hubs.tscn), upgrades every PNG it drew to the 32px
# palette art (tools/art32/upgrade.py --fresh), moves the scenes it wrote onto
# the 32px grid (tools/art32/migrate_built.py), and re-imports. The builder
# also rewrites the shop and food data, which can carry hand edits, so those
# are put back as they were.
#
#   tools/hubs/rebuild_village.sh
#   GODOT=/path/to/godot tools/hubs/rebuild_village.sh
set -eu
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
stamp="$(mktemp)"
trap 'rm -f "$stamp"' EXIT
sleep 1
"$GODOT" --headless --path . res://tools/hubs/build_hubs.tscn
mapfile -t fresh < <(find assets -name '*.png' -newer "$stamp")
python3 tools/art32/upgrade.py --fresh "${fresh[@]}"
python3 tools/art32/migrate_built.py scenes/regions/yosemite_village.tscn scenes/objects/shuttle_stop.tscn --fresh "${fresh[@]}"
git checkout -- data/
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
