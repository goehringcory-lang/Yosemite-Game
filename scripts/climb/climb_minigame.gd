class_name ClimbMinigame
extends CanvasLayer
## The climbing screen. The rules live in ClimbState; this draws them and turns
## input into moves.
##
## The view is a granite wall seen face-on, its ragged right edge against the
## sky, with the real skyline of the route behind it. The climber works up the
## face on a rope that runs down through every quickdraw, cam or old piton to
## the belayer on the ledge. The wall scrolls as you climb, the far ridges
## sink as you gain height, and the light follows the time of day.
##
## Before the climb a route card shows the line, the gear and the food. At a
## crux there's a short skill check; at a belay you can eat; on a wall, nights
## are spent on a ledge or a portaledge.
##
## Controls: arrows climb (up = straight up, left/right = up-left/up-right);
## use tool = clip a bolt or place a cam; interact = eat (at a belay ledge) or
## chalk up (on the wall); Shift + an arrow = aid a hard move or jug a fixed
## rope (when you have the gear); cancel = retreat (asks first).

## Emitted when the player leaves the screen after topping out or retreating.
signal finished(success: bool, minutes: int)

const L := preload("res://scripts/climb/art/climb_layout.gd")
const UI := preload("res://scripts/climb/art/climb_ui.gd")
const P := preload("res://scripts/climb/art/climb_paint.gd")

enum Phase { INTRO, CLIMB, CRUX, NIGHT, PAUSE, RESULT }

const SCREEN := Vector2(480, 270)
const MOVE_TIME := 0.2
const FALL_TIME := 0.55
## A crux check ignores input for this long when it starts.
const CRUX_GRACE := 0.35
## The top of the gear tray along the bottom. A belayer whose feet sink below
## this is off the bottom of the picture, not half hidden behind the tray.
const TRAY_TOP := 237.0

const ROPE := Color("d8452e")
const ROPE_LIT := Color("f07a5a")
const ROPE_DARK := Color("7a2218")
const STEEL := Color("c8ccd4")
const STEEL_DARK := Color("6a6e78")
const OUTLINE := Color("1e1620")

var state: ClimbState
var route: RouteData
var profile: Dictionary
var belayer_look: Dictionary

var _canvas: Control
var _phase := Phase.INTRO
var _pal: Dictionary
var _sky_tex: Texture2D
var _clouds: Array[Texture2D] = []
var _layers: Array[Dictionary] = []
var _falls: Array[Dictionary] = []
var _wall_tex: Texture2D
var _wall_edge := PackedInt32Array()
var _wall_gap := Rect2i()
var _wall_pitch := -1
var _fx := ClimbFx.new()
## The row the view is centered on; eases toward the climber.
var _view_row := 0.0
## The climber's drawn position in (column, row), easing between holds.
var _shown := Vector2.ZERO
var _from := Vector2.ZERO
var _move_t := 1.0
var _move_dur := MOVE_TIME
var _reach := 0
var _step := 0
var _time := 0.0
var _fade := 0.0
var _start_minutes := 0
var _kit := {}
var _pose_mode := "wall"
var _act_t := 1.0
var _act_kind := ""
var _card_age := 0.0
var _result_age := 0.0
var _result_delay := -1.0
var _toast_text := ""
var _toast_age := 99.0
var _banner_age := 99.0
var _speech_text := ""
var _speech_age := 99.0
var _stamina_flash := 0.0
var _shake := 0.0
var _confirm_retreat := false
var _crux := {}
var _crux_grace := 0.0
var _crux_result := ""
var _crux_result_age := 99.0
var _night := {}
var _night_age := 0.0
var _lightning := 0.0
var _next_lightning := 4.0
var _bird_phase := 0.0
var _won_line := ""
var _swing_x := 0.0
var _seed := -1
## True while a roof pitch is showing: the picture runs sideways.
var _roof := false
var _roof_info := {}


## Call before adding the node to the tree.
func setup(p_route: RouteData, seed := -1) -> void:
	route = p_route
	_seed = seed
	_kit = Gear.owned.duplicate()
	state = ClimbState.new(route, Gear.count("cam"), seed, Gear.owned)
	state.interactive = true


func _ready() -> void:
	layer = 20
	profile = ClimbProfiles.get_profile(route.id)
	belayer_look = ClimbProfiles.belayer_look(route)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_draw_screen)
	add_child(_canvas)
	_start_minutes = GameClock.minutes
	state.start_minutes = _start_minutes
	_paint_scenery()
	_shown = Vector2(state.col, state.row)
	_from = _shown
	_view_row = state.row
	_events()


## For tools and tests: go straight to the climb.
func skip_intro() -> void:
	if _phase == Phase.INTRO:
		_phase = Phase.CLIMB
		_banner_age = 0.0
		_speak("start")


func _process(delta: float) -> void:
	_time += delta
	_card_age += delta
	_toast_age += delta
	_banner_age += delta
	_speech_age += delta
	_crux_result_age += delta
	_bird_phase += delta
	_stamina_flash = maxf(_stamina_flash - delta * 3.0, 0.0)
	_shake = maxf(_shake - delta * 18.0, 0.0)
	_act_t = minf(_act_t + delta / 0.35, 1.0)
	_lightning = maxf(_lightning - delta * 5.0, 0.0)
	if _move_t < 1.0:
		_move_t = minf(_move_t + delta / _move_dur, 1.0)
		var t := _move_t * _move_t * (3.0 - 2.0 * _move_t)
		_shown = _from.lerp(Vector2(state.col, state.row), t)
	else:
		_shown = Vector2(state.col, state.row)
	_view_row = lerpf(_view_row, _shown.y, minf(delta * 6.0, 1.0))
	_fade = maxf(_fade - delta * 2.5, 0.0)
	if _phase == Phase.CRUX:
		_update_crux(delta)
	if _phase == Phase.NIGHT:
		_night_age += delta
	if _result_delay >= 0.0:
		_result_delay -= delta
		if _result_delay < 0.0:
			_phase = Phase.RESULT
			_result_age = 0.0
	if _phase == Phase.RESULT:
		_result_age += delta
	_weather(delta)
	_fx.update(delta)
	# Low stamina: the climber sweats.
	if _phase == Phase.CLIMB and state.stamina <= 25 and state.status == ClimbState.Status.CLIMBING and fmod(_time, 0.9) < delta:
		_fx.sweat(_torso() + Vector2(4, -16))
	_canvas.queue_redraw()


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	var is_press := false
	for a in ["move_up", "move_left", "move_right", "use_tool", "interact", "ui_cancel"]:
		if event.is_action_pressed(a):
			is_press = true
	if not is_press or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	# The top-out and the retreat play out before the result card comes up.
	if _result_delay >= 0.0:
		return
	var cancel := event.is_action_pressed("ui_cancel")
	# E and Space both confirm on the cards, like the other screens.
	var interact := event.is_action_pressed("interact") or (event.is_action_pressed("use_tool") and _phase in [Phase.INTRO, Phase.RESULT])
	match _phase:
		Phase.INTRO:
			if interact:
				if ClimbState.starts_too_late(route, _start_minutes):
					return # the card says why
				skip_intro()
				_card_age = 0.0
			elif cancel:
				finished.emit(false, 0)
				queue_free()
		Phase.CLIMB:
			_climb_input(event)
		Phase.CRUX:
			_crux_input(event)
		Phase.NIGHT:
			if _night_age > 0.8 and (interact or event.is_action_pressed("use_tool")):
				_end_night()
		Phase.PAUSE:
			# Esc backs out of the question, so a second tap doesn't retreat.
			if interact:
				_phase = Phase.CLIMB
				state.retreat()
				_events()
				_after_action(Vector3i(state.col, state.row, state.pitch))
			elif cancel:
				_phase = Phase.CLIMB
		Phase.RESULT:
			if _result_age > 0.5 and (interact or cancel):
				finished.emit(state.status == ClimbState.Status.TOPPED_OUT, state.minutes)
				queue_free()


func _climb_input(event: InputEvent) -> void:
	if state.status != ClimbState.Status.CLIMBING or _move_t < 0.55:
		if event.is_action_pressed("ui_cancel") and state.status == ClimbState.Status.CLIMBING:
			_phase = Phase.PAUSE
		return
	var before := Vector3i(state.col, state.row, state.pitch)
	var dx := 99
	if event.is_action_pressed("move_up"):
		dx = 0
	elif event.is_action_pressed("move_left"):
		dx = -1
	elif event.is_action_pressed("move_right"):
		dx = 1
	var assist := Input.is_action_pressed("assist")
	if dx != 99:
		if assist and state.can_jug(dx):
			state.jug(dx)
		elif assist and state.can_aid(dx):
			state.aid_step(dx)
		elif assist:
			state.message = "Shift + an arrow aids a hard move (aiders) or jugs a fixed rope (ascenders), if you have them and it's there."
			_toast(state.message)
		else:
			state.move(dx)
	elif event.is_action_pressed("use_tool"):
		if state.protect():
			_act_t = 0.0
			_act_kind = "protect"
	elif event.is_action_pressed("interact"):
		if state.is_at_belay():
			eat_next()
		else:
			state.chalk_up()
	elif event.is_action_pressed("ui_cancel"):
		_phase = Phase.PAUSE
		return
	_after_action(before)


## Eats the smallest food that will spoil soonest, keeping a real meal for
## each night on the wall.
func eat_next() -> void:
	var id := state.next_food()
	if id == "":
		state.message = "You have nothing to eat."
		return
	state.eat(id)


## Starts the move animation, and repaints the wall on a new pitch.
func _after_action(before: Vector3i) -> void:
	_events()
	if before.z != state.pitch and state.status == ClimbState.Status.CLIMBING and _phase != Phase.NIGHT:
		_new_pitch()
	elif before.x != state.col or before.y != state.row:
		_from = _shown
		_move_t = 0.0
		_move_dur = FALL_TIME if _fell else MOVE_TIME
		_reach = state.col - before.x if before.y < state.row else 0
		_step += 1
		_belay_frame = 2 if _fell else 1
		_belay_frame_t = 0.3
		if _fell:
			_pose_mode = "fall"
		else:
			_pose_mode = "wall"
			if state.style() == "slab" or state.style() == "dike":
				_fx.dust(_torso() + Vector2(0, 22), _dust_color(), 3)
	_fell = false
	if state.message != "" and _toast_text != state.message:
		_toast(state.message)
	if not state.pending.is_empty() and _phase == Phase.CLIMB:
		_start_crux()


var _fell := false


func _new_pitch() -> void:
	_paint_scenery()
	_fade = 1.0
	_from = Vector2(state.col, state.row)
	_shown = _from
	_view_row = 0.0
	_move_t = 1.0
	_banner_age = 0.0
	_pose_mode = "wall"


func _toast(text: String) -> void:
	_toast_text = text
	_toast_age = 0.0


func _speak(event: String) -> void:
	var line := ClimbProfiles.banter(route, event)
	if line != "":
		_speech_text = line
		_speech_age = -2.5 if event == "start" else 0.0


## Reacts to what the rules reported: effects, speech, the crux, nights.
func _events() -> void:
	for e in state.take_events():
		match e.type:
			"pitch_start":
				_banner_age = 0.0
				if e.pitch == 0:
					_speak("start")
			"clip":
				_fx.sparks(_torso() + Vector2(8, -10), 8)
				if randf() < 0.5:
					_speak("clip")
			"cam":
				_fx.sparks(_torso() + Vector2(8, -6), 6)
			"chalk":
				_fx.chalk(_torso() + Vector2(0, 2), 16)
				_act_t = 0.0
				_act_kind = "chalk"
			"eat":
				_act_t = 0.0
				_act_kind = "eat"
				_stamina_flash = 1.0
			"rest":
				_stamina_flash = 0.7
				if randf() < 0.5:
					_speak("rest")
			"fall":
				_fell = true
				_shake = 6.0
				_speak("fall")
				_fx.dust(_torso(), _dust_color(), 10)
			"crux":
				_crux_result = e.result
				_crux_result_age = 0.0
				if e.result == "perfect":
					_fx.sparks(_torso() + Vector2(0, -16), 16)
					_speak("crux")
			"aid", "jug":
				_fx.sparks(_torso() + Vector2(6, -14), 6)
			"bivy":
				_night = e
				_night_age = 0.0
				_phase = Phase.NIGHT
			"topout":
				_fx.confetti(_torso() + Vector2(0, -20))
				_pose_mode = "cheer"
				_result_delay = 1.6
				_won_line = ClimbProfiles.banter(route, "top")
				_speak("top")
			"retreat":
				_result_delay = 0.9


func _end_night() -> void:
	_phase = Phase.CLIMB
	_new_pitch()
	_fade = 1.0
	_toast(state.message)


func _dust_color() -> Color:
	return (_pal.get("lit", Color("e8e0d0")) if _pal.has("lit") else Color(0.82, 0.78, 0.7, 0.8))


# ---------------------------------------------------------------- the crux

func _start_crux() -> void:
	_phase = Phase.CRUX
	_crux_grace = CRUX_GRACE
	var kind: String = state.pending.kind
	match kind:
		"timing":
			_crux = {"kind": kind, "name": state.pending.name, "window": state.pending.window,
				"center": randf_range(0.3, 0.7), "pos": 0.0, "dir": 1.0, "speed": 1.15 + 0.1 * float(state.spec.get("diff", 2)), "passes": 0}
		"rhythm":
			_crux = {"kind": kind, "name": state.pending.name, "need": 8, "done": 0, "left_next": true,
				"time_total": 5.0 + (2.0 if state.has_shoes else 0.0), "time_left": 5.0 + (2.0 if state.has_shoes else 0.0)}
		_:
			_crux = {"kind": "mash", "name": state.pending.name, "need": 9, "done": 0, "left_next": true,
				"time_total": 4.0, "time_left": 4.0}


func _update_crux(delta: float) -> void:
	# The meter waits a moment, so a second tap of the arrow that brought you
	# here doesn't spend the check.
	if _crux_grace > 0.0:
		_crux_grace -= delta
		return
	match _crux.kind:
		"timing":
			_crux.pos += _crux.dir * _crux.speed * delta
			if _crux.pos >= 1.0:
				_crux.pos = 1.0
				_crux.dir = -1.0
				_crux.passes += 1
			elif _crux.pos <= 0.0:
				_crux.pos = 0.0
				_crux.dir = 1.0
				_crux.passes += 1
			# Wait as long as you like, but the marker keeps sweeping; after a
			# long time it counts as an average move.
			if _crux.passes >= 9:
				_resolve_crux("good")
		_:
			_crux.time_left -= delta
			if _crux.time_left <= 0.0:
				_resolve_crux("good" if _crux.done >= _crux.need * 0.6 else "slip")


func _crux_input(event: InputEvent) -> void:
	if _crux_grace > 0.0:
		return
	match _crux.kind:
		"timing":
			if event.is_action_pressed("use_tool") or event.is_action_pressed("interact") or event.is_action_pressed("move_up"):
				var off := absf(_crux.pos - _crux.center)
				var half: float = _crux.window / 2.0
				if off <= half * 0.38:
					_resolve_crux("perfect")
				elif off <= half:
					_resolve_crux("good")
				else:
					_resolve_crux("slip")
		"rhythm":
			var left := event.is_action_pressed("move_left")
			var right := event.is_action_pressed("move_right")
			if left or right:
				if left == _crux.left_next:
					_crux.done += 1
					_crux.left_next = not _crux.left_next
					_fx.dust(_torso() + Vector2(-8 if left else 8, 4), _dust_color(), 2)
					if _crux.done >= _crux.need:
						_resolve_crux("perfect" if _crux.time_left > _crux.time_total * 0.4 else "good")
				else:
					_crux.time_left -= 0.4
		_:
			if event.is_action_pressed("move_up"):
				_crux.done += 1
				_fx.dust(_torso() + Vector2(0, -14), _dust_color(), 2)
				if _crux.done >= _crux.need:
					_resolve_crux("perfect" if _crux.time_left > _crux.time_total * 0.4 else "good")


func _resolve_crux(result: String) -> void:
	_phase = Phase.CLIMB
	var before := Vector3i(state.col, state.row, state.pitch)
	state.resolve_crux(result)
	_crux = {}
	_after_action(before)


# ---------------------------------------------------------------- scenery

func _hour() -> float:
	return (_start_minutes + state.minutes) / 60.0


## Paints the sky, landscape, clouds and this pitch's wall for the current light.
func _paint_scenery() -> void:
	_pal = ClimbSky.palette(_hour())
	var seed_value := hash(route.id)
	_sky_tex = ImageTexture.create_from_image(ClimbSky.sky(_pal))
	var land := ClimbLandscape.build(profile, _pal, seed_value)
	_layers.clear()
	for layer: Dictionary in land.layers:
		_layers.append({"tex": ImageTexture.create_from_image(layer.image), "sink": layer.sink, "pad": layer.pad})
	_falls = land.falls
	_clouds.clear()
	for i in 4:
		_clouds.append(ImageTexture.create_from_image(ClimbSky.cloud(_pal, seed_value + i)))
	var rock: String = profile.get("rock", "apron")
	_roof = state.style() == "roof"
	if _roof:
		_roof_info = ClimbRock.paint_roof(state, rock, _pal, seed_value + state.pitch * 97)
		_wall_tex = ImageTexture.create_from_image(_roof_info.image)
		_wall_pitch = state.pitch
		return
	var wall := ClimbRock.paint(state, rock, _pal, seed_value + state.pitch * 97)
	var im: Image = wall.image
	_wall_edge = wall.edge
	_wall_gap = wall.gap
	if state.pitch == 0:
		ClimbScenes.paint_base(im, profile.get("ground", ""), state, _pal, _wall_edge, seed_value)
	if state.pitch == route.pitches.size() - 1:
		ClimbScenes.paint_finish(im, profile.get("finish", ""), state, _pal, _wall_edge, seed_value)
	_wall_tex = ImageTexture.create_from_image(im)
	_wall_pitch = state.pitch


## Screen position of a (possibly fractional) row and column's hold.
func _screen(r: float, c: float) -> Vector2:
	if _roof:
		return Vector2(L.ROOF_X + (r - _view_row) * L.ROOF_ROW_W, L.ROOF_Y + (c - 2.0) * 4.0 - L.roof_lift(state.top_row, r))
	if state.style() == "chimney":
		return Vector2(L.CHIMNEY_X + (c - 2.0) * 9.0, L.ANCHOR_Y - (r - _view_row) * L.ROW_H)
	return Vector2(L.GRID_X + (c + 0.5) * L.COL_W, L.ANCHOR_Y - (r - _view_row) * L.ROW_H)


func _img_y() -> float:
	return L.ANCHOR_Y + _view_row * L.ROW_H - (state.top_row + L.ROWS_ABOVE - 0.5) * L.ROW_H


## Screen x of the left edge of a roof picture.
func _img_x() -> float:
	return L.ROOF_X - (_view_row + L.ROOF_BEFORE + 0.5) * L.ROOF_ROW_W


## Screen y of the surface of the belay ledge at [param r] (0 or the top row).
func _ledge_y(r: int) -> float:
	if _roof:
		return float(_roof_info.ledge_y) if r == 0 else float(_roof_info.shelf_top)
	return _img_y() + L.wall_px(state.top_row, r, 0).y + 7.0


## How far up the whole route the climber is, 0 at the start, 1 at the top.
func _progress() -> float:
	var total := route.pitches.size()
	var done := float(mini(state.pitch, total))
	if state.pitch < total:
		done += clampf(_shown.y / float(state.top_row), 0.0, 1.0)
	return clampf(done / float(total), 0.0, 1.0)


func _torso() -> Vector2:
	var hold := _screen(_shown.y, _shown.x)
	var t := hold + Vector2(0, 24 if _roof else 20)
	if _shown.y < 0.5:
		var stand := Vector2(hold.x, _ledge_y(0) - 26.0)
		t = stand.lerp(t, clampf(_shown.y * 2.0, 0.0, 1.0))
	elif _shown.y > state.top_row - 0.5:
		var stand_top := Vector2(hold.x, _ledge_y(state.top_row) - 26.0)
		t = t.lerp(stand_top, clampf((_shown.y - (state.top_row - 0.5)) * 2.0, 0.0, 1.0))
	return t.round()


func _harness() -> Vector2:
	return _torso() + Vector2(0, 5)


func _belay_spot() -> Vector2:
	if _roof:
		return Vector2(_img_x() + float(_roof_info.wall_x) + 34.0, _ledge_y(0) + 2.0)
	if route.top_rope:
		return Vector2(_screen(0, ClimbState.COLUMNS / 2).x + 10, _ledge_y(state.top_row))
	return Vector2(_screen(0, 0).x - 26, _ledge_y(0))


# ---------------------------------------------------------------- drawing

func _draw_screen() -> void:
	if _phase == Phase.NIGHT:
		ClimbNight.draw(_canvas, _night, state, route, profile, _night_age, _time, _kit)
		return
	var height := _progress()
	var shake := Vector2(roundf(sin(_time * 80.0) * _shake * 0.35), roundf(cos(_time * 63.0) * _shake * 0.25))
	_canvas.draw_set_transform(shake)
	_canvas.draw_texture(_sky_tex, Vector2.ZERO)
	_draw_clouds(height)
	_draw_layers(0.5 if _roof else height)
	_draw_birds()
	_draw_wall()
	_draw_protection()
	_draw_rope()
	_draw_belayer()
	_draw_climber()
	_draw_reachable()
	_fx.draw(_canvas)
	_canvas.draw_set_transform(Vector2.ZERO)
	_draw_atmosphere()
	_draw_hud(height)
	if _fade > 0.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0, 0, 0, _fade))
	match _phase:
		Phase.INTRO:
			ClimbHud.route_card(_canvas, state, profile, belayer_look, _recommended_food(), _card_age, {"sky": _sky_tex, "layers": _layers})
		Phase.CRUX:
			ClimbHud.crux(_canvas, _crux.kind, _crux.name, _crux, _time)
		Phase.PAUSE:
			ClimbHud.pause_card(_canvas, state)
		Phase.RESULT:
			ClimbHud.result_card(_canvas, state, profile, _won_line, _result_age, state.status == ClimbState.Status.TOPPED_OUT)


## About how much food energy this route wants, for the route card.
func _recommended_food() -> int:
	return int(profile.get("food", 0))


func _draw_clouds(height: float) -> void:
	var tint := Color(1, 1, 1, 0.35 if _pal.night else 0.95)
	var storm: bool = state.is_stormy()
	if storm:
		tint = Color(0.55, 0.57, 0.66, 1.0)
	for i in _clouds.size():
		var speed := 3.0 + i * 1.7
		var x := fposmod(140.0 + i * 131.0 + _time * speed, SCREEN.x + 140.0) - 70.0
		var y := 22.0 + i * 27.0 + height * (8.0 + i * 3.0)
		_canvas.draw_texture(_clouds[i], Vector2(x, y).round(), tint)
		if storm:
			_canvas.draw_texture(_clouds[i], Vector2(x - 40, y - 8).round(), tint)


func _draw_layers(height: float) -> void:
	for i in _layers.size():
		var layer: Dictionary = _layers[i]
		_canvas.draw_texture(layer.tex, Vector2(0, roundf(height * layer.sink) - layer.pad))
	# Waterfalls shimmer.
	for f: Dictionary in _falls:
		var layer: Dictionary = _layers[f.layer]
		var off: float = roundf(height * layer.sink) - float(layer.pad)
		for y in range(int(f.y0) + 2, int(f.y1), 3):
			var pos := Vector2(f.x + 1 + int(sin(_time * 3.0 + y * 0.3) * 1.2), y + off)
			if fmod(_time * 7.0 + y * 0.21, 3.0) < 1.0:
				_canvas.draw_rect(Rect2(pos, Vector2(1, 2)), Color(1, 1, 1, 0.8))


## Swifts darting past the wall.
func _draw_birds() -> void:
	if _pal.night:
		return
	for i in 3:
		var t := fposmod(_bird_phase * (0.12 + i * 0.03) + i * 0.37, 1.0)
		var x := SCREEN.x + 20 - t * (SCREEN.x * 0.62)
		var y := 60.0 + i * 38.0 + sin(t * 9.0 + i) * 10.0
		var flap := int(_time * 8.0 + i) % 2
		var col := Color(0.1, 0.1, 0.14, 0.9)
		_canvas.draw_rect(Rect2(x, y, 2, 1), col)
		_canvas.draw_rect(Rect2(x - 2, y - flap, 2, 1), col)
		_canvas.draw_rect(Rect2(x + 2, y - flap, 2, 1), col)


func _draw_wall() -> void:
	var top := _img_y()
	if _roof:
		_canvas.draw_texture(_wall_tex, Vector2(roundf(_img_x()), 0))
		top = SCREEN.y
	else:
		_canvas.draw_texture(_wall_tex, Vector2(0, roundf(top)))
	# Below the picture: more wall, or the forest floor at the foot of pitch one.
	var bottom := top + (0 if _roof else _wall_tex.get_height())
	if bottom < SCREEN.y and not _roof:
		var ground: Color = Color("2e3a2a") if state.pitch == 0 else (_pal.rock as Color).darkened(0.2)
		_canvas.draw_rect(Rect2(0, bottom, SCREEN.x, SCREEN.y - bottom), ground)
	# Fixed pieces glint until they're clipped.
	for r: int in state.bolts:
		var cell := Vector2i(state.bolts[r], r)
		if cell in state.clipped_bolts:
			continue
		var p := _bolt_pos(cell)
		if state.bolt_kinds.get(r, "bolt") == "pin":
			# An old iron piton, rusty, with a ring.
			_canvas.draw_rect(Rect2(p + Vector2(-3, -1), Vector2(6, 3)), OUTLINE)
			_canvas.draw_rect(Rect2(p + Vector2(-2, 0), Vector2(5, 1)), Color("a85a2a"))
			_canvas.draw_rect(Rect2(p + Vector2(-2, 1), Vector2(5, 1)), Color("6a3a1a"))
			_canvas.draw_rect(Rect2(p + Vector2(-3, -2), Vector2(2, 2)), Color("8a8e98"))
		else:
			_canvas.draw_rect(Rect2(p + Vector2(-2, -2), Vector2(5, 6)), OUTLINE)
			_canvas.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(3, 4)), STEEL)
			_canvas.draw_rect(Rect2(p + Vector2(0, 0), Vector2(1, 2)), STEEL_DARK)
		if fmod(_time * 1.3 + r * 0.37, 2.0) < 0.25:
			_canvas.draw_rect(Rect2(p + Vector2(-2, -1), Vector2(5, 1)), Color(1, 1, 1, 0.9))
			_canvas.draw_rect(Rect2(p + Vector2(0, -3), Vector2(1, 5)), Color(1, 1, 1, 0.9))
	# Fixed ropes hang beside the line where there are some.
	for r in range(1, state.top_row):
		for c: int in state.holds.get(r, {}):
			if state.holds[r][c].get("fixed", false):
				var p := _screen(r, c) + Vector2(-12, 0)
				_canvas.draw_rect(Rect2(p, Vector2(2, L.ROW_H)), Color("e8c040"))
				_canvas.draw_rect(Rect2(p, Vector2(1, L.ROW_H)), Color("f8e888"))
				_canvas.draw_rect(Rect2(p + Vector2(0, 0), Vector2(2, 1)), Color("8a6a1a"))


func _bolt_pos(cell: Vector2i) -> Vector2:
	return (_screen(cell.y, cell.x) + Vector2(10, -5)).round()


## Quickdraws hanging from clipped bolts, and cams in their cracks.
func _draw_protection() -> void:
	for piece: Dictionary in state.protection:
		var cell: Vector2i = piece.cell
		if piece.kind == "draw":
			var p := _bolt_pos(cell)
			var tex := ClimbSprites.hardware("pin_draw" if piece.get("hw", "bolt") == "pin" else "draw")
			_canvas.draw_texture(tex, p + Vector2(-5, -2))
		else:
			var p := (_screen(cell.y, cell.x) + Vector2(4, -4)).round()
			var ci := (cell.y + cell.x) % ClimbSprites.CAM_COLORS.size()
			_canvas.draw_texture(ClimbSprites.hardware("cam", ci), p + Vector2(-6, -4))


## Where the rope leaves each piece of protection.
func _rope_point(piece: Dictionary) -> Vector2:
	var cell: Vector2i = piece.cell
	if piece.kind == "draw":
		return _bolt_pos(cell) + Vector2(0, 12)
	return (_screen(cell.y, cell.x) + Vector2(4, 10)).round()


## The rope: from the belayer up through every piece to the climber's harness
## (a top rope runs up to the anchor and back), with a little sag between.
func _draw_rope() -> void:
	var points: Array[Vector2] = [_belay_spot() + Vector2(8, -22)]
	if route.top_rope:
		var anchor := Vector2(_screen(0, ClimbState.COLUMNS / 2).x + 6, _ledge_y(state.top_row) - 6)
		points.append(anchor)
		points.append(_harness() + Vector2(0, -2))
	else:
		for piece in state.protection:
			points.append(_rope_point(piece))
		points.append(_harness())
	for i in points.size() - 1:
		var sag := 0.07 if i == 0 else 0.035
		if route.top_rope:
			sag = 0.0 if i == 0 else 0.01
		_sag(points[i], points[i + 1], sag)
	if not route.top_rope:
		# The tail piled below the belayer.
		if _belayer_in_view():
			_coil(points[0] + Vector2(-4, 22))


func _sag(a: Vector2, b: Vector2, amount: float) -> void:
	var length := a.distance_to(b)
	var sway := sin(_time * 1.6 + a.y * 0.02) * 1.5
	var mid := (a + b) / 2.0 + Vector2(length * amount * 0.5 + sway, length * amount * 0.6)
	var pts := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t).round())
	_canvas.draw_polyline(pts, ROPE_DARK, 3.0)
	_canvas.draw_polyline(pts, ROPE, 2.0)
	# A lit thread and the sheath's pattern.
	for i in range(0, pts.size(), 2):
		_canvas.draw_rect(Rect2(pts[i] + Vector2(0, -1), Vector2(1, 1)), ROPE_LIT)


func _coil(p: Vector2) -> void:
	for i in 3:
		_canvas.draw_arc(p + Vector2(i, 0), 6.0 - i, 0.0, TAU, 14, ROPE_DARK, 3.0)
		_canvas.draw_arc(p + Vector2(i, 0), 6.0 - i, 0.0, TAU, 14, ROPE, 2.0)


var _belay_frame := 0
var _belay_frame_t := 0.0


## False once the belay ledge has sunk below the gear tray as you climb.
func _belayer_in_view() -> bool:
	var p := _belay_spot()
	return p.y >= -30 and p.y <= TRAY_TOP + 6.0


func _draw_belayer() -> void:
	var p := _belay_spot()
	if not _belayer_in_view():
		return
	var mode := "belay"
	if route.top_rope or (state.pitch > 0 and route.pitches.size() >= 5) or _roof:
		mode = "anchor"
	elif state.row > 0 and state.status == ClimbState.Status.CLIMBING:
		mode = "look_up"
	# A pay-out hop when you move, a quick take-in on a catch.
	var frame := 0
	if _belay_frame_t > 0.0:
		frame = _belay_frame
		_belay_frame_t -= get_process_delta_time()
	if state.status == ClimbState.Status.TOPPED_OUT:
		mode = "cheer"
		frame = int(_time * 2.0) % 3
	var tex := ClimbSprites.belayer(belayer_look, mode, frame)
	var sz := tex.get_size()
	var pos := Vector2(p.x - sz.x * 0.5, p.y - sz.y + 4 + (2 if mode == "anchor" else 0))
	# A soft shadow on the ledge.
	_canvas.draw_rect(Rect2(p + Vector2(-9, 0), Vector2(18, 2)), Color(0, 0, 0, 0.25))
	_canvas.draw_texture(tex, pos.round())
	ClimbHud.speech(_canvas, p + Vector2(0, -26), _speech_text, belayer_look.get("name", ""), _speech_age)


## The climber, with their gear.
func _draw_climber() -> void:
	var pose := _pose()
	var flags := {"portaledge": route.nights > 0 and state.has_portaledge, "aiders": state.has_aiders and bool(state.spec.get("hard_aid", false)),
		"snow": state.is_snow()}
	var tex := ClimbSprites.climber(pose, _kit, flags)
	var o := ClimbSprites.ORIGIN
	var torso := _torso()
	if pose.get("mode", "") == "chimney":
		torso.x = roundf(L.CHIMNEY_X + int(pose.side) * 6.0)
	var pos := torso - o
	_canvas.draw_texture(tex, pos.round())
	# The haul bag swings below on a big wall.
	if route.nights > 0 and state.has_haul_bag and _shown.y > 0.5:
		var hp := torso + Vector2(-14, 46 + sin(_time * 1.3) * 2.0)
		_canvas.draw_line(torso + Vector2(-2, 6), hp + Vector2(0, -4), ROPE_DARK, 2.0)
		_canvas.draw_texture(UI.icon_texture("haul_bag"), (hp + Vector2(-6, -6)).round())
	# Headlamp glow after dark.
	if _pal.night:
		for i in 6:
			_canvas.draw_circle(torso + Vector2(0, -14), 52.0 - i * 8.0, Color(1.0, 0.92, 0.7, 0.045))


## The pose to draw now: a stance that eases into the next one while a move
## plays, with the special poses (fall, hang, cheer, chalk, protect, eat,
## roof, chimney) from ClimbSprites.
func _pose() -> Dictionary:
	var step := _step
	var a := ClimbSprites.stance(step)
	if _roof:
		a = ClimbSprites.roof_pose(step)
	elif state.style() == "chimney":
		a = ClimbSprites.chimney_pose(-1 if step % 2 == 0 else 1)
	if _move_t < 1.0:
		var b: Dictionary = ClimbSprites.stance(step - 1)
		if _roof:
			b = ClimbSprites.roof_pose(step - 1)
		elif state.style() == "chimney":
			b = ClimbSprites.chimney_pose(-1 if (step - 1) % 2 == 0 else 1)
		var t := _move_t * _move_t * (3.0 - 2.0 * _move_t)
		var lean_move := _reach * sin(t * PI) * 2.0
		if a.get("mode", "") == "chimney":
			# Hop across the slot: the pose flips at the halfway point.
			a = a if t > 0.5 else b
		else:
			a = ClimbSprites.blend_pose(b, a, t)
			# The hand that's reaching goes up over the next hold first.
			var arc := sin(t * PI) * 5.0
			if not _roof:
				a["hr" if (step % 2) == 0 else "hl"] += Vector2(0, -arc)
			a["lean"] = float(a.get("lean", 0)) + lean_move
	elif a.get("mode", "") != "chimney":
		a["lean"] = float(a.get("lean", 0)) + roundf(sin(_time * 2.0) * 0.6) + (1.0 if state.stamina <= 25 and fmod(_time, 1.2) < 0.15 else 0.0)
	var mode := _pose_mode
	var on_ledge := _shown.y < 0.45 or _shown.y > state.top_row - 0.45
	if on_ledge and mode == "wall" and state.status == ClimbState.Status.CLIMBING:
		mode = "stand"
	match mode:
		"stand":
			a = ClimbSprites.stand_pose()
		"fall":
			a = ClimbSprites.fall_pose()
			a["hr"] += Vector2(0, sin(_time * 30.0) * 2.0)
			if _move_t >= 1.0:
				_pose_mode = "hang"
		"hang":
			a = ClimbSprites.hang_pose()
			if _move_t >= 1.0 and fmod(_time, 2.5) > 2.45:
				_pose_mode = "wall"
		"cheer":
			a = ClimbSprites.cheer_pose()
			a["lean"] = roundf(sin(_time * 9.0))
	# Other short actions.
	if _act_t < 1.0 and mode in ["wall", "stand", "hang"] and a.get("mode", "") != "chimney":
		match _act_kind:
			"chalk":
				a = ClimbSprites.chalk_pose(step)
			"protect":
				a = ClimbSprites.protect_pose(step)
			"eat":
				a = ClimbSprites.eat_pose()
	if state.chalk_moves > 0:
		a["chalk"] = true
	return a


func _hint() -> String:
	if state.status != ClimbState.Status.CLIMBING:
		return ""
	var parts: Array[String] = []
	if state.can_clip():
		parts.append("Space: clip the bolt" if state.bolt_kinds.get(state.row, "bolt") == "bolt" else "Space: clip the old piton")
	elif state.can_place_cam():
		parts.append("Space: place a cam")
	if state.is_at_belay():
		if state.can_eat():
			parts.append("E: eat")
	elif state.can_chalk():
		parts.append("E: chalk up")
	for dx in [-1, 0, 1]:
		if state.can_jug(dx):
			parts.append("Shift+arrow: jug")
			break
	for dx in [-1, 0, 1]:
		if state.can_aid(dx):
			parts.append("Shift+arrow: aid")
			break
	if parts.is_empty():
		# The reminder is for the first minute; after that it just covers the wall.
		return "Arrows: climb     Esc: retreat" if _time < 40.0 and state.pitch == 0 else ""
	return "     ".join(parts)


func _usable() -> Dictionary:
	var out := {}
	if state.status != ClimbState.Status.CLIMBING:
		return out
	out["cam"] = state.can_place_cam() and not state.can_clip()
	out["clip"] = state.can_clip()
	out["chalk"] = state.can_chalk()
	out["eat"] = state.can_eat()
	for dx in [-1, 0, 1]:
		out["jug"] = out.get("jug", false) or state.can_jug(dx)
		out["aid"] = out.get("aid", false) or state.can_aid(dx)
	return out


## Rings round the holds you can reach, with what each move costs.
func _draw_reachable() -> void:
	if state.status != ClimbState.Status.CLIMBING or _move_t < 1.0 or _phase != Phase.CLIMB:
		return
	var pulse := 0.6 + 0.4 * sin(_time * 5.0)
	for dx in [-1, 0, 1]:
		var r := state.row + 1
		var c: int = state.col + dx
		if state.hold_at(r, c).is_empty():
			continue
		var p := _screen(r, c).round()
		var hold := state.hold_at(r, c)
		var cost := state.move_cost(r, c)
		if r == state.top_row:
			_canvas.draw_arc(p, 7.0, 0, TAU, 16, Color(UI.GOOD, pulse), 1.0)
			if dx == 0 or state.hold_at(r, state.col).is_empty():
				UI.text(_canvas, p + Vector2(-12, -10), "ledge", UI.GOOD)
			continue
		var color := _cost_color(cost)
		if hold.get("rest", false):
			color = UI.GOOD
		_canvas.draw_arc(p, 7.0, 0, TAU, 16, Color(color, pulse), 1.0)
		var key: String = ["<", "^", ">"][dx + 1]
		var label := "%s %d" % [key, cost]
		if hold.get("crux", false):
			label += " crux"
		elif hold.get("rest", false):
			label += " rest"
		elif hold.get("fixed", false):
			label += " fixed"
		# Left ring's label goes left, the middle one above, the right one
		# right. Under a roof the three rings sit almost on top of each other,
		# so their labels stack in a list beside them instead.
		if _roof:
			UI.outlined(_canvas, p + Vector2(9, -7 + (dx + 1) * 10), label, color, 10)
		else:
			match dx:
				-1:
					UI.outlined(_canvas, p + Vector2(-9, -1), label, color, 10, -1.0, HORIZONTAL_ALIGNMENT_RIGHT)
				0:
					UI.outlined(_canvas, p + Vector2(0, -11), label, color, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
				_:
					UI.outlined(_canvas, p + Vector2(9, -1), label, color, 10)
		if state.stamina - cost <= 0 and not hold.get("crux", false):
			UI.outlined(_canvas, p + Vector2(0, 17), "fall!", UI.WARN, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)


func _cost_color(cost: int) -> Color:
	var base := 2 + roundi(int(state.spec.diff) * ClimbState.COST_PER_GRADE)
	return UI.GOOD if cost <= base else (UI.GOLD if cost <= base + 2 else UI.WARN)


## Weather and the dark: rain, a gray cast, lightning, a night vignette.
func _weather(delta: float) -> void:
	if state.is_stormy() and _phase in [Phase.CLIMB, Phase.CRUX]:
		for i in 5:
			_fx.spawn(Vector2(randf_range(0, SCREEN.x + 60), -4), Vector2(-50, 240), 1.2, Color(0.8, 0.88, 1.0, 0.85), 1, 0.0, true)
		_next_lightning -= delta
		if _next_lightning <= 0.0:
			_lightning = 1.0
			_next_lightning = randf_range(5.0, 11.0)


func _draw_atmosphere() -> void:
	if state.is_stormy():
		_canvas.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.08, 0.1, 0.18, 0.36))
	if _lightning > 0.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(1, 1, 1, 0.5 * _lightning))
	if _pal.night:
		_canvas.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.02, 0.03, 0.1, 0.18))


func _draw_hud(height: float) -> void:
	var feet := int(round(height * route.total_height_ft()))
	# The cards stand alone: no plate, bars or toolbar peeking out behind them.
	if _phase == Phase.INTRO or _phase == Phase.RESULT:
		return
	ClimbHud.route_plate(_canvas, state, feet)
	ClimbHud.topo_bar(_canvas, state, height)
	ClimbHud.stamina(_canvas, state, _stamina_flash, 0.0)
	if _phase == Phase.CLIMB or _phase == Phase.PAUSE:
		var toolbar_end := ClimbHud.toolbar(_canvas, state, _time, _usable())
		ClimbHud.hints(_canvas, _hint(), toolbar_end + 6.0)
	if _phase == Phase.CLIMB:
		ClimbHud.toast(_canvas, _toast_text, _toast_age)
		ClimbHud.pitch_banner(_canvas, state, _banner_age)
	if _phase == Phase.CRUX or _crux_result_age < 1.4:
		ClimbHud.crux_result(_canvas, _crux_result, _crux_result_age)
