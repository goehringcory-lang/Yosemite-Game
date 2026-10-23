#!/usr/bin/env bash
# Rebuilds the insides of the park's buildings onto the 32px grid in one go:
# runs the 16px builder (build_interiors.tscn), upgrades every PNG it drew to
# the 32px palette art (tools/art32/upgrade.py --fresh), moves the room scenes
# it wrote onto the 32px grid (tools/art32/migrate_built.py), paints the
# Ahwahnee's six rooms and their furniture natively at 32px over what the
# builder drew for them (tools/hubs/ahwahnee32/paint.py), does the same for
# every other room, the Camp Curry Store and Mountain Shop, and the furniture
# they share (tools/hubs/interiors32/paint.py), and re-imports.
# The doors outside (scenes/story/doors/) are written in 32px already.
#
#   tools/hubs/rebuild_interiors.sh
#   GODOT=/path/to/godot tools/hubs/rebuild_interiors.sh
#   ONLY_ROOMS=degnans,yosemite_chapel tools/hubs/rebuild_interiors.sh   # just these scenes
set -eu
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
PYTHON="${PYTHON:-python3}"
stamp="$(mktemp)"
trap 'rm -f "$stamp"' EXIT
sleep 1
"$GODOT" --headless --path . res://tools/hubs/build_interiors.tscn
mapfile -t fresh < <(find assets/sprites/interiors -name '*.png' -newer "$stamp")
mapfile -t rooms < <(find scenes/regions -maxdepth 1 -name '*.tscn' -newer "$stamp")
"$PYTHON" tools/art32/upgrade.py --fresh "${fresh[@]}"
"$PYTHON" tools/art32/migrate_built.py "${rooms[@]}" --fresh "${fresh[@]}"
"$PYTHON" tools/hubs/ahwahnee32/paint.py
"$PYTHON" tools/hubs/interiors32/paint.py
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
