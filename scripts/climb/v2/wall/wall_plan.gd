class_name WallPlan
extends RefCounted
## The authored plan of every pitch of a route: what the rock is and where its
## features are, in metres. WallBuilder turns a pitch plan into a V2Wall.
##
## Plans live in data/climb/v2/routes/<route id>.json (see wall/README.md for
## every key). A route with no file gets an automatic plan made from its old
## ClimbProfiles spec, so a new route always has a wall; tools/climb_v2/
## convert_routes.tscn writes those automatic plans out as a starting draft.

const DIR := "res://data/climb/v2/routes/"
## Pitch height range for automatic plans, metres. The game climbs real
## pitches shorter than they are, as the old screen did with its rows.
const AUTO_MIN_H := 10.0
const AUTO_MAX_H := 20.0
const AUTO_WIDTH := 8.0

static var _cache := {}


## The plan for [param route]: {"route", "rock", "pitches": [pitch plan...]}.
static func for_route(route: RouteData) -> Dictionary:
	if route == null:
		return {}
	if _cache.has(route.id):
		return _cache[route.id]
	var plan := V2Data.load_json(DIR + route.id + ".json")
	if plan.is_empty():
		plan = auto(route)
		plan["auto"] = true
	_cache[route.id] = plan
	return plan


static func has_file(route_id: String) -> bool:
	return FileAccess.file_exists(DIR + route_id + ".json")


static func clear_cache() -> void:
	_cache.clear()


## Pitch [param index]'s plan (the last pitch's if past the end), with the
## route-level keys (rock) filled in.
static func pitch(route: RouteData, index: int) -> Dictionary:
	var plan := for_route(route)
	var list: Array = plan.get("pitches", [])
	if list.is_empty():
		return {}
	var p: Dictionary = (list[clampi(index, 0, list.size() - 1)] as Dictionary).duplicate(true)
	if not p.has("rock"):
		p["rock"] = plan.get("rock", "")
	if route.top_rope:
		p["top_rope"] = true
	if route.boulder:
		p["boulder"] = true
	return p


## An automatic plan from the route's old ClimbProfiles spec.
static func auto(route: RouteData) -> Dictionary:
	var profile := ClimbProfiles.get_profile(route.id)
	var n := maxi(1, route.pitches.size())
	var out := {"route": route.id, "rock": profile.get("rock", ""), "pitches": []}
	for i in n:
		out.pitches.append(auto_pitch(route, i))
	return out


static func auto_pitch(route: RouteData, index: int) -> Dictionary:
	var spec := ClimbProfiles.pitch_spec(route, index)
	var n := maxi(1, route.pitches.size())
	var style: String = spec.style
	var rows := maxi(2, int(spec.rows))
	var height := clampf(float(route.total_height_ft()) * 0.3048 / n, AUTO_MIN_H, AUTO_MAX_H)
	if route.boulder:
		height = clampf(float(route.total_height_ft()) * 0.3048 * 0.8, 3.0, 8.0)
	height = snappedf(height, 0.5)
	var width := AUTO_WIDTH
	var traverse := String(spec.name).to_lower().contains("traverse") or style == "roof"
	if traverse:
		width = 12.0
	var p := {
		"name": spec.name, "style": style, "diff": int(spec.diff), "height": height, "width": width,
		"beta": spec.get("beta", ""), "belay": "ledge",
	}
	var row_y := func(r: float) -> float: return snappedf(clampf(r / rows * height, 1.0, height - 1.0), 0.1)
	# The line: straight up the middle, or across for a traverse or a roof.
	if traverse:
		p["line"] = [[2.5, 0.0], [2.5, height * 0.4], [width - 2.5, height * 0.65], [width - 2.5, height]]
	else:
		p["line"] = [[width * 0.5, 0.0], [width * 0.5 - 0.6, height * 0.5], [width * 0.5, height]]
	if style == "roof":
		p["sections"] = [{"from": height * 0.4, "to": height * 0.7, "style": "roof", "angle": 90.0}]
		p["style"] = "crack"
	# Cracks: one main crack beside the line for crack-type pitches, short
	# seams on slab and knobs.
	var widths := _width_range(spec)
	var crack_chance := float(spec.get("cracks", 0.0))
	if style in ["crack", "flake", "chimney", "roof"] or crack_chance >= 0.4:
		var kind := _crack_kind(widths)
		if style == "flake":
			p["flakes"] = [{"id": "flake0", "side": "right", "points": _along(p.line, 0.35, 1.0, height - 1.0), "widths": _widths(widths, 5, index)}]
		else:
			var c := {"id": "crack0", "kind": "chimney" if style == "chimney" else kind,
				"points": _along(p.line, 0.35 if style != "chimney" else 0.0, 0.8, height - 0.8),
				"widths": _widths(widths if style != "chimney" else [6, 7], 5, index)}
			c["constrictions"] = _constrictions(c.widths)
			p["cracks"] = [c]
	elif crack_chance > 0.0:
		var seams := []
		var y := 2.0
		var k := 0
		while y < height - 2.0:
			seams.append({"id": "seam%d" % k, "kind": _crack_kind(widths), "points": _along(p.line, 0.6 if k % 2 == 0 else -0.6, y, minf(y + 1.6, height - 1.0)), "widths": _widths(widths, 2, index + k)})
			y += 3.5
			k += 1
		p["cracks"] = seams
	if style == "knobs":
		p["horns"] = [height * 0.3, height * 0.55, height * 0.8]
	# Fixed protection.
	if str(spec.get("bolts", "")) == "line":
		var gap := clampf(float(spec.get("bolt_gap", 2)) * height / rows, 2.0, 7.0)
		var bolts := []
		var b := minf(2.5, gap)
		while b < height - 1.0:
			bolts.append(snappedf(b, 0.1))
			b += gap
		p["bolts"] = bolts
		p["runout"] = snappedf(gap + 1.0, 0.5)
	var pins := []
	for r: int in spec.get("pins", []):
		pins.append({"y": row_y.call(r), "kind": str(spec.get("pin_kind", "pin")), "tags": ["rusty"]})
	if not pins.is_empty():
		p["pins"] = pins
	var rests := []
	for r: int in spec.get("rest", []):
		rests.append({"y": row_y.call(r), "kind": "stance"})
	if not rests.is_empty():
		p["rests"] = rests
	var fixed: Array = spec.get("fixed", [])
	if not fixed.is_empty():
		p["fixed_rope"] = [row_y.call(fixed.min() - 1), row_y.call(fixed.max())]
	if spec.get("hard_aid", false):
		p["aid"] = true
	if spec.has("bivy"):
		p["bivy"] = spec.bivy
		p["belay"] = "ledge" if spec.bivy == "ledge" else "hanging"
	# Cruxes, from the old crux rows.
	var cruxes := []
	for r: int in spec.cruxes:
		var c := ClimbProfiles.crux_at(spec, r)
		var y0: float = row_y.call(r - 0.6)
		var crux := {"id": "crux%d" % cruxes.size(), "name": c.get("name", "The crux"), "from": y0, "to": minf(y0 + 2.2, height - 0.6)}
		match str(c.get("kind", "timing")):
			"swing":
				crux["special"] = "swing"
			"layback":
				crux["hip"] = "layback"
			"mash":
				crux["hip"] = "mantel"
			"dyno":
				crux["hip"] = "lunge"
			"rhythm":
				crux["hip"] = "chimney"
		crux["sequence"] = ["rh", "lh", "lh", "rh"] if cruxes.size() % 2 == 0 else ["lh", "rh", "rh", "lh"]
		cruxes.append(crux)
	if not cruxes.is_empty():
		p["cruxes"] = cruxes
	return p


static func _width_range(spec: Dictionary) -> Array:
	var name := String(spec.get("name", "")).to_lower()
	for pair: Array in ClimbRack.NAME_WIDTHS:
		if name.contains(pair[0]):
			return pair[1]
	return ClimbRack.STYLE_WIDTHS.get(spec.get("style", "crack"), [2, 6])


static func _crack_kind(widths: Array) -> String:
	var mid := (float(widths[0]) + float(widths[1])) * 0.5
	if mid < 1.0:
		return "seam"
	if mid < 3.0:
		return "finger"
	if mid < 5.5:
		return "hand"
	if mid < 6.5:
		return "fist"
	return "offwidth"


## [param count] widths in [lo, hi], wavering, from [param salt].
static func _widths(range_: Array, count: int, salt: int) -> Array:
	var lo := float(range_[0])
	var hi := float(range_[1])
	var out := []
	for i in count:
		var f := 0.5 + 0.5 * sin(float(i) * 1.7 + float(salt) * 2.3)
		out.append(snappedf(lerpf(lo, hi, f), 0.25))
	return out


## Points where the crack is narrower just below: where a nut seats.
static func _constrictions(widths: Array) -> Array:
	var out := []
	for i in range(1, widths.size()):
		if float(widths[i - 1]) < float(widths[i]) - 0.2:
			out.append(i)
	return out


## Five points beside [param line] (offset [param dx] metres), from y0 to y1.
static func _along(line: Array, dx: float, y0: float, y1: float) -> Array:
	var out := []
	for i in 5:
		var y := lerpf(y0, y1, i / 4.0)
		out.append([snappedf(line_x(line, y) + dx, 0.05), snappedf(y, 0.05)])
	return out


## The line's x at height [param y] (the first segment that spans it).
static func line_x(line: Array, y: float) -> float:
	if line.is_empty():
		return 4.0
	for i in line.size() - 1:
		var a := V2Data.vec(line[i])
		var b := V2Data.vec(line[i + 1])
		if y >= minf(a.y, b.y) and y <= maxf(a.y, b.y) and absf(b.y - a.y) > 0.001:
			return lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
	return V2Data.vec(line[line.size() - 1 if y > 0.0 else 0]).x
