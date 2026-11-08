class_name RoomWindows
extends Node2D
## A room's windows, following the clock. The room pictures are painted at
## noon: the view in the glass is a bright day and the sun falls through each
## window in a pale shaft across the floor. This takes that light back out as
## the sun goes down (no sunny floor at midnight), lays the low sun in long
## and warm and leaning across the room at either end of the day, lets a faint
## cool moonbeam in on clear nights near full moon, and turns the glass to the
## hour's sky: gold and pink at dusk, deep blue with stars at night, grey
## under cloud, the land beyond gone to a dark silhouette.
##
## Where each room's windows and painted shafts are comes from
## data/park/room_windows.json, which tools/hubs/interiors32/room_windows.py
## writes from the room painters. World adds one to each indoor region that
## has windows (see [method attach]), just over the room's picture and under
## its furniture.

const DATA := "res://data/park/room_windows.json"
const PANE_SHADER := preload("res://assets/shaders/room_pane.gdshader")

## How much a painted shaft brightened the floor, as the share of the floor's
## light to take away (black at this alpha) per unit of the painter's
## strength, at the top of the shaft.
const SHAFT_CANCEL := 0.28
## How much the painted glow round each window brightened the wall.
const GLOW_CANCEL := 0.12
## The low sun's light through the glass, added at the golden hours.
const GOLDEN := Color(1.0, 0.72, 0.42)
const GOLDEN_ADD := 0.26
## Moonlight on a clear night, at full moon.
const MOON := Color(0.6, 0.7, 1.0)
const MOON_ADD := 0.07
## Bands each shaft is drawn in, so its fade follows the painter's curve.
const BANDS := 12
## The light through the windows moves on in steps of this many hours
## (1.2 game minutes, under a second of play).
const HOUR_STEP := 0.02

static var _data := {}

## Where the windows are: {panes: [{x, y, w, h, kind}], shafts: [{x, w, y, len, strength, slant}]}.
var spec: Dictionary
## Set to an hour (0-24) to hold the windows there (screenshots); -1 follows the clock.
var hour_override := -1.0

var _cancel: Node2D
var _sun: Node2D
var _panes: Array[Sprite2D] = []
var _state := {}
var _key := ""


## Adds the windows to [param region] if it's a room with windows (once; the
## region keeps them). Returns the RoomWindows, or null.
static func attach(region: Node) -> RoomWindows:
	if region == null or not region.get("indoors"):
		return null
	var existing := region.get_node_or_null("RoomWindows") as RoomWindows
	if existing:
		return existing
	var found: Variant = data().get(str(region.get("region_id")))
	var room := region.get_node_or_null("Room") as Sprite2D
	if found == null or room == null:
		return null
	var windows := RoomWindows.new()
	windows.spec = found
	windows.position = room.position
	windows.z_index = room.z_index + 1
	region.add_child(windows)
	windows._build(room.texture)
	return windows


static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(DATA):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		if parsed is Dictionary:
			_data = parsed
	return _data


func _init() -> void:
	name = "RoomWindows"


func _build(texture: Texture2D) -> void:
	for pane: Dictionary in spec.get("panes", []):
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.region_enabled = true
		sprite.region_rect = Rect2(pane.x, pane.y, pane.w, pane.h)
		sprite.position = Vector2(pane.x, pane.y)
		var mat := ShaderMaterial.new()
		mat.shader = PANE_SHADER
		mat.set_shader_parameter("pane_size", Vector2(pane.w, pane.h))
		mat.set_shader_parameter("stained", pane.get("kind", "") == "stained")
		sprite.material = mat
		add_child(sprite)
		_panes.append(sprite)
	_cancel = Node2D.new()
	_cancel.name = "Shade"
	_cancel.draw.connect(_draw_shade)
	add_child(_cancel)
	_sun = Node2D.new()
	_sun.name = "Sunbeams"
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sun.material = add
	_sun.draw.connect(_draw_beams)
	add_child(_sun)
	_update()


func _process(_delta: float) -> void:
	_update()


## How the light through the windows stands at [param hour]: what share of
## the painted noon light stays, the low sun's and the moon's beams, their
## lean and reach, and the glass's colors.
static func light_at(hour: float, weather: Dictionary) -> Dictionary:
	var clouds: float = weather.get("clouds", 0.0)
	var wet: float = maxf(weather.get("rain", 0.0), weather.get("snow", 0.0))
	var clear := (1.0 - clouds * 0.6) * (1.0 - wet * 0.7)
	var daylight := Sun.daylight(hour)
	var golden := Sun.golden(hour)
	var height := Sun.height(hour)
	# the painted noon shaft, faded out at night, under cloud, and as the
	# low sun takes over
	var noon := daylight * clear * (1.0 - golden * 0.7)
	# how low the sun is: its light reaches further across the floor
	var low := 1.0 - smoothstep(6.0, 40.0, height)
	var sun_dir := Sun.direction(hour)
	var night := Sun.night(hour)
	var moon_dir := Sun.moon_direction(hour)
	var pal := ClimbSky.palette(hour)
	var dark := 1.0 - daylight
	var tint: Color = pal.tint
	var land := Color.WHITE.lerp(tint * lerpf(1.0, 0.55, night), clampf(dark + golden * 0.5, 0.0, 1.0))
	land = land.lerp(Color(0.8, 0.8, 0.82), clouds * 0.4 * daylight)
	return {
		"noon": noon,
		"golden": golden * daylight * clear,
		# travelling away from the sun: east (right) of the room at sunrise
		"sun_lean": -sun_dir.x * (0.4 + 1.2 * low),
		"sun_reach": 1.0 + 0.9 * low,
		"moon": night * Sun.moon() * (1.0 - clouds) * (1.0 - wet),
		"moon_lean": -moon_dir.x * 0.8,
		"glow": dark * 0.5 + (1.0 - clear) * 0.5 * daylight,
		"sky_mix": clampf(maxf(dark, golden * 0.75) + clouds * 0.3, 0.0, 1.0),
		"sky_top": pal.top, "sky_mid": pal.mid, "sky_low": pal.low,
		"land": land, "night": night, "clouds": clouds,
	}


func _update() -> void:
	# The live clock is snapped (to HOUR_STEP): it moves on every frame, and
	# each change drew all the room's beams and glow again, two dozen times
	# a second.
	var hour := hour_override if hour_override >= 0.0 else snappedf(Sun.hour_now(), HOUR_STEP)
	var weather := Weather.today()
	var key := "%.3f %s" % [hour, weather]
	if key == _key:
		return
	_key = key
	_state = light_at(hour, weather)
	for sprite in _panes:
		var mat := sprite.material as ShaderMaterial
		mat.set_shader_parameter("sky_top", _state.sky_top)
		mat.set_shader_parameter("sky_mid", _state.sky_mid)
		mat.set_shader_parameter("sky_low", _state.sky_low)
		mat.set_shader_parameter("sky_mix", _state.sky_mix)
		mat.set_shader_parameter("land_tint", _state.land)
		mat.set_shader_parameter("night", _state.night)
		mat.set_shader_parameter("clouds", _state.clouds)
	_cancel.queue_redraw()
	_sun.queue_redraw()


## Takes the painted light back out: black, at the alpha that undoes it.
## (Black stays black under the room's evening tint, RoomLight, where a
## multiply would be darkened twice.)
func _draw_shade() -> void:
	var off := 1.0 - float(_state.get("noon", 1.0))
	if off <= 0.005:
		return
	for s: Dictionary in spec.get("shafts", []):
		_shaft(_cancel, s, float(s.slant), 1.0, Color(0, 0, 0, SHAFT_CANCEL * float(s.strength) * off))
	var glow: float = _state.get("glow", 0.0)
	if glow > 0.005:
		for p: Dictionary in spec.get("panes", []):
			var c := Vector2(p.x + p.w * 0.5, p.y + p.h * 0.5)
			_ellipse(_cancel, c, Vector2(p.w * 0.9 + 16.0, p.h * 0.9 + 16.0), Color(0, 0, 0, GLOW_CANCEL * glow))


## The low sun and the moon, added through the same windows.
func _draw_beams() -> void:
	var golden: float = _state.get("golden", 0.0)
	var moon: float = _state.get("moon", 0.0)
	for s: Dictionary in spec.get("shafts", []):
		var lean: float = float(s.slant) * 0.4 + float(_state.sun_lean)
		if golden > 0.005:
			var c := GOLDEN * (GOLDEN_ADD * float(s.strength) * golden)
			c.a = 1.0
			_shaft(_sun, s, lean, float(_state.sun_reach), c, 14.0)
		if moon > 0.005:
			var m := MOON * (MOON_ADD * float(s.strength) * moon)
			m.a = 1.0
			_shaft(_sun, s, float(s.slant) * 0.4 + float(_state.moon_lean), 1.2, m, 14.0)


## One shaft from the foot of the window's wall, [param reach] times the
## painted length, leaning [param lean] px across per px down, fading from
## [param color] at the wall the way the painter faded it, its sides softened
## over [param feather] px. For the added beams the fade is in the color; for
## the shade, in the alpha.
func _shaft(canvas: Node2D, s: Dictionary, lean: float, reach: float, color: Color, feather := 3.0) -> void:
	var length := float(s.len) * reach
	var x := float(s.x)
	var w := float(s.w)
	var y := float(s.y)
	var f := minf(feather, w * 0.4)
	for i in BANDS:
		var t0 := float(i) / BANDS
		var t1 := float(i + 1) / BANDS
		var y0 := y + length * t0
		var y1 := y + length * t1
		var a0 := x + length * t0 * lean
		var a1 := x + length * t1 * lean
		var c0 := _fade(color, 1.0 - smoothstep(0.0, 1.0, t0))
		var c1 := _fade(color, 1.0 - smoothstep(0.0, 1.0, t1))
		var n0 := _fade(color, 0.0)
		# the core, then a soft edge each side fading to nothing
		canvas.draw_polygon(PackedVector2Array([Vector2(a0 + f, y0), Vector2(a0 + w - f, y0), Vector2(a1 + w - f, y1), Vector2(a1 + f, y1)]),
			PackedColorArray([c0, c0, c1, c1]))
		canvas.draw_polygon(PackedVector2Array([Vector2(a0 - f, y0), Vector2(a0 + f, y0), Vector2(a1 + f, y1), Vector2(a1 - f, y1)]),
			PackedColorArray([n0, c0, c1, n0]))
		canvas.draw_polygon(PackedVector2Array([Vector2(a0 + w - f, y0), Vector2(a0 + w + f, y0), Vector2(a1 + w + f, y1), Vector2(a1 + w - f, y1)]),
			PackedColorArray([c0, n0, n0, c1]))


func _ellipse(canvas: Node2D, center: Vector2, radii: Vector2, color: Color) -> void:
	# rings, so it fades smoothly from the middle to nothing at the edge
	const RINGS := 6
	const STEPS := 24
	for r in RINGS:
		var a0 := float(r) / RINGS
		var a1 := float(r + 1) / RINGS
		var c0 := _fade(color, 1.0 - smoothstep(0.0, 1.0, a0))
		var c1 := _fade(color, 1.0 - smoothstep(0.0, 1.0, a1))
		for k in STEPS:
			var u0 := TAU * k / STEPS
			var u1 := TAU * (k + 1) / STEPS
			var d0 := Vector2(cos(u0), sin(u0)) * radii
			var d1 := Vector2(cos(u1), sin(u1)) * radii
			canvas.draw_polygon(PackedVector2Array([center + d0 * a0, center + d1 * a0, center + d1 * a1, center + d0 * a1]),
				PackedColorArray([c0, c0, c1, c1]))


static func _fade(color: Color, f: float) -> Color:
	if color.r == 0.0 and color.g == 0.0 and color.b == 0.0:
		return Color(0, 0, 0, color.a * f)
	return Color(color.r * f, color.g * f, color.b * f, 1.0)
