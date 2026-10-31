class_name SlacklineMinigame
extends CanvasLayer
## The Camp 4 slacklines, seen from the side: webbing strung between pines in
## the campground, the walls across the Valley behind, climbers watching from
## the boulders, and a six-pack of King Cobra on the stump at the end of the
## Camp 4 line for whoever walks it first. The rules live in SlacklineState,
## the pictures in SlacklineArt and the overlays in SlacklineHud; this runs
## the screen and turns the keys into a push.
##
## Pick a line (three, each harder, the last unlocked by walking the Camp 4
## line), step on, and walk. Left/Right lean you back the other way; interact
## does a trick when you're steady. Each crossing wins a medal by score, and
## the best score and medal for each line are kept (Perks.record).
##
## Controls: Up/Down pick a line, interact walks it (and does tricks on it),
## cancel steps off, goes back to the lines, or leaves.
##
## The same screen walks the slackline you carry (TravelSlackline), rigged
## between two trees anywhere in the park: give [method setup] the line, and
## there's no choosing, no crowd and no campfire, just you and the trees.

## Emitted when the player leaves the screen. [param walked] is true if they
## have ever walked the Camp 4 line end to end.
signal finished(walked: bool)

const UI := preload("res://scripts/climb/art/climb_ui.gd")
const HUD := preload("res://scripts/slackline/slackline_hud.gd")
const ART := preload("res://scripts/slackline/slackline_art.gd")

enum Phase { SELECT, READY, WALK, FALL, RESULT }

const SCREEN := Vector2(480, 270)
## The prize, the line it's on, and the unlock that marks it as won (so it's
## given once; it also opens the long line).
const PRIZE := "king_cobra"
const PRIZE_COUNT := 6
const PRIZE_LINE := "camp4"
const WON := "slackline_walked"
## Gold on every line.
const LEGEND := "slackline_legend"
## Gold on any one of the Camp 4 lines (Wren's quest, wren_slackline, asks
## for it).
const GOLD := "slackline_gold"
const GOLD_QUEST := "wren_slackline"
## Game minutes each walk takes, warm-up and all.
const MINUTES_PER_WALK := 10
## Seconds from stepping onto the line to walking.
const READY_TIME := 1.5
## Time runs this much slower while you're right at the edge, so a quick
## hand can still save it.
const EDGE_SLOWMO := 0.55
const OUTLINE := Color("15141c")
const WEB := Color("d8a63b")
const WEB_LIT := Color("f1cf6a")
const WEB_DARK := Color("ad7a22")
const PAD := Color("437f45")
const STEEL := Color("bdb8ae")
## What the climbers watching call out. Keys are SlacklineState events and
## the screen's own moments.
const BANTER := {
	"start": ["Eyes on the far tree!", "Soft knees. Breathe.", "Don't look at your feet!", "Arms up, shoulders loose!"],
	"halfway": ["Halfway! Smooth!", "That's the saggy bit. Easy now!", "Keep it going!"],
	"close_call": ["Whoa! Saved it!", "How are you still on?!", "Nice save!"],
	"trick": ["Yeah! %s!", "Style! %s!", "Do it again!"],
	"gust": ["Watch the wind!", "Here comes a gust!"],
	"fell_early": ["Shake it off. Again!", "Everybody falls at first.", "The line wins that one."],
	"fell_late": ["So close!", "Ooh! Almost had it!", "Next time, for sure."],
	"walked": ["All the way! Yeah!", "Sent it!", "Look at that!"],
	"prize": ["That six-pack's yours!"],
}

## The line being walked (or last walked).
var state: SlacklineState
## The id of the line picked (see SlacklineState.LINES).
var line_id := "camp4"
## True once the Camp 4 line has been walked end to end (this visit or before).
var walked := false
## True if this visit won the six-pack.
var won_prize := false
## Walks started this visit.
var attempts := 0
## The last walk's medal (0 none .. 3 gold) and whether it set a best score.
var last_medal := 0
var new_best := false
## True on the walk that won the six-pack.
var prize_now := false
## The line you carry, rigged somewhere (SlacklineState.travel_line), or
## empty at Camp 4.
var travel: Dictionary = {}

var _canvas: Control
var _phase := Phase.SELECT
var _seed := -1
var _time := 0.0
var _phase_age := 0.0
var _chosen := 1
var _push := 0.0
var _ghost := 0.0
var _bounce := 0.0
var _quiver := 0.0
var _shake := 0.0
var _fall_t := 0.0
var _shown_score := 0.0
var _score_pulse := 0.0
var _slowmo := 1.0
var _best_pct := 0
var _popups: Array[Dictionary] = []
var _result := {}
## Rows of the results card counted so far, and whether its medal has landed.
var _tallied := 0
var _stamped := false
var _fx := ClimbFx.new()
var _rng := RandomNumberGenerator.new()
var _pal: Dictionary
var _back_tex: Texture2D
var _clouds: Array[Texture2D] = []
var _trees := {}
var _stump_tex: Texture2D
var _stump_taken_tex: Texture2D
var _crowd: Array[Dictionary] = []
var _speech := {"text": "", "who": 0, "age": 99.0}
var _leaf_wait := 0.0
var _kit := {}


## Call before adding the node to the tree. A [param seed] of 0 or more makes
## the lines buck the same way every time (for tests). [param travel_line]
## walks your own rigged line instead of the Camp 4 ones.
func setup(seed := -1, travel_line := {}) -> void:
	_seed = seed
	travel = travel_line


func _ready() -> void:
	layer = 20
	UiScale.layer(self)
	add_to_group("climb_screen") # Sound treats it like the climbing screen
	_canvas = Control.new()
	UiScale.fit(_canvas)
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_draw_screen)
	add_child(_canvas)
	var snap := ColorRect.new()
	UiScale.fit(snap)
	snap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	snap.material = ShaderMaterial.new()
	snap.material.shader = load("res://assets/shaders/palette_snap.gdshader")
	add_child(snap)
	if _seed >= 0:
		_rng.seed = _seed
	else:
		_rng.randomize()
	walked = QuestLog.is_unlocked(WON)
	# a gold won before the quest that asks for one still counts
	if not QuestLog.is_unlocked(GOLD) and SlacklineState.LINES.any(func(l: Dictionary) -> bool: return medal_for(l.id) >= 3):
		QuestLog.unlocks.append(GOLD)
	_kit = {"climbing_shoes": int(Gear.owned.get("climbing_shoes", 0)), "chalk_bag": int(Gear.owned.get("chalk_bag", 0))}
	_paint()
	for i in ART.CROWD.size():
		_crowd.append({"cheer": 0.0, "gasp": 0.0})
	_chosen = _first_choice()
	line_id = SlacklineState.LINES[_chosen].id
	state = SlacklineState.new(_seed, line_id)
	Sound.play("ui_open")
	if is_travel():
		begin(SlacklineState.TRAVEL)


## True when walking your own rigged line rather than a Camp 4 one.
func is_travel() -> bool:
	return not travel.is_empty()


## Paints the backdrop, trees and stump for the hour.
func _paint() -> void:
	_pal = ClimbSky.palette(GameClock.minutes / 60.0)
	_back_tex = ImageTexture.create_from_image(ART.backdrop(_pal, 4, not is_travel()))
	_clouds.clear()
	for i in 3:
		_clouds.append(ImageTexture.create_from_image(ClimbSky.cloud(_pal, 40 + i)))
	for young in [false, true]:
		for side in 2:
			var t := ART.tree(_pal, young, 9 + side * 31 + (5 if young else 0))
			_trees["%s%d" % [young, side]] = {"tex": ImageTexture.create_from_image(t.image), "foot": t.foot}
	_stump_tex = ImageTexture.create_from_image(ART.stump(_pal, false))
	_stump_taken_tex = ImageTexture.create_from_image(ART.stump(_pal, true))


## The line to offer first: the first one you can walk that you haven't
## crossed yet, or the Camp 4 line.
func _first_choice() -> int:
	for i in SlacklineState.LINES.size():
		var l: Dictionary = SlacklineState.LINES[i]
		if is_open(l.id) and medal_for(l.id) == 0:
			return i
	return 1


## True if the line can be walked (the long line waits for the Camp 4 line).
static func is_open(id: String) -> bool:
	var needs: String = SlacklineState.line_by_id(id).needs
	return needs == "" or QuestLog.is_unlocked(needs)


## The best medal won on a line (0 if none), and its best score.
static func medal_for(id: String) -> int:
	return Perks.stat("slackline_medal_" + id)


static func best_for(id: String) -> int:
	return Perks.stat("slackline_best_" + id)


## Starts a walk on [param id] (the chosen line if empty). Returns false if
## that line isn't open yet.
func begin(id := "") -> bool:
	if id == "":
		id = SlacklineState.TRAVEL if is_travel() else SlacklineState.LINES[_chosen].id
	if id == SlacklineState.TRAVEL and not is_travel():
		return false
	if id != SlacklineState.TRAVEL and not is_open(id):
		return false
	line_id = id
	for i in SlacklineState.LINES.size():
		if SlacklineState.LINES[i].id == id:
			_chosen = i
	attempts += 1
	state = SlacklineState.new(_seed + attempts if _seed >= 0 else -1, line_id, travel if id == SlacklineState.TRAVEL else {})
	_bounce = 0.0
	_quiver = 0.0
	_fall_t = 0.0
	_shown_score = 0.0
	_ghost = state.lean
	_best_pct = 0
	_popups.clear()
	new_best = false
	last_medal = 0
	prize_now = false
	_set_phase(Phase.READY)
	Sound.play("ui_select")
	Sound.play("slack_twang", -6.0, 0.05, 1.2)
	if attempts == 1 or _rng.randf() < 0.4:
		_say("start")
	return true


## Skips the "Ready... Walk!" beat (tests, and a second press of interact).
func go() -> void:
	if _phase == Phase.READY:
		_set_phase(Phase.WALK)


func _set_phase(phase: Phase) -> void:
	_phase = phase
	_phase_age = 0.0


func _process(delta: float) -> void:
	_time += delta
	_phase_age += delta
	_fx.update(delta)
	_shake = maxf(0.0, _shake - delta * 6.0)
	_score_pulse = maxf(0.0, _score_pulse - delta * 3.0)
	_speech.age += delta
	for p in _popups:
		p.age += delta
	_popups.assign(_popups.filter(func(p: Dictionary) -> bool: return p.age < 1.6))
	for c in _crowd:
		c.cheer = maxf(0.0, c.cheer - delta)
		c.gasp = maxf(0.0, c.gasp - delta)
	_ambient(delta)
	match _phase:
		Phase.READY:
			if _phase_age >= READY_TIME:
				_set_phase(Phase.WALK)
		Phase.WALK:
			_walk(delta)
		Phase.FALL:
			_fall_t = minf(1.0, _fall_t + delta * 2.4)
			_quiver = maxf(0.0, _quiver - delta * 1.5)
			if _phase_age > 1.3:
				_show_result()
		Phase.RESULT:
			_tally()
	_shown_score = move_toward(_shown_score, float(state.score), maxf(400.0, absf(state.score - _shown_score) * 6.0) * delta)
	_canvas.queue_redraw()


func _walk(delta: float) -> void:
	_push = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	# right at the edge, time slows so there's a moment to save it
	var target := EDGE_SLOWMO if absf(state.lean) > SlacklineState.EDGE else 1.0
	_slowmo = move_toward(_slowmo, target, delta * 4.0)
	var dt := delta * _slowmo
	var before := state.progress
	state.step(dt, _push)
	_ghost = lerpf(_ghost, state.lean, minf(1.0, delta * 6.0))
	# the line bounces a little with each step
	if int(state.progress * 40.0) != int(before * 40.0):
		_bounce = 1.0
		Sound.play("step_wood", -16.0, 0.1)
	_bounce = maxf(0.0, _bounce - delta * 5.0)
	_quiver = maxf(0.0, _quiver - delta * 2.0)
	_best_pct = maxi(_best_pct, state.percent())
	for e in state.take_events():
		_on_event(e)


## Reacts to what happened on the line: sounds, shakes, callouts and the
## crowd.
func _on_event(e: Dictionary) -> void:
	var at := feet() + Vector2(0, -52)
	match str(e.kind):
		"buck":
			_quiver = 1.0
			_shake = maxf(_shake, 0.6 + float(e.kick) * 0.4)
			Sound.play("slack_twang", -4.0 + float(e.kick) * 3.0, 0.08)
			_fx.dust(feet() + Vector2(0, 1), Color(0.839, 0.741, 0.533, 0.8), 3)
		"gust":
			Sound.play("slack_gust", -2.0)
			if _rng.randf() < 0.6:
				_say("gust")
		"wobble":
			for c in _crowd:
				c.gasp = 0.6
		"close_call":
			_popup("Close call! +%d" % SlacklineState.CLOSE_CALL_POINTS, UI.WARN, at, false)
			_score_pulse = 1.0
			Sound.play("climb_crux", -6.0, 0.02, 0.9)
			_cheer(0.9)
			_say("close_call")
		"flow":
			_popup("Flow x%d" % e.flow, UI.GOOD_DARK if e.flow == 2 else UI.GOLD, Vector2(SCREEN.x - 68, 52), false)
			_score_pulse = 1.0
			Sound.play("ui_select", -8.0, 0.0, 1.0 + 0.15 * e.flow)
		"trick":
			_popup("%s! +%d" % [e.name, e.points], UI.GOLD, at, true)
			_score_pulse = 1.0
			_fx.chalk(feet() + Vector2(0, -20), 10)
			Sound.play("climb_crux", -3.0)
			_cheer(1.2)
			_say("trick", e.name)
		"trick_fail":
			_popup("Bailed the %s" % str(e.name).to_lower(), UI.INK_SOFT, at, false)
		"milestone":
			if int(e.quarter) == 2:
				_popup("Halfway!", UI.CREAM, Vector2(SCREEN.x / 2.0, 70), true)
				_say("halfway")
				_cheer(0.8)
			Sound.play("ui_move", -6.0)
		"fell":
			_set_phase(Phase.FALL)
			_fall_t = 0.0
			_quiver = 1.0
			_slowmo = 1.0
			Sound.play("climb_fall", -2.0, 0.03)
			for c in _crowd:
				c.gasp = 1.0
			_say("fell_late" if state.progress > 0.7 else "fell_early")
		"walked":
			_finish_walk()


## The far tree: the line's walked. Scores it, and the first time on the
## Camp 4 line the six-pack is yours.
func _finish_walk() -> void:
	_slowmo = 1.0
	if line_id == PRIZE_LINE and not QuestLog.is_unlocked(WON):
		QuestLog.unlocks.append(WON)
		Inventory.add(PRIZE, PRIZE_COUNT)
		won_prize = true
		prize_now = true
		QuestLog.changed.emit()
	if line_id == PRIZE_LINE:
		walked = true
	Perks.note("slackline_crossings")
	Sound.play("climb_topout")
	_fx.confetti(feet() + Vector2(0, -30), 50)
	_cheer(2.5)
	_say("prize" if prize_now else "walked")
	_show_result()


## Scores the walk (best score, medal, a first gold, Camp 4 Legend) and opens
## the results card.
func _show_result() -> void:
	var crossed := state.status == SlacklineState.Status.WALKED
	last_medal = state.medal()
	new_best = crossed and Perks.record("slackline_best_" + line_id, state.score)
	Perks.record("slackline_medal_" + line_id, last_medal)
	var first_gold := false
	if last_medal >= 3 and not is_travel() and not QuestLog.is_unlocked(GOLD):
		QuestLog.unlocks.append(GOLD)
		first_gold = true
		QuestLog.changed.emit()
	if not QuestLog.is_unlocked(LEGEND) and SlacklineState.LINES.all(func(l: Dictionary) -> bool: return medal_for(l.id) >= 3):
		QuestLog.unlocks.append(LEGEND)
	var rows: Array = []
	rows.append(["Distance (%d%%)" % state.percent(), int(state.distance_points)])
	if state.tricks_landed > 0:
		rows.append(["Tricks x%d" % state.tricks_landed, state.trick_points])
	if state.close_calls > 0:
		rows.append(["Close calls x%d" % state.close_calls, state.close_calls * SlacklineState.CLOSE_CALL_POINTS])
	rows.append(["Best flow", "x%d" % state.best_flow])
	if crossed:
		rows.append(["Reached the far tree", state.finish_points])
	var note := ""
	if crossed:
		var l := state.line
		if last_medal < 2:
			note = "Silver at %d, gold at %d. Steady walking builds flow, and flow multiplies everything." % [l.silver, l.gold]
		elif last_medal < 3:
			note = "Gold at %d. Land your tricks with flow up for the big points." % l.gold
		elif is_travel():
			note = "Gold, with nobody watching but the jays."
		else:
			note = "Gold. Camp 4 will be talking about that one."
		if first_gold and QuestLog.active.has(GOLD_QUEST):
			note += " Wren will want to hear about this. She's at the foot of Firefall Slab in Curry Village."
		if prize_now:
			note = "You touch the far pine, and the six-pack of King Cobra on the stump is yours. " + note
	else:
		var where := "halfway" if state.percent() >= 45 and state.percent() <= 55 else "%d%% of the way across" % state.percent()
		note = "You stepped off %s. Hold the key away from the way you're tipping, and watch for the arrows: they show which way the next buck will throw you." % where
	var prize: Texture2D = null
	if prize_now:
		var item := ItemDB.get_item(PRIZE)
		prize = item.icon if item else null
	_result = {
		"title": "You walked the line!" if crossed else "Off the line",
		"line": "%s · %d m" % [state.line.name, state.line.meters],
		"rows": rows, "total": state.score, "medal": last_medal, "new_best": new_best,
		"prize": prize, "prize_text": "King Cobra x%d" % PRIZE_COUNT, "note": note,
	}
	_tallied = 0
	_stamped = false
	_set_phase(Phase.RESULT)


## The results card's sounds: a tick as each row counts up, then the medal
## landing (with confetti for gold).
func _tally() -> void:
	var rows: int = _result.rows.size()
	var shown := clampi(int(floor((_phase_age - 0.35) / 0.28)) + 1, 0, rows)
	if shown > _tallied:
		_tallied = shown
		Sound.play("ui_move", -8.0, 0.0, 1.0 + 0.08 * shown)
	if not _stamped and _phase_age >= HUD.tally_time(rows):
		_stamped = true
		if last_medal > 0:
			Sound.play("slack_medal")
			_shake = 0.8
			if last_medal >= 3:
				_fx.confetti(Vector2(SCREEN.x / 2.0 + 116, 60), 60)


func _input(event: InputEvent) -> void:
	var go_key := MenuInput.confirm(event)
	var back := event.is_action_pressed("ui_cancel")
	var vertical := MenuInput.vertical(event) if _phase == Phase.SELECT else 0
	if (not go_key and not back and vertical == 0) or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	match _phase:
		Phase.SELECT:
			if vertical != 0:
				_chosen = wrapi(_chosen + vertical, 0, SlacklineState.LINES.size())
				Sound.play("ui_move")
			elif go_key:
				if not begin():
					Sound.play("ui_back")
					_shake = 1.0
			else:
				leave()
		Phase.READY:
			if back and is_travel():
				leave()
			elif back:
				_to_select()
			elif go_key:
				go()
		Phase.WALK:
			if back:
				# stepping off on purpose: down you hop
				state.status = SlacklineState.Status.FELL
				state.fell_to = -1 if state.lean < 0.0 else 1
				_on_event({"kind": "fell", "side": state.fell_to})
			elif go_key and state.start_trick():
				Sound.play("ui_select", -6.0)
		Phase.RESULT:
			if _phase_age < HUD.tally_time(_result.rows.size()):
				_phase_age = HUD.tally_time(_result.rows.size()) # skip the count-up
				return
			if go_key:
				_result = {}
				begin(line_id)
			elif is_travel():
				leave()
			else:
				_to_select()


func _to_select() -> void:
	_result = {}
	_set_phase(Phase.SELECT)
	Sound.play("ui_back")


## Closes the screen. Each walk out takes a little time (see [method minutes]).
func leave() -> void:
	set_process(false)
	set_process_input(false)
	Sound.play("ui_close")
	finished.emit(walked)
	queue_free()


## Game minutes spent on the lines this visit.
func minutes() -> int:
	return attempts * MINUTES_PER_WALK


## A callout at [param at] that pops and floats up.
func _popup(text: String, color: Color, at: Vector2, big: bool) -> void:
	_popups.append({"text": text, "color": color, "age": 0.0, "at": at, "big": big})


## The crowd cheers for [param seconds] (nobody's there on your own line).
func _cheer(seconds: float) -> void:
	if is_travel():
		return
	for c in _crowd:
		c.cheer = seconds * _rng.randf_range(0.7, 1.0)
		c.gasp = 0.0
	Sound.play("slack_cheer", -6.0 if seconds < 2.0 else -2.0, 0.08)


## Someone in the crowd calls out (see BANTER).
func _say(kind: String, arg := "") -> void:
	var lines: Array = BANTER.get(kind, [])
	if lines.is_empty() or is_travel():
		return
	var text: String = lines[_rng.randi() % lines.size()]
	if "%s" in text:
		text = text % arg
	_speech = {"text": text, "who": _rng.randi() % ART.CROWD.size(), "age": 0.0}


## Leaves drifting down, more in a gust; sparks off the fire.
func _ambient(delta: float) -> void:
	_leaf_wait -= delta
	var gust := _phase == Phase.WALK and state.gusting()
	if _leaf_wait <= 0.0:
		_leaf_wait = _rng.randf_range(0.05, 0.12) if gust else _rng.randf_range(0.5, 1.4)
		var side := float(state.warning().get("side", 1)) if gust else 1.0
		var x := -4.0 if side > 0 else SCREEN.x + 4.0
		if not gust:
			x = _rng.randf_range(0, SCREEN.x)
		var col := Color("84b04a") if _rng.randf() < 0.5 else Color("d8a63b")
		_fx.spawn(Vector2(x, _rng.randf_range(10, 200 if gust else 120)), Vector2(side * (_rng.randf_range(90, 160) if gust else _rng.randf_range(4, 14)), _rng.randf_range(6, 16)), _rng.randf_range(3.0, 6.0), col, 2, 2.0)
	if not is_travel() and _rng.randf() < delta * (4.0 if ClimbProps.night_amount(_pal) > 0.4 else 1.5):
		_fx.spawn(ART.FIRE + Vector2(_rng.randf_range(-3, 3), -6), Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-26, -14)), _rng.randf_range(0.6, 1.2), Color(0.969, 0.651, 0.29, 0.9), 1, -4.0)


# ---------------------------------------------------------------- drawing

## The line on screen: tree x positions, anchors, height and sag.
func _line() -> Dictionary:
	return state.line if _phase != Phase.SELECT else SlacklineState.LINES[_chosen]


func _anchors(l: Dictionary) -> Array[Vector2]:
	var inset := 5.0 if _young(l) else 10.0
	return [Vector2(float(l.span.x) + inset, l.line_y), Vector2(float(l.span.y) - inset, l.line_y)]


## Where the walker stands, in screen pixels (their feet on the line).
func feet() -> Vector2:
	var a := _anchors(state.line)
	var x := lerpf(a[0].x, a[1].x, state.progress)
	return Vector2(x, float(state.line.line_y) + float(state.line.sag) * state.sag() + 3.0 + _bounce * 2.0 * state.sag())


func _draw_screen() -> void:
	var ci := _canvas
	var shake := Vector2(sin(_time * 53.0), cos(_time * 41.0)) * _shake * 1.5
	ci.draw_set_transform(shake.round(), 0.0, Vector2.ONE)
	ci.draw_texture(_back_tex, Vector2.ZERO)
	_draw_clouds(ci)
	if not is_travel():
		_draw_fire(ci)
		_draw_crowd(ci)
	var l := _line()
	_draw_trees(ci, l)
	if l.id != "long" and l.id != SlacklineState.TRAVEL:
		ci.draw_texture(_stump_tex if not walked else _stump_taken_tex, Vector2(ART.STUMP_X - 16, ART.GROUND_Y - 36))
	var on_line := _phase in [Phase.READY, Phase.WALK] or (_phase == Phase.RESULT and state.status == SlacklineState.Status.WALKED)
	_draw_webbing(ci, l, on_line)
	if _phase == Phase.SELECT:
		pass
	elif _phase == Phase.FALL or (_phase == Phase.RESULT and state.status == SlacklineState.Status.FELL):
		_draw_fallen(ci)
	else:
		_draw_walker(ci)
	_fx.draw(ci)
	_draw_wind(ci)
	_draw_night(ci)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_speech(ci)
	if _phase != Phase.SELECT:
		HUD.popups(ci, _popups)
	match _phase:
		Phase.SELECT:
			HUD.select_card(ci, _select_rows(), _chosen, _phase_age, "[%s] Choose    [%s] Walk    [%s] Leave" % [_button("Up/Down", "D-pad"), _button("E", "A"), _button("Esc", "B")], QuestLog.is_unlocked(LEGEND))
		Phase.READY:
			_draw_walk_hud(ci)
			HUD.countdown(ci, _phase_age, READY_TIME)
		Phase.WALK, Phase.FALL:
			_draw_walk_hud(ci)
		Phase.RESULT:
			_draw_walk_hud(ci)
			var keys := "[%s] %s    [%s] %s" % [_button("E", "A"), "Walk again" if state.status == SlacklineState.Status.WALKED else "Try again", _button("Esc", "B"), "Leave" if is_travel() else "Lines"]
			HUD.result_card(ci, _result, _phase_age, keys)


func _draw_walk_hud(ci: CanvasItem) -> void:
	HUD.meter(ci, state, _ghost, _time, _shake * 0.6)
	HUD.plate(ci, state.line, state)
	HUD.score_box(ci, state, int(_shown_score), _score_pulse)
	if _phase == Phase.WALK:
		if attempts <= 1 and _phase_age < 6.0:
			HUD.hint(ci, "[%s] Lean back against the tip    [%s] Step off" % [_button("Left/Right", "Stick"), _button("Esc", "B")], 58, clampf(6.0 - _phase_age, 0.0, 1.0))
		HUD.trick_prompt(ci, state, _button("E", "A"), _time)


func _select_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for l: Dictionary in SlacklineState.LINES:
		rows.append({"line": l, "open": is_open(l.id), "medal": medal_for(l.id), "best": best_for(l.id)})
	return rows


func _draw_clouds(ci: CanvasItem) -> void:
	var tint := Color(1, 1, 1, 0.35 if _pal.night else 0.9)
	for i in _clouds.size():
		var x := fposmod(60.0 + i * 170.0 + _time * (2.5 + i * 1.3), SCREEN.x + 140.0) - 70.0
		ci.draw_texture(_clouds[i], Vector2(x, 14.0 + i * 22.0).round(), tint)


## The campfire: flickering flames in the ring, and their glow after dark.
func _draw_fire(ci: CanvasItem) -> void:
	var f := ART.FIRE
	var night := ClimbProps.night_amount(_pal)
	if night > 0.1:
		for k in 3:
			var r := 26.0 - k * 7.0 + sin(_time * 9.0) * 1.5
			ci.draw_circle(f + Vector2(0, -4), r, Color(0.969, 0.651, 0.29, 0.06 * night * (k + 1)))
	for i in 5:
		var h := 4.0 + absf(sin(_time * (7.0 + i * 1.7) + i * 2.1)) * (6.0 + night * 3.0)
		var x := f.x - 5 + i * 2.5
		ci.draw_rect(Rect2(x - 1, f.y - 1 - h, 3, h), Color("d9772a"))
		ci.draw_rect(Rect2(x, f.y - 1 - h * 0.6, 1, h * 0.6), Color("f1cf6a"))


## Climbers watching: sitting until something happens, then up and cheering
## (or wincing).
func _draw_crowd(ci: CanvasItem) -> void:
	for i in ART.CROWD.size():
		var spec: Dictionary = ART.CROWD[i]
		var look: Dictionary = ClimbProfiles.BELAYERS[spec.look].duplicate()
		look["id"] = spec.look
		var c: Dictionary = _crowd[i]
		var mode := "sit" if spec.sit else "look_up"
		var frame := 0
		if c.cheer > 0.0:
			mode = "cheer"
			frame = int(_time * 6.0 + i) % 2
		elif c.gasp > 0.0:
			mode = "look_up"
		var tex := ClimbSprites.belayer(look, mode, frame)
		var at: Vector2 = spec.at
		ci.draw_rect(Rect2(at + Vector2(-10, -1), Vector2(20, 2)), Color(0.082, 0.078, 0.11, 0.25))
		ci.draw_texture(tex, (at - Vector2(tex.get_width() / 2.0, tex.get_height() - 4)).round())


## True for a line strung between slim young trees (the short line, or a
## short rig of your own).
func _young(l: Dictionary) -> bool:
	return l.get("young", l.id == "short")


func _draw_trees(ci: CanvasItem, l: Dictionary) -> void:
	var young := _young(l)
	for side in 2:
		var t: Dictionary = _trees["%s%d" % [young, side]]
		var x: float = l.span.x if side == 0 else l.span.y
		ci.draw_texture(t.tex, Vector2(x, ART.GROUND_Y) - t.foot)


## The webbing: two runs to the walker's feet (a slackline sags in a V under
## a person), or a gentle curve when nobody's on it. A buck sends a ripple
## down the line ahead of it, and the line quivers after.
func _draw_webbing(ci: CanvasItem, l: Dictionary, on_line: bool) -> void:
	var a := _anchors(l)
	var points := PackedVector2Array()
	var steps := 48
	var mid := feet() + Vector2(0, 1) if on_line else Vector2.ZERO
	var w := state.warning() if _phase == Phase.WALK else {}
	for i in steps + 1:
		var u := float(i) / steps
		var p := a[0].lerp(a[1], u)
		if on_line:
			var k := clampf(state.progress, 0.001, 0.999)
			var dip := mid.y - a[0].y
			p.y += dip * (u / k if u <= k else (1.0 - u) / (1.0 - k))
		else:
			var rest := float(l.sag) * 0.35
			p.y += rest * sin(u * PI)
			if _phase == Phase.FALL or _phase == Phase.RESULT:
				p.y += sin(_time * 28.0) * 5.0 * _quiver * sin(u * PI)
			elif _phase == Phase.SELECT:
				p.y += sin(_time * 2.0 + u * 6.0) * 0.6 * sin(u * PI)
		# quiver after a buck: a standing wave that dies away
		if on_line and _quiver > 0.0:
			p.y += sin(u * PI * 6.0 + _time * 40.0) * 1.2 * _quiver * sin(u * PI)
		# a ripple running toward the walker before a buck lands
		if not w.is_empty() and w.kind == "buck":
			var from := 0.0 if state.progress > 0.5 else 1.0
			var at := lerpf(from, state.progress, float(w.t))
			var d := (u - at) * 30.0
			p.y -= 2.5 * exp(-d * d)
		points.append(p)
	ci.draw_polyline(points, OUTLINE, 4.0)
	ci.draw_polyline(points, WEB, 2.0)
	var lit := PackedVector2Array()
	for p in points:
		lit.append(p + Vector2(0, -0.5))
	ci.draw_polyline(lit, WEB_LIT, 1.0)
	# tree pro and the slings round each trunk, and the ratchet
	var trunk := 5.0 if _young(l) else 10.0
	for i in 2:
		var tx: float = l.span.x if i == 0 else l.span.y
		ci.draw_rect(Rect2(tx - trunk - 1, a[i].y - 4, trunk * 2 + 2, 7), OUTLINE)
		ci.draw_rect(Rect2(tx - trunk, a[i].y - 3, trunk * 2, 5), PAD)
		ci.draw_rect(Rect2(tx - trunk, a[i].y - 3, trunk * 2, 1), PAD.lightened(0.25))
		ci.draw_rect(Rect2(tx - trunk, a[i].y - 1, trunk * 2, 2), WEB_DARK)
	var r := points[int(12.0 / (a[1].x - a[0].x) * steps)]
	ci.draw_rect(Rect2(r.x - 5, r.y - 4, 10, 7), OUTLINE)
	ci.draw_rect(Rect2(r.x - 4, r.y - 3, 8, 5), STEEL)
	ci.draw_rect(Rect2(r.x - 4, r.y - 3, 8, 1), Color("f5eee0"))
	ci.draw_rect(Rect2(r.x + 2, r.y - 6, 2, 4), Color("b3362b"))


## The pose for this moment on the line: arms out for balance, the pushing
## arm dropped and the other raised, or a trick, or arms up at the end.
func _pose() -> Dictionary:
	if state.status == SlacklineState.Status.WALKED:
		return ClimbSprites.cheer_pose()
	var arm := clampf(_push, -1.0, 1.0) * 7.0 + sin(_time * 9.0) * 2.5 * absf(state.lean)
	var step := int(state.progress * 40.0) % 2
	var pose := {"hr": Vector2(16, roundf(-7 - arm)), "hl": Vector2(-16, roundf(-7 + arm)),
		"fr": Vector2(2, 22 - step), "fl": Vector2(-2, 21 + step), "lean": 0}
	if not state.trick.is_empty():
		match str(state.trick.id):
			"drop_knee":
				pose = {"hr": Vector2(15, -12), "hl": Vector2(-15, -4), "fr": Vector2(6, 13), "fl": Vector2(-7, 14), "lean": 0}
			"sit":
				pose = {"hr": Vector2(9, 8), "hl": Vector2(-9, 8), "fr": Vector2(12, 6), "fl": Vector2(-12, 6), "lean": 0}
	return pose


## How far a trick drops the body below standing, in pixels.
func _crouch() -> float:
	if state.trick.is_empty():
		return 0.0
	var t := clampf(state.trick_age / float(state.trick.time), 0.0, 1.0)
	var depth := 0.0
	match str(state.trick.id):
		"drop_knee":
			depth = 8.0
		"sit":
			depth = 15.0
	# down quickly, hold, back up at the end
	return depth * minf(minf(t * 5.0, 1.0), minf((1.0 - t) * 5.0, 1.0))


func _draw_walker(ci: CanvasItem) -> void:
	var at := feet()
	var pose := _pose()
	if _phase == Phase.READY:
		# stepping up from the tree onto the line
		var up := clampf(_phase_age / 0.5, 0.0, 1.0)
		at.y += (1.0 - up) * 10.0
		pose = ClimbSprites.blend_pose(ClimbSprites.stand_pose(), pose, up)
	var crouch := _crouch()
	if crouch > 0.0:
		pose = ClimbSprites.blend_pose(_pose_standing(), pose, crouch / maxf(crouch, 8.0))
	var flip := 1.0
	if not state.trick.is_empty() and state.trick.id == "turnaround":
		flip = cos(clampf(state.trick_age / float(state.trick.time), 0.0, 1.0) * TAU)
		if absf(flip) < 0.15:
			flip = 0.15 * signf(flip if flip != 0.0 else 1.0)
	_shadow(ci, at.x, absf(ART.GROUND_Y - at.y))
	var tex := ClimbSprites.climber(pose, _kit)
	var angle := 0.0 if state.status == SlacklineState.Status.WALKED else state.lean * 0.6
	ci.draw_set_transform(at.round() + Vector2(0, 0) + _shake_offset(), angle, Vector2(flip, 1.0))
	ci.draw_texture(tex, Vector2(-ClimbSprites.ORIGIN.x, -ClimbSprites.ORIGIN.y - 22 + crouch))
	ci.draw_set_transform(_shake_offset(), 0.0, Vector2.ONE)
	_headlamp(ci, at + Vector2(sin(angle) * 36.0, -36.0 + crouch))


func _pose_standing() -> Dictionary:
	return {"hr": Vector2(16, -7), "hl": Vector2(-16, -7), "fr": Vector2(2, 22), "fl": Vector2(-2, 22), "lean": 0}


func _shake_offset() -> Vector2:
	return (Vector2(sin(_time * 53.0), cos(_time * 41.0)) * _shake * 1.5).round()


## A soft shadow on the dirt under the walker, smaller the higher they are.
func _shadow(ci: CanvasItem, x: float, height: float) -> void:
	var w := clampf(22.0 - height * 0.12, 8.0, 22.0)
	ci.draw_rect(Rect2(x - w / 2.0, ART.GROUND_Y + 3, w, 2), Color(0.082, 0.078, 0.11, 0.28))
	ci.draw_rect(Rect2(x - w / 4.0, ART.GROUND_Y + 3, w / 2.0, 2), Color(0.082, 0.078, 0.11, 0.2))


## After dark, a headlamp: a bright dot and a pool of light on the line ahead.
func _headlamp(ci: CanvasItem, head: Vector2) -> void:
	var n := ClimbProps.night_amount(_pal)
	if n < 0.4:
		return
	var ahead := Vector2(head.x + 46, float(state.line.line_y) + 6)
	var beam := PackedVector2Array([head, ahead + Vector2(-14, 0), ahead + Vector2(18, 4)])
	ci.draw_colored_polygon(beam, Color(1, 0.96, 0.75, 0.1 * n))
	ci.draw_circle(ahead + Vector2(2, 1), 9, Color(1, 0.96, 0.75, 0.08 * n))
	ci.draw_rect(Rect2(head + Vector2(-1, -1), Vector2(3, 2)), Color("fff4c0"))


## Streaks of wind across the screen while a gust blows.
func _draw_wind(ci: CanvasItem) -> void:
	if _phase != Phase.WALK or not state.gusting():
		return
	var side := float(state.warning().get("side", 1))
	for i in 10:
		var speed := 260.0 + (i % 3) * 70.0
		var x := fposmod(i * 97.0 + _time * speed * side, SCREEN.x + 60.0) - 30.0
		var y := 30.0 + fposmod(i * 53.0, 190.0) + sin(_time * 3.0 + i) * 3.0
		ci.draw_rect(Rect2(x, y, 16 + (i % 3) * 6, 1), Color(0.961, 0.933, 0.878, 0.45))


## The night darkens the moving parts a little to sit with the painted scene.
func _draw_night(ci: CanvasItem) -> void:
	var n := ClimbProps.night_amount(_pal)
	if n > 0.05:
		ci.draw_rect(Rect2(Vector2(-4, -4), SCREEN + Vector2(8, 8)), Color(0.04, 0.05, 0.14, 0.18 * n))


## Off the line: a quick tip to one side, then dusting off in the dirt.
func _draw_fallen(ci: CanvasItem) -> void:
	var start := feet()
	var side := float(state.fell_to if state.fell_to != 0 else 1)
	var t := _fall_t
	var ground := ART.GROUND_Y + 6.0
	var at := Vector2(start.x + side * 14.0 * t, lerpf(start.y, ground, t * t))
	var angle := lerpf(state.lean * 0.6, side * 1.2, minf(1.0, t * 1.4))
	var pose := ClimbSprites.fall_pose()
	if t >= 1.0:
		angle = side * 0.12
		pose = ClimbSprites.stand_pose()
		if _phase_age < 0.9:
			_fx.dust(at + Vector2(0, -1), Color(0.839, 0.741, 0.533, 0.9), 2)
	_shadow(ci, at.x, ground - at.y)
	var tex := ClimbSprites.climber(pose, _kit)
	ci.draw_set_transform(at.round() + _shake_offset(), angle, Vector2.ONE)
	ci.draw_texture(tex, Vector2(-ClimbSprites.ORIGIN.x, -ClimbSprites.ORIGIN.y - 22))
	ci.draw_set_transform(_shake_offset(), 0.0, Vector2.ONE)


func _draw_speech(ci: CanvasItem) -> void:
	if _speech.text == "" or _phase == Phase.SELECT or is_travel():
		return
	var spec: Dictionary = ART.CROWD[_speech.who]
	ClimbHud.speech(ci, spec.at + Vector2(0, -8), _speech.text, "", _speech.age)


func _button(keyboard: String, gamepad: String) -> String:
	return MenuInput.button(get_tree(), keyboard, gamepad)
