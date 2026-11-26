class_name TradGear
extends GearSystem
## Trad gear for climbing v2 (thread 6): cams offered to the crack and read
## by their lobes, nuts slid down until the crack pinches them, offsets for
## flared pin scars, old fixed pins you tug-test, and booty stuck in the
## cracks that you can work free. "Feel it": nothing here ever shows a
## quality number or bar. You see the piece beside the crack before you pay
## anything (eyeball it), the offer shows the lobes or how the nut sits, and
## the fall and the partner at the belay tell you how good it really was.
##
## Rules (with Fable's advice; GEAR.md next to this file has the why):
## - A cam's lobes open with the crack: e = 0 shut tight (over-cammed: holds,
##   but the partner fights to clean it), about 0.2..0.7 is the sweet spot,
##   past 0.85 it's tipped out, past 1 it won't stay. Real Camalot C4 ranges,
##   so neighbouring sizes overlap as they do on the rock.
## - A nut slides down from where you offer it until the crack narrows to its
##   size; it seats well only where the crack really pinches below it.
## - Flare makes cams walk and nuts skate (offsets don't mind); a pin scar
##   is an offset's home; a flake flexes.
## - Each offer costs pump (effort prices "offer"); each further offer from
##   the same stance costs more, so being right first time pays. A stretched
##   offer costs more and you can't see in properly. If one more try would
##   pump you off, the hint says so before you press; nothing is lost if you
##   fall fiddling (offers never take the piece off the harness).

const PLACE_REACH := ClimbV2.ARM_M + 0.4
## Further than this from the placing hand's shoulder and you're at full
## stretch (you can't see in properly).
const STRETCH_M := ClimbV2.ARM_M + 0.2
## Shoulders sit this far either side of the spine.
const SHOULDER_HALF_M := 0.2
## How far up and down a press of Up/Down slides the spot, metres.
const SLIDE_M := 0.1
## Each extra offer from one stance costs this much more (x the first).
const FIDDLE_STEP := 0.6
const STRETCH_COST := 1.4

## Millimetres across for the width scale's whole numbers (0 = #0.3 ...
## 7 = #4): the middle of each Camalot's range, so a cam's own number sits
## right in its sweet spot.
const WIDTH_MM := [18.6, 21.1, 26.5, 32.5, 41.2, 51.0, 69.3, 90.3]
## Black Diamond Camalot C4 ranges (mm), by size on the width scale.
const CAM_MM := [[13.8, 23.4], [15.5, 26.7], [19.6, 33.5], [23.9, 41.2], [30.2, 52.1],
	[37.2, 64.9], [50.7, 87.9], [66.0, 114.7]]
## A nut wedges within this many mm beyond the widths it's rated for.
const NUT_SLOP_MM := 2.0
## How far a nut can slide before it's gone past your reach.
const NUT_SLIDE_M := 0.8
## The crack must narrow this much (mm) in the 15 cm below a nut to hold it.
const PINCH_MM := 0.6

## Sling colours by Gear id, as the partner names them.
const COLOR_NAMES := {"cam_03": "blue", "cam_04": "grey", "cam_05": "purple", "cam_075": "green",
	"cam_1": "red", "cam_2": "gold", "cam_3": "blue", "cam_4": "grey"}

## The place phase, while it's open (the overlay reads it).
var place_phase: PlacePhase


func id() -> StringName:
	return &"gear"


# ------------------------------------------------------------------ widths

## Millimetres across for a width on the Camalot scale.
static func mm(width: float) -> float:
	if width <= 0.0:
		return WIDTH_MM[0] + width * (WIDTH_MM[1] - WIDTH_MM[0])
	if width >= 7.0:
		return WIDTH_MM[7] + (width - 7.0) * (WIDTH_MM[7] - WIDTH_MM[6])
	var i := int(floor(width))
	return lerpf(WIDTH_MM[i], WIDTH_MM[i + 1], width - i)


## A cam's range in mm for its size on the width scale (between sizes too).
static func cam_range(size: float) -> Vector2:
	var s := clampf(size, 0.0, 7.0)
	var i := mini(int(floor(s)), 6)
	var f := s - i
	return Vector2(lerpf(CAM_MM[i][0], CAM_MM[i + 1][0], f), lerpf(CAM_MM[i][1], CAM_MM[i + 1][1], f))


## How far open a cam of [param size] sits in a crack of [param width]:
## 0 shut tight, 1 wide open on its tips (outside 0..1 it won't go / stay).
static func expansion(size: float, width: float) -> float:
	var r := cam_range(size)
	return (mm(width) - r.x) / (r.y - r.x)


## Holding power of a cam from its expansion alone (before flare and the
## rest), 0..1. A broad plateau with soft shoulders.
static func cam_hold(e: float) -> float:
	if e < 0.0 or e > 1.0:
		return 0.0
	if e < 0.1:
		return 0.8
	if e < 0.2:
		return lerpf(0.8, 0.92, (e - 0.1) / 0.1)
	if e <= 0.7:
		return 0.92
	if e <= 0.85:
		return lerpf(0.92, 0.5, (e - 0.7) / 0.15)
	return lerpf(0.5, 0.15, (e - 0.85) / 0.15)


# ------------------------------------------------------------------ queries

func shoulder() -> Vector2:
	return session.pose.hip + Vector2(0, ClimbV2.TORSO_M)


func placeable() -> Array[V2Crack]:
	return session.wall.cracks_within(shoulder(), PLACE_REACH)


## The rack opens at a crack, an old pin or a stuck piece in reach.
func can_rack() -> bool:
	return not placeable().is_empty() or not pins_in_reach().is_empty() or not booty_in_reach().is_empty()


func in_reach(at: Vector2) -> bool:
	return at.distance_to(shoulder()) <= PLACE_REACH + 0.001


func stretched(at: Vector2) -> bool:
	var side := signf(at.x - session.pose.hip.x)
	return at.distance_to(shoulder() + Vector2(side * SHOULDER_HALF_M, 0)) > STRETCH_M


## Offers from this stance so far (query).
func tries_here() -> int:
	var n := session.note(id())
	return int(n.get("tries", 0)) if n.get("stance", []) == _stance_key() else 0


## What the next offer (or tug, or working booty) at [param at] costs: effort's
## price for an "offer", more for each try from this stance and at a stretch.
func offer_cost(at: Vector2, kind := &"offer") -> V2Cost:
	var hand := session.pose.limb(session.pose.next_hand) as V2Limb
	var base := session.sys.effort.price_action(&"offer", {"stretched": stretched(at),
		"hand_hold": hand.id if hand and hand.kind == &"hold" else ""})
	var mult := (1.0 + FIDDLE_STEP * tries_here()) * (STRETCH_COST if stretched(at) else 1.0)
	if kind == &"tug":
		mult *= 0.5
	return V2Cost.make(base.pump * mult, base.gas * mult, base.minutes)


## How the next try feels, for the hint: "light", "more", "heavy" or
## "last" (one more and you're off). Query.
func next_try_feel(at: Vector2) -> String:
	var c := offer_cost(at)
	if session.effort.pump + c.pump >= 1.0:
		return "last"
	var first := offer_cost(at).pump / (1.0 + FIDDLE_STEP * tries_here())
	if tries_here() == 0 or c.pump <= first * 1.05:
		return "light"
	return "more" if tries_here() < 3 else "heavy"


func offer(item_id: String, crack_id: String, at: Vector2) -> Dictionary:
	var item := session.rack.item(item_id)
	var crack := session.wall.crack(crack_id)
	if item.is_empty() or crack == null or int(item.get("count", 0)) <= 0:
		return {"fits": false, "lobes": "", "seated": false, "note": "nothing to place", "state": "none"}
	var near := crack.nearest(at)
	var spot: Vector2 = near.pos
	var murky := stretched(spot)
	var r: Dictionary
	match str(item.kind):
		"cam":
			r = _offer_cam(item, crack, near)
		"nut", "offset":
			r = _offer_nut(item, crack, near)
		_:
			r = {"fits": false, "lobes": "", "seated": false, "note": "that doesn't go in a crack", "state": "none"}
	r.item = item_id
	r.crack = crack_id
	r.at = [spot.x, spot.y]
	r.murky = murky
	r.kind = str(item.kind)
	if murky and r.fits:
		r.note = "You can't quite see in. " + str(r.note)
	return r


func _knows_lobes() -> bool:
	return session.mods.knows("lobes")


func _offer_cam(item: Dictionary, crack: V2Crack, near: Dictionary) -> Dictionary:
	var width := float(near.width)
	var e := expansion(float(item.width_min), width)
	var walks := crack.flare > 0.3 or crack.kind == &"pinscar"
	var r := {"e": e, "walks": walks, "seated": false, "fits": e >= 0.0 and e <= 1.0}
	var lobes_known := _knows_lobes()
	if e < 0.0:
		r.merge({"lobes": "", "state": "tight", "note": "Even squeezed shut it won't go in."})
	elif e > 1.0:
		r.merge({"lobes": "", "state": "out", "note": "It rattles loose. Too small for this."})
	elif e < 0.1:
		r.merge({"lobes": "over", "state": "over", "note": ("Trigger pinned, lobes shut tight: it'll hold, and it'll be a fight to clean." if lobes_known else "The lobes are nearly shut.")})
	elif e > 0.85:
		r.merge({"lobes": "tipped", "state": "tipped", "note": ("Tips barely biting: it could walk right out." if lobes_known else "The lobes are wide open.")})
	elif e > 0.7:
		r.merge({"lobes": "sweet", "state": "open", "note": ("Open past halfway. It'll do, a size up would be better." if lobes_known else "The lobes are well open.")})
	else:
		r.merge({"lobes": "sweet", "state": "sweet", "note": ("Lobes about half shut, all four flat on the rock." if lobes_known else "The lobes are half shut.")})
	if r.fits and walks:
		r.note = str(r.note) + (" The crack flares; it wants to walk." if crack.flare > 0.3 else " Pin-scarred: the lobes sit uneven.")
	if r.fits and crack.kind == &"flake":
		r.note = str(r.note) + " The flake flexes a little."
	return r


## Slides a nut down the crack from [param near] until it catches.
func _offer_nut(item: Dictionary, crack: V2Crack, near: Dictionary) -> Dictionary:
	var lo := mm(float(item.width_min)) - NUT_SLOP_MM
	var hi := mm(float(item.width_max)) + NUT_SLOP_MM
	var offset := str(item.kind) == "offset" or (item.get("tags", []) as Array).has("offset")
	var start: Vector2 = near.pos
	var r := {"e": -1.0, "walks": false, "lobes": "", "fits": false, "seated": false, "stop": [start.x, start.y]}
	if mm(float(near.width)) < lo:
		r.merge({"state": "tight", "note": "Too fat to go in here."})
		return r
	var t := float(near.t)
	var total := crack.length()
	var step := 0.04 / maxf(total, 0.01)
	var slid := 0.0
	var stop := {}
	while t >= 0.0 and slid <= NUT_SLIDE_M:
		var p := _at_t(crack, t)
		if mm(float(p.width)) <= hi:
			stop = p
			break
		t -= step
		slid += 0.04
	if stop.is_empty():
		r.merge({"state": "through", "note": "It slides down through. Nowhere here pinches it."})
		return r
	var stop_pos: Vector2 = stop.pos
	r.stop = [stop_pos.x, stop_pos.y]
	r.slid = slid
	var w_mm := mm(float(stop.width))
	var below := _at_t(crack, maxf(0.0, float(stop.t) - 0.15 / maxf(total, 0.01)))
	var pinch := w_mm - mm(float(below.width))
	var flared := crack.flare > 0.45 and not offset
	if flared:
		r.merge({"state": "flare", "note": "It skates on the flare and won't seat."})
		return r
	r.fits = true
	r.seated = true
	r.pinch = pinch
	if pinch >= PINCH_MM and w_mm >= lo:
		r.merge({"state": "seated", "note": "It drops in and stops, snug, in a pinch." if session.mods.knows("constrictions") else "It drops in and stops."})
	else:
		r.merge({"state": "shallow", "note": "It catches, but only just: the crack barely narrows." if session.mods.knows("constrictions") else "It catches on something."})
	if crack.kind == &"pinscar":
		r.note = str(r.note) + (" Its offset faces fill the scar." if offset else " The pin scar's flare leaves it on two corners.")
	return r


func _at_t(crack: V2Crack, t: float) -> Dictionary:
	t = clampf(t, 0.0, 1.0)
	var total := crack.length()
	var want := t * total
	var run := 0.0
	for i in crack.points.size() - 1:
		var seg := crack.points[i].distance_to(crack.points[i + 1])
		if run + seg >= want or i == crack.points.size() - 2:
			var f := 0.0 if seg <= 0.0 else clampf((want - run) / seg, 0.0, 1.0)
			return {"t": t, "pos": crack.points[i].lerp(crack.points[i + 1], f), "width": lerpf(crack.widths[i], crack.widths[i + 1], f)}
		run += seg
	return {"t": t, "pos": crack.points[0] if crack.points.size() > 0 else Vector2.ZERO, "width": crack.widths[0] if crack.widths.size() > 0 else 0.0}


## The hidden holding power of a [method offer] reading, 0..1, before the
## small seeded wobble [method place] adds. Pure.
func quality_of(reading: Dictionary) -> float:
	if not reading.get("fits", false):
		return 0.0
	var crack := session.wall.crack(str(reading.get("crack", "")))
	var flare := crack.flare if crack else 0.0
	var q := 0.0
	if reading.get("kind", "") == "cam":
		q = cam_hold(float(reading.e))
		q *= 1.0 - 0.7 * maxf(0.0, flare - 0.15)
		if crack and crack.kind == &"pinscar":
			q *= 0.6
		if crack and crack.kind == &"flake":
			q *= 0.85
	else:
		q = 0.9 if reading.get("state", "") == "seated" else 0.45
		var offset: bool = reading.get("kind", "") == "offset"
		q *= 1.0 - (0.2 if offset else 0.8) * flare
		if crack and crack.kind == &"pinscar":
			q *= 1.05 if offset else 0.7
	if reading.get("murky", false):
		q *= 0.9
	return clampf(q, 0.0, 1.0)


## The size that would hold best at [param at] in [param crack_id] (for the
## "auto_gear" assist's cursor). Pure. "" if nothing fits.
func best_item(crack_id: String, at: Vector2) -> String:
	var best := ""
	var best_q := 0.0
	for it in session.rack.items:
		if int(it.count) <= 0 or not str(it.kind) in ["cam", "nut", "offset"]:
			continue
		var q := quality_of(offer(str(it.id), crack_id, at))
		if q > best_q + 0.001:
			best_q = q
			best = str(it.id)
	return best


## Old fixed pins (and other fixed pieces) a hand can tug-test from here.
func pins_in_reach() -> Array[V2Piece]:
	var out: Array[V2Piece] = []
	for p in session.wall.fixed_within(shoulder(), PLACE_REACH):
		if p.kind == &"pin" and not p.popped:
			out.append(p)
	return out


## What a tug on fixed piece [param piece_id] tells you (query).
func tug_reading(piece_id: String) -> Dictionary:
	var p := session.piece(piece_id)
	if p == null:
		return {"kind": "pin", "note": ""}
	var note := "It rings when you tap it and doesn't move. Solid."
	if p.quality < 0.35:
		note = "It shifts in the rock. You wouldn't hang a coat on it."
	elif p.quality < 0.6:
		note = "It flexes a little in its eye. Old, but it's something."
	if p.tags.has("rusty"):
		note += " Rust bleeds down the rock below it."
	return {"kind": "pin", "piece": piece_id, "note": note, "fits": false, "lobes": "", "seated": false}


## Stuck pieces on this pitch within reach: [{id, pos, crack, gear, name,
## text, worked, needs}] (query).
func booty_in_reach() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b: Dictionary in session.note(id()).get("booty", []):
		if in_reach(V2Data.vec(b.pos)):
			out.append(b)
	return out


## How the partner would grade [param piece] and name it ("your red #1 at
## 6 m walked"). Falls' cleaning can use it (has_method("grade_for")).
func grade_for(piece: V2Piece) -> Dictionary:
	var grade := "bomber"
	if piece.popped:
		grade = "it popped"
	elif piece.tags.has("tipped"):
		grade = "tipped out"
	elif piece.tags.has("walked"):
		grade = "walked a bit"
	elif piece.tags.has("overcammed"):
		grade = "over-cammed"
	elif piece.tags.has("shallow"):
		grade = "barely seated"
	elif piece.quality < 0.5:
		grade = "a prayer"
	var lines := {
		"bomber": "bomber, nice", "tipped out": "tipped out, I could've pulled it with two fingers",
		"walked a bit": "walked up the crack a bit", "over-cammed": "over-cammed, took me ten minutes with the nut tool",
		"barely seated": "barely seated, one tug and it came out", "a prayer": "that one was a prayer",
		"it popped": "popped when you came on it",
	}
	var why: String = {"tipped out": "tipped", "walked a bit": "walked", "over-cammed": "overcammed",
		"barely seated": "shallow", "a prayer": "marginal", "it popped": "popped"}.get(grade, "")
	return {"grade": grade, "line": "Your %s at %d m: %s." % [piece_name(piece), roundi(piece.pos.y), lines[grade]], "why": why}


## The size printed on a piece: "#0.75", "mid"... (Gear's size label, else
## the rack's name).
func size_label(item_id: String) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var g: Node = tree.root.get_node_or_null("/root/Gear") if tree else null
	var data: Resource = g.get_gear(item_id) if g and g.has_method("get_gear") else null
	if data and str(data.get("size")) != "":
		return str(data.get("size"))
	return str(session.rack.item(item_id).get("name", item_id))


## "red #1", "mid nuts"...
func piece_name(piece: V2Piece) -> String:
	var size := size_label(piece.gear_id)
	if piece.kind == &"cam":
		var colour: String = COLOR_NAMES.get(piece.gear_id, "")
		return ("%s %s" % [colour, size]).strip_edges() if size.begins_with("#") else size.to_lower()
	return (size + " nut").to_lower() if size != "" and not size.to_lower().contains("nut") else size.to_lower()


# ------------------------------------------------------------------ mutators

func pitch_started() -> void:
	var n := session.note(id())
	n.erase("tries")
	n.erase("stance")
	n["tested"] = {}
	n["booty"] = _booty_for_pitch()


## Counts one more try from this stance (the place phase calls it when an
## offer, tug or booty try is paid for).
func note_try() -> void:
	var n := session.note(id())
	var key := _stance_key()
	if n.get("stance", []) != key:
		n.stance = key
		n.tries = 0
	n.tries = int(n.get("tries", 0)) + 1


func place(item_id: String, crack_id: String, at: Vector2) -> V2Piece:
	var reading := offer(item_id, crack_id, at)
	if not reading.fits or not session.rack.take(item_id):
		return null
	var n := session.note(id())
	n.placed = int(n.get("placed", 0)) + 1
	n.last_item = item_id
	var item := session.rack.item(item_id)
	var p := V2Piece.new()
	p.id = "placed%d_%d" % [session.pitch, n.placed]
	p.kind = &"nut" if str(item.kind) == "offset" else StringName(str(item.kind))
	p.pos = V2Data.vec(reading.stop) if reading.has("stop") else V2Data.vec(reading.at)
	p.gear_id = item_id
	p.crack_id = crack_id
	var crack := session.wall.crack(crack_id)
	p.width = crack.width_near(p.pos)
	var wobble := session.rng_for(id()).randf_range(-0.04, 0.04)
	p.quality = clampf(quality_of(reading) + wobble, 0.0, 1.0)
	match str(reading.get("state", "")):
		"over":
			p.tags.append("overcammed")
		"tipped":
			p.tags.append("tipped")
		"shallow":
			p.tags.append("shallow")
	if reading.get("walks", false) and p.kind == &"cam":
		p.tags.append("walked")
	if reading.get("murky", false):
		p.tags.append("stretched")
	if str(item.kind) == "offset":
		p.tags.append("offset")
	session.pieces[p.id] = p
	session.bus.send(&"piece_placed", [p.id])
	return p


## Tugs fixed pin [param piece_id]: remembers what it told you.
func tug(piece_id: String) -> Dictionary:
	var r := tug_reading(piece_id)
	(session.note(id())["tested"] as Dictionary)[piece_id] = r.note
	session.bus.send(&"piece_offered", [piece_id, r])
	return r


## One go at working stuck booty [param booty_id] loose. Returns the reading;
## reading.freed is true the time it comes out (then it's on your rack and
## yours for good).
func work_booty(booty_id: String) -> Dictionary:
	var list: Array = session.note(id()).get("booty", [])
	for i in list.size():
		var b: Dictionary = list[i]
		if b.id != booty_id:
			continue
		b.worked = int(b.worked) + 1
		var left := int(b.needs) - int(b.worked)
		var r := {"kind": "booty", "booty": booty_id, "fits": false, "lobes": "", "seated": false, "freed": left <= 0}
		if left <= 0:
			r.note = "It comes free in your hand: %s." % str(b.name)
			r.text = str(b.get("text", ""))
			list.remove_at(i)
			_take_booty(b)
		elif left == 1:
			r.note = "It rattles. Nearly."
		elif int(b.worked) == 1:
			r.note = "It doesn't budge."
		else:
			r.note = "It shifts, a little."
		session.bus.send(&"piece_offered", [str(b.gear), r])
		return r
	return {}


func _take_booty(b: Dictionary) -> void:
	var n := session.note(id())
	var freed: Array = n.get("freed", [])
	freed.append(str(b.id))
	n["freed"] = freed
	var wb := _wall_booty()
	if wb:
		for entry: Dictionary in wb.all():
			if str(entry.id) == str(b.id):
				wb.take(entry)
				break
	# On the harness now if you rack that size; otherwise it rides in the pack.
	if not session.rack.item(str(b.gear)).is_empty():
		session.rack.give_back(str(b.gear))


func _wall_booty() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("/root/WallBooty") if tree else null


## Booty waiting on this pitch, put in the crack nearest its old row.
func _booty_for_pitch() -> Array:
	var out := []
	var wb := _wall_booty()
	if wb == null or session.wall == null or session.wall.cracks.is_empty():
		return out
	var w := session.wall
	var rng := session.rng_for(id())
	for b: Dictionary in wb.waiting(session.route_id):
		if int(b.get("pitch", 0)) != session.pitch:
			continue
		var y := clampf(w.start.y + 1.2 * float(b.get("row", 3)), w.start.y + 1.5, w.top.y - 1.0)
		var guess := Vector2(w.size.x * 0.5, y)
		var crack: V2Crack = w.cracks_within(guess, 100.0)[0]
		var spot: Vector2 = crack.nearest(guess).pos
		out.append({"id": str(b.id), "pos": [spot.x, spot.y], "crack": crack.id, "gear": str(b.get("gear", "cam")),
			"name": str(b.get("name", "a stuck piece")), "text": str(b.get("text", "")), "worked": 0,
			"needs": 2 + rng.randi_range(0, 2)})
	return out


func _stance_key() -> Array:
	return [snappedf(session.pose.hip.x, 0.01), snappedf(session.pose.hip.y, 0.01)]


func phases() -> Dictionary:
	return {&"place": PlacePhase.new()}


func make_overlay() -> Node:
	var o := TradGearOverlay.new()
	o.gear = self
	return o


## The place phase. Left/Right walks along the harness (then any old pin to
## tug or stuck piece to work), Up/Down slides the spot along the crack, swap
## changes crack. Before you pay, the overlay shows the piece held beside the
## crack at true size. Commit offers (pump), commit again places (a nut gets
## a tug to set it) and opens the clip; cancel puts it back for free.
class PlacePhase extends ClimbPhase:
	var crack_id := ""
	var at := Vector2.ZERO
	## {type: "item"|"pin"|"booty", id}
	var entries: Array[Dictionary] = []
	var index := 0
	var reading := {}
	## Presentation: seconds since the last offer (nut slide, lobe settle).
	var since := 0.0

	func gear() -> TradGear:
		return director.session.sys.gear as TradGear

	func enter(p_director: ClimbDirector, _args := {}) -> void:
		director = p_director
		name = &"place"
		var g := gear()
		var cracks := g.placeable()
		crack_id = ""
		at = g.shoulder()
		if not cracks.is_empty():
			crack_id = cracks[0].id
			var c := director.session.wall.crack(crack_id)
			at = c.nearest(g.shoulder() + Vector2(0, 0.1)).pos
			if not g.in_reach(at):
				at = c.nearest(g.shoulder()).pos
		_build_entries()
		if entries.is_empty():
			director.go(&"climb")
			return
		reading = {}
		index = _start_index()
		g.place_phase = self
		director.use_hand(&"gear", at)

	func exit() -> void:
		var g := gear() if director and director.session.sys.gear is TradGear else null
		if g and g.place_phase == self:
			g.place_phase = null

	func _build_entries() -> void:
		var s := director.session
		entries.clear()
		for it in s.rack.items:
			if crack_id != "" and int(it.count) > 0 and str(it.kind) in ["cam", "nut", "offset"]:
				entries.append({"type": "item", "id": str(it.id)})
		for p in gear().pins_in_reach():
			entries.append({"type": "pin", "id": p.id})
		for b in gear().booty_in_reach():
			entries.append({"type": "booty", "id": str(b.id)})

	func _start_index() -> int:
		var s := director.session
		var want: String = s.note(&"gear").get("last_item", "")
		if s.mods.assisted("auto_gear"):
			var best := gear().best_item(crack_id, at)
			if best != "":
				want = best
		for i in entries.size():
			if entries[i].type == "item" and entries[i].id == want:
				return i
		return 0

	func current() -> Dictionary:
		return entries[index] if index < entries.size() else {}

	func current_item() -> String:
		var e := current()
		return str(e.id) if e.get("type", "") == "item" else ""

	func handle(verb: StringName, pressed: bool) -> bool:
		if not pressed or entries.is_empty():
			return false
		var s := director.session
		var g := gear()
		match verb:
			&"aim_left", &"aim_right":
				index = wrapi(index + (1 if verb == &"aim_right" else -1), 0, entries.size())
				reading = {}
				return true
			&"aim_up", &"aim_down":
				var c := s.wall.crack(crack_id)
				if c == null:
					return true
				var next: Vector2 = c.nearest(at + Vector2(0, TradGear.SLIDE_M if verb == &"aim_up" else -TradGear.SLIDE_M)).pos
				if g.in_reach(next) and next != at:
					at = next
					reading = {}
					director.return_hand()
					director.use_hand(&"gear", at)
				return true
			&"swap":
				var cracks := g.placeable()
				if cracks.size() > 1:
					var i := 0
					for k in cracks.size():
						if cracks[k].id == crack_id:
							i = k
					crack_id = cracks[(i + 1) % cracks.size()].id
					at = s.wall.crack(crack_id).nearest(at).pos
					reading = {}
				return true
			&"commit":
				_commit()
				return true
			&"cancel":
				s.bus.send(&"piece_cancelled", [current_item()])
				director.return_hand()
				director.go(&"climb")
				return true
		return false

	func _commit() -> void:
		var s := director.session
		var g := gear()
		var e := current()
		if e.type == "item" and not reading.is_empty() and reading.get("item", "") == e.id:
			var p := g.place(e.id, crack_id, at)
			if p == null:
				return
			director.spend(s.sys.effort.price_action(&"place"))
			director.return_hand()
			director.go(&"clip", {"piece_id": p.id})
			return
		var spot := at
		if e.type == "pin":
			spot = s.piece(e.id).pos
		elif e.type == "booty":
			for b in g.booty_in_reach():
				if b.id == e.id:
					spot = V2Data.vec(b.pos)
		var cost := g.offer_cost(spot, &"tug" if e.type == "pin" else &"offer")
		director.spend(cost)
		g.note_try()
		if s.sys.effort.pumped_out():
			# Pumped off while fiddling: you let go. The piece is still on
			# your harness (an offer never takes it).
			s.bus.send(&"piece_cancelled", [current_item()])
			reading = {}
			director.take_fall()
			return
		since = 0.0
		match str(e.type):
			"item":
				reading = g.offer(e.id, crack_id, at)
				s.bus.send(&"piece_offered", [e.id, reading])
			"pin":
				reading = g.tug(e.id)
			"booty":
				reading = g.work_booty(e.id)
				if reading.get("freed", false):
					var keep := current_item()
					_build_entries()
					index = clampi(index, 0, maxi(0, entries.size() - 1))
					if keep != "":
						for i in entries.size():
							if entries[i].id == keep:
								index = i

	func step(delta: float) -> void:
		since += delta

	func hint() -> String:
		if director == null or entries.is_empty():
			return ""
		var e := current()
		var feel := gear().next_try_feel(at)
		var cost_line: String = {"light": "", "more": " Each try here costs more.", "heavy": " Your forearms are burning.",
			"last": " One more try and you're off!"}.get(feel, "")
		match str(e.type):
			"pin":
				return "Space tugs the old pin. Left/Right for your rack, Esc to climb on." + cost_line
			"booty":
				return "Space works the stuck piece. Left/Right for your rack, Esc to climb on." + cost_line
		if not reading.is_empty() and reading.get("item", "") == e.id:
			if reading.get("fits", false):
				return ("Space tugs it to set. " if reading.get("kind", "") != "cam" else "Space lets the lobes go: placed. ") + "Left/Right tries another, Up/Down moves it, Esc puts it back." + cost_line
			return "Left/Right for another size, Up/Down moves along the crack, Esc puts it back." + cost_line
		return "Left/Right picks a piece, Up/Down moves along the crack, Space offers it, Esc puts it back." + cost_line
