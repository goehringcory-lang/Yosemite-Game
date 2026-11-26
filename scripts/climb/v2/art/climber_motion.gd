class_name ClimberMotion
extends RefCounted
## The climber's animation: what the drawn body is doing between the poses
## the body system commits. It never changes the session and nothing waits
## for it; every new pose or event retargets from wherever the drawing is.
##
## How a move plays (see [method retarget]):
## - the hips lead: they start toward the new position first, the legs
##   pushing the body up, while the hand that moves leaves a beat later;
## - the hand travels on an arc and arrives fast with a hard stop (no
##   ease-out mush), the shoulders sag a touch at the latch (a deadpoint),
##   then the feet step up one at a time;
## - big reaches dip first; dynos crouch, launch, cut the feet loose and
##   swing back in.
## Limbs that stay on their holds stay exactly there.
##
## On top of that: breathing (faster when pumped or low on gas), tremor in
## the loaded limbs as pump rises, posture decay (shoulders up, elbows out),
## the head looking where you aim, gestures (pulling rope, clipping, placing
## gear, chalking, shaking out, eating), the fall (peel, drop, catch, bounce,
## pendulum swing, settle) and swinging gear.
##
## Deterministic: no random numbers or wall-clock reads, only [member time].

const HANDS: Array[StringName] = [&"lh", &"rh"]
const FEET: Array[StringName] = [&"lf", &"rf"]
## Seconds a joint takes to swap which way it bends.
const BEND_TIME := 0.15
## Farther than this (metres) and a change is a cut, not a move.
const SNAP_DIST := 3.0

var time := 0.0
## The drawn hips and hand/foot ends (wall metres), before overlays.
var hip := Vector2.ZERO
var ends := {}
## The pose being moved toward (the session's, copied).
var target: V2Pose
## What each limb is doing in the target.
var kinds := {}
var bend := {}
var bend_goal := {}
var twist := 0.0
var look := Vector2.ZERO
var look_goal := Vector2.ZERO
## Pump and gas, 0..1, as last heard.
var pump := 0.0
var gas := 1.0
## Share of weight per limb (the last move's load).
var load := {&"lh": 0.25, &"rh": 0.25, &"lf": 0.25, &"rf": 0.25}
## Hips nudged toward an aimed hip shift (the body button), metres.
var lean := Vector2.ZERO
var lean_goal := Vector2.ZERO
## Effort just spent: makes breathing quicker for a while (0..1).
var exertion := 0.0
var chalk := {&"lh": 0.7, &"rh": 0.7}
## Strain signs from the effort system (session.notes.effort.signs: tremble,
## chicken_wing, breath, hip_sag, sweat, bonked ... each 0..1). Empty: the
## motion works them out from pump and gas itself.
var signs := {}

# springs
var _sag := Vector2.ZERO
var _sag_v := Vector2.ZERO
var _swing := Vector2.ZERO
var _swing_v := Vector2.ZERO
var _last_hip := Vector2.ZERO
var _last_hip_v := Vector2.ZERO
var _breath_phase := 0.0
var _look_v := Vector2.ZERO

## Key (a limb or &"hip") -> {pts: Array[Vector2], at: Array[float], arc: Vector2}.
var _tracks := {}
## Limb -> {pts, at, rel (&"hip" | &"base"), env}.
var _gestures := {}
## Timed things to do: {at, kind, ...}, kept sorted by at.
var _events: Array[Dictionary] = []
## Puffs of chalk or dust the view should show: {pos, kind, size}.
var fx: Array[Dictionary] = []
## An active fall, or {}.
var _fall := {}
## When the last fall was caught (for the rope's whip), -1 if never.
var caught_at := -1.0


func _init() -> void:
	for l in V2Pose.LIMBS:
		ends[l] = Vector2.ZERO
		bend[l] = 1.0
		bend_goal[l] = 1.0
		kinds[l] = &"free"


## Jumps straight to [param pose] (a new pitch).
func snap(pose: V2Pose) -> void:
	target = pose.copy()
	var at := ClimberRig.settle_free(pose, _pose_ends(pose))
	hip = pose.hip
	_last_hip = hip
	_last_hip_v = Vector2.ZERO
	for l in V2Pose.LIMBS:
		ends[l] = at[l]
		kinds[l] = (pose.limb(l) as V2Limb).kind
	twist = float(pose.facing)
	_tracks.clear()
	_gestures.clear()
	_events.clear()
	_fall = {}
	_sag = Vector2.ZERO
	_sag_v = Vector2.ZERO
	look = hip + Vector2(0, 1.5)
	look_goal = look
	var rig := _bend_rig()
	for l in V2Pose.LIMBS:
		bend[l] = rig.bend_wanted(l, pose.tags)
		bend_goal[l] = bend[l]


static func _pose_ends(pose: V2Pose) -> Dictionary:
	var out := {}
	for l in V2Pose.LIMBS:
		out[l] = (pose.limb(l) as V2Limb).pos
	return out


## Moves toward [param pose]. [param move] (when this is a committed move)
## sets the timing: which hand leads, how big the reach, a dyno.
func retarget(pose: V2Pose, move: V2Move = null) -> void:
	if target == null:
		snap(pose)
		return
	var goal := ClimberRig.settle_free(pose, _pose_ends(pose))
	if pose.hip.distance_to(hip) > SNAP_DIST and _fall.is_empty():
		snap(pose)
		return
	target = pose.copy()
	for l in V2Pose.LIMBS:
		kinds[l] = (pose.limb(l) as V2Limb).kind
	if not _fall.is_empty():
		return
	var now := time
	var hand: StringName = move.hand if move and move.to else &""
	var lunge := move != null and (move.has_tag("lunge") or move.reach > 0.88)
	var dyno := move != null and move.has_tag("dyno")
	var dip := 0.0
	var anticipation := 0.0
	if dyno:
		dip = 0.12
		anticipation = 0.25
	elif lunge:
		dip = 0.06
		anticipation = 0.18
	var latch := now
	if hand != &"" and _moved(hand, goal):
		var d := _current(hand).distance_to(goal[hand])
		var start := now + anticipation + (0.08 if not dyno else 0.18)
		var dur := clampf(0.16 + d * 0.2, 0.2, 0.34)
		if lunge:
			dur = 0.3
		if dyno:
			dur = 0.24
		latch = start + dur
		var side := -1.0 if hand == &"lh" else 1.0
		var arc := Vector2(side * clampf(d * 0.12, 0.03, 0.1), 0.02)
		_track(hand, [_current(hand), _current(hand), goal[hand]], [now, start, latch], arc)
		_event(latch, {"kind": "latch", "hand": hand, "big": lunge or dyno})
		# The hips lead and arrive with the hand, dipping first on a big one.
		var h0 := _current(&"hip")
		if dip > 0.0:
			var low := h0 + Vector2(0, -dip)
			_track(&"hip", [h0, low, low, pose.hip], [now, now + anticipation * 0.85, now + anticipation, latch - 0.02], Vector2.ZERO)
		else:
			_track(&"hip", [h0, pose.hip], [now, latch - 0.03], Vector2.ZERO)
		# The other hand: if it changes too (a match), after this one.
		var other: StringName = &"rh" if hand == &"lh" else &"lh"
		if _moved(other, goal):
			_track(other, [_current(other), goal[other]], [latch + 0.05, latch + 0.3], Vector2(0, 0.03))
		# Feet step up after the latch, one at a time; a dyno cuts them loose first.
		var step_at := latch + 0.05
		for f in FEET:
			var fside := -1.0 if f == &"lf" else 1.0
			if dyno:
				var loose: Vector2 = pose.hip + Vector2(fside * 0.12, -0.86)
				_track(f, [_current(f), _current(f), loose, loose, goal[f]],
					[now, latch - 0.06, latch + 0.12, latch + 0.3 + (0.12 if f == &"rf" else 0.0), latch + 0.55 + (0.12 if f == &"rf" else 0.0)], Vector2(0, 0.06))
			elif _moved(f, goal):
				_track(f, [_current(f), goal[f]], [step_at, step_at + 0.18], Vector2(fside * 0.02, 0.05))
				_event(step_at + 0.18, {"kind": "foot", "limb": f})
				step_at += 0.13
		if move.load:
			load = move.load.duplicate()
	else:
		# Any other change (a hand off to the rope or the rack, a stance, a
		# hip shift): everything eases over, hands a little behind the hips.
		var h0 := _current(&"hip")
		if h0.distance_to(pose.hip) > 0.004:
			_track(&"hip", [h0, pose.hip], [now, now + 0.28], Vector2.ZERO)
		var delay := 0.04
		for l in V2Pose.LIMBS:
			if _moved(l, goal):
				var lift := Vector2(0, 0.03) if l in FEET else Vector2((-1.0 if l == &"lh" else 1.0) * 0.03, 0.03)
				_track(l, [_current(l), goal[l]], [now + delay, now + delay + 0.24], lift)
				delay += 0.06
	lean_goal = Vector2.ZERO


func _moved(l: StringName, goal: Dictionary) -> bool:
	return _track_end(l).distance_to(goal[l]) > 0.004


func _track_end(key: StringName) -> Vector2:
	if _tracks.has(key):
		var pts: Array = _tracks[key].pts
		return pts[pts.size() - 1]
	return hip if key == &"hip" else ends[key]


func _current(key: StringName) -> Vector2:
	return _eval(key) if _tracks.has(key) else (hip if key == &"hip" else ends[key])


func _track(key: StringName, pts: Array, at: Array, arc: Vector2) -> void:
	_tracks[key] = {"pts": pts, "at": at, "arc": arc}


func _event(at: float, e: Dictionary) -> void:
	e["at"] = at
	_events.append(e)
	_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.at < b.at)


## Where [param key]'s track is now.
func _eval(key: StringName) -> Vector2:
	var tr: Dictionary = _tracks[key]
	var pts: Array = tr.pts
	var at: Array = tr.at
	if time <= at[0]:
		return pts[0]
	var last := pts.size() - 1
	if time >= at[last]:
		return pts[last]
	for i in last:
		if time <= at[i + 1]:
			var span: float = at[i + 1] - at[i]
			var s: float = 1.0 if span <= 0.0 else (time - float(at[i])) / span
			var e := _ease(key, s)
			var p: Vector2 = (pts[i] as Vector2).lerp(pts[i + 1], e)
			if last == 1 or i == last - 1:
				p += (tr.arc as Vector2) * sin(PI * s)
			return p
	return pts[last]


## Hands and feet come in fast and stop hard; the hips ease in and out.
func _ease(key: StringName, s: float) -> float:
	if key == &"hip":
		return s * s * (3.0 - 2.0 * s)
	# Slow off the hold, quick into the next: velocity peaks near arrival.
	return s * s * (2.2 - 1.2 * s)


## Plays [param pts] (offsets from the hips or from the limb's own end) on
## [param l] over [param dur] seconds, easing in from and back to where the
## limb belongs.
func gesture(l: StringName, pts: Array, dur: float, rel: StringName = &"hip", delay := 0.0) -> void:
	var at: Array = []
	for i in pts.size():
		at.append(time + delay + dur * float(i) / maxf(pts.size() - 1, 1))
	_gestures[l] = {"pts": pts, "at": at, "rel": rel, "start": time + delay, "end": time + delay + dur}


func gesturing(l: StringName) -> bool:
	return _gestures.has(l)


func _gesture_pos(l: StringName, base: Vector2) -> Vector2:
	var g: Dictionary = _gestures[l]
	var pts: Array = g.pts
	var at: Array = g.at
	var origin: Vector2 = hip if g.rel == &"hip" else base
	var p: Vector2 = origin + (pts[pts.size() - 1] as Vector2)
	if time <= at[0]:
		p = origin + (pts[0] as Vector2)
	else:
		for i in pts.size() - 1:
			if time <= at[i + 1]:
				var s: float = (time - float(at[i])) / maxf(float(at[i + 1]) - float(at[i]), 0.001)
				s = s * s * (3.0 - 2.0 * s)
				p = origin + (pts[i] as Vector2).lerp(pts[i + 1], s)
				break
	# Ease in from and out to the limb's own place.
	var env := clampf((time - float(g.start)) / 0.1, 0.0, 1.0) * clampf((float(g.end) - time) / 0.12 + 0.0, 0.0, 1.0)
	if g.rel == &"base":
		env = 1.0
	env = env * env * (3.0 - 2.0 * env)
	return base.lerp(p, env)


## Plays the fall in [param fall]: the session already holds the settled pose.
func start_fall(fall: V2Fall, catch_at: Vector2) -> void:
	if not _fall.is_empty() and _fall.fall == fall:
		return
	var start := _current(&"hip")
	var end := fall.settle_pos
	var drop := maxf(fall.drop_m, start.y - end.y)
	var stretch := clampf(drop * 0.07, 0.08, 0.4)
	var free := clampf(sqrt(2.0 * maxf(drop, 0.2) / 9.8) / 0.85, 0.22, 0.95)
	var swing_amp := fall.swing_m * signf(start.x - catch_at.x) if fall.swing_m > 0.0 else clampf(start.x - end.x, -1.5, 1.5)
	var rope_len := clampf(catch_at.distance_to(end), 1.0, 12.0)
	var from_ends := {}
	for l in V2Pose.LIMBS:
		from_ends[l] = _current(l) - start
	_tracks.clear()
	_gestures.clear()
	_events.clear()
	_fall = {"fall": fall, "t0": time, "start": start, "end": end, "stretch": stretch, "free": free,
		"swing": swing_amp, "omega": sqrt(9.8 / rope_len), "from": from_ends}
	fx.append({"pos": fall.from_pos, "kind": "dust", "size": 1.0})


func falling() -> bool:
	return not _fall.is_empty()


## How long the fall plays (after it, the climber hangs as posed).
const FALL_PEEL := 0.12
const FALL_SETTLE := 0.6


func _fall_length() -> float:
	return FALL_PEEL + float(_fall.free) + 1.6 + FALL_SETTLE


func _step_fall() -> void:
	var f := _fall
	var t := time - float(f.t0)
	var start: Vector2 = f.start
	var end: Vector2 = f.end
	var catch_y: float = end.y - float(f.stretch)
	var swing: float = f.swing
	var free: float = f.free
	var after := t - FALL_PEEL - free
	var shape := {}
	var hang := ClimberRig.settle_free(target, _pose_ends(target)) if target else {}
	if t < FALL_PEEL:
		# Peel: the hands open, the body tips back off the wall.
		var s := t / FALL_PEEL
		hip = start + Vector2(0, -0.04 * s)
		for l in V2Pose.LIMBS:
			shape[l] = hip + (f.from[l] as Vector2) + Vector2((-1.0 if l in [&"lh", &"lf"] else 1.0) * 0.04 * s, -0.03 * s)
	elif after < 0.0:
		# The drop: gravity's square, arms trailing up, legs a little bent.
		var s := (t - FALL_PEEL) / free
		hip = Vector2(lerpf(start.x, end.x + swing, s), lerpf(start.y - 0.04, catch_y, s * s))
		var fl := sin(time * 23.0) * 0.03
		var trail := {&"lh": Vector2(-0.33, 0.5 + fl), &"rh": Vector2(0.33, 0.56 - fl), &"lf": Vector2(-0.2, -0.74), &"rf": Vector2(0.24, -0.68 + fl)}
		var w := clampf(s * 3.0, 0.0, 1.0)
		for l in V2Pose.LIMBS:
			shape[l] = hip + (f.from[l] as Vector2).lerp(trail[l], w)
	else:
		# Caught: the rope stretches and bounces, the pendulum swings out
		# and damps, the body folds at the harness then hangs.
		if caught_at < float(f.t0):
			caught_at = time
		var omega: float = f.omega
		var x := end.x + swing * cos(omega * after) * exp(-0.25 * omega * after)
		var y := end.y - float(f.stretch) * cos(TAU * 1.5 * after) * exp(-2.2 * after)
		hip = Vector2(x, y)
		var fold := clampf(1.0 - after / 0.35, 0.0, 1.0) * clampf(after / 0.08, 0.0, 1.0)
		var settle := clampf((after - 1.6) / FALL_SETTLE, 0.0, 1.0)
		settle = settle * settle * (3.0 - 2.0 * settle)
		for l in V2Pose.LIMBS:
			var side := -1.0 if l in [&"lh", &"lf"] else 1.0
			var hang_rel: Vector2 = (hang.get(l, end) as Vector2) - end
			var folded := Vector2(side * 0.3, 0.12) if l in HANDS else Vector2(side * 0.2, -0.45)
			var rel := hang_rel.lerp(folded, fold)
			shape[l] = hip + rel
			if settle > 0.0:
				shape[l] = (shape[l] as Vector2).lerp(hang.get(l, end), settle)
		if settle > 0.0:
			hip = hip.lerp(end, settle)
	for l in V2Pose.LIMBS:
		ends[l] = shape[l]
	if t >= _fall_length():
		_fall = {}
		if target:
			hip = target.hip
			for l in V2Pose.LIMBS:
				ends[l] = hang[l]


## The torso's lean back during a fall (radians).
func fall_tilt() -> float:
	if _fall.is_empty():
		return 0.0
	var t := time - float(_fall.t0)
	if t < FALL_PEEL:
		return 0.25 * t / FALL_PEEL
	var after := t - FALL_PEEL - float(_fall.free)
	if after < 0.0:
		return 0.25
	return 0.25 * clampf(1.0 - after / 0.5, 0.0, 1.0)


## Advances [param delta] seconds.
func step(delta: float) -> void:
	time += delta
	while not _events.is_empty() and _events[0].at <= time:
		_fire(_events.pop_front())
	if not _fall.is_empty():
		_step_fall()
	else:
		for key: StringName in _tracks.keys():
			var p := _eval(key)
			if key == &"hip":
				hip = p
			else:
				ends[key] = p
			var at: Array = _tracks[key].at
			if time >= at[at.size() - 1]:
				_tracks.erase(key)
	for l: StringName in _gestures.keys():
		if time >= float(_gestures[l].end):
			_gestures.erase(l)
	# Joints swap their bend over BEND_TIME, never in one frame.
	for l in V2Pose.LIMBS:
		bend[l] = move_toward(bend[l], bend_goal[l], delta * 2.0 / BEND_TIME)
	if target:
		twist = move_toward(twist, float(target.facing) * 0.85, delta * 3.0)
	# Deadpoint sag, the hip nudge toward an aimed shift, the look.
	_sag_v += (-_sag * 160.0 - _sag_v * 2.0 * sqrt(160.0)) * delta
	_sag += _sag_v * delta
	lean = lean.lerp(lean_goal, clampf(delta * 8.0, 0.0, 1.0))
	_look_v += ((look_goal - look) * 60.0 - _look_v * 2.0 * sqrt(60.0)) * delta
	look += _look_v * delta
	# Swinging gear: a damped pendulum pushed by the hips' acceleration.
	var v := (hip - _last_hip) / maxf(delta, 0.001)
	var acc := (v - _last_hip_v) / maxf(delta, 0.001)
	_last_hip = hip
	_last_hip_v = v
	_swing_v += (-_swing * 90.0 - _swing_v * 3.0 - acc.limit_length(40.0) * 0.012) * delta
	_swing += _swing_v * delta
	_swing = _swing.limit_length(0.06)
	exertion = maxf(exertion - delta * 0.12, 0.0)
	var puff := clampf(maxf(maxf(pump, 1.0 - gas), exertion), 0.0, 1.0)
	if signs.has("breath"):
		puff = maxf(float(signs.breath), exertion)
	var rate := lerpf(0.33, 1.2, puff)
	_breath_phase = fmod(_breath_phase + rate * delta, 1.0)


func _fire(e: Dictionary) -> void:
	match str(e.kind):
		"latch":
			_sag_v += Vector2(0, -0.32 if e.big else -0.18)
			exertion = minf(exertion + (0.35 if e.big else 0.12), 1.0)
			fx.append({"pos": ends[e.hand], "kind": "chalk", "size": 1.2 if e.big else 0.7, "limb": e.hand})
		"foot":
			fx.append({"pos": ends[e.limb], "kind": "grit", "size": 0.5, "limb": e.limb})


## The breath, 0..1 (the ribs at the top of a breath).
func breath() -> float:
	return 0.5 - 0.5 * cos(TAU * _breath_phase)


## Secondary swing for dangling gear and hair (metres).
func swing() -> Vector2:
	return _swing


## Pump tremor on limb [param l]'s elbow or knee: bursts at ~10 Hz, bigger
## on loaded limbs and higher pump. Never on the contact itself.
func tremor(l: StringName) -> Vector2:
	var p := clampf((pump - 0.25) / 0.75, 0.0, 1.0)
	if signs.has("tremble"):
		p = clampf(float(signs.tremble), 0.0, 1.0)
	if p <= 0.0 or kinds.get(l, &"free") != &"hold" and kinds.get(l, &"free") != &"smear":
		return Vector2.ZERO
	var seed := float(V2Pose.LIMBS.find(l)) * 1.7
	var burst := clampf(sin(time * 1.3 + seed) * 0.8 + sin(time * 0.47 + seed * 2.1) * 0.6 + p * 0.9 - 0.4, 0.0, 1.0)
	var amp := pow(p, 1.5) * (0.4 + float(load.get(l, 0.25)) * 2.4) * 0.011 * burst
	return Vector2(sin(time * 62.0 + seed), sin(time * 71.0 + seed * 3.0)) * amp


## Puts the animation into [param rig]: hips, ends (with gestures), twist,
## bends, look, breath, posture decay, tremor, the fall's lean.
func apply(rig: ClimberRig) -> void:
	rig.hip = hip + _sag + (lean if _fall.is_empty() else Vector2.ZERO) + Vector2(0, -0.025 * float(signs.get("hip_sag", 0.0)))
	for l in V2Pose.LIMBS:
		var e: Vector2 = ends[l]
		if _gestures.has(l):
			e = _gesture_pos(l, e)
		rig.ends[l] = e
	rig.twist = twist
	rig.look = look
	rig.breath = breath()
	rig.hunch = maxf(clampf((pump - 0.45) / 0.55, 0.0, 1.0) * 0.8, float(signs.get("bonked", 0.0)))
	rig.torso_tilt = fall_tilt()
	for l in V2Pose.LIMBS:
		rig.bend[l] = bend[l]
		var push := tremor(l)
		var wing := float(signs.get("chicken_wing", clampf((pump - 0.55) / 0.45, 0.0, 1.0)))
		if l in HANDS and wing > 0.0:
			# Chicken wings: the elbows creep out as the forearms go.
			push += Vector2((-1.0 if l == &"lh" else 1.0) * wing * 0.032, 0.01 * wing)
		rig.joint_push[l] = push
	rig.solve()


## Works out the bends the limbs want now and eases toward them.
func update_bends(tags: PackedStringArray) -> void:
	var rig := _bend_rig()
	for l in V2Pose.LIMBS:
		bend_goal[l] = rig.bend_wanted(l, tags)


func _bend_rig() -> ClimberRig:
	var rig := ClimberRig.new()
	rig.hip = hip
	rig.twist = twist
	for l in V2Pose.LIMBS:
		rig.ends[l] = ends[l]
	return rig


## True once nothing is moving: no tracks, gestures, fall or springs.
func idle() -> bool:
	return _tracks.is_empty() and _gestures.is_empty() and _fall.is_empty() and _sag.length() < 0.001 and _swing.length() < 0.001
