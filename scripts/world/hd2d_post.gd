class_name HD2DPost
extends CanvasLayer
## HD-2D cinematic post-processing pass (assets/shaders/hd2d_post.gdshader),
## sitting on CanvasLayer 2 right after Atmosphere and well below every menu
## and HUD layer. Active only on High graphics (LitSprites.active()).
##
## Adds subtle tilt-shift miniature depth-of-field at the top and bottom edges,
## aerial perspective haze across the distant horizon outdoors, micro-contrast
## clarity in the focused center band, and a gentle filmic highlight shoulder.

const SHADER := preload("res://assets/shaders/hd2d_post.gdshader")
const AtmosphereScript := preload("res://scripts/world/atmosphere.gd")

## Set to false to disable HD-2D post-processing (tests or debugging).
static var enabled := true

var _rect: ColorRect
var _mat: ShaderMaterial
var _indoors := false
var _high := false


static func active() -> bool:
	return enabled and LitSprites.active()


func _ready() -> void:
	name = "HD2DPost"
	layer = 2
	_rect = ColorRect.new()
	_rect.name = "HD2DRect"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	add_child(_rect)
	visible = false
	var world := get_parent()
	if world and world.has_signal("region_changed"):
		world.region_changed.connect(_on_region_changed)


func _on_region_changed(region: Region) -> void:
	_indoors = region != null and region.indoors
	_high = region != null and HighCountry.is_high(region.region_id)


func _process(_delta: float) -> void:
	visible = active()
	if not visible:
		return
	var golden := Sun.golden()
	var night := Sun.night()
	var daylight := Sun.daylight()
	var weather := Weather.today()
	var clouds: float = float(weather.clouds)

	# Slightly gentler tilt-shift indoors so room walls stay crisp.
	_mat.set_shader_parameter("dof_strength", 0.42 if _indoors else 0.72)
	_mat.set_shader_parameter("dof_radius", 2.0 if _indoors else 2.6)
	_mat.set_shader_parameter("clarity", 0.12 if _indoors else 0.16)

	if _indoors:
		_mat.set_shader_parameter("aerial_strength", 0.0)
	else:
		# Subtle aerial perspective near the top of outdoor scenes: warm amber
		# at golden hour, crisp alpine blue in the high country, deep indigo at night.
		var day_sky := Color(0.68, 0.80, 0.96) if _high else Color(0.76, 0.84, 0.93)
		var gold_sky := Color(0.95, 0.76, 0.56)
		var night_sky := Color(0.14, 0.19, 0.34)
		var sky := day_sky.lerp(gold_sky, golden * 0.75).lerp(night_sky, night)
		sky = sky.lerp(Color(0.64, 0.68, 0.74), clouds * 0.45 * daylight)
		var aerial: float = (0.09 + 0.09 * golden + 0.05 * AtmosphereScript.haze()) * (1.0 - night * 0.45)
		if _high:
			aerial *= 0.75
		_mat.set_shader_parameter("aerial_color", Vector3(sky.r, sky.g, sky.b))
		_mat.set_shader_parameter("aerial_strength", aerial)
