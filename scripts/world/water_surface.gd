class_name WaterSurface
extends Node2D
## Brings the painted rivers, creeks and lakes to life
## (assets/shaders/water_surface.gdshader): the banks, trees, rocks and people
## beside the water are mirrored in it and ripple, open water takes the colour
## of the sky (gold at sunset, deep blue at dusk) and on a clear night it holds
## the stars. One rectangle the size of the view, like CloudShadows, drawn
## just under the cloud shadows so they still slide across the water. The
## region's painted ground says where the water is. Off indoors.
##
## Reading the screen costs a copy of the whole picture, and the shader's
## work is per pixel, so only the parts of the view near painted water are
## drawn (data/park/water_cells.json, made by tools/perf/water_cells.py), and
## nothing at all when no water is in view.

const SHADER := preload("res://assets/shaders/water_surface.gdshader")
const CELLS_PATH := "res://data/park/water_cells.json"

## Ground texture path -> Array of Rect2 (texture pixels) holding water;
## a ground missing from the table is drawn over the whole view.
static var _cells: Dictionary = {}
static var _cells_loaded := false

var _mat: ShaderMaterial
var _view := Rect2()
var _ground: Sprite2D
var _region: Node
var _tint: CanvasModulate
## The current ground's water rectangles (null: not known, draw everywhere).
var _water: Variant = null
## The parts of the view drawn this frame, in world pixels.
var _draw_rects: Array[Rect2] = []


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
		_water = null
		_view = Rect2()
		if _ground:
			_mat.set_shader_parameter("ground_tex", _ground.texture)
			_mat.set_shader_parameter("ground_size", _ground.texture.get_size())
			_water = water_rects(_ground.texture.resource_path)
	visible = _ground != null and not (region as Region).indoors
	if not visible:
		return
	_mat.set_shader_parameter("ground_origin", _ground.global_position)
	# the season's grade on the ground, so the shader knows bare ground when
	# it sees it (only what stands on the ground is mirrored)
	var grade := _ground.material as ShaderMaterial
	var season_tint: Variant = grade.get_shader_parameter("tint") if grade else null
	var season_amount: Variant = grade.get_shader_parameter("tint_amount") if grade else null
	var season_desat: Variant = grade.get_shader_parameter("desaturate") if grade else null
	var snow: Variant = grade.get_shader_parameter("snow") if grade else null
	var tint_c: Color = season_tint if season_tint is Color else Color.WHITE
	_mat.set_shader_parameter("season_tint", Vector3(tint_c.r, tint_c.g, tint_c.b))
	_mat.set_shader_parameter("season_amount", float(season_amount) if season_amount != null else 0.0)
	_mat.set_shader_parameter("season_desaturate", float(season_desat) if season_desat != null else 0.0)
	_mat.set_shader_parameter("snow", float(snow) if snow != null else 0.0)
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
		_draw_rects = _rects_in_view(view)
		queue_redraw()
	# no water in view: skip the screen copy and the shader altogether
	visible = not _draw_rects.is_empty()


func _draw() -> void:
	for rect in _draw_rects:
		draw_rect(rect, Color.WHITE)


## The parts of [param view] (world pixels) to draw: where the ground has
## water, or all of it if that isn't known.
func _rects_in_view(view: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if _water == null:
		out.append(view)
		return out
	var at := _ground.global_position
	for cell: Rect2 in _water:
		var rect := Rect2(cell.position + at, cell.size).intersection(view)
		if rect.has_area():
			out.append(rect)
	return out


## Where the ground at [param path] has water, as rectangles in its pixels,
## or null if the table doesn't know that ground.
static func water_rects(path: String) -> Variant:
	if not _cells_loaded:
		_cells_loaded = true
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CELLS_PATH))
		if data is Dictionary and data.get("grounds") is Dictionary:
			for key: String in data.grounds:
				var rects: Array[Rect2] = []
				for r: Array in data.grounds[key]:
					rects.append(Rect2(r[0], r[1], r[2], r[3]))
				_cells[key] = rects
	return _cells.get(path, null)


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
