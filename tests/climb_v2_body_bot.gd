class_name ClimbV2BodyBot
extends ClimbV2TestBot
## The foundation's scripted climber, but it climbs through the real body's
## climb phase the way a player does: aim at a hold, step the hips to the
## best cell when neutral won't go, commit. Clipping, placing, rests and
## belays are the foundation bot's.

## Moves it took, and how many needed a hip shift.
var moves := 0
var shifted := 0
var swaps := 0


func _climb() -> void:
	var s := director.session
	var shoulder := s.pose.hip + Vector2(0, ClimbV2.TORSO_M)
	for p in s.sys.rope.clippable():
		if p.pos.y <= shoulder.y + 0.8 and (not p.fixed or s.rack.count("quickdraw") > 0):
			if director.handle_verb(&"rope", true):
				return
	if place_from >= 0.0 and s.pieces.is_empty() and s.pose.hip.y > place_from and not s.sys.gear.placeable().is_empty():
		if director.handle_verb(&"rack", true):
			return
	if s.effort.pump > rest_at and s.sys.body.rest_kind() != &"":
		if director.handle_verb(&"rest", true):
			return
	var phase := director.current as BodyAimPhase
	if phase == null:
		return
	var pick := choose(phase)
	if pick.is_empty():
		swaps += 1
		director.handle_verb(&"swap", true)
		pick = choose(phase)
		if pick.is_empty():
			return
	phase.aim_at(pick[0])
	phase.set_hip_shift(pick[1])
	if pick[1] != Vector2.ZERO:
		shifted += 1
	moves += 1
	director.handle_verb(&"commit", true)


## [hold id, hip shift] of the best upward move for the next hand, or [].
func choose(phase: BodyAimPhase) -> Array:
	var s := director.session
	var body: ClimbBody = s.sys.body
	var high := s.pose.high_point()
	var own: V2Limb = s.pose.limb(s.pose.next_hand)
	var best := []
	var best_score := -INF
	for hid in phase.aim_set:
		if own.kind == &"hold" and own.id == hid:
			continue
		var shift := Vector2.ZERO
		var m := body.preview(hid)
		if not m.valid or m.strain > 0.6:
			var sug: Array = body.suggest_shift(hid)
			if sug[1] != null and (not m.valid or (sug[1] as V2Move).strain < m.strain):
				shift = sug[0]
				m = sug[1]
		if not m.valid:
			continue
		var h := s.wall.hold(hid)
		var score := (h.pos.y - high) * 1.5 + m.security - m.strain
		if score > best_score or (score == best_score and not best.is_empty() and hid < str(best[0])):
			best_score = score
			best = [hid, shift]
	return best


## Starts the climb, then plays it (see [method run]).
func run_from_start(max_steps := 900) -> bool:
	director.start()
	return run(max_steps)
