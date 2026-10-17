class_name SlacklineMinigame
extends CanvasLayer
## The Camp 4 slackline, seen from the side: webbing strung between two
## ponderosa pines, the granite behind, and a six-pack of King Cobra on the
## stump at the far end for whoever walks the whole line. The rules live in
## SlacklineState; this draws them and turns the arrow keys into a push.
##
## Controls: Left/Right lean you back the other way (hold the key opposite the
## way you're tipping); interact starts and retries; cancel steps off or
## leaves.

## Emitted when the player leaves the screen. [param walked] is true if they
## walked the whole line at least once this visit.
signal finished(walked: bool)

const UI := preload("res://scripts/climb/art/climb_ui.gd")

enum Phase { INTRO, WALK, FALL, RESULT }

const SCREEN := Vector2(480, 270)
## The prize, and the ability that marks it as won (so it's given once).
const PRIZE := "king_cobra"
const PRIZE_COUNT := 6
const WON := "slackline_walked"
## Game minutes each walk takes, warm-up and all.
const MINUTES_PER_WALK := 10

const GROUND_Y := 232.0
const LINE_Y := 166.0
const TREE_X := [44.0, 436.0]
const LINE_X := [62.0, 418.0]
const SAG := 16.0
const OUTLINE := Color("15141c")
const WEB := Color("d8a63b")
const WEB_DARK := Color("ad7a22")
const BARK := Color("6b4829")
const BARK_LIT := Color("92693d")
const BARK_DARK := Color("47301f")
const NEEDLES := Color("3f6b3a")
const NEEDLES_LIT := Color("5f8a3e")
const NEEDLES_DARK := Color("2c4a30")
const GRANITE := Color("93918f")
const GRANITE_LIT := Color("bdb8ae")
const GRANITE_DARK := Color("6a6a70")
const DIRT := Color("92693d")
const DIRT_DARK := Color("6b4829")
const SKIN := Color("d6a77a")
const SHIRT := Color("b3362b")
const PANTS := Color("3a5a8a")
const CAN := Color("15141c")
const CAN_BAND := Color("d8a63b")

var state: SlacklineState
## True once the line has been walked end to end (this visit or before).
var walked := false
## True if this visit won the prize.
var won_prize := false
var attempts := 0

var _canvas: Control
var _phase := Phase.INTRO
var _seed := -1
var _time := 0.0
var _phase_age := 0.0
var _push := 0.0
var _bounce := 0.0
var _fall_t := 0.0
var _best := 0
var _sky := [Color("3a86a8"), Color("8fc5d6")]


## Call before adding the node to the tree. A [param seed] of 0 or more makes
## the line buck the same way every time (for tests).
func setup(seed := -1) -> void:
	_seed = seed


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
	walked = QuestLog.is_unlocked(WON)
	_sky = _sky_colors()
	_new_walk()
	Sound.play("ui_open")


func _new_walk() -> void:
	state = SlacklineState.new(_seed + attempts if _seed >= 0 else -1)
	_bounce = 0.0
	_fall_t = 0.0


## Starts walking out from the first tree.
func begin() -> void:
	attempts += 1
	if attempts > 1:
		_new_walk()
	_set_phase(Phase.WALK)
	Sound.play("ui_select")


func _set_phase(phase: Phase) -> void:
	_phase = phase
	_phase_age = 0.0


func _process(delta: float) -> void:
	_time += delta
	_phase_age += delta
	match _phase:
		Phase.WALK:
			_push = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
			var before := state.progress
			state.step(delta, _push)
			# the line bounces a little with each step
			if int(state.progress * 40.0) != int(before * 40.0):
				_bounce = 1.0
				Sound.play("step_wood", -14.0, 0.1)
			_bounce = maxf(0.0, _bounce - delta * 5.0)
			_best = maxi(_best, state.percent())
			if state.status == SlacklineState.Status.FELL:
				_set_phase(Phase.FALL)
				Sound.play("climb_fall", -2.0, 0.03)
			elif state.status == SlacklineState.Status.WALKED:
				_finish_walk()
		Phase.FALL:
			_fall_t = minf(1.0, _fall_t + delta * 2.2)
			if _phase_age > 1.1:
				_set_phase(Phase.RESULT)
	_canvas.queue_redraw()


## The far tree: the line's walked. The first time, the six-pack is yours.
func _finish_walk() -> void:
	_set_phase(Phase.RESULT)
	if not QuestLog.is_unlocked(WON):
		QuestLog.unlocks.append(WON)
		Inventory.add(PRIZE, PRIZE_COUNT)
		won_prize = true
		Sound.play("quest_done")
	else:
		Sound.play("climb_topout")
	walked = true


func _input(event: InputEvent) -> void:
	var go := event.is_action_pressed("interact") or event.is_action_pressed("use_tool") or event.is_action_pressed("ui_accept")
	var back := event.is_action_pressed("ui_cancel")
	if (not go and not back) or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	match _phase:
		Phase.INTRO:
			if go:
				begin()
			else:
				leave()
		Phase.WALK:
			if back:
				# stepping off on purpose: down you hop
				state.status = SlacklineState.Status.FELL
				state.fell_to = -1 if state.lean < 0.0 else 1
				_set_phase(Phase.FALL)
		Phase.RESULT:
			if _phase_age < 0.4:
				return
			if go:
				begin()
			else:
				leave()


## Closes the screen. Each walk out takes a little time (see [method minutes]).
func leave() -> void:
	set_process(false)
	set_process_input(false)
	Sound.play("ui_close")
	finished.emit(walked)
	queue_free()


## Game minutes spent on the line this visit.
func minutes() -> int:
	return attempts * MINUTES_PER_WALK


# ---------------------------------------------------------------- drawing

func _sky_colors() -> Array:
	var hour := GameClock.minutes / 60.0
	if hour >= 20.5 or hour < 5.5:
		return [Color("15141c"), Color("2c3a5a")]
	if hour >= 18.5 or hour < 7.0:
		return [Color("5a4a7a"), Color("f7a64a")]
	return [Color("3a86a8"), Color("8fc5d6")]


## Where the walker stands, in screen pixels (their feet on the line).
func feet() -> Vector2:
	var x: float = lerpf(LINE_X[0], LINE_X[1], state.progress)
	return Vector2(x, LINE_Y + SAG * state.sag() + 4.0 + _bounce * 2.0 * state.sag())


func _draw_screen() -> void:
	var ci := _canvas
	_draw_backdrop(ci)
	_draw_tree(ci, TREE_X[0])
	_draw_tree(ci, TREE_X[1])
	_draw_line(ci)
	_draw_prize(ci)
	if _phase == Phase.FALL or (_phase == Phase.RESULT and state.status == SlacklineState.Status.FELL):
		_draw_fallen(ci)
	else:
		var upright := state.status == SlacklineState.Status.WALKED
		_draw_walker(ci, feet(), 0.0 if upright else state.lean * 0.6)
	match _phase:
		Phase.INTRO:
			_draw_intro(ci)
		Phase.WALK:
			_draw_balance(ci)
			_hint(ci, "%s  lean back     %s  step off" % [_button("Left/Right", "Stick"), _button("Esc", "B")])
		Phase.FALL:
			_draw_balance(ci)
		Phase.RESULT:
			_draw_result(ci)


func _draw_backdrop(ci: CanvasItem) -> void:
	# sky in bands, the cliffs above Camp 4, then the campground floor
	var bands := 8
	for i in bands:
		var c: Color = (_sky[0] as Color).lerp(_sky[1], float(i) / (bands - 1))
		ci.draw_rect(Rect2(0, i * 12, SCREEN.x, 12), c)
	ci.draw_rect(Rect2(0, bands * 12, SCREEN.x, 120), _sky[1])
	# the granite wall, a ragged skyline from the left
	var tops := [34, 30, 26, 28, 22, 18, 24, 30, 36, 40, 44, 50, 56, 60, 64, 70]
	var w := SCREEN.x / (tops.size() - 1)
	for i in tops.size() - 1:
		var x0 := i * w
		var top: float = minf(tops[i], tops[i + 1])
		ci.draw_rect(Rect2(x0, top, w + 1, GROUND_Y - top), GRANITE)
		ci.draw_rect(Rect2(x0, top, w + 1, 2), GRANITE_LIT)
		ci.draw_rect(Rect2(x0, top - 1, w + 1, 1), OUTLINE)
	# shade toward the foot of the wall, ledges, and cracks that wander down it
	ci.draw_rect(Rect2(0, 150, SCREEN.x, GROUND_Y - 150), GRANITE.darkened(0.08))
	for ledge in [[96, 70, 60], [250, 98, 80], [150, 132, 50], [340, 120, 70]]:
		ci.draw_rect(Rect2(ledge[0], ledge[1], ledge[2], 2), GRANITE_LIT)
		ci.draw_rect(Rect2(ledge[0], ledge[1] + 2, ledge[2], 2), GRANITE_DARK)
	for crack in [[120, 50], [212, 40], [300, 64], [372, 76]]:
		var cx: float = crack[0]
		var cy: float = crack[1]
		for j in 9:
			ci.draw_rect(Rect2(cx, cy, 1, 10), GRANITE_DARK)
			cx += [1, -1, 1, 0, -1, 1, 1, -1, 0][j]
			cy += 10
	# talus and forest along the foot of the wall
	for i in 16:
		var tx := i * 32.0 - 8.0
		var h := 26.0 + float((i * 37) % 18)
		ci.draw_rect(Rect2(tx, GROUND_Y - h, 30, h), NEEDLES_DARK)
		ci.draw_rect(Rect2(tx + 6, GROUND_Y - h - 8, 18, 8), NEEDLES_DARK)
	# dirt, with the worn path under the line
	ci.draw_rect(Rect2(0, GROUND_Y, SCREEN.x, SCREEN.y - GROUND_Y), DIRT)
	ci.draw_rect(Rect2(0, GROUND_Y, SCREEN.x, 2), DIRT_DARK)
	for i in 30:
		ci.draw_rect(Rect2(float((i * 53) % 480), GROUND_Y + 6 + float((i * 29) % 30), 3, 1), DIRT_DARK)
	# a boulder or two, Camp 4 style
	_boulder(ci, Vector2(150, GROUND_Y + 6), 28, 14)
	_boulder(ci, Vector2(330, GROUND_Y + 10), 22, 10)


func _boulder(ci: CanvasItem, at: Vector2, w: float, h: float) -> void:
	ci.draw_rect(Rect2(at.x - w / 2 - 1, at.y - h - 1, w + 2, h + 2), OUTLINE)
	ci.draw_rect(Rect2(at.x - w / 2, at.y - h, w, h), GRANITE)
	ci.draw_rect(Rect2(at.x - w / 2, at.y - h, w, 2), GRANITE_LIT)
	ci.draw_rect(Rect2(at.x - w / 2, at.y - 3, w, 3), GRANITE_DARK)


func _draw_tree(ci: CanvasItem, x: float) -> void:
	# a ponderosa: a tall plated trunk, the crown above the top of the screen
	ci.draw_rect(Rect2(x - 10, -4, 20, GROUND_Y + 6), OUTLINE)
	ci.draw_rect(Rect2(x - 9, -4, 18, GROUND_Y + 5), BARK)
	ci.draw_rect(Rect2(x - 9, -4, 4, GROUND_Y + 5), BARK_LIT)
	ci.draw_rect(Rect2(x + 5, -4, 4, GROUND_Y + 5), BARK_DARK)
	for y in range(8, int(GROUND_Y), 18):
		var off := 1 if (y / 18) % 2 == 0 else -2
		ci.draw_rect(Rect2(x - 6 + off, y, 9, 1), BARK_DARK)
	# low branches
	for b in [[-1, 24], [1, 52], [-1, 80]]:
		var dir: int = b[0]
		var by: float = b[1]
		var bx := x + (8.0 if dir > 0 else -40.0)
		ci.draw_rect(Rect2(bx, by, 32, 3), BARK_DARK)
		ci.draw_rect(Rect2(bx - 4, by - 10, 40, 12), NEEDLES_DARK)
		ci.draw_rect(Rect2(bx, by - 12, 32, 8), NEEDLES)
		ci.draw_rect(Rect2(bx + 4, by - 12, 20, 3), NEEDLES_LIT)
	# roots flaring into the dirt
	ci.draw_rect(Rect2(x - 14, GROUND_Y - 4, 28, 6), OUTLINE)
	ci.draw_rect(Rect2(x - 13, GROUND_Y - 3, 26, 4), BARK)


func _draw_line(ci: CanvasItem) -> void:
	var a := Vector2(LINE_X[0], LINE_Y)
	var b := Vector2(LINE_X[1], LINE_Y)
	var mid := feet() + Vector2(0, 1)
	if _phase == Phase.FALL or (_phase == Phase.RESULT and state.status == SlacklineState.Status.FELL):
		# empty, the line springs back and quivers
		var q := sin(_time * 30.0) * 4.0 * (1.0 - clampf(_phase_age, 0.0, 1.0))
		mid = Vector2(mid.x, LINE_Y + SAG * 0.3 * state.sag() + q)
	elif _phase == Phase.INTRO:
		mid = Vector2((a.x + b.x) / 2.0, LINE_Y + SAG * 0.3)
	for seg in [[a, mid], [mid, b]]:
		ci.draw_line(seg[0] + Vector2(0, 1), seg[1] + Vector2(0, 1), OUTLINE, 3.0)
		ci.draw_line(seg[0], seg[1], WEB, 2.0)
		ci.draw_line(seg[0] + Vector2(0, 1), seg[1] + Vector2(0, 1), WEB_DARK, 1.0)
	# the tree wraps and ratchet
	for x: float in TREE_X:
		ci.draw_rect(Rect2(x - 10, LINE_Y - 3, 20, 5), OUTLINE)
		ci.draw_rect(Rect2(x - 9, LINE_Y - 2, 18, 3), Color("5a4a7a"))
	ci.draw_rect(Rect2(LINE_X[0] + 6, LINE_Y - 3, 8, 6), OUTLINE)
	ci.draw_rect(Rect2(LINE_X[0] + 7, LINE_Y - 2, 6, 4), Color("bdb8ae"))


## The prize on the stump past the far tree: six tall black cans.
func _draw_prize(ci: CanvasItem) -> void:
	var sx := 462.0
	ci.draw_rect(Rect2(sx - 13, GROUND_Y - 15, 26, 17), OUTLINE)
	ci.draw_rect(Rect2(sx - 12, GROUND_Y - 14, 24, 16), BARK)
	ci.draw_rect(Rect2(sx - 12, GROUND_Y - 14, 24, 3), Color("d6bd88"))
	if walked:
		return # taken
	for i in 6:
		var cx := sx - 11 + (i % 3) * 7
		var cy := GROUND_Y - 27 - (0 if i < 3 else 2)
		if i >= 3:
			cx += 3
		ci.draw_rect(Rect2(cx - 1, cy - 1, 7, 14), OUTLINE)
		ci.draw_rect(Rect2(cx, cy, 5, 12), CAN)
		ci.draw_rect(Rect2(cx, cy + 4, 5, 3), CAN_BAND)
		ci.draw_rect(Rect2(cx + 1, cy, 1, 12), Color("47301f"))


## The walker, standing at [param at] and leaning by [param angle] radians.
func _draw_walker(ci: CanvasItem, at: Vector2, angle: float) -> void:
	ci.draw_set_transform(at, angle, Vector2.ONE)
	# arms: out wide for balance, the pushing side dropped and the other raised
	var arm := clampf(_push, -1.0, 1.0)
	var wave := sin(_time * 9.0) * 2.0 * absf(state.lean)
	_arm(ci, Vector2(-3, -26), -1, 6.0 + arm * 8.0 + wave)
	_arm(ci, Vector2(3, -26), 1, 6.0 - arm * 8.0 - wave)
	# legs, one foot ahead of the other on the line
	ci.draw_rect(Rect2(-5, -14, 10, 15), OUTLINE)
	ci.draw_rect(Rect2(-4, -13, 3, 13), PANTS)
	ci.draw_rect(Rect2(1, -13, 3, 13), PANTS.darkened(0.2))
	ci.draw_rect(Rect2(-5, -1, 5, 2), OUTLINE)
	ci.draw_rect(Rect2(1, -1, 5, 2), OUTLINE)
	# body and head, with a beanie
	ci.draw_rect(Rect2(-5, -29, 10, 17), OUTLINE)
	ci.draw_rect(Rect2(-4, -28, 8, 15), SHIRT)
	ci.draw_rect(Rect2(-4, -28, 2, 15), SHIRT.lightened(0.2))
	ci.draw_rect(Rect2(-4, -38, 8, 10), OUTLINE)
	ci.draw_rect(Rect2(-3, -37, 6, 8), SKIN)
	ci.draw_rect(Rect2(-4, -40, 8, 4), Color("3f6b3a"))
	ci.draw_rect(Rect2(1, -34, 1, 1), OUTLINE)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _arm(ci: CanvasItem, shoulder: Vector2, side: int, lift: float) -> void:
	var hand := shoulder + Vector2(side * 14.0, -lift)
	ci.draw_line(shoulder, hand, OUTLINE, 4.0)
	ci.draw_line(shoulder, hand, SHIRT, 2.0)
	ci.draw_rect(Rect2(hand.x - 1.5, hand.y - 1.5, 3, 3), SKIN)


## Off the line: a quick tip to one side, then sitting in the dirt.
func _draw_fallen(ci: CanvasItem) -> void:
	var start := feet()
	var side := float(state.fell_to if state.fell_to != 0 else 1)
	var t := _fall_t
	var at := Vector2(start.x + side * 10.0 * t, lerpf(start.y, GROUND_Y + 2.0, t * t))
	var angle := lerpf(state.lean * 0.6, side * 1.4, minf(1.0, t * 1.4))
	if t >= 1.0:
		angle = side * 0.25 # back on your feet, dusting off
	_draw_walker(ci, at, angle)
	if t >= 1.0 and _phase_age < 1.6:
		for i in 4:
			var puff := Vector2(at.x - 12 + i * 8, GROUND_Y - 2 - fmod(_phase_age * 10.0 + i * 3, 6.0))
			ci.draw_rect(Rect2(puff, Vector2(3, 2)), Color("d6bd88"))


func _draw_balance(ci: CanvasItem) -> void:
	# the balance meter: green in the middle, warning, then red at the edges
	var r := Rect2(140, 10, 200, 26)
	UI.panel(ci, r)
	var bar := Rect2(r.position.x + 10, r.position.y + 8, r.size.x - 20, 7)
	ci.draw_rect(bar.grow(1), OUTLINE)
	ci.draw_rect(bar, UI.WARN)
	var safe := bar.size.x * SlacklineState.STEADY_LEAN
	ci.draw_rect(Rect2(bar.position.x + (bar.size.x - safe) / 2.0, bar.position.y, safe, bar.size.y), UI.GOOD)
	ci.draw_rect(Rect2(bar.position.x, bar.position.y, 10, bar.size.y), Color("b3362b"))
	ci.draw_rect(Rect2(bar.end.x - 10, bar.position.y, 10, bar.size.y), Color("b3362b"))
	var nx := bar.position.x + bar.size.x * (state.lean + 1.0) / 2.0
	ci.draw_rect(Rect2(nx - 2, bar.position.y - 3, 4, bar.size.y + 6), OUTLINE)
	ci.draw_rect(Rect2(nx - 1, bar.position.y - 2, 2, bar.size.y + 4), UI.CREAM)
	# how far along, as a strip under the meter
	var trail := Rect2(bar.position.x, bar.end.y + 3, bar.size.x, 2)
	ci.draw_rect(trail, UI.PAPER_DARK)
	ci.draw_rect(Rect2(trail.position, Vector2(trail.size.x * state.progress, 2)), UI.GOLD)
	UI.outlined(ci, Vector2(r.end.x + 6, r.position.y + 17), "%d%%" % state.percent(), UI.CREAM, 10)
	if absf(state.lean) >= SlacklineState.STEADY_LEAN and _phase == Phase.WALK and fmod(_time, 0.5) < 0.3:
		UI.outlined(ci, Vector2(SCREEN.x / 2.0, r.end.y + 16), "Steady...", UI.WARN, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)


func _card(ci: CanvasItem, title: String, body: String, foot: String, prize: Texture2D = null) -> void:
	var w := 300.0
	var lines := UI.wrap_lines(body, w - 28, 10)
	var h := 52.0 + lines.size() * 13.0 + (40.0 if prize else 0.0)
	var r := Rect2((SCREEN.x - w) / 2.0, 52, w, h)
	UI.panel(ci, r)
	UI.text(ci, Vector2(r.position.x + 14, r.position.y + 20), title, UI.GOLD, 12)
	UI.wrapped(ci, Vector2(r.position.x + 14, r.position.y + 36), body, w - 28, UI.INK, 10)
	UI.ink(ci, Vector2(r.position.x + 14, r.end.y - 10), foot, UI.INK_SOFT, 10)
	if prize:
		var at := Vector2(r.position.x + 14, r.end.y - 58)
		ci.draw_texture_rect(prize, Rect2(at, Vector2(32, 32)), false)
		UI.text(ci, at + Vector2(38, 21), "King Cobra x%d" % PRIZE_COUNT, UI.CREAM, 10)


func _draw_intro(ci: CanvasItem) -> void:
	var body := "Flat webbing strung between two pines, a little higher than it looks. Hold the arrow key away from the way you're tipping to lean back. Lean too far and you're off."
	if walked:
		body += " You've walked it before. The six-pack's long gone, but the line's still here."
	else:
		body += " Somebody's left a six-pack of King Cobra on the stump at the far end, for whoever walks the whole line."
	_card(ci, "The Camp 4 Slackline", body, "%s  Walk out     %s  Leave" % [_button("E", "A"), _button("Esc", "B")])


func _draw_result(ci: CanvasItem) -> void:
	var foot := "%s  Try again     %s  Leave" % [_button("E", "A"), _button("Esc", "B")]
	if state.status == SlacklineState.Status.WALKED:
		var body := "You touch the far pine. The whole line, end to end, and nobody saw you wobble (everybody saw you wobble)."
		if won_prize:
			body += " The six-pack of King Cobra on the stump is yours."
		var item := ItemDB.get_item(PRIZE)
		var tex: Texture2D = item.icon if won_prize and item else null
		_card(ci, "You walked the line!", body, foot.replace("Try again", "Walk it again"), tex)
		return
	var where := "halfway" if state.percent() >= 45 and state.percent() <= 55 else "%d%% of the way across" % state.percent()
	var body2 := "You stepped off %s. Your best is %d%%." % [where, _best]
	if not walked:
		body2 += " The King Cobra's still sitting on the stump."
	_card(ci, "Off the line", body2, foot)


func _hint(ci: CanvasItem, text: String) -> void:
	var w := UI.text_width(text, 10) + 16
	var r := Rect2((SCREEN.x - w) / 2.0, SCREEN.y - 26, w, 18)
	UI.panel(ci, r)
	UI.ink(ci, Vector2(r.position.x + 8, r.position.y + 13), text, UI.INK, 10)


func _button(keyboard: String, gamepad: String) -> String:
	return MenuInput.button(get_tree(), keyboard, gamepad)
