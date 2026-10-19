#!/usr/bin/env bash
# Rebuilds El Portal onto the 32px grid in one go: runs the 16px hub
# builder (build_el_portal.tscn), upgrades every PNG it drew to the 32px
# palette art (tools/art32/upgrade.py --fresh), moves the scene it wrote onto
# the 32px grid (tools/art32/migrate_built.py), and re-imports.
#
#   tools/hubs/rebuild_el_portal.sh
#   GODOT=/path/to/godot PYTHON=/path/to/python3 tools/hubs/rebuild_el_portal.sh
#
# The Python steps need Pillow and numpy.
set -eu
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
PYTHON="${PYTHON:-python3}"
stamp="$(mktemp)"
trap 'rm -f "$stamp"' EXIT
sleep 1
"$GODOT" --headless --path . res://tools/hubs/build_el_portal.tscn
mapfile -t fresh < <(find assets -name '*.png' -newer "$stamp")
"$PYTHON" tools/art32/upgrade.py --fresh "${fresh[@]}"
"$PYTHON" tools/art32/migrate_built.py scenes/regions/el_portal.tscn --fresh "${fresh[@]}"
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
