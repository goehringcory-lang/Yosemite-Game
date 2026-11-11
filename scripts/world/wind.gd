class_name Wind
extends Node
## The wind in the valley. Trees and plants sway in it, each rooted at its
## foot and leaning from the top, and every ten seconds or so a gust crosses
## the view: a band of grass blades catching the light runs over the meadows
## (seasonal_ground.gdshader), and each tree bends as the band reaches it
## (sway.gdshaderinc). It blows harder under cloud and hardest in rain and
## snow. World adds one, which keeps the wind's strength up to date for the
## shaders; the rest is static.
##
## The sway is drawn by the sprite's shader, so nothing moves in the scene:
## shadows, collisions and the brush-past rustle (Rustle) are as they were.
## Works on both graphics levels. On High the trees already have a material
## of their own (LitSprites), which takes the sway; the ones without, and all
## of them on Low, get a plain one here.

const SHADER := preload("res://assets/shaders/sway_sprite.gdshader")
const SPRITE_DIR := "res://assets/sprites/"
## The shader global the strength is kept in (see project.godot).
const STRENGTH := &"wind_strength"
## How far a tree's top leans in a full gust, in texture pixels for each
## pixel of its height, and the least and most.
const TREE_LEAN := 0.04
const TREE_LEAN_RANGE := Vector2(4.0, 10.0)
## The giants hardly move.
const GIANT_LEAN := 2.0
const PLANT_LEAN := 3.0
## Art that stands in the wind without moving: dead and fallen wood, and
## plants too low to bend.
const STIFF := ["snag", "fallen", "tunnel", "carved", "mushroom", "stump"]
const GIANTS := ["giant", "sequoia"]
## File names (after the folder) that sway as plants.
const PLANTS := ["plant_", "garden_flowerbed", "flower_bed", "wild_dry_grass"]
const TREES := ["tree_", "apple_tree", "gp_red_fir"]

## Set to false to still the air (tests and the renderer comparison, which
## need the same picture twice).
static var enabled := true
## Lean (texture pixels) -> the plain swaying material for it.
static var _materials := {}
## Art path -> its lean, worked out once.
static var _leans := {}

var _strength := -1.0


func _ready() -> void:
	name = "Wind"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_strength = strength_now()
	RenderingServer.global_shader_parameter_set(STRENGTH, _strength)


func _process(delta: float) -> void:
	var target := strength_now()
	if not is_equal_approx(target, _strength):
		_strength = move_toward(_strength, target, delta * 0.5)
		RenderingServer.global_shader_parameter_set(STRENGTH, _strength)


## How hard it blows today: 0 with the wind turned off, about 1 on a fair
## day, up to 1.5 in heavy rain or snow.
static func strength_now() -> float:
	if not enabled or not Settings.wind:
		return 0.0
	var weather := Weather.today()
	var storm: float = maxf(weather.rain, weather.snow)
	return 0.8 + 0.25 * weather.clouds + 0.45 * storm


## How far the top of a sprite drawn from [param art] leans in a full gust,
## in texture pixels, or 0 if it isn't a thing that sways.
static func lean_for(art: String) -> float:
	if _leans.has(art):
		return _leans[art]
	var lean := 0.0
	if art.begins_with(SPRITE_DIR):
		var file := art.get_file()
		if not _has_any(file, STIFF):
			if _has_any(file, PLANTS):
				lean = PLANT_LEAN
			elif _has_any(file, GIANTS) and _has_any(file, TREES):
				lean = GIANT_LEAN
			elif _has_any(file, TREES):
				var tex := load(art) as Texture2D
				var height := tex.get_height() if tex else 128
				lean = clampf(height * TREE_LEAN, TREE_LEAN_RANGE.x, TREE_LEAN_RANGE.y)
	_leans[art] = lean
	return lean


static func _has_any(file: String, words: Array) -> bool:
	for word: String in words:
		if file.contains(word):
			return true
	return false


## Sets every tree and plant of [param region] swaying. World calls it on a
## region's first visit, after LitSprites.
static func attach(region: Node) -> void:
	for node in region.find_children("*", "Sprite2D", true, false):
		attach_sprite(node as Sprite2D)


## Sets one sprite swaying if its art is a tree or a plant (again after its
## texture changes, as with the seasons). A sprite LitSprites shades sways
## through that material; one with some other material of its own is left
## alone. Returns true if the sprite sways now.
static func attach_sprite(sprite: Sprite2D) -> bool:
	if sprite == null or sprite.texture == null:
		return false
	var lean := lean_for(sprite.texture.resource_path) if _whole(sprite) else 0.0
	if sprite.has_meta("lit"):
		return lean > 0.0
	if sprite.material != null and not sprite.has_meta("sway"):
		return false
	if lean <= 0.0:
		if sprite.has_meta("sway"):
			sprite.material = null
			sprite.remove_meta("sway")
		return false
	sprite.material = _material(lean)
	sprite.set_meta("sway", true)
	return true


## True if the sprite draws its whole texture (the shader takes the bottom
## edge of the texture for the plant's foot).
static func _whole(sprite: Sprite2D) -> bool:
	return not sprite.region_enabled and sprite.hframes == 1 and sprite.vframes == 1


static func _material(lean: float) -> ShaderMaterial:
	if not _materials.has(lean):
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("sway", lean)
		_materials[lean] = mat
	return _materials[lean]
