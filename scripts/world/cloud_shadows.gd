class_name CloudShadows
extends Node2D
## Shadows of fair-weather clouds sliding across the ground on sunny days
## (assets/shaders/cloud_shadows.gdshader). One rectangle the size of the
## view, redrawn where the camera is; the shader works in world pixels, so
## the shadows stay put on the ground while you walk under them. They fade
## out at dusk, on overcast days (when there's no sun to cast them) and
## indoors.

const SHADER := preload("res://assets/shaders/cloud_shadows.gdshader")
## How fast the clouds drift, in pixels a second.
const WIND := Vector2(-7.0, -2.0)
const STRENGTH := 0.2

var _drift := Vector2.ZERO
var _view := Rect2()
var _tint: CanvasModulate
var _mat: ShaderMaterial


func _ready() -> void:
	z_index = 15
	z_as_relative = false
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	_drift = Vector2(randf() * 4000.0, randf() * 4000.0)


func _process(delta: float) -> void:
	var weather := Weather.today()
	var clouds: float = weather.clouds
	# Overcast skies cast no separate shadows.
	var sun := 1.0 - _darkness() * 1.6
	if clouds >= 1.0:
		sun = 0.0
	var world := get_parent()
	if world and "region" in world and world.region and world.region.indoors:
		sun = 0.0
	visible = sun > 0.02
	if not visible:
		return
	_drift += WIND * delta
	_mat.set_shader_parameter("drift", _drift)
	_mat.set_shader_parameter("coverage", clampf(clouds, 0.0, 0.75))
	_mat.set_shader_parameter("strength", STRENGTH * clampf(sun, 0.0, 1.0))
	var size := get_viewport_rect().size
	var camera := get_viewport().get_camera_2d()
	var center := size / 2.0
	if camera:
		size /= camera.zoom
		center = camera.get_screen_center_position()
	var view := Rect2((center - size / 2.0).floor() - Vector2(2, 2), size.ceil() + Vector2(4, 4))
	if view != _view:
		_view = view
		queue_redraw()


func _draw() -> void:
	draw_rect(_view, Color.WHITE)


func _darkness() -> float:
	if _tint == null:
		_tint = get_parent().get_node_or_null("DayNight") as CanvasModulate
		if _tint == null:
			return 0.0
	var lum := (_tint.color.r + _tint.color.g + _tint.color.b) / 3.0
	return clampf((0.9 - lum) / 0.45, 0.0, 1.0)
