class_name ClimbDirector
extends RefCounted
## The v2 climb's coordinator (thread 1): runs the move pipeline, owns the
## phase table, the clock and the result, and applies cross-system effects in
## one place. It has no drawing, so tests and bots run a climb headless; the
## screen (ClimbScreenV2) is a thin layer of views and input over it.
##
## Rules it keeps: a system's fields are changed only by that system's own
## mutators, and mutators that touch more than one system are called here.

signal finished(result: V2Result)

## Phase -> the system that supplies it (its phases()). "director" phases
## are built in.
const PHASES := {
	&"read": &"director", &"climb": &"body", &"clip": &"rope", &"place": &"gear",
	&"fall": &"falls", &"belay": &"falls", &"special": &"cruxes", &"result": &"director",
}
## Verbs the director answers itself in these phases, before the phase sees them.
const CLIMB_VERBS := [&"rope", &"rack", &"rest", &"eat", &"cancel"]

var session: ClimbSession
var current: ClimbPhase
var done := false

var _phases := {}
var _retreat_armed := false


## Starts a climb of [param route]. [param mods] and [param rack] default to
## the game's (Gear, Settings, Perks); tests pass their own.
func setup(route: RouteData, seed := 0, mods: V2Modifiers = null, rack: V2Rack = null) -> ClimbSession:
	session = ClimbSession.new()
	session.route = route
	session.route_id = route.id if route else ""
	session.seed = seed
	session.result.route = route
	session.mods = mods if mods else V2Modifiers.from_world(route)
	session.rack = rack if rack else V2Rack.from_gear()
	ClimbSystems.build(session)
	_phases = {&"read": ReadPhase.new(), &"result": ResultPhase.new()}
	for system in session.sys.all():
		var given: Dictionary = system.phases()
		for phase: StringName in given:
			if PHASES.get(phase) == system.id():
				_phases[phase] = given[phase]
			else:
				push_warning("ClimbDirector: %s can't supply phase %s" % [system.id(), phase])
	session.bus.piece_cleaned.connect(_on_piece_cleaned)
	session.bus.crux_sent.connect(_on_crux_sent)
	return session


## Begins the first pitch.
func start() -> void:
	session.bus.send(&"climb_started", [session.route_id])
	_begin_pitch(0)


func pitch_count() -> int:
	return session.sys.wall.pitch_count(session.route)


func _begin_pitch(index: int) -> void:
	session.pitch = index
	session.pieces.clear()
	session.wall = session.sys.wall.build_pitch(session.route, index, session.seed)
	session.sys.rope.reset_for_pitch()
	session.pose = session.sys.body.start_pose(session.wall)
	for system in session.sys.all():
		system.pitch_started()
	session.bus.send(&"pitch_started", [index])
	go(&"read")


## Changes phase. [param args] go to the new phase's enter().
func go(phase: StringName, args := {}) -> void:
	if not _phases.has(phase):
		push_warning("ClimbDirector: no phase %s (is %s's system missing it?)" % [phase, PHASES.get(phase, "?")])
		phase = &"climb" if _phases.has(&"climb") else &"read"
	var from := session.phase
	if current:
		current.exit()
	current = _phases[phase]
	current.name = phase
	session.phase = phase
	_retreat_armed = false
	session.bus.send(&"phase_changed", [from, phase])
	current.enter(self, args)


## A verb (ClimbInput) from the player or a bot. True if something used it.
func handle_verb(verb: StringName, pressed: bool) -> bool:
	if done or current == null:
		return false
	if pressed and verb != &"cancel":
		_retreat_armed = false
	if session.phase == &"climb" and verb in CLIMB_VERBS:
		return _climb_verb(verb, pressed)
	if session.phase == &"belay" and verb == &"eat":
		return pressed and eat()
	return current.handle(verb, pressed)


func _climb_verb(verb: StringName, pressed: bool) -> bool:
	if not pressed:
		return false
	match verb:
		&"rope":
			var pieces: Array[V2Piece] = session.sys.rope.clippable()
			if pieces.is_empty():
				return false
			go(&"clip", {"piece_id": pieces[0].id})
			if session.phase == &"clip":
				current.handle(&"rope", true)
			return true
		&"rack":
			if session.sys.gear.placeable().is_empty():
				return false
			go(&"place")
			return true
		&"rest":
			return rest()
		&"eat":
			return eat()
		&"cancel":
			if _retreat_armed:
				retreat()
			else:
				_retreat_armed = true
			return true
	return false


# ---------------------------------------------------------------- the pipeline

## The move of the next hand to [param hold_id], fully worked out but not
## taken: body.preview -> cruxes.constrain -> effort.price -> falls.risk.
## Pure (changes nothing, draws nothing).
func preview(hold_id: String, hip_shift := Vector2.ZERO) -> V2Move:
	var s := session.sys
	var move := s.body.preview(hold_id, hip_shift)
	if move.valid:
		s.cruxes.constrain(move)
	s.effort.price(move)
	s.falls.risk(move)
	return move


## Takes [param move] (from [method preview]). Returns false if it can't be
## taken. Spends its cost, moves the body, tells cruxes, then rolls for a
## fall once; topping out opens the belay.
func commit(move: V2Move) -> bool:
	if done or move == null or not move.valid or session.phase != &"climb":
		return false
	var s := session.sys
	spend(move.cost)
	s.body.commit(move)
	s.cruxes.committed(move)
	session.result.moves += 1
	if s.falls.falls_now(move):
		take_fall()
		return true
	if s.body.at_top():
		_top_out()
		return true
	var hold := session.wall.hold(move.hold_id)
	var special: StringName = s.cruxes.special_at(hold.pos) if hold else &""
	if special != &"" and _phases.has(&"special"):
		go(&"special", {"kind": special})
		return true
	current.refresh()
	return true


## Spends [param cost]: pump and gas through effort, minutes on the clock.
func spend(cost: V2Cost) -> void:
	if cost == null:
		return
	session.sys.effort.apply(cost)
	session.minutes += cost.minutes


## Comes off: rope works out the fall, falls decides it, popped pieces are
## unclipped, the body hangs where it settles and the fall is paid for.
func take_fall() -> V2Fall:
	var s := session.sys
	s.body.return_hand()
	if session.rope.pulling_for != "":
		s.rope.cancel_clip()
	var fall := s.rope.fall_geometry(session.pose.tie_in())
	fall = s.falls.resolve(fall)
	for piece_id in fall.popped:
		s.rope.remove(piece_id)
	s.body.settle(fall.settle_pos)
	spend(fall.cost)
	session.result.falls += 1
	go(&"fall", {"fall": fall})
	return fall


## Puts the climber hanging at [param pos] (the King Swing landing at the far
## crack, standing in aiders, an inchworm up a chimney), with [param tags]
## added to the pose.
func hang_at(pos: Vector2, tags := PackedStringArray()) -> void:
	session.sys.body.settle(pos)
	if not tags.is_empty():
		session.sys.body.tag_pose(tags)


## Counts [param n] aid moves (pulling on gear): they cost the medal.
func count_aid(n := 1) -> void:
	session.result.aid_moves += n


## Shakes out if the pose allows it ([param kind] "" = body's rest_kind;
## the belay passes "belay").
func rest(kind: StringName = &"") -> bool:
	if kind == &"":
		kind = session.sys.body.rest_kind()
	if kind == &"":
		return false
	spend(session.sys.effort.rest(kind))
	if current:
		current.refresh()
	return true


## Eats [param food_id] ("" = effort's best pick).
func eat(food_id := "") -> bool:
	if food_id == "":
		food_id = session.sys.effort.best_food()
	if food_id == "" or not session.sys.effort.eat(food_id):
		return false
	spend(session.sys.effort.price_action(&"eat"))
	session.result.food_eaten.append(food_id)
	return true


## Lends the free hand to a task (rope, gear) at [param at].
func use_hand(task: StringName, at: Vector2) -> void:
	var hand := session.sys.body.free_hand()
	if hand != &"":
		session.sys.body.use_hand(hand, task, at)


func return_hand() -> void:
	session.sys.body.return_hand()


func _top_out() -> void:
	var anchor := session.wall.anchor()
	if anchor and not anchor.clipped:
		anchor.clipped = true
		session.rope.clipped.append(anchor.id)
		session.bus.send(&"clipped", [anchor.id, false])
	session.result.pitches_done += 1
	session.bus.send(&"pitch_finished", [session.pitch])
	var special := session.sys.cruxes.belay_special()
	if special != &"" and _phases.has(&"special"):
		go(&"special", {"kind": special, "belay": true})
	else:
		go(&"belay")


## From the belay: the next pitch, or the top.
func next_pitch() -> void:
	if session.pitch + 1 < pitch_count():
		_begin_pitch(session.pitch + 1)
	else:
		finish(true)


func retreat() -> void:
	finish(false)


func finish(success: bool) -> void:
	if done:
		return
	done = true
	var r := session.result
	r.success = success
	r.minutes = session.minutes
	go(&"result")
	session.bus.send(&"climb_finished", [r])
	finished.emit(r)
	_close()


## Breaks the session <-> systems <-> phases reference loops so a finished
## climb is freed. The session's data, bus and result stay readable.
func _close() -> void:
	for system in session.sys.all():
		system.session = null
	for phase: ClimbPhase in _phases.values():
		phase.director = null
	_phases.clear()
	current = null


func _on_piece_cleaned(piece_id: String, grade: String) -> void:
	var p := session.piece(piece_id)
	session.result.placements.append({"gear_id": p.gear_id if p else "", "quality": p.quality if p else 0.0, "grade": grade})


func _on_crux_sent(_zone_id: String, clean: bool) -> void:
	if clean:
		session.result.perfect_cruxes += 1
	else:
		session.result.slipped_cruxes += 1


## Before the first move: look up the pitch. Any commit starts climbing.
## (Thread 10 makes this the real read-the-route view.)
class ReadPhase extends ClimbPhase:
	func handle(verb: StringName, pressed: bool) -> bool:
		if pressed and verb == &"commit":
			director.go(&"climb")
			return true
		return false

	func hint() -> String:
		return "Look up the pitch. Space to start climbing"


class ResultPhase extends ClimbPhase:
	func hint() -> String:
		return "Topped out!" if director.session.result.success else "Back on the ground"
