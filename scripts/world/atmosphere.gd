extends CanvasLayer
## Grades the outdoor picture (assets/shaders/atmosphere.gdshader): cool
## shadows, warm lights, a little body in the midtones and soft corners, and
## the light of the hour from the sun's place in the sky (see Sun): golden
## hour, alpenglow on the granite after sunset, silver moonlit nights where
## only lamplight keeps its colour, and a haze in the summer heat and the fall
## smoke. Off indoors, where each room is painted with its own light, and in
## the regions listed in SKIP. It sits just above the world and below every
## menu.

const SKIP := ["tuolumne_meadows"]
## How hazy the air gets in each season, at its haziest (afternoon), before
## the day's own roll: summer heat, and the smoke of fall's fires.
const SEASON_HAZE := [0.12, 0.35, 0.5, 0.04]

var _rect: ColorRect
var _mat: ShaderMaterial
var _tint: CanvasModulate


func _ready() -> void:
	layer = 1
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://assets/shaders/atmosphere.gdshader")
	_rect.material = _mat
	add_child(_rect)
	visible = false
	var world := get_parent()
	if world.has_signal("region_changed"):
		world.region_changed.connect(_on_region_changed)
	_tint = world.get_node_or_null("DayNight") as CanvasModulate


func _on_region_changed(region: Region) -> void:
	visible = not region.indoors and region.region_id not in SKIP


func _process(_delta: float) -> void:
	if not visible:
		return
	var weather := Weather.today()
	var clear: float = 1.0 - weather.clouds * 0.75
	if _tint:
		_mat.set_shader_parameter("tint", _tint.color)
	_mat.set_shader_parameter("golden", Sun.golden() * clear)
	_mat.set_shader_parameter("alpenglow", Sun.alpenglow() * clear)
	var night := Sun.night()
	_mat.set_shader_parameter("night", night)
	_mat.set_shader_parameter("moon_color", Color(0.5, 0.6, 1.0).lerp(Color(0.72, 0.8, 1.0), Sun.moon()))
	_mat.set_shader_parameter("haze", haze() * (1.0 - night))


## How hazy the valley air is now (0..1): a little each day by season, more
## in the afternoon, less after rain has washed the air clean.
static func haze() -> float:
	var weather := Weather.today()
	var season := clampi(GameClock.season, 0, 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("haze:%d:%d:%d" % [GameClock.year, season, GameClock.day])
	var day_roll := rng.randf_range(0.4, 1.0)
	var afternoon := 0.5 + 0.5 * smoothstep(0.2, 0.75, Sun.arc())
	var washed: float = 1.0 - maxf(weather.rain, weather.snow)
	return SEASON_HAZE[season] * day_roll * afternoon * washed
