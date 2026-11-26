class_name ClimbLookLive
extends ClimbLook
## Thread 10's look for climbing v2: the lit granite wall, the sky and valley
## past the arete, the bolts and gear on the rock, the living camera and the
## climb's sounds, all derived from the session and bus events. It never
## changes the session, and nothing waits on it.
##
##   LookBackdrop   sky, stars, clouds, skyline and valley (screen-fixed)
##   wall sprite    LookWallPaint's height picture lit by look_wall.gdshader
##   LookFixtures   ground, ledge grass, bolts, pins, anchors, gear, ticks
##   LookCamera     where the world node looks (phase by phase, see there)
##   LookSound      what plays on each event, breathing with the pump
##
## The hour is the game clock when the climb began plus the climb's minutes
## (or [member hour_override] for shots). Sound's "climb" ambience finds this
## node in the "climb_screen" group and asks it for [method exposure].

const T := preload("res://scripts/climb/v2/look/look_tuning.gd")
const WALL_SHADER := preload("res://scripts/climb/v2/look/look_wall.gdshader")

## For still shots and tests: the hour every new look lights the wall at
## (-1 = the game clock). Copied into [member hour_override] at bind.
static var force_hour := -1.0
## The hour to light the wall at (-1 = the game clock).
var hour_override := -1.0
var reduce_motion := false

var camera := LookCamera.new()
var sound := LookSound.new()
var backdrop := LookBackdrop.new()
var wall_sprite := Sprite2D.new()
var fixtures := LookFixtures.new()
var paint := {}

var _start_minutes := 8 * 60
var _aim: Variant = null
var _aim_id := ""
var _special_zone := Rect2()
var _material := ShaderMaterial.new()
var _ramp_hour := -99.0
var _time := 0.0


func bind(p_session: ClimbSession, p_world: Node2D, p_screen_size: Vector2) -> void:
	super.bind(p_session, p_world, p_screen_size)
	add_to_group("climb_screen")
	hour_override = force_hour
	camera.screen_size = screen_size
	camera.reduce_motion = reduce_motion
	var clock := _autoload("GameClock")
	if clock:
		_start_minutes = int(clock.minutes)
	backdrop.name = "Backdrop"
	backdrop.screen_size = screen_size
	add_child(backdrop)
	backdrop.setup(session.route_id, hour())
	wall_sprite.name = "Wall"
	wall_sprite.centered = false
	wall_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_material.shader = WALL_SHADER
	wall_sprite.material = _material
	add_child(wall_sprite)
	fixtures.name = "Fixtures"
	fixtures.session = session
	add_child(fixtures)
	var bus := session.bus
	sound.listen(bus, session)
	bus.phase_changed.connect(_on_phase_changed)
	bus.aim_changed.connect(_on_aim_changed)
	bus.move_committed.connect(func(_m: V2Move) -> void:
		camera.move_committed()
		_aim = null
		_aim_id = ""
		_refresh_fixtures())
	bus.fall_caught.connect(func(f: V2Fall) -> void:
		camera.fall_caught(f.drop_m)
		_refresh_fixtures())
	for event: StringName in [&"clipped", &"unclipped", &"piece_placed", &"piece_popped", &"piece_cleaned", &"hand_swapped"]:
		bus.connect(event, func(_a: Variant = null, _b: Variant = null) -> void: _refresh_fixtures())
	bus.special_started.connect(func(_kind: StringName) -> void:
		_special_zone = Rect2()
		if session.wall:
			for z in session.wall.zones_at(session.pose.hip, &"crux"):
				_special_zone = z.rect)


## The hour of the day now (0-24, may run past 24 on a long climb).
func hour() -> float:
	if hour_override >= 0.0:
		return hour_override
	return (_start_minutes + (session.minutes if session else 0)) / 60.0


## How exposed you are, 0 (at the foot) to 1 (EXPOSED_M up): the beds turn
## to wind, the valley sinks away.
func exposure() -> float:
	if session == null or session.route == null:
		return 0.0
	var route_m := float(session.route.total_height_ft()) * 0.3048
	var pitches := maxi(1, session.sys.wall.pitch_count(session.route) if session.sys.wall else 1)
	var below := route_m * float(session.pitch) / pitches
	var hip := session.pose.hip.y if session.pose else 0.0
	return clampf((below + maxf(hip, 0.0)) / minf(T.EXPOSED_M, maxf(route_m, 30.0)), 0.0, 1.0)


## A new pitch: paint it, jump the camera to it, light it.
func show_wall(wall: V2Wall) -> void:
	paint = LookWallPaint.paint(wall, session.seed if session else 0)
	var rect: Rect2 = paint.rect
	wall_sprite.texture = ImageTexture.create_from_image(paint.height)
	wall_sprite.position = ClimberView.px(Vector2(rect.position.x, rect.end.y))
	_material.set_shader_parameter("tone_tex", ImageTexture.create_from_image(paint.tone))
	_material.set_shader_parameter("marks_tex", ImageTexture.create_from_image(paint.marks))
	_material.set_shader_parameter("sheets_tex", ImageTexture.create_from_image(paint.sheets))
	_ramp_hour = -99.0
	camera.snap_to(wall, session.pose.hip if session else wall.start)
	_light()
	_refresh_fixtures()
	_apply_camera()


func frame(delta: float) -> void:
	if session == null or world == null:
		return
	_time += delta
	camera.reduce_motion = reduce_motion
	camera.step(delta, session, _aim, _special_zone)
	_apply_camera()
	_light()
	backdrop.frame(delta, hour(), exposure())
	sound.step(delta, session.mods.wind if session.mods else 0.0, exposure())


func _apply_camera() -> void:
	if world:
		world.transform = camera.world_transform()
		backdrop.transform = world.transform.affine_inverse()


## Pictures painted, light set: for still shots.
func settle() -> void:
	backdrop.finish_painting()
	frame(0.0)


# ------------------------------------------------------------------ light

## What the hour, the weather and the headlamp do to the wall shader.
func _light() -> void:
	if paint.is_empty():
		return
	var h := hour()
	var pal := ClimbSky.palette(h)
	if absf(h - _ramp_hour) > 1.0 / 12.0:
		_ramp_hour = h
		var rock := session.wall.rock if session.wall and session.wall.rock != "" else ""
		if rock == "":
			rock = str(ClimbProfiles.get_profile(session.route_id).get("rock", "apron"))
		var colors := ClimbRock.colors(rock, pal)
		var tones := PackedVector3Array()
		for col: Color in colors.ramp:
			tones.append(Vector3(col.r, col.g, col.b))
		_material.set_shader_parameter("ramp", tones)
		_material.set_shader_parameter("ramp_count", tones.size())
		var day := PackedVector3Array()
		for col: Color in ClimbRock.colors(rock, ClimbSky.palette(12.0)).ramp:
			day.append(Vector3(col.r, col.g, col.b))
		_material.set_shader_parameter("ramp_day", day)
		_material.set_shader_parameter("chalk_color", colors.chalk)
		_material.set_shader_parameter("lichen_color", (colors.lichen_g as Color).lerp(colors.lichen_y, 0.35))
		_material.set_shader_parameter("streak_color", colors.streak)
	var sun := sun_at(h)
	_material.set_shader_parameter("sun_travel", sun.travel)
	_material.set_shader_parameter("sun_strength", sun.strength)
	_material.set_shader_parameter("sun_color", sun.color)
	var dark := night_at(h)
	_material.set_shader_parameter("night", dark)
	_material.set_shader_parameter("night_floor", T.NIGHT_FLOOR)
	var head := lamp_at()
	var rect: Rect2 = paint.rect
	_material.set_shader_parameter("lamp_pos", LookWallPaint.to_px(head, rect))
	_material.set_shader_parameter("lamp_radius", T.LAMP_RADIUS * ClimbV2.PX_PER_M)
	_material.set_shader_parameter("wet", session.mods.wet if session.mods else 0.0)
	_material.set_shader_parameter("time", _time)
	fixtures.night = dark
	fixtures.lamp = head
	# Things on the rock take the light too (the lamp keeps them visible).
	var tint: Color = pal.tint
	fixtures.modulate = Color(1, 1, 1).lerp(tint, 0.4).lerp(Color(0.45, 0.5, 0.7), dark * 0.6)


## The sun for [param h]: across the face from the left in the morning to
## the right by evening, highest at midday, gone at night; at least SUN_MIN
## while it's up so the holds' shadows always read.
static func sun_at(h: float) -> Dictionary:
	h = fposmod(h, 24.0)
	var a := clampf((h - 6.0) / 13.5, 0.0, 1.0)
	var up := sin(PI * a)
	var travel := Vector2(lerpf(0.85, -0.85, a), 0.5 + 0.5 * up).normalized()
	var strength := 0.0
	if h > 5.8 and h < 19.8:
		strength = lerpf(T.SUN_MIN, 0.8, up)
	var pal := ClimbSky.palette(h)
	return {"travel": travel, "strength": strength, "color": (pal.sun as Color).lerp(Color.WHITE, 0.4)}


## 0 by day .. 1 at night, easing through dusk and dawn.
static func night_at(h: float) -> float:
	h = fposmod(h, 24.0)
	if h >= 19.6:
		return clampf((h - 19.6) / 1.0, 0.0, 1.0)
	if h <= 6.0:
		return clampf((6.0 - h) / 0.8, 0.0, 1.0)
	return 0.0


## Where the headlamp shines: at the head, leaning toward the aimed hold.
func lamp_at() -> Vector2:
	if session == null or session.pose == null:
		return Vector2.ZERO
	var head := session.pose.hip + Vector2(0, ClimbV2.TORSO_M + 0.25)
	if _aim is Vector2:
		head += ((_aim as Vector2) - head).limit_length(1.0) * T.LAMP_LEAN
	return head


## Light on a spot of the wall, for views that want to match it (thread 9's
## climber): white in full sun, dim and blue at night, warm in the lamp.
func light_at(pos: Vector2) -> Color:
	var h := hour()
	var pal := ClimbSky.palette(h)
	var day := Color(1, 1, 1).lerp(pal.tint, 0.4)
	var dark := night_at(h)
	if dark <= 0.0:
		return day
	var r := pos.distance_to(lamp_at()) / T.LAMP_RADIUS
	var pool := clampf(1.0 - r * r, 0.0, 1.0)
	var night_col := day.lerp(Color(0.3, 0.34, 0.5), dark)
	return night_col.lerp(Color(1.0, 0.93, 0.8), pool * dark)


# ------------------------------------------------------------------ events

func _on_phase_changed(_from: StringName, to: StringName) -> void:
	camera.phase_changed(to)
	_refresh_fixtures()


func _on_aim_changed(hold_id: String) -> void:
	_aim_id = hold_id
	var h := session.wall.hold(hold_id) if session.wall and hold_id != "" else null
	_aim = h.pos if h else null
	_refresh_fixtures()


func _refresh_fixtures() -> void:
	fixtures.aim_id = _aim_id
	fixtures.queue_redraw()


func _autoload(name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("/root/" + name) if tree else null
