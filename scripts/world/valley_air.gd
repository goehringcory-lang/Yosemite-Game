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


func _ready() -> void:
	z_index = 16
	z_as_relative = false
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	_drift = Vector2(randf() * 4000.0, randf() * 4000.0)


func _process(delta: float) -> void:
	var world := get_parent()
	var region: Region = world.region if world and "region" in world else null
	var mist := 0.0
	var rays := 0.0
	if region and not region.indoors:
		mist = mist_now() * (1.0 if _damp(region.region_id) else 0.6)
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
	_mat.set_shader_parameter("ray_dir", Vector2(away.x, away.y * 0.62 + 0.25))
	# Mist catches the colour of the low sun.
	_mat.set_shader_parameter("mist_color", Color(0.86, 0.9, 0.97).lerp(Color(1.0, 0.88, 0.78), Sun.golden() * 0.6))
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


## How thick the morning mist is right now, before the place is counted (0..1).
static func mist_now() -> float:
	var season := clampi(GameClock.season, 0, 3)
	var weather := Weather.today()
	if weather.snow > 0.0:
		return 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("mist:%d:%d:%d" % [GameClock.year, season, GameClock.day])
	var thick: float = MIST_THICKNESS[season] * rng.randf_range(0.6, 1.0)
	var misty: bool = rng.randf() < MIST_CHANCE[season]
	# The ground is wet after rain, and the mist comes up thick the next morning.
	var yesterday: Dictionary = Weather.on_day(GameClock.year, season, GameClock.day - 1) if GameClock.day > 1 else {}
	if yesterday.get("rain", 0.0) > 0.0:
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
