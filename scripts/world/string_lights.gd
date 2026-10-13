class_name StringLights
extends Node
## Lights the strings of bulbs over the plazas after dusk: each "Lights*"
## sprite in the region gets a warm glow on its bulbs (NightGlow), built here
## from the bulb pixels of its own picture, so it fades in with the lit
## windows. World adds one.

const NightGlow := preload("res://scripts/world/night_glow.gd")

var _region: Node
## Texture -> its glow picture.
static var _glows: Dictionary = {}


func _process(_delta: float) -> void:
	var world := get_parent()
	if world == null or not "region" in world or world.region == _region:
		return
	_region = world.region
	if _region == null or not "entities" in _region or _region.entities == null:
		return
	for child in _region.entities.get_children():
		if child is Sprite2D and child.name.begins_with("Lights") and child.texture and not child.has_node("Glow"):
			light(child)


## Puts a glow over [param sprite]'s bulbs.
static func light(sprite: Sprite2D) -> Sprite2D:
	var glow := Sprite2D.new()
	glow.name = "Glow"
	glow.set_script(NightGlow)
	glow.texture = glow_for(sprite.texture)
	glow.offset = sprite.offset
	glow.centered = sprite.centered
	sprite.add_child(glow)
	return glow


## A picture of soft halos around the bright warm pixels (the bulbs).
static func glow_for(texture: Texture2D) -> Texture2D:
	if _glows.has(texture):
		return _glows[texture]
	var source := texture.get_image()
	if source.is_compressed():
		source.decompress()
	var size := source.get_size()
	var out := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var c := source.get_pixel(x, y)
			if c.a < 0.5 or c.r < 0.95 or c.g < 0.75:
				continue
			# The bulbs are 2x2 blocks on the 2x art: the same 5x5 halo, in 2px cells.
			for dy in range(-5, 6):
				for dx in range(-5, 6):
					var at := Vector2i(x + dx, y + dy)
					var cx := ((x + dx) >> 1) - (x >> 1)
					var cy := ((y + dy) >> 1) - (y >> 1)
					if absi(cx) > 2 or absi(cy) > 2:
						continue
					if at.x < 0 or at.y < 0 or at.x >= size.x or at.y >= size.y:
						continue
					var a := 0.55 if cx == 0 and cy == 0 else (0.28 if absi(cx) + absi(cy) <= 1 else 0.1)
					var old := out.get_pixelv(at)
					out.set_pixelv(at, Color(1.0, 0.82, 0.45, maxf(old.a, a)))
	var made := ImageTexture.create_from_image(out)
	_glows[texture] = made
	return made
