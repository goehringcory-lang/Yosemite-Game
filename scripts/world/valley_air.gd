class_name ValleyAir
extends Node2D
## Morning mist and shafts of low sun (assets/shaders/valley_air.gdshader).
## Mist pools on the meadows in the cool hour around sunrise and burns off as
## the sun climbs: most mornings in spring and fall, thickest after a wet day,
## rare in the dry summer. Low sun in the first and last hours of the day
## slants through the air in soft shafts, brightest through the mist. Like
## the cloud shadows, it's one view-sized rectangle drawn in world space, and
## it's hidden indoors.

const SHADER := preload("res://assets/shaders/valley_air.gdshader")
## How fast the mist drifts, in world pixels a second.
const WIND := Vector2(5.0, 0.8)
## How likely a misty morning is in each season, and how thick it gets.
const MIST_CHANCE := [0.5, 0.25, 0.5, 0.4]
const MIST_THICKNESS := [0.85, 0.5, 0.9, 0.7]
## Mist gathers thickest on the open meadows and by the water.
const DAMP_PLACES := ["meadow", "lake", "happy_isles", "tenaya", "bridalveil", "leidig", "valley"]

var _drift := Vector2.ZERO
var _view := Rect2()
var _mat: ShaderMaterial
var _time := 0.0
## How far World has moved the world at seams (see the shader's anchor).
var _anchor := Vector2.ZERO


func _ready() -> void:
	z_index = 16
	z_as_relative = false
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	_drift = Vector2(randf() * 4000.0, randf() * 4000.0)
	var world := get_parent()
	if world and world.has_signal("seam_crossed"):
		world.seam_crossed.connect(shift)


## Over a seam the world moved by [param by]: the mist moves with it.
func shift(by: Vector2) -> void:
	_anchor += by
	_mat.set_shader_parameter("anchor", _anchor)


func _process(delta: float) -> void:
	var world := get_parent()
	var region: Region = world.region if world and "region" in world else null
	var mist := 0.0
	var rays := 0.0
	if region and not region.indoors:
		var high := HighCountry.is_high(region.region_id)
		mist = mist_now(high) * (1.0 if _damp(region.region_id) else 0.6)
		var weather := Weather.today()
		rays = Sun.golden() * (1.0 - smoothstep(0.6, 0.9, weather.clouds))
	visible = mist > 0.01 or rays > 0.01
	if not visible:
		return
	_time += delta
	_drift += WIND * delta
	var away := -Sun.direction()
	_mat.set_shader_parameter("drift", _drift)
	_mat.set_shader_parameter("time", _time)
	_mat.set_shader_parameter("mist", mist)
	_mat.set_shader_parameter("rays", rays)
	_mat.set_shader_parameter("high_quality", LitSprites.active())
	_mat.set_shader_parameter("ray_dir", Vector2(away.x, away.y * 0.62 + 0.25))
	# Mist catches the colour of the low sun. Up in the high country the dawn
	# is colder: the mist is whiter and bluer and the sun warms it less.
	var high_air := region != null and HighCountry.is_high(region.region_id)
	var cold := Color(0.9, 0.94, 1.0) if high_air else Color(0.86, 0.9, 0.97)
	_mat.set_shader_parameter("mist_color", cold.lerp(Color(1.0, 0.88, 0.78), Sun.golden() * (0.4 if high_air else 0.6)))
	var size := get_viewport_rect().size
	var camera := get_viewport().get_camera_2d()
	var center := size / 2.0
	if camera:
		size /= camera.zoom
		center = camera.get_screen_center_position()
	var view := Rect2((center - size / 2.0).floor() - Vector2(4, 4), size.ceil() + Vector2(8, 8))
	if view != _view:
		_view = view
		queue_redraw()


func _draw() -> void:
	draw_rect(_view, Color.WHITE)


static var _mist_key := -1
static var _mist_thick_base := 0.0
static var _mist_roll := 1.0
static var _mist_yday_rain := 0.0


## How thick the morning mist is right now, before the place is counted (0..1).
## [param high]: in the high country, where cold air pools on the meadows on
## summer nights too (HighCountry.MIST_CHANCE).
static func mist_now(high := false) -> float:
	var season := clampi(GameClock.season, 0, 3)
	var weather := Weather.today()
	if weather.snow > 0.0:
		return 0.0
	var key := (GameClock.year * 4 + season) * 64 + GameClock.day
	if key != _mist_key:
		_mist_key = key
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("mist:%d:%d:%d" % [GameClock.year, season, GameClock.day])
		_mist_thick_base = MIST_THICKNESS[season] * rng.randf_range(0.6, 1.0)
		_mist_roll = rng.randf()
		var yesterday: Dictionary = Weather.on_day(GameClock.year, season, GameClock.day - 1) if GameClock.day > 1 else {}
		_mist_yday_rain = yesterday.get("rain", 0.0)
	var thick := _mist_thick_base
	var chance: float = HighCountry.MIST_CHANCE[season] if high else MIST_CHANCE[season]
	var misty: bool = _mist_roll < chance
	# The ground is wet after rain, and the mist comes up thick the next morning.
	if _mist_yday_rain > 0.0:
		misty = true
		thick = maxf(thick, 0.95)
	if weather.rain > 0.0:
		misty = true
		thick = maxf(thick, 0.55)
	if not misty:
		return 0.0
	var t := Sun.times()
	var h := fposmod(Sun.hour_now(), 24.0)
	# Up before dawn, thickest just after sunrise, gone a couple of hours later.
	var rise := smoothstep(t.x - 1.5, t.x + 0.2, h)
	var burn := 1.0 - smoothstep(t.x + 0.6, t.x + 2.6, h)
	return thick * rise * burn


static func _damp(region_id: String) -> bool:
	for word in DAMP_PLACES:
		if word in region_id:
			return true
	return false
