class_name ClimbSession
extends RefCounted
## Everything about one climb in progress: the one object every v2 system
## is handed. Plain data plus the systems and the bus. Who writes which field
## is in CONTRACTS.md; in short: wall = wall source, pose = body, effort =
## effort, rope = rope, pieces = gear (placement) / rope (clips) / falls
## (pops), rack = through take/give_back, minutes + result + pitch = director,
## notes[<system>] = that system.

var route: RouteData
var route_id := ""
## Seeds every random stream (see [method rng_for]).
var seed := 0
var pitch := 0
var wall: V2Wall
var pose := V2Pose.new()
var effort := V2Effort.new()
var rope := V2Rope.new()
var rack := V2Rack.new()
var mods := V2Modifiers.new()
## Pieces the leader placed this pitch, by id (fixed ones live on the wall).
var pieces := {}
## Minutes since the climb began.
var minutes := 0
## Counters that end up in the result (director).
var result := V2Result.new()
## Each system's own scratch data, keyed by system id; only that system
## writes its entry. Kept in snapshots.
var notes := {}
## The systems, by name (ClimbSystemSet).
var sys := ClimbSystemSet.new()
var bus := ClimbEvents.new()
## The current phase's name (director).
var phase: StringName = &""

var _rngs := {}


## A random stream for [param system] on this pitch, the same every time for
## the same seed, route and pitch, and apart from other systems' streams so a
## system's draws never shift another's.
func rng_for(system: StringName) -> RandomNumberGenerator:
	var key := "%s:%d" % [system, pitch]
	if not _rngs.has(key):
		var r := RandomNumberGenerator.new()
		r.seed = hash([seed, route_id, String(system), pitch])
		_rngs[key] = r
	return _rngs[key]


## A placed or fixed piece by id, or null.
func piece(piece_id: String) -> V2Piece:
	if pieces.has(piece_id):
		return pieces[piece_id]
	return wall.fixed_piece(piece_id) if wall else null


## Every piece on the pitch: fixed ones then placed ones.
func all_pieces() -> Array[V2Piece]:
	var out: Array[V2Piece] = []
	if wall:
		out.append_array(wall.fixed)
	for p: V2Piece in pieces.values():
		out.append(p)
	return out


## The note dictionary [param system] writes (made on first use).
func note(system: StringName) -> Dictionary:
	if not notes.has(system):
		notes[system] = {}
	return notes[system]


## Plain data for everything that changes during a pitch. The wall itself is
## rebuilt from its source (only fixed pieces' state is kept). Cheap enough
## for undo, ghost previews and a bot's search.
func snapshot() -> Dictionary:
	var fixed := {}
	if wall:
		for p in wall.fixed:
			fixed[p.id] = p.to_dict()
	var placed := {}
	for id: String in pieces:
		placed[id] = (pieces[id] as V2Piece).to_dict()
	var rng_states := {}
	for key: String in _rngs:
		rng_states[key] = [(_rngs[key] as RandomNumberGenerator).seed, (_rngs[key] as RandomNumberGenerator).state]
	return {"pitch": pitch, "pose": pose.to_dict(), "effort": effort.to_dict(), "rope": rope.to_dict(),
		"rack": rack.to_dict(), "mods": mods.to_dict(), "pieces": placed, "fixed": fixed,
		"minutes": minutes, "result": result.to_dict(), "notes": notes.duplicate(true),
		"phase": String(phase), "rngs": rng_states}


## Puts back a [method snapshot] of the same pitch.
func restore(d: Dictionary) -> void:
	pitch = int(d.get("pitch", pitch))
	pose = V2Pose.from_dict(d.get("pose", {}))
	effort = V2Effort.from_dict(d.get("effort", {}))
	rope = V2Rope.from_dict(d.get("rope", {}))
	rack = V2Rack.from_dict(d.get("rack", {}))
	mods = V2Modifiers.from_dict(d.get("mods", {}))
	pieces.clear()
	for id: String in d.get("pieces", {}):
		pieces[id] = V2Piece.from_dict(d.pieces[id])
	if wall:
		var fixed: Dictionary = d.get("fixed", {})
		for i in wall.fixed.size():
			if fixed.has(wall.fixed[i].id):
				wall.fixed[i] = V2Piece.from_dict(fixed[wall.fixed[i].id])
				wall.fixed[i].fixed = true
	minutes = int(d.get("minutes", 0))
	result.load_dict(d.get("result", {}))
	notes = (d.get("notes", {}) as Dictionary).duplicate(true)
	phase = StringName(str(d.get("phase", phase)))
	_rngs.clear()
	var states: Dictionary = d.get("rngs", {})
	for key: String in states:
		var r := RandomNumberGenerator.new()
		r.seed = int(states[key][0])
		r.state = int(states[key][1])
		_rngs[key] = r
