class_name ClimbRack
extends RefCounted
## The rack you climb with, as the climbing screen sees it: every cam and nut
## you carry, and what width of crack each one fits. And the cracks: each crack
## hold on a pitch has a width, and a piece fits it or it doesn't.
##
## Widths run 0 to 7 on the Camalot scale (see [constant WIDTHS]): 0 is a
## #0.3's thin fingers, 4 a #1's hands, 7 a #4's offwidth. A cam fits one
## width; a nut fits a couple of thin ones. A piece one width off goes in
## badly (tipped out, or over-cammed); two off doesn't go in at all.
##
## The gear itself (which sizes you own and carry) belongs to Gear. While
## Gear only counts "cam" as one number, the rack is filled in CamSizes order
## (#0.75, #1, #2, #3, then doubles).

## Each width: what climbers call a crack that size, the Camalot that fits it,
## and that size's sling color.
const WIDTHS := [
	{"name": "thin fingers", "size": "#0.3", "color": Color("2f6cc0")},
	{"name": "fingers", "size": "#0.4", "color": Color("8a8a90")},
	{"name": "tight hands", "size": "#0.5", "color": Color("7a4aa8")},
	{"name": "thin hands", "size": "#0.75", "color": Color("4f9a3a")},
	{"name": "hands", "size": "#1", "color": Color("c8382e")},
	{"name": "wide hands", "size": "#2", "color": Color("dcaa2c")},
	{"name": "fists", "size": "#3", "color": Color("2f6cc0")},
	{"name": "offwidth", "size": "#4", "color": Color("8a8a90")},
]
const MAX_WIDTH := 7
## CamSizes' four sizes, as widths: #0.75, #1, #2, #3.
const CAM_SIZE_WIDTHS := [3, 4, 5, 6]
## The piece you can always make when nothing on your rack fits: a sling
## round a horn or a chockstone. It holds a short fall at best.
const SLING := {"id": "sling", "kind": "sling", "width_min": 0, "width_max": MAX_WIDTH,
	"color": Color("6a8f3a"), "count": 99, "name": "Slung horn"}
## Crack widths on a pitch, by style, when its spec doesn't say ("widths").
const STYLE_WIDTHS := {
	"crack": [2, 6], "flake": [3, 6], "chimney": [5, 7], "roof": [3, 6],
	"slab": [0, 4], "dike": [0, 3], "knobs": [0, 3],
}
## Words in a pitch's name that say how wide its cracks are.
const NAME_WIDTHS := [
	["fingertip", [0, 2]], ["finger", [0, 3]], ["thin", [0, 3]], ["seam", [0, 2]],
	["stoveleg", [3, 5]], ["grack", [3, 5]], ["enduro", [3, 5]], ["hand", [3, 5]], ["wide", [5, 7]], ["fist", [5, 7]], ["offwidth", [6, 7]],
	["slot", [6, 7]], ["chimney", [5, 7]], ["squeeze", [6, 7]],
]


## What a crack [param width] wide is called: "hands".
static func width_name(width: int) -> String:
	return WIDTHS[clampi(width, 0, MAX_WIDTH)].name


static func width_color(width: int) -> Color:
	return WIDTHS[clampi(width, 0, MAX_WIDTH)].color


## The Camalot that fits [param width]: "#1".
static func width_size(width: int) -> String:
	return WIDTHS[clampi(width, 0, MAX_WIDTH)].size


## The rack Gear says you're carrying: pieces {id, kind, width_min, width_max,
## color, count, name}, smallest first. Gear.rack_carried() gives it once
## the gear knows its sizes; until then, CamSizes fills it from the cam count.
static func from_gear() -> Array[Dictionary]:
	if Gear.has_method("rack_carried"):
		var out: Array[Dictionary] = []
		for piece: Dictionary in Gear.call("rack_carried"):
			if piece.get("kind", "") in ["cam", "nut"] and int(piece.get("count", 0)) > 0 and int(piece.get("width_min", -1)) >= 0:
				out.append(_clean(piece))
		return out
	return from_count(Gear.carried("cam"))


## A rack of [param cams] cams, sized the way CamSizes fills it.
static func from_count(cams: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var counts := CamSizes.counts(cams)
	for i in counts.size():
		if counts[i] <= 0:
			continue
		var w: int = CAM_SIZE_WIDTHS[i]
		out.append({"id": "cam", "kind": "cam", "width_min": w, "width_max": w,
			"color": CamSizes.SIZES[i].color, "count": counts[i], "name": "Cam " + CamSizes.SIZES[i].size,
			"size_index": i})
	return out


static func _clean(piece: Dictionary) -> Dictionary:
	var out := piece.duplicate()
	out["count"] = int(piece.get("count", 0))
	out["width_min"] = int(piece.get("width_min", 0))
	out["width_max"] = int(piece.get("width_max", out.width_min))
	if not out.has("color") or not out.color is Color:
		out["color"] = width_color(out.width_min)
	if not out.has("name"):
		out["name"] = str(out.get("id", "Cam"))
	return out


## A key for [param piece] that tells sizes apart even when Gear calls every
## cam "cam": its id and the widths it fits.
static func key(piece: Dictionary) -> String:
	return "%s:%d-%d" % [piece.get("id", ""), int(piece.get("width_min", 0)), int(piece.get("width_max", 0))]


## How many widths [param piece] is off [param width]: 0 if it fits.
static func misfit(piece: Dictionary, width: int) -> int:
	if piece.get("kind", "") == "sling":
		return 0
	var lo := int(piece.get("width_min", 0))
	var hi := int(piece.get("width_max", lo))
	if width < lo:
		return lo - width
	return maxi(width - hi, 0)


## +1 if [param piece] is too big for [param width] (it would over-cam), -1
## if too small (it would tip out), 0 if it fits.
static func misfit_side(piece: Dictionary, width: int) -> int:
	if piece.get("kind", "") == "sling":
		return 0
	if width < int(piece.get("width_min", 0)):
		return 1
	return -1 if width > int(piece.get("width_max", 0)) else 0


## The widths a pitch's cracks come in, [lo, hi]: the spec's "widths", or
## what its name says ("Finger Crack", "Harding Slot"), or its style.
static func pitch_widths(spec: Dictionary) -> Array:
	if spec.has("widths"):
		return spec.widths
	var name := String(spec.get("name", "")).to_lower()
	for pair: Array in NAME_WIDTHS:
		if name.contains(pair[0]):
			return pair[1]
	return STYLE_WIDTHS.get(spec.get("style", "crack"), [2, 6])


## "hands to fists", for the route card and the pitch banner.
static func range_text(widths: Array) -> String:
	var lo := width_name(int(widths[0]))
	var hi := width_name(int(widths[1]))
	return lo if lo == hi else "%s to %s" % [lo, hi]
