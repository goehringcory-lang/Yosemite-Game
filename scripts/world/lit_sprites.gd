class_name LitSprites
extends RefCounted
## Gives sprites their normal maps (assets/normals/, made by tools/normals) so
## real light shades them: the sun (SunLight) by day, lamps and fires
## (NightLight) after dark. A slope toward the light brightens and a slope
## away dims, while flat ground stays as painted (see lit.gdshaderinc), so a
## sprite without a normal map looks just as it did.
##
## World calls [method attach] on each region's first visit, after the
## seasons have dressed it, and [method attach_sprite] for the player.
## Only on High graphics (the Forward+ renderer): Low stays as painted.

const SHADER := preload("res://assets/shaders/lit_sprite.gdshader")
const SPRITE_DIR := "res://assets/sprites/"
const NORMAL_DIR := "res://assets/normals/"
## The light layer only lit sprites are on, so the sun (SunLight) shapes them
## and leaves everything without a normal map alone.
const LIT_LAYER := 1 << 9

## Art path -> its ShaderMaterial, shared by every sprite drawn from it.
static var _materials := {}
## Set to false to keep everything unlit (tests and the renderer comparison).
static var enabled := true


## True when the game shades sprites with real light.
static func active() -> bool:
	return enabled and RenderingServer.get_current_rendering_method() != "gl_compatibility"


static func attach(region: Node) -> void:
	if not active():
		return
	for node in region.find_children("*", "Sprite2D", true, false):
		attach_sprite(node as Sprite2D)
	for ground_name in ["GroundArt", "GroundPainting"]:
		var ground := region.get_node_or_null(ground_name) as Sprite2D
		if ground and ground.material is ShaderMaterial and ground.texture:
			var normal := normal_for(ground.texture.resource_path)
			if normal:
				(ground.material as ShaderMaterial).set_shader_parameter("normal_map", normal)
				ground.light_mask |= LIT_LAYER


## Puts the lit material on one sprite if its art has a normal map and it has
## no material of its own (the seasonal ground, snow caps, glows keep theirs).
## Returns true if it did.
static func attach_sprite(sprite: Sprite2D) -> bool:
	if not active() or sprite == null or sprite.texture == null:
		return false
	if sprite.material != null and not sprite.has_meta("lit"):
		return false
	var mat := material_for(sprite.texture.resource_path)
	if mat == null:
		if sprite.has_meta("lit"):
			detach_sprite(sprite)
		return false
	sprite.material = mat
	sprite.light_mask |= LIT_LAYER
	sprite.set_meta("lit", true)
	return true


## Takes the lit material off a sprite again (the snow cap needs it).
static func detach_sprite(sprite: Sprite2D) -> void:
	if sprite.has_meta("lit"):
		sprite.material = null
		sprite.light_mask &= ~LIT_LAYER
		sprite.remove_meta("lit")


## The lit material for sprites drawn from [param art], or null if it has no
## normal map.
static func material_for(art: String) -> ShaderMaterial:
	if _materials.has(art):
		return _materials[art]
	var mat: ShaderMaterial = null
	var normal := normal_for(art)
	if normal:
		mat = ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("normal_map", normal)
	_materials[art] = mat
	return mat


## The normal maps the sprites of the scene at [param scene_path] will want,
## so World can load them in the background before the scene is set up
## (loading them as it is set up stalls a frame for tens of milliseconds).
static func normals_for_scene(scene_path: String) -> Array[String]:
	var found: Array[String] = []
	if not active():
		return found
	for dep in ResourceLoader.get_dependencies(scene_path):
		var art: String = dep.get_slice("::", dep.get_slice_count("::") - 1)
		if not art.begins_with(SPRITE_DIR) or _materials.has(art):
			continue
		var path := NORMAL_DIR + art.trim_prefix(SPRITE_DIR)
		if not ResourceLoader.has_cached(path) and ResourceLoader.exists(path):
			found.append(path)
	return found


## The normal map painted for [param art], or null.
static func normal_for(art: String) -> Texture2D:
	if not art.begins_with(SPRITE_DIR):
		return null
	var path := NORMAL_DIR + art.trim_prefix(SPRITE_DIR)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
