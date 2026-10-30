class_name LampLights
extends RefCounted
## Real light from the lamps, lanterns and fires painted into the outdoor
## maps. Many were placed before NightLight existed and only had their art,
## so after dark a street lamp was a white speck over dark ground. World calls
## [method attach] on each outdoor region's first visit: every sprite whose art
## is listed in LIGHTS gets a NightLight at its lamp head or flames, unless the
## thing already has a light of its own.

## Art that gives light: where the light sits (from the top of the sprite, in
## pixels; a negative number counts from its feet), how far it reaches, how
## bright it is, how much it flickers and its colour.
const LIGHTS := {
	"res://assets/sprites/ahwahnee/lamp_wrought.png": {"head": 9, "radius": 72.0, "strength": 0.95, "flicker": 0.0, "color": Color(1.0, 0.8, 0.52)},
	"res://assets/sprites/clutter/camp_lantern.png": {"head": 12, "radius": 46.0, "strength": 0.85, "flicker": 0.12, "color": Color(1.0, 0.78, 0.45)},
	"res://assets/sprites/lamon/campfire.png": {"head": -10, "radius": 84.0, "strength": 1.15, "flicker": 0.4, "color": Color(1.0, 0.66, 0.34)},
	"res://assets/sprites/buildings/camp4_fire_ring.png": {"head": -10, "radius": 84.0, "strength": 1.15, "flicker": 0.4, "color": Color(1.0, 0.66, 0.34)},
}


static func attach(region: Region) -> void:
	if region.indoors or region.entities == null:
		return
	for sprite in region.entities.find_children("*", "Sprite2D", true, false):
		var spec: Dictionary = LIGHTS.get(_art_of(sprite), {})
		if spec.is_empty():
			continue
		var holder := sprite.get_parent() as Node2D
		if holder == null or not holder.find_children("*", "PointLight2D", true, false).is_empty():
			continue
		var rect: Rect2 = sprite.get_rect()
		var head: int = spec.head
		var y := rect.position.y + head if head >= 0 else rect.end.y + head
		var light := NightLight.new()
		light.name = "NightLight"
		light.radius = spec.radius
		light.strength = spec.strength
		light.flicker = spec.flicker
		light.position = sprite.position + Vector2(rect.get_center().x, y)
		holder.add_child(light)
		light.color = spec.color


static func _art_of(sprite: Sprite2D) -> String:
	return sprite.texture.resource_path if sprite.texture else ""
