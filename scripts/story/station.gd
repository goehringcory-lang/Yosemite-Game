class_name Station
extends StaticBody2D
## A place to prepare food: a campfire, a bedrock mortar, or a leaching
## basin by the river. Interact to pick a known recipe and make it.

## Must match RecipeData.station.
@export_enum("campfire", "mortar", "leaching") var station := "campfire"
@export var display_name := "Campfire"
## Painted art. Without it the station draws the plain placeholder shapes
## below. [member frames] side-by-side frames play at [member fps]; the
## sprite's ground line sits [member ground_inset] px above its bottom edge.
@export var texture: Texture2D
@export var frames := 1
@export var fps := 0.0
@export var ground_inset := 4
## Footprint and reach in pixels (zero keeps the scene's default sizes).
@export var body_size := Vector2.ZERO
@export var reach_size := Vector2.ZERO


func _ready() -> void:
	if texture:
		_add_sprite()
		if body_size.x > 0.0:
			_resize("Collision", body_size, Vector2(0, -body_size.y / 2.0))
		if reach_size.x > 0.0:
			_resize("Hitbox/Shape", reach_size, Vector2(0, -reach_size.y / 2.0 - 2.0))
		if station == "campfire":
			_add_fire_effects()
	else:
		queue_redraw()


func _add_sprite() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Art"
	sprite.texture = texture
	sprite.hframes = frames
	sprite.offset = Vector2(0, -texture.get_height() / 2.0 + ground_inset)
	if frames > 1 and fps > 0.0:
		sprite.set_script(load("res://scripts/world/frame_cycle.gd"))
		sprite.set("fps", fps)
	add_child(sprite)
	move_child(sprite, 0)


func _resize(node_path: String, size: Vector2, at_pos: Vector2) -> void:
	var shape_node := get_node_or_null(node_path) as CollisionShape2D
	if shape_node == null:
		return
	var rect := RectangleShape2D.new()
	rect.size = size
	shape_node.shape = rect
	shape_node.position = at_pos


## A fire throws sparks, and lights the ground around it after dark.
func _add_fire_effects() -> void:
	var sparks := CPUParticles2D.new()
	sparks.name = "Sparks"
	sparks.set_script(load("res://scripts/world/ambient_fx.gd"))
	sparks.set("effect", "sparks")
	sparks.set("area", Vector2(4, 1))
	sparks.position = Vector2(0, -12)
	sparks.z_index = 6
	add_child(sparks)
	var light := PointLight2D.new()
	light.name = "NightLight"
	light.set_script(load("res://scripts/world/night_light.gd"))
	light.position = Vector2(0, -10)
	light.set("radius", 70.0)
	light.set("strength", 1.0)
	light.set("flicker", 0.35)
	add_child(light)


## Placeholder art until real sprites exist.
func _draw() -> void:
	if texture:
		return
	match station:
		"campfire":
			for i in 5:
				var angle := TAU * i / 5.0
				draw_circle(Vector2(cos(angle), sin(angle) * 0.5) * 6 + Vector2(0, -3), 2.0, Color(0.5, 0.48, 0.45))
			draw_colored_polygon(PackedVector2Array([Vector2(-3, -3), Vector2(3, -3), Vector2(0, -11)]), Color(1.0, 0.55, 0.15))
		"mortar":
			draw_rect(Rect2(-10, -8, 20, 9), Color(0.6, 0.58, 0.55))
			draw_circle(Vector2(-4, -4), 2.0, Color(0.35, 0.33, 0.3))
			draw_circle(Vector2(4, -4), 2.0, Color(0.35, 0.33, 0.3))
		"leaching":
			draw_circle(Vector2(0, -4), 7.0, Color(0.75, 0.68, 0.5))
			draw_circle(Vector2(0, -4), 4.5, Color(0.4, 0.6, 0.8))


func interact(player: Player) -> void:
	var recipes := Recipes.known_for(station)
	if recipes.is_empty():
		DialogueBox.say_to(player, [{"speaker": "", "text": "%s. You don't know anything to make here yet." % display_name}])
		return
	var options := []
	for recipe in recipes:
		var mark := "" if Recipes.can_make(recipe) else " (missing ingredients)"
		options.append("%s: %s%s" % [recipe.display_name, Recipes.describe_inputs(recipe), mark])
	options.append("Leave")
	player.can_act = false
	var box := DialogueBox.open(player)
	var choice := await box.choose("%s. What will you make?" % display_name, options)
	if choice >= 0 and choice < recipes.size():
		var recipe := recipes[choice]
		if Recipes.make(recipe):
			var item := ItemDB.get_item(recipe.output_id)
			await box.say([{"speaker": "", "text": "%s You made %d %s." % [
				recipe.description, recipe.output_count, item.display_name if item else recipe.output_id]}])
		else:
			await box.say([{"speaker": "", "text": "You need %s." % Recipes.describe_inputs(recipe)}])
	box.close()
	player.can_act = true
