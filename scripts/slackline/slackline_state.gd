class_name SlacklineState
extends RefCounted
## The rules of the Camp 4 slackline, apart from its drawing so tests can walk
## it. You walk on by yourself; the line tips you one way or the other, and the
## arrow keys lean you back. Lean too far and you step off.
##
## Balance works like an upside-down pendulum: the further you lean, the faster
## you tip ([member LINES] "tip"), the line damps a little of it ([constant
## DAMP]), and your arms push back ([constant PUSH]). Every so often the line
## bucks under you, harder toward the middle where it sags most. A buck is
## felt coming ([constant BUCK_WARN] seconds ahead, see [method warning]), so
## a quick hand can lean into it before it lands. On the long line the wind
## gusts too, with more warning and a steadier shove.
##
## Scoring: steps earn points, multiplied by your flow (how long you've stayed
## steady, see [method flow]); tricks earn more; pulling back from the very
## edge is a close call; reaching the far tree adds a bonus. A crossing wins a
## bronze medal, and a high enough score silver or gold (each line's
## "silver" and "gold").

enum Status { WALKING, FELL, WALKED }

## The lines strung at Camp 4, easiest first. walk_time is seconds to cross
## at a steady pace; tip how fast a lean grows; buck_gap and buck_kick the
## line's bucking (seconds between, and how hard); gusts whether the wind
## blows; sag in screen pixels at the middle; span the screen x of the two
## trees and line_y the height of the line (the screen draws from these).
## "needs" is the unlock that opens it.
const LINES: Array[Dictionary] = [
	{"id": "short", "name": "The Short Line", "meters": 10, "height": "knee-high",
		"walk_time": 12.0, "tip": 2.0, "buck_gap": Vector2(1.0, 2.0), "buck_kick": Vector2(0.3, 0.9), "gusts": false,
		"sag": 8.0, "span": Vector2(126, 354), "line_y": 196.0, "silver": 3000, "gold": 5000, "needs": "",
		"blurb": "Knee-high and tight, strung between two young pines by the picnic tables. Where everybody starts."},
	{"id": "camp4", "name": "The Camp 4 Line", "meters": 20, "height": "waist-high",
		"walk_time": 22.0, "tip": 2.4, "buck_gap": Vector2(0.7, 1.8), "buck_kick": Vector2(0.4, 1.45), "gusts": false,
		"sag": 16.0, "span": Vector2(62, 418), "line_y": 166.0, "silver": 3500, "gold": 5800, "needs": "",
		"blurb": "The classic, between two big ponderosas. Somebody's left a six-pack of King Cobra on the stump at the far end."},
	{"id": "long", "name": "The Long Line", "meters": 35, "height": "head-high",
		"walk_time": 32.0, "tip": 2.6, "buck_gap": Vector2(0.65, 1.6), "buck_kick": Vector2(0.45, 1.5), "gusts": true,
		"sag": 26.0, "span": Vector2(30, 450), "line_y": 140.0, "silver": 3800, "gold": 6000, "needs": "slackline_walked",
		"blurb": "Long, saggy and high, across the whole clearing. The wind off the wall finds you halfway."},
]

## The id of the line you carry (see [method travel_line]), and how long it
## must be before the wind finds it.
const TRAVEL := "travel"
const TRAVEL_WINDY := 24

const DAMP := 1.6
## How hard holding an arrow key pushes you back upright.
const PUSH := 4.5
## Past this lean you stop to steady yourself instead of stepping on.
const STEADY_LEAN := 0.55
## Inside this lean you're steady: your flow builds.
const CENTER := 0.35
## Past this lean you're nearly off. Coming back from it is a close call.
const EDGE := 0.85
## Seconds of warning before a buck lands, and before a gust.
const BUCK_WARN := 0.45
const GUST_WARN := 1.0
## Gusts on a windy line: seconds between, how long they blow, how hard.
const GUST_GAP := Vector2(5.0, 9.0)
const GUST_TIME := Vector2(1.2, 2.0)
const GUST_FORCE := 1.5
## The first steps off the tree are calm, so you can find your feet.
const CALM_START := 0.06

## Points: a whole crossing at flow x1, a finished line, a close call.
const DISTANCE_POINTS := 1000
const FINISH_POINTS := 500
const CLOSE_CALL_POINTS := 100
## Flow: seconds of steadiness for x2 and x3. Wobbling past STEADY_LEAN
## starts it over.
const FLOW_STEPS := [2.0, 5.0]

## Tricks, done one after another along the line. While you're in one you
## stop walking, your arms are busy (less push) and the line is livelier; hold
## it steady to the end and it lands.
const TRICKS: Array[Dictionary] = [
	{"id": "drop_knee", "name": "Drop knee", "time": 1.3, "points": 150},
	{"id": "turnaround", "name": "Turnaround", "time": 1.1, "points": 200},
	{"id": "sit", "name": "Sit down", "time": 1.6, "points": 250},
]
const TRICK_PUSH := 0.7
const TRICK_TIP := 1.15
## Seconds after one trick before the next can start, and how much further
## along the line you must walk first (so tricks can't be strung forever).
const TRICK_REST := 0.8
const TRICK_SPACING := 0.14

var line: Dictionary
var status := Status.WALKING
## -1 (all the way left, falling) to 1 (all the way right, falling).
var lean := 0.0
var lean_speed := 0.0
## 0 at the first tree, 1 at the far one.
var progress := 0.0
var time := 0.0
## The side you fell to: -1 left, 1 right (0 while you're on the line).
var fell_to := 0

## Score so far, and what it's made of (for the results card).
var score := 0
var distance_points := 0.0
var trick_points := 0
var tricks_landed := 0
var close_calls := 0
var finish_points := 0
## Seconds you've been steady without a wobble, and the longest such run.
var steady_time := 0.0
var best_flow := 1
## Times you leaned past STEADY_LEAN.
var wobbles := 0

## The trick in progress (an entry of TRICKS, empty if none), and its clock.
var trick: Dictionary = {}
var trick_age := 0.0
var next_trick := 0
var _trick_from := 0.0

## Events since the screen last asked (see [method take_events]): each is
## {"kind": "buck"|"gust"|"wobble"|"close_call"|"flow"|"trick"|"trick_fail"|
## "milestone"|"fell"|"walked", ...}.
var _events: Array[Dictionary] = []

var _next_buck := 1.0
var _buck_side := 0.0
var _buck_kick := 0.0
var _next_gust := 0.0
var _gust_side := 0.0
var _gust_left := 0.0
var _trick_rest := 0.0
var _was_edge := false
var _was_wobbling := false
var _milestone := 0
var _rng := RandomNumberGenerator.new()


## [param line_id] picks one of LINES (the Camp 4 line if it's unknown), or
## [param custom] is a whole line of its own (see [method travel_line]). A
## [param seed] of 0 or more makes the line buck the same way every time.
func _init(seed := -1, line_id := "camp4", custom := {}) -> void:
	line = custom if not custom.is_empty() else line_by_id(line_id)
	if seed >= 0:
		_rng.seed = seed
	else:
		_rng.randomize()
	_schedule_buck()
	_next_gust = _rng.randf_range(GUST_GAP.x * 0.5, GUST_GAP.y * 0.6)
	# never perfectly upright, or there'd be nothing to catch at first
	lean = _rng.randf_range(0.04, 0.08) * (1.0 if _rng.randf() < 0.5 else -1.0)


## Your own slackline (TravelSlackline), rigged [param meters] long between
## two trees somewhere in the park, [param where] (for its blurb). It sits
## between the short line and the long one: a longer rig sags more, bucks
## harder, is strung higher on screen, and past [constant TRAVEL_WINDY]
## meters the wind finds it.
static func travel_line(meters: int, where := "") -> Dictionary:
	var short := line_by_id("short")
	var long := line_by_id("long")
	var t := clampf(float(meters - int(short.meters)) / float(int(long.meters) - int(short.meters)), 0.0, 1.0)
	var height := "knee-high" if t < 0.3 else ("waist-high" if t < 0.7 else "head-high")
	return {"id": TRAVEL, "name": "Your Slackline", "meters": meters, "height": height,
		"walk_time": lerpf(short.walk_time, long.walk_time, t), "tip": lerpf(short.tip, long.tip, t),
		"buck_gap": (short.buck_gap as Vector2).lerp(long.buck_gap, t), "buck_kick": (short.buck_kick as Vector2).lerp(long.buck_kick, t),
		"gusts": meters >= TRAVEL_WINDY, "sag": lerpf(short.sag, long.sag, t),
		"span": (short.span as Vector2).lerp(long.span, t).round(), "line_y": roundf(lerpf(short.line_y, long.line_y, t)),
		"silver": int(lerpf(short.silver, long.silver, t) / 100.0) * 100, "gold": int(lerpf(short.gold, long.gold, t) / 100.0) * 100,
		"needs": "", "young": t < 0.3,
		"blurb": "Your own line, rigged %d m between two trees%s." % [meters, " at " + where if where != "" else ""]}


static func line_by_id(id: String) -> Dictionary:
	for l: Dictionary in LINES:
		if l.id == id:
			return l
	return LINES[1]


## How much the line sags and bounces where you stand: 0 at the trees, 1 in
## the middle.
func sag() -> float:
	return sin(progress * PI)


## The multiplier your steadiness has earned: 1, 2 or 3.
func flow() -> int:
	var f := 1
	for need: float in FLOW_STEPS:
		if steady_time >= need:
			f += 1
	return f


## A shove that's on its way: {"side": -1 or 1, "t": 0 just felt .. 1 now,
## "kind": "buck" or "gust"}, or empty. A gust that's blowing reports t = 1.
func warning() -> Dictionary:
	if status != Status.WALKING:
		return {}
	if line.gusts and _gust_left > 0.0:
		return {"side": int(_gust_side), "t": 1.0, "kind": "gust"}
	if line.gusts and _next_gust <= GUST_WARN and _gust_side != 0.0:
		return {"side": int(_gust_side), "t": 1.0 - _next_gust / GUST_WARN, "kind": "gust"}
	if _buck_side != 0.0 and _next_buck <= BUCK_WARN and progress > CALM_START:
		return {"side": int(_buck_side), "t": 1.0 - _next_buck / BUCK_WARN, "kind": "buck"}
	return {}


## True while the wind is actually blowing.
func gusting() -> bool:
	return line.gusts and _gust_left > 0.0


## The next trick in the line's order, and whether it can start now (steady,
## not mid-trick, rested since the last one).
func next_trick_info() -> Dictionary:
	return TRICKS[next_trick % TRICKS.size()]


func can_trick() -> bool:
	return status == Status.WALKING and trick.is_empty() and _trick_rest <= 0.0 \
		and absf(lean) < CENTER and progress > CALM_START and progress < 0.97 \
		and progress >= _trick_from


## Starts the next trick if it can. Returns true if it started.
func start_trick() -> bool:
	if not can_trick():
		return false
	trick = next_trick_info()
	trick_age = 0.0
	_trick_from = progress + TRICK_SPACING
	return true


## Moves time on by [param delta] seconds. [param push] is the player's input:
## -1 holding left, 1 holding right, 0 neither (or both).
func step(delta: float, push: float) -> void:
	if status != Status.WALKING:
		return
	time += delta
	var in_trick := not trick.is_empty()
	if progress > CALM_START:
		_next_buck -= delta
		if _next_buck <= 0.0:
			lean_speed += _buck_kick * _buck_side
			_event({"kind": "buck", "side": int(_buck_side), "kick": _buck_kick})
			_schedule_buck()
		if line.gusts:
			_update_gust(delta)
	# a constant small shiver, more in the middle
	lean_speed += _rng.randf_range(-1.0, 1.0) * 0.6 * delta * (0.5 + sag())
	var tip: float = line.tip * (TRICK_TIP if in_trick else 1.0)
	var arms := PUSH * (TRICK_PUSH if in_trick else 1.0)
	var wind := GUST_FORCE * _gust_side if _gust_left > 0.0 else 0.0
	var accel := tip * lean - DAMP * lean_speed + arms * clampf(push, -1.0, 1.0) + wind
	lean_speed += accel * delta
	lean += lean_speed * delta
	if absf(lean) >= 1.0:
		lean = signf(lean)
		fell_to = int(signf(lean))
		status = Status.FELL
		if in_trick:
			_event({"kind": "trick_fail", "name": trick.name})
			trick = {}
		_event({"kind": "fell", "side": fell_to})
		return
	_score_balance(delta)
	if in_trick:
		_update_trick(delta)
	else:
		_trick_rest -= delta
		if absf(lean) < STEADY_LEAN:
			var before := progress
			progress = minf(1.0, progress + delta / float(line.walk_time))
			distance_points += (progress - before) * DISTANCE_POINTS * flow()
			var quarter := int(progress * 4.0)
			if quarter > _milestone and quarter < 4:
				_milestone = quarter
				_event({"kind": "milestone", "quarter": quarter})
	score = int(distance_points) + trick_points + close_calls * CLOSE_CALL_POINTS + finish_points
	if progress >= 1.0:
		status = Status.WALKED
		finish_points = FINISH_POINTS
		score += FINISH_POINTS
		_event({"kind": "walked"})


## Steadiness, wobbles and close calls.
func _score_balance(delta: float) -> void:
	var a := absf(lean)
	var flow_before := flow()
	if a >= STEADY_LEAN:
		if not _was_wobbling:
			wobbles += 1
			_event({"kind": "wobble"})
		_was_wobbling = true
		steady_time = 0.0
	else:
		_was_wobbling = false
		if a < CENTER:
			steady_time += delta
	if a >= EDGE:
		_was_edge = true
	elif _was_edge and a < CENTER:
		_was_edge = false
		close_calls += 1
		_event({"kind": "close_call"})
	if flow() > flow_before:
		_event({"kind": "flow", "flow": flow()})
	best_flow = maxi(best_flow, flow())


func _update_trick(delta: float) -> void:
	trick_age += delta
	if absf(lean) >= STEADY_LEAN:
		_event({"kind": "trick_fail", "name": trick.name})
		trick = {}
		_trick_rest = TRICK_REST
		return
	if trick_age >= float(trick.time):
		var points := int(trick.points) * flow()
		trick_points += points
		tricks_landed += 1
		_event({"kind": "trick", "name": trick.name, "points": points})
		trick = {}
		next_trick += 1
		_trick_rest = TRICK_REST


func _update_gust(delta: float) -> void:
	if _gust_left > 0.0:
		_gust_left -= delta
		if _gust_left <= 0.0:
			_gust_side = 0.0
			_next_gust = _rng.randf_range(GUST_GAP.x, GUST_GAP.y)
		return
	if _gust_side == 0.0:
		_gust_side = 1.0 if _rng.randf() < 0.5 else -1.0
	_next_gust -= delta
	if _next_gust <= 0.0:
		_gust_left = _rng.randf_range(GUST_TIME.x, GUST_TIME.y)
		_event({"kind": "gust", "side": int(_gust_side)})


## Picks when the next buck lands, which way, and how hard.
func _schedule_buck() -> void:
	var gap: Vector2 = line.buck_gap
	var kick: Vector2 = line.buck_kick
	_next_buck = _rng.randf_range(gap.x, gap.y) * (1.0 - 0.3 * sag())
	_buck_kick = _rng.randf_range(kick.x, kick.y) * (0.45 + 0.55 * sag())
	# the line mostly throws you further the way you're already going
	_buck_side = signf(lean) if _rng.randf() < 0.65 and lean != 0.0 else (1.0 if _rng.randf() < 0.5 else -1.0)


func _event(e: Dictionary) -> void:
	_events.append(e)


## The events since the last call, oldest first.
func take_events() -> Array[Dictionary]:
	var out := _events
	_events = []
	return out


## How far along you got, as a whole percent.
func percent() -> int:
	return int(floor(progress * 100.0))


## 0 no medal, 1 bronze (crossed), 2 silver, 3 gold.
func medal() -> int:
	return medal_for(line, score, status == Status.WALKED)


static func medal_for(l: Dictionary, points: int, crossed: bool) -> int:
	if not crossed:
		return 0
	if points >= int(l.gold):
		return 3
	if points >= int(l.silver):
		return 2
	return 1
