#!/usr/bin/env bash
# Paints every area's ground into a scratch folder and lays the sprites over
# a screen-sized crop round each named spot, for looking at it side by side
# with the ground in the game:
#   tools/art32/ground32/shots.sh DUMP_DIR OUT_DIR region:marker ...
# BEFORE=1 also lays them over the ground the game has now.
set -eu
here="$(dirname "$0")"
dump="$1"; out="$2"; shift 2
ids=()
for spec in "$@"; do ids+=("${spec%%:*}"); done
python3 "$here/paint.py" --out "$out/ground" "$dump" "${ids[@]}" > /dev/null
for spec in "$@"; do
  id="${spec%%:*}"; mk="${spec#*:}"
  ground="$(python3 -c "import json,os;print(os.path.basename(json.load(open('$dump/$id.json'))['ground'].replace('res://','')))")"
  rect="$(python3 -c "
import json;d=json.load(open('$dump/$id.json'));W,H=d['w']*d['tile'],d['h']*d['tile']
x,y=d['markers'].get('$mk',[W/2,H/2]);x=int(min(max(x-480,0),W-960));y=int(min(max(y-270,0),H-540));print(f'{x},{y},960,540')")"
  python3 "$here/preview.py" "$dump/$id.json" "$out/ground/$ground" "$out/${id}_${mk}.png" "$rect" 2
  if [ -n "${BEFORE:-}" ]; then
    old="$(python3 -c "import json;print(json.load(open('$dump/$id.json'))['ground'].replace('res://',''))")"
    python3 "$here/preview.py" "$dump/$id.json" "$old" "$out/${id}_${mk}_before.png" "$rect" 2
  fi
done
