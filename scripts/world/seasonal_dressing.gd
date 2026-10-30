extends Node
## Makes a hand-built region follow the seasons without rebuilding its scene.
## Region adds one as a child. It finds the Ahwahnee-style trees and plants by
## their texture and swaps in the season's version from
## assets/sprites/ahwahnee/seasons/ (made by tools/hubs/build_seasonal_art.gd):
## black oaks go gold in fall and bare in winter, dogwoods bloom only in
## spring, wildflowers dry out in fall and vanish in winter, the garden beds
## and meadow grass turn, and the conifers pick up snow. It also grades the
## painted ground (GroundArt) with a small shader: dry and golden in fall,
## cool and frosted in winter. As the winter's snow builds up
## (Seasons.snow_cover) it lies on the ground in drifts and on the tops of
## roofs, cars, rocks, logs and signs (a small shader on each), and it melts
## away in early spring. Only sprites change. Collision and foraging don't.

const SPRITE_DIR := "res://assets/sprites/ahwahnee/"
const SEASON_DIR := SPRITE_DIR + "seasons/"
const SEASON_NAMES := ["spring", "summer", "fall", "winter"]
const GROUND_SHADER := preload("res://assets/shaders/seasonal_ground.gdshader")
const SNOW_CAP_SHADER := preload("res://assets/shaders/snow_cap.gdshader")

## Sprite folders whose pictures can hold snow on top: buildings, cars, camp
## gear, rocks and logs. Trees and plants have their own winter drawings.
const CAP_DIRS := ["buildings", "cars", "curry", "wawona", "el_portal", "glacier", "tuolumne", "ahwahnee", "lamon"]
## Pictures that never hold snow: lit windows, shadows, the falls and walls,
## the painted ground, and the trees and plants.
const NO_CAP := ["glow", "shadow", "light", "window", "_fall_", "_mist_", "_wall", "ground_", "water", "pool", "rink"]
const NO_CAP_PREFIX := ["tree_", "plant_", "garden_"]

## Regions that don't get the shimmer on their water (Tuolumne's river runs by
## its own "water_flow" instead; see the shader).
const STILL_WATER := ["tuolumne_meadows"]

## Sprites with no place in a season: they are hidden, not swapped.
const HIDDEN_IN_WINTER := [
	"plant_lupine", "plant_paintbrush", "plant_wildflowers_a", "plant_wildflowers_b",
	"plant_wildflowers_c", "plant_cornlily",
]

## Ground grade per season: tint, tint strength, desaturation, frost, and the
## colour that covers the painted wildflower dots (transparent keeps them).
## Spring is the fresh green of the snowmelt; by midsummer the Valley's
## meadows are drying toward straw (the wet ones and the high country stay
## greener, and the grade pulls grass hardest); fall is gold.
const GROUND_LOOKS := [
	{"tint": Color(0.62, 0.92, 0.45), "amount": 0.08, "desat": 0.0, "frost": 0.0, "fill": Color(0, 0, 0, 0)},
	{"tint": Color(0.88, 0.8, 0.48), "amount": 0.14, "desat": 0.05, "frost": 0.0, "fill": Color(0, 0, 0, 0)},
	{"tint": Color(0.93, 0.74, 0.34), "amount": 0.5, "desat": 0.12, "frost": 0.0, "fill": Color(0.5, 0.45, 0.2, 1)},
	{"tint": Color(0.62, 0.72, 0.86), "amount": 0.34, "desat": 0.5, "frost": 0.2, "fill": Color(0.42, 0.55, 0.45, 1)},
]

## texture name -> [spring, summer, fall, winter] texture, or null to hide.
static var _looks := {}

var _season := -1
var _key := ""
var _sprites: Array[Sprite2D] = []
## Sprites that take a snow cap, all sharing one material.
var _caps: Array[Sprite2D] = []
static var _cap_material: ShaderMaterial
var _names: Array[String] = []
var _grounds: Array[CanvasItem] = []


func _ready() -> void:
	var region := get_parent()
	for node in region.find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		if sprite.texture == null:
			continue
		var path := sprite.texture.resource_path
		if path.begins_with(SPRITE_DIR) and path.get_base_dir() + "/" == SPRITE_DIR:
			var tex_name := path.get_file().get_basename()
			if not _look_for(tex_name).is_empty():
				_sprites.append(sprite)
				_names.append(tex_name)
				continue
		if sprite.material == null and not sprite is SeasonalSprite and _holds_snow(path):
			_caps.append(sprite)
	for ground_name in ["GroundArt", "GroundPainting"]:
		var ground := region.get_node_or_null(ground_name) as Sprite2D
		if ground:
			ground.material = ShaderMaterial.new()
			(ground.material as ShaderMaterial).shader = GROUND_SHADER
			# a region whose painted river runs (see the shader)
			(ground.material as ShaderMaterial).set_shader_parameter("flow", region.get_meta("water_flow", Vector2.ZERO))
			# and the rest shimmer (STILL_WATER keeps theirs as painted)
			var still: bool = region is Region and (region as Region).region_id in STILL_WATER
			(ground.material as ShaderMaterial).set_shader_parameter("water_shimmer", 0.0 if still else 1.0)
			_grounds.append(ground)
	# The needles and slabs lying on the ground (tools/hubs/dress_wilds.gd)
	# turn with it: each sprite uses its parent's material.
	var detail := region.get_node_or_null("Entities/WildDressing/GroundDetail") as CanvasItem
	if detail:
		detail.material = ShaderMaterial.new()
		(detail.material as ShaderMaterial).shader = GROUND_SHADER
		_grounds.append(detail)
	apply()


func _process(_delta: float) -> void:
	if _date_key() != _key:
		apply()


func _date_key() -> String:
	return "%d:%d:%d" % [GameClock.year, GameClock.season, GameClock.day]


## Dresses everything for the clock's current season and today's snow.
func apply() -> void:
	_key = _date_key()
	_season = clampi(GameClock.season, 0, 3)
	for i in _sprites.size():
		var sprite := _sprites[i]
		var look: Array = _look_for(_names[i])
		var tex: Texture2D = look[_season]
		sprite.visible = tex != null
		if tex:
			sprite.texture = tex
	var g: Dictionary = GROUND_LOOKS[_season]
	for ground in _grounds:
		var mat := ground.material as ShaderMaterial
		mat.set_shader_parameter("tint", g["tint"])
		mat.set_shader_parameter("tint_amount", g["amount"])
		mat.set_shader_parameter("desaturate", g["desat"])
		mat.set_shader_parameter("frost", g["frost"])
		mat.set_shader_parameter("flower_fill", g["fill"])
	var snow := Seasons.snow_cover()
	for ground in _grounds:
		(ground.material as ShaderMaterial).set_shader_parameter("snow", snow)
	if _cap_material == null:
		_cap_material = ShaderMaterial.new()
		_cap_material.shader = SNOW_CAP_SHADER
	_cap_material.set_shader_parameter("snow", snow)
	# No shader at all on a bare day.
	for sprite in _caps:
		sprite.material = _cap_material if snow > 0.0 else null


## True if a sprite drawn from [param path] can hold snow on top.
static func _holds_snow(path: String) -> bool:
	if path == "res://assets/sprites/info_sign.png":
		return true
	var parts := path.trim_prefix("res://assets/sprites/").split("/")
	if parts.size() != 2 or not parts[0] in CAP_DIRS:
		return false
	var file := parts[1]
	for word: String in NO_CAP:
		if file.contains(word):
			return false
	for prefix: String in NO_CAP_PREFIX:
		if file.begins_with(prefix):
			return false
	return true


## The four textures for a base sprite, or [] if it has no seasonal versions.
## Seasons without a drawing keep the base sprite.
static func _look_for(tex_name: String) -> Array:
	if _looks.has(tex_name):
		return _looks[tex_name]
	var base := load(SPRITE_DIR + tex_name + ".png") as Texture2D
	var look := []
	var any := false
	for s in 4:
		var path: String = SEASON_DIR + "%s_%s.png" % [tex_name, SEASON_NAMES[s]]
		if ResourceLoader.exists(path):
			look.append(load(path))
			any = true
		elif s == 3 and tex_name in HIDDEN_IN_WINTER:
			look.append(null)
			any = true
		else:
			look.append(base)
	if not any:
		look = []
	_looks[tex_name] = look
	return look
