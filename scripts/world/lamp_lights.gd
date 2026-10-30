class_name LampLights
extends RefCounted
## Real light from the lamps, lanterns and fires painted into the outdoor
## maps and rooms. Many were placed before NightLight existed and only had their art,
## so after dark a street lamp was a white speck over dark ground. World calls
## [method attach] on each region's first visit: every sprite whose art
## is listed in LIGHTS gets a NightLight at its lamp head or flames, unless the
## thing already has a light of its own.

## Art that gives light: where the light sits (from the top of the sprite, in
## pixels; a negative number counts from its feet), how far it reaches, how
## bright it is, how much it flickers and its colour.
const LIGHTS := {
	"res://assets/sprites/ahwahnee/lamp_wrought.png": {"head": 9, "radius": 72.0, "strength": 0.95, "flicker": 0.0, "color": Color(1.0, 0.8, 0.52)},
	"res://assets/sprites/clutter/camp_lantern.png": {"head": 12, "radius": 46.0, "strength": 0.85, "flicker": 0.12, "color": Color(1.0, 0.78, 0.45)},
	"res://assets/sprites/lamon/campfire.png": {"head": -10, "radius": 112.0, "strength": 1.5, "flicker": 0.4, "color": Color(1.0, 0.66, 0.34)},
	"res://assets/sprites/buildings/camp4_fire_ring.png": {"head": -10, "radius": 112.0, "strength": 1.5, "flicker": 0.4, "color": Color(1.0, 0.66, 0.34)},
	# Indoors: they come up as the room dims at night (RoomLight, High graphics).
	"res://assets/sprites/interiors/props/table_lamp.png": {"head": 8, "radius": 70.0, "strength": 0.8, "flicker": 0.0, "color": Color(1.0, 0.82, 0.55)},
	"res://assets/sprites/interiors/props/lamp.png": {"head": 10, "radius": 80.0, "strength": 0.85, "flicker": 0.0, "color": Color(1.0, 0.82, 0.55)},
	"res://assets/sprites/interiors/props/lamp_ahw.png": {"head": 10, "radius": 80.0, "strength": 0.85, "flicker": 0.0, "color": Color(1.0, 0.82, 0.55)},
	"res://assets/sprites/interiors/props/desk_lamp.png": {"head": 4, "radius": 56.0, "strength": 0.7, "flicker": 0.0, "color": Color(0.95, 0.9, 0.7)},
	"res://assets/sprites/interiors/props/desk_ahw_lamp.png": {"head": 4, "radius": 56.0, "strength": 0.7, "flicker": 0.0, "color": Color(0.95, 0.9, 0.7)},
	"res://assets/sprites/interiors/props/stove.png": {"head": 50, "radius": 76.0, "strength": 0.9, "flicker": 0.3, "color": Color(1.0, 0.62, 0.32)},
	"res://assets/sprites/curry/interiors/store_stove.png": {"head": 50, "radius": 76.0, "strength": 0.9, "flicker": 0.3, "color": Color(1.0, 0.62, 0.32)},
	"res://assets/sprites/curry/interiors/shop_stove.png": {"head": 50, "radius": 76.0, "strength": 0.9, "flicker": 0.3, "color": Color(1.0, 0.62, 0.32)},
	"res://assets/sprites/interiors/props/hearth.png": {"head": -30, "radius": 120.0, "strength": 1.1, "flicker": 0.4, "color": Color(1.0, 0.64, 0.34)},
	"res://assets/sprites/interiors/props/hearth_small.png": {"head": -28, "radius": 110.0, "strength": 1.1, "flicker": 0.4, "color": Color(1.0, 0.64, 0.34)},
	"res://assets/sprites/interiors/props/hearth_lodge.png": {"head": -32, "radius": 130.0, "strength": 1.15, "flicker": 0.4, "color": Color(1.0, 0.64, 0.34)},
	"res://assets/sprites/interiors/props/hearth_ahw_great.png": {"head": -45, "radius": 170.0, "strength": 1.2, "flicker": 0.4, "color": Color(1.0, 0.64, 0.34)},
}


static func attach(region: Region) -> void:
	if region.entities == null:
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
