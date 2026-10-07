extends Node
## Every recipe, and which ones the player knows.
##
## To add a recipe: create a RecipeData resource in res://data/recipes/, add
## it to RECIPES below, and teach it with a quest's reward_recipes (or add it
## to STARTING_RECIPES). Make sure its output has an ItemData and a FoodDB entry.

signal learned(recipe: RecipeData)
## Emitted after something is made. Quests listen for this.
signal made(recipe: RecipeData)

const RECIPES: Array[RecipeData] = [
	preload("res://data/recipes/acorn_flour.tres"),
	preload("res://data/recipes/leached_acorn_meal.tres"),
	preload("res://data/recipes/acorn_mush.tres"),
	preload("res://data/recipes/acorn_cake.tres"),
	preload("res://data/recipes/elderberry_sauce.tres"),
	preload("res://data/recipes/manzanita_cider.tres"),
	preload("res://data/recipes/roasted_morels.tres"),
	preload("res://data/recipes/toasted_toyon.tres"),
	preload("res://data/recipes/yerba_buena_tea.tres"),
	preload("res://data/recipes/spring_greens.tres"),
	preload("res://data/recipes/bread_pudding.tres"),
	preload("res://data/recipes/dry_crusts.tres"),
]

const STARTING_RECIPES := ["yerba_buena_tea", "roasted_morels"]

var known: Array[String] = []
## Recipe id -> how many times the player has made it (quests check this).
var times_made: Dictionary = {}

var _by_id: Dictionary = {}


func _ready() -> void:
	add_to_group("persist")
	for recipe: RecipeData in RECIPES:
		_by_id[recipe.id] = recipe


func start_new_game() -> void:
	known.assign(STARTING_RECIPES)
	times_made = {}


func get_recipe(id: String) -> RecipeData:
	return _by_id.get(id)


func knows(id: String) -> bool:
	return id in known


func learn(id: String) -> void:
	var recipe := get_recipe(id)
	if recipe == null:
		push_error("Unknown recipe id: %s" % id)
		return
	if not knows(id):
		known.append(id)
		learned.emit(recipe)


## Known recipes for one station, in the order they're listed in RECIPES.
func known_for(station: String) -> Array[RecipeData]:
	var result: Array[RecipeData] = []
	for recipe: RecipeData in RECIPES:
		if recipe.station == station and knows(recipe.id):
			result.append(recipe)
	return result


func can_make(recipe: RecipeData) -> bool:
	for id: String in recipe.inputs:
		if Inventory.count(id) < int(recipe.inputs[id]):
			return false
	return true


## "4 Black Oak Acorns" style list of the ingredients.
func describe_inputs(recipe: RecipeData) -> String:
	var parts := PackedStringArray()
	for id: String in recipe.inputs:
		var item := ItemDB.get_item(id)
		parts.append(ItemDB.count_name(int(recipe.inputs[id]), item.display_name if item else id))
	return ", ".join(parts)


## Uses the ingredients, adds the result, and spends the time. Returns false
## (and changes nothing) if the player is missing an ingredient.
func make(recipe: RecipeData) -> bool:
	if not can_make(recipe):
		return false
	for id: String in recipe.inputs:
		Inventory.remove(id, int(recipe.inputs[id]))
	Inventory.add(recipe.output_id, recipe.output_count)
	times_made[recipe.id] = times_made.get(recipe.id, 0) + 1
	GameClock.advance_minutes(recipe.minutes)
	made.emit(recipe)
	return true


func save_data() -> Dictionary:
	return {"known": known, "times_made": times_made}


func load_data(data: Dictionary) -> void:
	known.assign(data.get("known", STARTING_RECIPES))
	times_made = {}
	var saved: Dictionary = data.get("times_made", {})
	for id in saved:
		times_made[str(id)] = int(saved[id])
