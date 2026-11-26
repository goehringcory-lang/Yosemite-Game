class_name LookBackdrop
extends Node2D
## What you see past the arete (thread 10): the sky for the hour, stars at
## night, a couple of clouds, and the route's real skyline and the valley
## floor far below (ClimbLandscape), whose layers sink at different speeds
## as you climb, so height feels like height. Fixed to the screen: the look
## gives it the inverse of the camera's transform each frame (top_level
## would draw it over the wall); the wall draws over it.
##
## The landscape is painted on a worker thread when the climb starts, and
## the sky again when the light has moved on, so nothing hitches mid-climb.

## The art is painted on the 480 x 270 menu grid and drawn doubled.
const GRID := 2.0
## Repaint the sky after the clock has moved this many hours.
const REPAINT_HOURS := 0.25

var screen_size := Vector2(960, 540)
## 0 at the foot of the route .. 1 fully exposed: how far the layers sink.
var height := 0.0
var hour := 12.0

var _profile := {}
var _seed := 0
var _sky: ImageTexture
var _layers: Array[Dictionary] = []
var _clouds: Array[ImageTexture] = []
var _painted_hour := -99.0
var _task := -1
var _built := {}
var _time := 0.0


## Starts painting for [param route_id] at [param p_hour].
func setup(route_id: String, p_hour: float) -> void:
	_profile = ClimbProfiles.get_profile(route_id) if route_id != "" else {}
	_seed = hash(route_id)
	hour = p_hour
	_paint(true)


func _paint(with_land: bool) -> void:
	var pal := ClimbSky.palette(hour)
	_painted_hour = hour
	_sky = ImageTexture.create_from_image(ClimbSky.sky(pal))
	if not with_land or _task >= 0:
		return
	var profile := _profile.duplicate(true)
	var seed_value := _seed
	var built := {}
	_built = built
	_task = WorkerThreadPool.add_task(func() -> void:
		var land := ClimbLandscape.build(profile, pal, seed_value)
		var layers: Array = []
		for layer: Dictionary in land.layers:
			layers.append({"image": layer.image, "sink": layer.sink, "pad": layer.pad})
		var clouds: Array = []
		for i in 2:
			clouds.append(ClimbSky.cloud(pal, seed_value + i))
		built["layers"] = layers
		built["clouds"] = clouds)


## Each frame from the look.
func frame(delta: float, p_hour: float, p_height: float) -> void:
	_time += delta
	hour = p_hour
	height = p_height
	if absf(hour - _painted_hour) >= REPAINT_HOURS:
		_paint(false)
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		_take()
	queue_redraw()


## Waits for the painting task and turns its pictures into textures.
func _take() -> void:
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_layers.clear()
	for layer: Dictionary in _built.get("layers", []):
		_layers.append({"tex": ImageTexture.create_from_image(layer.image), "sink": layer.sink, "pad": layer.pad})
	_clouds.clear()
	for im: Image in _built.get("clouds", []):
		_clouds.append(ImageTexture.create_from_image(im))


## Waits for the landscape (tests and still shots).
func finish_painting() -> void:
	if _task >= 0:
		_take()


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(GRID, GRID))
	if _sky:
		draw_texture(_sky, Vector2.ZERO)
	NightSky.draw(self, _time, ClimbSky.stars(ClimbSky.palette(hour)))
	for i in _clouds.size():
		var x := fposmod(60.0 + i * 190.0 + _time * (2.0 + i), 480.0 + 120.0) - 60.0
		var y := 30.0 + i * 34.0 + height * 30.0
		draw_texture(_clouds[i], Vector2(x, y).round())
	for layer: Dictionary in _layers:
		draw_texture(layer.tex, Vector2(0, roundf(height * float(layer.sink)) - float(layer.pad)))
	draw_set_transform(Vector2.ZERO)
