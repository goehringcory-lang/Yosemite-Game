class_name WaterSurface
extends Node2D
## Brings the painted rivers, creeks and lakes to life
## (assets/shaders/water_surface.gdshader): the banks, trees, rocks and people
## beside the water are mirrored in it and ripple, open water takes the colour
## of the sky (gold at sunset, deep blue at dusk) and on a clear night it holds
## the stars. One rectangle the size of the view, like CloudShadows, drawn
## just under the cloud shadows so they still slide across the water. The
## region's painted ground says where the water is. Off indoors.

const SHADER := preload("res://assets/shaders/water_surface.gdshader")

var _mat: ShaderMaterial
var _view := Rect2()
var _ground: Sprite2D
var _region: Node
var _tint: CanvasModulate


func _ready() -> void:
	z_index = 14
	z_as_relative = false
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	visible = false


func _process(_delta: float) -> void:
	var world := get_parent()
	var region: Node = world.region if world and "region" in world else null
	if region != _region:
		_region = region
		_ground = _find_ground(region)
		if _ground:
			_mat.set_shader_parameter("ground_tex", _ground.texture)
			_mat.set_shader_parameter("ground_size", _ground.texture.get_size())
	visible = _ground != null and not (region as Region).indoors
	if not visible:
		return
	_mat.set_shader_parameter("ground_origin", _ground.global_position)
	var xf := get_viewport().get_canvas_transform()
	var scale_k := xf.get_scale()
	var size := get_viewport_rect().size / scale_k
	var origin := -xf.origin / scale_k
	_mat.set_shader_parameter("view_origin", origin)
	_mat.set_shader_parameter("view_size", size)
	var tint := _tint_color()
	_mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	var hour := GameClock.minutes / 60.0
	var weather := Weather.today()
	var pal := ClimbSky.palette(hour)
	var overcast := clampf(maxf(weather.clouds - 0.4, 0.0) / 0.6 + weather.rain + weather.snow, 0.0, 1.0)
	var sky_col: Color = (pal.mid as Color).lerp(pal.low, 0.35)
	sky_col = sky_col.lerp(Color(0.62, 0.66, 0.7), overcast * 0.7)
	_mat.set_shader_parameter("sky", Vector3(sky_col.r, sky_col.g, sky_col.b))
	# The sky shows most in the water at either end of the day.
	_mat.set_shader_parameter("sky_amount", 0.12 + 0.22 * float(pal.glow))
	_mat.set_shader_parameter("clear", 1.0 - overcast)
	var sun: Color = pal.sun
	_mat.set_shader_parameter("sun", Vector3(sun.r, sun.g, sun.b))
	_mat.set_shader_parameter("glow", float(pal.glow))
	var night := clampf(1.0 - absf(fposmod(hour + 12.0, 24.0) - 12.0) / 7.0, 0.0, 1.0)
	_mat.set_shader_parameter("stars", clampf(night * 1.6 - 0.3, 0.0, 1.0) * (1.0 - overcast))
	var view := Rect2(origin.floor() - Vector2(4, 4), size.ceil() + Vector2(8, 8))
	if view != _view:
		_view = view
		queue_redraw()


func _draw() -> void:
	draw_rect(_view, Color.WHITE)


## The region's painted ground, or null if it has none.
static func _find_ground(region: Node) -> Sprite2D:
	if region == null or not region is Region:
		return null
	for ground_name in ["GroundArt", "GroundPainting"]:
		var ground := region.get_node_or_null(ground_name) as Sprite2D
		if ground and ground.texture and not ground.centered:
			return ground
	return null


func _tint_color() -> Color:
	if _tint == null:
		_tint = get_parent().get_node_or_null("DayNight") as CanvasModulate
	if _tint == null or not _tint.visible:
		return Color.WHITE
	return _tint.color
