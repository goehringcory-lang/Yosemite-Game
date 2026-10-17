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
@export var ground_inset := 8
## Footprint and reach in pixels (zero keeps the scene's default sizes).
@export var body_size := Vector2.ZERO
@export var reach_size := Vector2.ZERO


func _ready() -> void:
	if texture:
		_add_sprite()
		if body_size.x > 0.0:
			_resize("Collision", body_size, Vector2(0, -body_size.y / 2.0))
		if reach_size.x > 0.0:
			_resize("Hitbox/Shape", reach_size, Vector2(0, -reach_size.y / 2.0 - 4.0))
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
	sparks.set("area", Vector2(8, 2))
	sparks.position = Vector2(0, -24)
	sparks.z_index = 6
	add_child(sparks)
	var light := PointLight2D.new()
	light.name = "NightLight"
	light.set_script(load("res://scripts/world/night_light.gd"))
	light.position = Vector2(0, -20)
	light.set("radius", 140.0)
	light.set("strength", 1.0)
	light.set("flicker", 0.35)
	add_child(light)


## Without painted art the station draws itself in pixels, in the sprites'
## style (shaded from the upper left, a dark rim): a ring of stones round
## burning logs with a flickering flame, a granite slab with mortar holes, or
## a sand basin with water.
const RIM := Color("2a1b14")
const STONE := Color("93918f")
const STONE_LIT := Color("bdb8ae")
const STONE_DARK := Color("6a6a70")
const LOG := Color("6b4829")
const LOG_LIT := Color("92693d")
const FLAME := [Color("f1cf6a"), Color("f7a64a"), Color("d9772a")]

var _flicker := 0.0


func _process(delta: float) -> void:
	if texture or station != "campfire":
		set_process(false)
		return
	_flicker += delta
	if int(_flicker * 8.0) != int((_flicker - delta) * 8.0):
		queue_redraw()


func _px(x: float, y: float, w: float, h: float, color: Color) -> void:
	# Coordinates below are in the old 16px art grid: draw each at 2x.
	draw_rect(Rect2(x * 2.0, y * 2.0, w * 2.0, h * 2.0), color)


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
			_px(-8, -8, 16, 8, Color("d6bd88"))
			_px(-8, -8, 16, 1, Color("d6bd88"))
			_px(-5, -6, 10, 4, Color("3a86a8"))
			_px(-5, -6, 10, 1, Color("63b3c6"))


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
	_px(-5, -4, 1, 2, Color("d9772a"))
	_px(4, -4, 1, 2, Color("d9772a"))
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


## The campfire's first option: the cooking pot (see Cooking), where you
## cook what you like without a recipe.
const POT_OPTION := "Cook in the pot"
## Ingredients listed on one page of the pot's menu.
const POT_PAGE := 6


func interact(player: Player) -> void:
	var recipes := Recipes.known_for(station)
	var has_pot := station == "campfire"
	if recipes.is_empty() and not has_pot:
		DialogueBox.say_to(player, [{"speaker": "", "text": "%s. You don't know anything to make here yet." % display_name}])
		return
	var menu := menu_for(recipes)
	if has_pot:
		menu.options.insert(0, POT_OPTION)
		menu.icons.insert(0, Cooking.dish_icon("foragers_hash"))
		menu.details.insert(0, {"title": "No recipe needed", "rows": [], "facts": "Up to %d ingredients" % Cooking.POT_SIZE,
			"note": "Put in what you've gathered and see what comes out. Cooked food gives more energy and keeps longer, and some ingredients help on a climb."})
	player.can_act = false
	var box := DialogueBox.open(player)
	var choice := await box.choose("%s. What will you make?" % display_name, menu.options, "", menu.icons, menu.details)
	if has_pot and choice == 0:
		await _cook_in_pot(box)
	elif choice >= 0:
		var index := choice - (1 if has_pot else 0)
		if index < recipes.size():
			await _make(box, recipes[index])
	box.close()
	player.can_act = true


func _make(box: DialogueBox, recipe: RecipeData) -> void:
	if Recipes.make(recipe):
		var item := ItemDB.get_item(recipe.output_id)
		await box.say([{"speaker": "", "text": "%s You made %s." % [
			recipe.description, ItemDB.count_name(recipe.output_count, item.display_name if item else recipe.output_id)]}])
	else:
		await box.say([{"speaker": "", "text": "You need %s." % Recipes.describe_inputs(recipe)}])


## Fills the pot one ingredient at a time, then cooks it or walks away.
func _cook_in_pot(box: DialogueBox) -> void:
	var pot: Array[String] = []
	var page := 0
	var cursor := 0
	while true:
		var menu := pot_menu(pot, page)
		var choice := await box.choose(pot_prompt(pot), menu.options, "", menu.icons, menu.details, cursor)
		if choice < 0:
			return
		cursor = choice
		var action: String = menu.actions[choice]
		match action:
			"leave":
				return
			"more":
				page += 1
				cursor = 0
			"remove":
				pot.pop_back()
			"cook":
				var fresh := not Cooking.knows_dish(Cooking.dish_for(pot))
				var meal := Cooking.cook(pot)
				if meal != "":
					await box.say([{"speaker": "", "text": cooked_line(meal, fresh)}])
				return
			_:
				pot.append(action.trim_prefix("add:"))


## "The pot holds 2 California Blackberries and 1 Yerba Buena (3 of 5)."
static func pot_prompt(pot: Array) -> String:
	if pot.is_empty():
		return "The pot is empty. What goes in?"
	return "In the pot: %s (%d of %d)." % [_pot_list(pot), pot.size(), Cooking.POT_SIZE]


static func _pot_list(pot: Array) -> String:
	var counts := {}
	for id: String in pot:
		counts[id] = int(counts.get(id, 0)) + 1
	var parts := PackedStringArray()
	for id: String in counts:
		var item := ItemDB.get_item(id)
		parts.append(ItemDB.count_name(counts[id], item.display_name if item else id))
	return ", ".join(parts)


## The pot's menu for what's in [param pot]: a page of ingredients from the
## pack (with how many are left), then "More ingredients" when they run past
## a page, "Cook it", "Take the last one out", and "Leave". [code]actions[/code]
## says what each option does: "add:<id>", "more", "cook", "remove", "leave".
static func pot_menu(pot: Array, page := 0) -> Dictionary:
	var options := []
	var icons := []
	var details := []
	var actions := []
	var spare: Array[String] = []
	for id in Cooking.ingredients_in_inventory():
		if Inventory.count(id) > pot.count(id):
			spare.append(id)
	if pot.size() < Cooking.POT_SIZE:
		var pages := maxi(1, ceili(spare.size() / float(POT_PAGE)))
		page = posmod(page, pages)
		for id: String in spare.slice(page * POT_PAGE, (page + 1) * POT_PAGE):
			var item := ItemDB.get_item(id)
			options.append("%s (%d)" % [item.display_name, Inventory.count(id) - pot.count(id)])
			icons.append(item.icon)
			details.append(_ingredient_card(id))
			actions.append("add:" + id)
		if pages > 1:
			options.append("More ingredients (%d/%d)" % [page + 1, pages])
			icons.append(null)
			details.append(null)
			actions.append("more")
	if not pot.is_empty():
		var result := Cooking.result_for(pot)
		options.append("Cook it")
		icons.append(Cooking.dish_icon(result.dish) if Cooking.knows_dish(result.dish) else null)
		details.append(_preview_card(pot, result))
		actions.append("cook")
		options.append("Take the last one out")
		icons.append(null)
		details.append(null)
		actions.append("remove")
	options.append("Leave")
	icons.append(null)
	details.append(null)
	actions.append("leave")
	return {"options": options, "icons": icons, "details": details, "actions": actions}


## What an ingredient brings to the pot.
static func _ingredient_card(id: String) -> Dictionary:
	var effect := Cooking.effect_of(id)
	var raw := FoodDB.energy(id)
	var note := ""
	if Cooking.cooked_energy(id) <= 0:
		note = "Still bitter with tannins: it would spoil the dish. Leach it first."
	elif effect != "":
		var info: Dictionary = Cooking.EFFECTS[effect]
		note = "%s: %s." % [info.name, info.text]
	return {"title": "In the pot", "rows": [],
		"facts": "%d energy cooked (%s raw)" % [Cooking.cooked_energy(id), str(raw) if raw > 0 else "not raw"],
		"note": note}


## What the pot will make. A dish you've cooked before shows its name and
## worth; a new one keeps its secret until it's cooked.
static func _preview_card(pot: Array, result: Dictionary) -> Dictionary:
	var rows := []
	var seen := {}
	for id: String in pot:
		if seen.has(id):
			continue
		seen[id] = true
		var item := ItemDB.get_item(id)
		rows.append([item.icon if item else null, "%s x%d" % [item.display_name if item else id, pot.count(id)], false])
	var effects := {}
	for id: String in pot:
		if Cooking.effect_of(id) != "":
			effects[Cooking.effect_of(id)] = true
	var note := "Two effects in one pot cancel out." if effects.size() > 1 else ""
	if not Cooking.knows_dish(result.dish):
		return {"title": "Something new", "rows": rows, "facts": "%d min" % Cooking.minutes_for(pot),
			"note": ("Cook it to find out. " + note).strip_edges()}
	var effect := Cooking.effect_text(result.effect, result.moves)
	return {"title": Cooking.meal_name(result), "rows": rows,
		"facts": "%d energy · %d min" % [result.energy, Cooking.minutes_for(pot)],
		"note": (effect + " " + note).strip_edges()}


## "You cooked Steady Simmered Berries! 52 energy, keeps 4 days. ..."
static func cooked_line(meal: String, fresh: bool) -> String:
	var item := ItemDB.get_item(meal)
	var text := "The pot bubbles. You cooked %s! %d energy, keeps %d day%s." % [item.display_name,
		FoodDB.energy(meal), FoodDB.shelf_life(meal), "" if FoodDB.shelf_life(meal) == 1 else "s"]
	var effect: Dictionary = Cooking.meal_effect(meal)
	var effect_line := Cooking.effect_text(effect.effect, effect.moves)
	if effect_line != "":
		text += " " + effect_line
	if FoodDB.energy(meal) >= ClimbState.BIVY_MEAL_ENERGY:
		text += " That's a night's meal on a big wall."
	if fresh:
		text += " A new dish for your cookbook."
	return text
