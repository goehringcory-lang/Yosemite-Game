class_name CloudShadows
extends Node2D
## Shadows of fair-weather clouds sliding across the ground on sunny days
## (assets/shaders/cloud_shadows.gdshader). One rectangle the size of the
## view, redrawn where the camera is; the shader works in world pixels, so
## the shadows stay put on the ground while you walk under them. They fade
## out at dusk, on overcast days (when there's no sun to cast them) and
## indoors.
##
## The shade comes in whole 2x2 cells of world pixels, so it is worked out
## once a cell, into a small picture rendered off screen (a SubViewport, one
## texel a cell), and that is laid over the view, scaled up, with
## cloud_shadows_show.gdshader. The same picture as working it out for every
## pixel of a 1080p screen, at a sixteenth of the work.

const SHADER := preload("res://assets/shaders/cloud_shadows.gdshader")
const SHOW_SHADER := preload("res://assets/shaders/cloud_shadows_show.gdshader")
## How fast the clouds drift, in world pixels a second.
const WIND := Vector2(-8.0, -3.0)
const STRENGTH := 0.16

var _drift := Vector2.ZERO
var _view := Rect2()
var _tint: CanvasModulate
## the noise, worked out in the off-screen picture
var _mat: ShaderMaterial
## laying the picture over the world
var _show: ShaderMaterial
var _viewport: SubViewport
var _cells: ColorRect


func _ready() -> void:
	z_index = 15
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_show = ShaderMaterial.new()
	_show.shader = SHOW_SHADER
	material = _show
	_viewport = SubViewport.new()
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.size = Vector2i(2, 2)
	_cells = ColorRect.new()
	_cells.material = _mat
	_viewport.add_child(_cells)
	add_child(_viewport)
	_drift = Vector2(randf() * 4000.0, randf() * 4000.0)


func _process(delta: float) -> void:
	var weather := Weather.today()
	var clouds: float = weather.clouds
	var world := get_parent()
	var strength := STRENGTH
	# In the high country the afternoon cumulus build over the domes (see
	# HighCountry): more of the meadow in shadow, and darker under them.
	if world and "region" in world and world.region and HighCountry.is_high(world.region.region_id) and clouds < 1.0:
		var build := HighCountry.cloud_build()
		clouds = lerpf(clouds, 0.72, build)
		strength *= 1.0 + build * 0.6
	# Overcast skies cast no separate shadows.
	var sun := 1.0 - _darkness() * 1.6
	if clouds >= 1.0:
		sun = 0.0
	if world and "region" in world and world.region and world.region.indoors:
		sun = 0.0
	visible = sun > 0.02
	var update := SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	if _viewport.render_target_update_mode != update:
		_viewport.render_target_update_mode = update
	if not visible:
		return
	_drift += WIND * delta
	_mat.set_shader_parameter("drift", _drift)
	_mat.set_shader_parameter("coverage", clampf(clouds, 0.0, 0.75))
	_show.set_shader_parameter("strength", strength * clampf(sun, 0.0, 1.0))
	var size := get_viewport_rect().size
	var camera := get_viewport().get_camera_2d()
	var center := size / 2.0
	if camera:
		size /= camera.zoom
		center = camera.get_screen_center_position()
	# whole cells (2x2 world pixels, on even coordinates) covering the view
	var corner := ((center - size / 2.0) / 2.0).floor() * 2.0 - Vector2(4, 4)
	var cells := Vector2i(((size + Vector2(8, 8)) / 2.0).ceil()) + Vector2i(1, 1)
	var view := Rect2(corner, Vector2(cells) * 2.0)
	if cells != _viewport.size:
		_viewport.size = cells
		_cells.size = Vector2(cells)
	_mat.set_shader_parameter("origin", corner)
	if view != _view:
		_view = view
		queue_redraw()


func _draw() -> void:
	draw_texture_rect(_viewport.get_texture(), _view, false)


func _darkness() -> float:
	if _tint == null:
		_tint = get_parent().get_node_or_null("DayNight") as CanvasModulate
		if _tint == null:
			return 0.0
	var lum := (_tint.color.r + _tint.color.g + _tint.color.b) / 3.0
	return clampf((0.9 - lum) / 0.45, 0.0, 1.0)
