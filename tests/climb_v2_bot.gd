class_name ClimbV2TestBot
extends RefCounted
## A plain scripted climber for the v2 foundation tests: it plays through
## the director's verbs and intents the way a player would (highest hold it
## can reach, clip what's in reach, plug one cam per pitch, rest when pumped).
## Thread 10 builds the real route solver; this one only proves the stubs run
## end to end.

var director: ClimbDirector
## Places a cam per pitch once the hips are this high (-1: never).
var place_from := 3.5
## Rests when pump is over this.
var rest_at := 0.5
var steps := 0


func _init(p_director: ClimbDirector) -> void:
	director = p_director


## Plays until the climb finishes or [param max_steps] run out. True if it
## topped out.
func run(max_steps := 600) -> bool:
	while not director.done and steps < max_steps:
		step()
	return director.done and director.session.result.success


func step() -> void:
	steps += 1
	var s := director.session
	match s.phase:
		&"read", &"fall", &"belay":
			director.handle_verb(&"commit", true)
		&"climb":
			_climb()
		&"clip":
			_clip()
		&"place":
			_place()
		_:
			director.handle_verb(&"commit", true)


func _climb() -> void:
	var s := director.session
	var shoulder := s.pose.hip + Vector2(0, ClimbV2.TORSO_M)
	for p in s.sys.rope.clippable():
		if p.pos.y <= shoulder.y + 0.8:
			if director.handle_verb(&"rope", true):
				return
	if place_from >= 0.0 and s.pieces.is_empty() and s.pose.hip.y > place_from and not s.sys.gear.placeable().is_empty():
		if director.handle_verb(&"rack", true):
			return
	if s.effort.pump > rest_at and s.sys.body.rest_kind() != &"":
		if director.handle_verb(&"rest", true):
			return
	var move := best_move()
	if move == null:
		s.sys.body.swap_hand()
		move = best_move()
	if move:
		director.commit(move)


## The valid move to the highest reachable hold for the next hand, or null.
func best_move() -> V2Move:
	var s := director.session
	var best: V2Move = null
	var best_y := -INF
	for h in s.sys.body.reachable(s.pose.next_hand):
		var m := director.preview(h.id)
		if m.valid and h.pos.y > best_y:
			best = m
			best_y = h.pos.y
	return best


func _clip() -> void:
	var s := director.session
	if s.rope.arms_pulled < s.sys.rope.arms_needed(s.rope.pulling_for):
		director.handle_verb(&"rope", true)
	else:
		director.handle_verb(&"commit", true)


var _tries := 0


func _place() -> void:
	var phase := director.current
	var reading: Dictionary = phase.get("reading")
	if reading.is_empty():
		_tries += 1
		if _tries > 8:
			_tries = 0
			director.handle_verb(&"cancel", true)
			place_from = -1.0
			return
		director.handle_verb(&"commit", true)
	elif reading.get("lobes", "") == "sweet" or reading.get("seated", false):
		_tries = 0
		director.handle_verb(&"commit", true)
	else:
		director.handle_verb(&"aim_right", true)
