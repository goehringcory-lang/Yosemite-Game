class_name V2Wall
extends RefCounted
## One pitch of rock, as every v2 system sees it (the WallModel). Built by the
## wall source (thread 2) when a pitch starts and read-only after that, except
## that fixed pieces' clip state lives on their V2Piece (rope writes it).
##
## Coordinates: metres, x right, y up, (0, 0) at the lower belay. The pitch
## runs from [member start] to the top anchor at [member top].

var route_id := ""
var pitch := 0
## Width and height of the climbable face, metres. x runs 0..size.x.
var size := Vector2(6, 25)
## slab | crack | flake | chimney | roof | dike | knobs | face | snow | ice
var style: StringName = &"face"
## The rock look for art (ClimbRock names: "golden", "elcap", ...).
var rock := ""
## Overall steepness, degrees past vertical (negative = slab, 90 = roof).
var angle := 0.0
var holds: Array[V2Hold] = []
var cracks: Array[V2Crack] = []
## Bolts, old pins and the anchors, with fixed = true.
var fixed: Array[V2Piece] = []
var zones: Array[V2Zone] = []
## Where the climber stands at the lower belay, and the top anchor's spot.
var start := Vector2(3, 0)
var top := Vector2(3, 24)
## Free-form pitch facts: name, beta line, grade, "ledge"/"hanging" belay.
var info := {}

var _by_id := {}


## The hold with [param hold_id], or null.
func hold(hold_id: String) -> V2Hold:
	if _by_id.size() != holds.size():
		_index()
	return _by_id.get(hold_id)


func crack(crack_id: String) -> V2Crack:
	for c in cracks:
		if c.id == crack_id:
			return c
	return null


func fixed_piece(piece_id: String) -> V2Piece:
	for p in fixed:
		if p.id == piece_id:
			return p
	return null


## Holds within [param radius] metres of [param pos], nearest first.
## [param for_hands] / [param for_feet] filter by use.
func holds_within(pos: Vector2, radius: float, for_hands := true, for_feet := false) -> Array[V2Hold]:
	var out: Array[V2Hold] = []
	for h in holds:
		if (for_hands and not h.hand) or (for_feet and not h.foot):
			continue
		if h.pos.distance_to(pos) <= radius:
			out.append(h)
	out.sort_custom(func(a: V2Hold, b: V2Hold) -> bool: return a.pos.distance_to(pos) < b.pos.distance_to(pos))
	return out


## Cracks passing within [param radius] of [param pos], nearest first.
func cracks_within(pos: Vector2, radius: float) -> Array[V2Crack]:
	var out: Array[V2Crack] = []
	for c in cracks:
		if float(c.nearest(pos).distance) <= radius:
			out.append(c)
	out.sort_custom(func(a: V2Crack, b: V2Crack) -> bool: return float(a.nearest(pos).distance) < float(b.nearest(pos).distance))
	return out


func fixed_within(pos: Vector2, radius: float) -> Array[V2Piece]:
	var out: Array[V2Piece] = []
	for p in fixed:
		if p.pos.distance_to(pos) <= radius:
			out.append(p)
	return out


## Zones of [param kind] (any kind when empty) that contain [param pos].
func zones_at(pos: Vector2, kind: StringName = &"") -> Array[V2Zone]:
	var out: Array[V2Zone] = []
	for z in zones:
		if (kind == &"" or z.kind == kind) and z.has_point(pos):
			out.append(z)
	return out


## The top anchor (a fixed piece of kind "anchor" near [member top]), or null.
func anchor() -> V2Piece:
	var best: V2Piece = null
	for p in fixed:
		if p.kind == &"anchor" and (best == null or p.pos.y > best.pos.y):
			best = p
	return best


func _index() -> void:
	_by_id.clear()
	for h in holds:
		_by_id[h.id] = h


func to_dict() -> Dictionary:
	return {
		"route_id": route_id, "pitch": pitch, "size": V2Data.arr(size), "style": String(style),
		"rock": rock, "angle": angle, "start": V2Data.arr(start), "top": V2Data.arr(top),
		"holds": holds.map(func(h: V2Hold) -> Dictionary: return h.to_dict()),
		"cracks": cracks.map(func(c: V2Crack) -> Dictionary: return c.to_dict()),
		"fixed": fixed.map(func(p: V2Piece) -> Dictionary: return p.to_dict()),
		"zones": zones.map(func(z: V2Zone) -> Dictionary: return z.to_dict()),
		"info": info.duplicate(true),
	}


static func from_dict(d: Dictionary) -> V2Wall:
	var w := V2Wall.new()
	w.route_id = str(d.get("route_id", ""))
	w.pitch = int(d.get("pitch", 0))
	w.size = V2Data.vec(d.get("size", [6, 25]))
	w.style = StringName(str(d.get("style", "face")))
	w.rock = str(d.get("rock", ""))
	w.angle = float(d.get("angle", 0.0))
	w.start = V2Data.vec(d.get("start", [w.size.x * 0.5, 0]))
	w.top = V2Data.vec(d.get("top", [w.size.x * 0.5, w.size.y - 1.0]))
	for h: Dictionary in d.get("holds", []):
		w.holds.append(V2Hold.from_dict(h))
	for c: Dictionary in d.get("cracks", []):
		w.cracks.append(V2Crack.from_dict(c))
	for p: Dictionary in d.get("fixed", []):
		var piece := V2Piece.from_dict(p)
		piece.fixed = true
		w.fixed.append(piece)
	for z: Dictionary in d.get("zones", []):
		w.zones.append(V2Zone.from_dict(z))
	w.info = (d.get("info", {}) as Dictionary).duplicate(true)
	return w
