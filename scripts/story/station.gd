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
	else:
		queue_redraw()
	if station == "campfire":
		_add_fire_effects()


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


## Without painted art the station draws itself in pixels, in the sprites'
## style (shaded from the upper left, a dark rim): a ring of stones round
## burning logs with a flickering flame, a granite slab with mortar holes, or
## a sand basin with water.
const RIM := Color("2a1f1a")
const STONE := Color("8a8a90")
const STONE_LIT := Color("b0b0b6")
const STONE_DARK := Color("5a5a62")
const LOG := Color("6a4024")
const LOG_LIT := Color("8a5a34")
const FLAME := [Color("f8e070"), Color("f8a030"), Color("e05a20")]

var _flicker := 0.0


func _process(delta: float) -> void:
	if texture or station != "campfire":
		set_process(false)
		return
	_flicker += delta
	if int(_flicker * 8.0) != int((_flicker - delta) * 8.0):
		queue_redraw()


func _px(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)


func _draw() -> void:
	if texture:
		return
	match station:
		"campfire":
			_draw_campfire()
		"mortar":
			# a low granite slab with two worn grinding holes
			_px(-11, -8, 22, 9, RIM)
			_px(-10, -7, 20, 7, STONE)
			_px(-10, -7, 20, 1, STONE_LIT)
			_px(-10, -2, 20, 2, STONE_DARK)
			for x in [-6, 3]:
				_px(x, -5, 4, 2, STONE_DARK.darkened(0.3))
				_px(x, -5, 4, 1, RIM)
		"leaching":
			# a sand basin by the river with water standing in it
			_px(-9, -9, 18, 10, RIM)
			_px(-8, -8, 16, 8, Color("d8c090"))
			_px(-8, -8, 16, 1, Color("ecd8a8"))
			_px(-5, -6, 10, 4, Color("4a8ac8"))
			_px(-5, -6, 10, 1, Color("8ac0e8"))


func _draw_campfire() -> void:
	# the stone ring, back stones first
	var stones := [Vector2(-7, -6), Vector2(-3, -8), Vector2(2, -8), Vector2(6, -6), Vector2(7, -2), Vector2(-8, -2), Vector2(-4, 0), Vector2(1, 0), Vector2(5, 0)]
	for at: Vector2 in stones.slice(0, 4):
		_stone(at)
	# crossed logs, glowing at the ends
	_px(-6, -5, 12, 3, RIM)
	_px(-5, -4, 10, 1, LOG_LIT)
	_px(-5, -3, 10, 1, LOG)
	_px(-2, -7, 4, 6, RIM)
	_px(-1, -6, 2, 4, LOG_LIT)
	_px(-5, -4, 1, 2, Color("f08030"))
	_px(4, -4, 1, 2, Color("f08030"))
	# the flame: three layers that lean and flicker
	var frame := int(_flicker * 8.0) % 4
	var lean: int = [0, 1, 0, -1][frame]
	var tall: int = [0, 1, 2, 1][frame]
	_px(-3 + lean, -10 - tall, 6, 6 + tall, FLAME[2])
	_px(-2 + lean, -12 - tall, 4, 7 + tall, FLAME[1])
	_px(-1 + lean, -13 - tall, 2, 6 + tall, FLAME[0])
	_px(0 + lean * 2, -15 - tall, 1, 2, FLAME[1])
	# front stones last, over the logs
	for at: Vector2 in stones.slice(4):
		_stone(at)


func _stone(at: Vector2) -> void:
	_px(at.x - 2, at.y - 2, 5, 4, RIM)
	_px(at.x - 1, at.y - 1, 3, 2, STONE)
	_px(at.x - 1, at.y - 1, 2, 1, STONE_LIT)
	_px(at.x + 1, at.y, 1, 1, STONE_DARK)


## The cooking menu for [param recipes]: each dish's name and picture, and a
## card for each with what goes in (what you have of each, in red when short),
## how much energy it gives, how long it takes, and its note. Then "Leave".
static func menu_for(recipes: Array[RecipeData]) -> Dictionary:
	var options := []
	var icons := []
	var details := []
	for recipe in recipes:
		var dish := ItemDB.get_item(recipe.output_id)
		icons.append(dish.icon if dish else null)
		options.append(recipe.display_name)
		var rows := []
		for id: String in recipe.inputs:
			var item := ItemDB.get_item(id)
			var need := int(recipe.inputs[id])
			var have := Inventory.count(id)
			rows.append([item.icon if item else null, "%s  %d/%d" % [item.display_name if item else id, have, need], have < need])
		var facts := PackedStringArray()
		var energy := FoodDB.energy(recipe.output_id)
		if energy > 0:
			facts.append("%d energy" % energy)
		var minutes := Perks.recipe_minutes(recipe)
		facts.append("%d min" % minutes if minutes < 60 else ("%d hr" % (minutes / 60) if minutes % 60 == 0 else "%d hr %d min" % [minutes / 60, minutes % 60]))
		if recipe.output_count > 1:
			facts.insert(0, "Makes %d" % recipe.output_count)
		details.append({"title": "You'll need" if Recipes.can_make(recipe) else "You're short", "rows": rows,
			"facts": " · ".join(facts), "note": recipe.description})
	options.append("Leave")
	icons.append(null)
	details.append(null)
	return {"options": options, "icons": icons, "details": details}


func interact(player: Player) -> void:
	var recipes := Recipes.known_for(station)
	if recipes.is_empty():
		DialogueBox.say_to(player, [{"speaker": "", "text": "%s. You don't know anything to make here yet." % display_name}])
		return
	var menu := menu_for(recipes)
	player.can_act = false
	var box := DialogueBox.open(player)
	var choice := await box.choose("%s. What will you make?" % display_name, menu.options, "", menu.icons, menu.details)
	if choice >= 0 and choice < recipes.size():
		var recipe := recipes[choice]
		if Recipes.make(recipe):
			var item := ItemDB.get_item(recipe.output_id)
			await box.say([{"speaker": "", "text": "%s You made %s." % [
				recipe.description, ItemDB.count_name(recipe.output_count, item.display_name if item else recipe.output_id)]}])
		else:
			await box.say([{"speaker": "", "text": "You need %s." % Recipes.describe_inputs(recipe)}])
	box.close()
	player.can_act = true
