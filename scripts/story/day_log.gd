class_name DayLog
extends Node
## What happened today, for the page shown when you go to sleep (DaySummary):
## what you found and were given, new gear, first ascents, finished quests,
## perks, recipes learned and dishes made. Starts over each morning. World
## adds one; it is saved with the game so a mid-day save keeps the page.

## item id -> count, gear id -> count.
var items: Dictionary = {}
var gear: Dictionary = {}
## Display names, in the order they happened.
var ticks: PackedStringArray = []
var quests: PackedStringArray = []
var perks: PackedStringArray = []
var recipes: PackedStringArray = []
## "Name (2 hearts)" for each heart gained today.
var friends: PackedStringArray = []
## Animals new to the field log today.
var animals: PackedStringArray = []
var dishes := 0


func _ready() -> void:
	name = "DayLog"
	add_to_group("persist")
	Inventory.added.connect(func(id: String, amount: int) -> void: items[id] = int(items.get(id, 0)) + amount)
	Gear.added.connect(func(id: String, amount: int) -> void: gear[id] = int(gear.get(id, 0)) + amount)
	QuestLog.ticked.connect(_on_ticked)
	QuestLog.quest_completed.connect(func(quest: QuestData) -> void: quests.append(quest.title))
	Perks.unlocked.connect(func(perk: Dictionary) -> void: perks.append(str(perk.get("name", ""))))
	Recipes.learned.connect(func(recipe: RecipeData) -> void: recipes.append(recipe.display_name))
	Recipes.made.connect(func(_recipe: RecipeData) -> void: dishes += 1)
	Friendship.heart_gained.connect(_on_heart)
	FieldLog.logged.connect(func(id: String) -> void: animals.append(str(FieldLog.get_animal(id).get("name", id))))
	GameClock.day_started.connect(clear.unbind(3))


func _on_ticked(route_id: String) -> void:
	for route: RouteData in Guidebook.routes():
		if route.id == route_id:
			ticks.append(route.display_name)
			return
	ticks.append(route_id)


func _on_heart(character_id: String, hearts: int) -> void:
	var character := QuestLog.get_character(character_id)
	var who := character.display_name if character else character_id
	for i in friends.size():
		if friends[i].begins_with(who + " ("):
			friends.remove_at(i)
			break
	friends.append("%s (%d heart%s)" % [who, hearts, "" if hearts == 1 else "s"])


func clear() -> void:
	items = {}
	gear = {}
	ticks = []
	quests = []
	perks = []
	recipes = []
	friends = []
	animals = []
	dishes = 0


## True when nothing worth a line happened.
func is_empty() -> bool:
	return items.is_empty() and gear.is_empty() and ticks.is_empty() and quests.is_empty() \
		and perks.is_empty() and recipes.is_empty() and friends.is_empty() and animals.is_empty() and dishes == 0


func save_data() -> Dictionary:
	return {"items": items, "gear": gear, "ticks": ticks, "quests": quests, "perks": perks,
		"recipes": recipes, "friends": friends, "animals": animals, "dishes": dishes}


func load_data(data: Dictionary) -> void:
	items = data.get("items", {})
	gear = data.get("gear", {})
	ticks = PackedStringArray(data.get("ticks", []))
	quests = PackedStringArray(data.get("quests", []))
	perks = PackedStringArray(data.get("perks", []))
	recipes = PackedStringArray(data.get("recipes", []))
	friends = PackedStringArray(data.get("friends", []))
	animals = PackedStringArray(data.get("animals", []))
	dishes = int(data.get("dishes", 0))
