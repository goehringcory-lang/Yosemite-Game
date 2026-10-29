extends Node
## Cooking in the pot at a campfire, in the style of Breath of the Wild: put
## up to [constant POT_SIZE] ingredients in, and what comes out depends on
## what went in. No recipe to learn first.
##
## - The dish is worked out from the kinds of ingredient (berries, greens,
##   mushrooms, acorn meal...); see [method dish_for]. Raw acorns spoil it.
## - Cooking is worth it: each ingredient gives more energy cooked than raw,
##   mixing different ones adds [constant VARIETY_BONUS] each, and five fresh
##   berries become one meal that keeps for days instead of spoiling tomorrow.
##   A meal of [constant ClimbState.BIVY_MEAL_ENERGY] or more is a night's
##   meal on a big wall.
## - Some ingredients carry an effect (see [constant EFFECTS]): more of them
##   makes it last longer, but two different effects cancel out.
##
## A cooked meal is an item like any other. Its id holds everything about it
## ("meal.simmered_berries.42.steady.10"), so the same meal stacks, saves and
## spoils with no extra bookkeeping. ItemDB and FoodDB ask here about any id
## that starts with "meal.".

signal cooked(meal_id: String)

const POT_SIZE := 5
const VARIETY_BONUS := 2
## A meal's effect lasts this many climbing moves for each point of potency.
const MOVES_PER_POTENCY := 5
const MAX_EFFECT_MOVES := 30
const BASE_MINUTES := 20
const MINUTES_PER_INGREDIENT := 5
const PREFIX := "meal."
const MEAL_ICONS := preload("res://assets/sprites/meal_items.png")

## What each ingredient gives in the pot: its energy once cooked, its kind
## (which picks the dish), and the effect it carries and how strongly.
## Anything not listed can't go in the pot (dishes that are already cooked,
## and things that aren't food).
const INGREDIENTS := {
	# Berries and fruit
	"wild_strawberry": {"energy": 13, "kind": "berry"},
	"manzanita_berries": {"energy": 13, "kind": "berry"},
	"california_blackberry": {"energy": 16, "kind": "berry"},
	"whitebark_raspberry": {"energy": 15, "kind": "berry"},
	"thimbleberry": {"energy": 12, "kind": "berry", "effect": "nimble", "potency": 1},
	"sierra_gooseberry": {"energy": 10, "kind": "berry", "effect": "nimble", "potency": 1},
	"sierra_bilberry": {"energy": 13, "kind": "berry", "effect": "keen", "potency": 1},
	"blue_elderberries": {"energy": 10, "kind": "berry", "effect": "keen", "potency": 1},
	"toyon_berries": {"energy": 7, "kind": "berry"},
	"chokecherry": {"energy": 9, "kind": "berry"},
	"wood_rose_hips": {"energy": 7, "kind": "berry", "effect": "warming", "potency": 1},
	"lamon_apple": {"energy": 16, "kind": "fruit"},
	"dried_apples": {"energy": 18, "kind": "fruit"},
	"dried_apricots": {"energy": 22, "kind": "fruit"},
	"sierra_plum": {"energy": 14, "kind": "fruit"},
	# Greens, roots and herbs
	"miners_lettuce": {"energy": 10, "kind": "green"},
	"sierra_onion": {"energy": 8, "kind": "green", "effect": "warming", "potency": 1},
	"cow_clover": {"energy": 8, "kind": "green"},
	"yampah": {"energy": 16, "kind": "root"},
	"blue_dicks_corm": {"energy": 10, "kind": "root"},
	"cattail_root": {"energy": 15, "kind": "root"},
	"yerba_buena": {"energy": 4, "kind": "herb", "effect": "steady", "potency": 1},
	"coyote_mint": {"energy": 4, "kind": "herb", "effect": "steady", "potency": 2},
	# Mushrooms
	"morel_mushroom": {"energy": 12, "kind": "mushroom"},
	"chanterelle": {"energy": 14, "kind": "mushroom"},
	"king_bolete": {"energy": 18, "kind": "mushroom", "effect": "hearty", "potency": 1},
	"hedgehog_mushroom": {"energy": 14, "kind": "mushroom"},
	# Nuts
	"hazelnut": {"energy": 16, "kind": "nut"},
	"whitebark_pine_nuts": {"energy": 18, "kind": "nut", "effect": "hearty", "potency": 1},
	# Staples
	"leached_acorn_meal": {"energy": 30, "kind": "grain"},
	"degnan_loaf": {"energy": 28, "kind": "grain"},
	"pilot_bread": {"energy": 24, "kind": "grain"},
	"pine_nuts": {"energy": 24, "kind": "nut", "effect": "hearty", "potency": 1},
	"cheddar_wedge": {"energy": 30, "kind": "savory"},
	"beef_jerky": {"energy": 34, "kind": "savory"},
	"brown_trout": {"energy": 32, "kind": "savory"},
	"brook_trout": {"energy": 28, "kind": "savory"},
	"chocolate_bar": {"energy": 26, "kind": "sweet", "effect": "keen", "potency": 1},
	# Still full of tannins: they spoil whatever they're cooked with.
	"black_oak_acorn": {"energy": 0, "kind": "bitter"},
	"acorn_flour": {"energy": 0, "kind": "bitter"},
}

## What each effect does on a climb (see ClimbState), the word it puts in
## front of the dish's name, and a short line for menus.
const EFFECTS := {
	"hearty": {"prefix": "Hearty", "name": "Hearty", "text": "fills your stamina all the way"},
	"steady": {"prefix": "Steady", "name": "Steady", "text": "each move pumps you 1 less"},
	"keen": {"prefix": "Keen", "name": "Keen", "text": "a wider green on crux moves"},
	"warming": {"prefix": "Warming", "name": "Warming", "text": "storms and slush don't slow you; a cold bivy can't chill you"},
	"nimble": {"prefix": "Nimble", "name": "Nimble", "text": "every move costs 1 less"},
}

## Every dish, in Cookbook order: its name, how many days it keeps, its frame
## in assets/sprites/meal_items.png, and a line about it.
const DISHES := {
	"simmered_berries": {"name": "Simmered Berries", "keeps": 4, "frame": 0,
		"note": "Berries cooked down soft and sweet. They keep far longer than fresh ones."},
	"berry_medley": {"name": "Copious Berry Medley", "keeps": 5, "frame": 1,
		"note": "Three kinds of berry or more, stewed together. A summer's worth in a pot."},
	"baked_fruit": {"name": "Baked Fruit", "keeps": 5, "frame": 2,
		"note": "Fruit baked in the coals until it slumps."},
	"wilted_greens": {"name": "Wilted Greens", "keeps": 1, "frame": 3,
		"note": "Greens softened over the fire. Eat them today."},
	"root_hash": {"name": "Root Hash", "keeps": 3, "frame": 4,
		"note": "Roots roasted in the ashes and fried up crisp."},
	"mushroom_skewer": {"name": "Mushroom Skewer", "keeps": 2, "frame": 5,
		"note": "Mushrooms threaded on a willow stick and turned over the flames."},
	"mushroom_saute": {"name": "Mushroom Sauté", "keeps": 2, "frame": 6,
		"note": "Mushrooms and wild greens cooked down together."},
	"herb_tea": {"name": "Wild Mint Tea", "keeps": 1, "frame": 7,
		"note": "Just herbs and hot water. Not much to it but the effect."},
	"berry_acorn_cakes": {"name": "Berry Acorn Cakes", "keeps": 10, "frame": 8,
		"note": "Leached acorn meal patted round berries and baked on a hot stone."},
	"berry_cobbler": {"name": "Berry Cobbler", "keeps": 5, "frame": 9,
		"note": "Bread crumbled over stewed fruit and baked in the coals."},
	"mountain_flatbread": {"name": "Mountain Flatbread", "keeps": 6, "frame": 10,
		"note": "A thick flatbread with whatever you had folded inside."},
	"camp_stew": {"name": "Camp Stew", "keeps": 2, "frame": 11,
		"note": "Store food and wild food simmered into something better than either."},
	"nut_berry_bars": {"name": "Nut and Berry Bars", "keeps": 14, "frame": 12,
		"note": "Pine nuts pressed with berries and dried by the fire. They keep for weeks."},
	"roasted_pine_nuts": {"name": "Roasted Nuts", "keeps": 30, "frame": 13,
		"note": "Nuts toasted in a basket with hot coals, the old way."},
	"chocolate_berries": {"name": "Chocolate-Dipped Berries", "keeps": 6, "frame": 14,
		"note": "Berries dipped in chocolate melted on a warm rock."},
	"foragers_hash": {"name": "Forager's Hash", "keeps": 2, "frame": 15,
		"note": "A little of everything. It fills you up."},
	"bitter_mush": {"name": "Bitter Mush", "keeps": 1, "frame": 16,
		"note": "Raw acorns ruined it. They need leaching before they're food."},
}
## Bitter Mush is worth only this much, whatever went in.
const BITTER_ENERGY := 3

## Dish id -> {"best": highest energy cooked, "made": times cooked}.
var discovered: Dictionary = {}

var _items: Dictionary = {}


func _ready() -> void:
	add_to_group("persist")


func start_new_game() -> void:
	discovered = {}


func can_cook_with(id: String) -> bool:
	return INGREDIENTS.has(id)


func cooked_energy(id: String) -> int:
	return int(INGREDIENTS.get(id, {}).get("energy", 0))


## The effect [param id] carries in the pot, or "".
func effect_of(id: String) -> String:
	return str(INGREDIENTS.get(id, {}).get("effect", ""))


## Ingredients in the pack the pot could take, in INGREDIENTS order.
func ingredients_in_inventory() -> Array[String]:
	var result: Array[String] = []
	for id: String in INGREDIENTS:
		if Inventory.count(id) > 0:
			result.append(id)
	return result


## Which dish the ingredients in [param pot] make (a key of DISHES).
func dish_for(pot: Array) -> String:
	var kinds := {}
	var berry_types := {}
	for id: String in pot:
		var kind := str(INGREDIENTS.get(id, {}).get("kind", ""))
		kinds[kind] = true
		if kind == "berry":
			berry_types[id] = true
	if kinds.has("bitter"):
		return "bitter_mush"
	# Herbs only season a dish, unless there's nothing else in the pot.
	kinds.erase("herb")
	if kinds.is_empty():
		return "herb_tea"
	var fruity := kinds.has("berry") or kinds.has("fruit")
	var savory := kinds.has("green") or kinds.has("root") or kinds.has("mushroom") or kinds.has("savory")
	if kinds.has("grain"):
		if fruity and not savory:
			return "berry_acorn_cakes" if "leached_acorn_meal" in pot else "berry_cobbler"
		return "mountain_flatbread"
	if kinds.has("nut"):
		if kinds.size() == 1:
			return "roasted_pine_nuts"
		if fruity and not savory:
			return "nut_berry_bars"
		return "foragers_hash"
	if kinds.has("sweet"):
		return "chocolate_berries" if fruity and not savory else "foragers_hash"
	if kinds.has("savory"):
		return "camp_stew" if not fruity else "foragers_hash"
	if fruity:
		if savory:
			return "foragers_hash"
		if berry_types.size() >= 3:
			return "berry_medley"
		return "simmered_berries" if kinds.has("berry") else "baked_fruit"
	if kinds.has("mushroom"):
		return "mushroom_skewer" if kinds.size() == 1 else "mushroom_saute"
	return "root_hash" if kinds.has("root") else "wilted_greens"


## What [param pot] would cook into: {"dish", "energy", "effect", "moves"}.
## Two different effects cancel each other out, as in Hyrule.
func result_for(pot: Array) -> Dictionary:
	var dish := dish_for(pot)
	if dish == "bitter_mush":
		return {"dish": dish, "energy": BITTER_ENERGY, "effect": "", "moves": 0}
	var energy := 0
	var distinct := {}
	var potency := {}
	for id: String in pot:
		energy += cooked_energy(id)
		distinct[id] = true
		var effect := effect_of(id)
		if effect != "":
			potency[effect] = int(potency.get(effect, 0)) + int(INGREDIENTS[id].get("potency", 1))
	energy += VARIETY_BONUS * maxi(distinct.size() - 1, 0)
	var effect := ""
	var moves := 0
	if potency.size() == 1:
		effect = potency.keys()[0]
		if effect != "hearty":
			moves = mini(int(potency[effect]) * MOVES_PER_POTENCY, MAX_EFFECT_MOVES)
	return {"dish": dish, "energy": energy, "effect": effect, "moves": moves}


## Minutes at the fire for [param pot].
func minutes_for(pot: Array) -> int:
	return BASE_MINUTES + MINUTES_PER_INGREDIENT * pot.size()


## Cooks [param pot] (an array of item ids, repeats allowed): uses the
## ingredients, adds the meal and spends the time. Returns the meal's id, or
## "" (changing nothing) if the pot is empty, too full, or holds something
## you don't have.
func cook(pot: Array) -> String:
	if pot.is_empty() or pot.size() > POT_SIZE:
		return ""
	var needed := {}
	for id: String in pot:
		if not can_cook_with(id):
			return ""
		needed[id] = int(needed.get(id, 0)) + 1
	for id: String in needed:
		if Inventory.count(id) < needed[id]:
			return ""
	for id: String in needed:
		Inventory.remove(id, needed[id])
	var result := result_for(pot)
	var meal := meal_id(result)
	Inventory.add(meal)
	var entry: Dictionary = discovered.get(result.dish, {"best": 0, "made": 0})
	entry.best = maxi(int(entry.best), int(result.energy))
	entry.made = int(entry.made) + 1
	discovered[result.dish] = entry
	GameClock.advance_minutes(minutes_for(pot))
	cooked.emit(meal)
	return meal


func knows_dish(dish: String) -> bool:
	return discovered.has(dish)


# ---------------------------------------------------------------- meal items

func meal_id(result: Dictionary) -> String:
	var effect: String = result.effect if result.effect != "" else "none"
	return "%s%s.%d.%s.%d" % [PREFIX, result.dish, int(result.energy), effect, int(result.moves)]


func is_meal(id: String) -> bool:
	return id.begins_with(PREFIX) and not parse(id).is_empty()


## {"dish", "energy", "effect", "moves"} for a meal id, or {} if it isn't one.
func parse(id: String) -> Dictionary:
	var parts := id.trim_prefix(PREFIX).split(".")
	if not id.begins_with(PREFIX) or parts.size() != 4 or not DISHES.has(parts[0]):
		return {}
	var effect := parts[2] if parts[2] != "none" else ""
	if effect != "" and not EFFECTS.has(effect):
		return {}
	return {"dish": parts[0], "energy": int(parts[1]), "effect": effect, "moves": int(parts[3])}


func meal_energy(id: String) -> int:
	return int(parse(id).get("energy", 0))


func meal_shelf_life(id: String) -> int:
	var meal := parse(id)
	return int(DISHES[meal.dish].keeps) if not meal.is_empty() else 0


## The meal's effect and how many moves it lasts: {"effect", "moves"}.
func meal_effect(id: String) -> Dictionary:
	var meal := parse(id)
	return {"effect": meal.get("effect", ""), "moves": int(meal.get("moves", 0))}


## "Steady Simmered Berries".
func meal_name(result: Dictionary) -> String:
	var name: String = DISHES[result.dish].name
	return "%s %s" % [EFFECTS[result.effect].prefix, name] if result.effect != "" else name


## "Steady for 10 moves: each move pumps you 1 less." or "".
func effect_text(effect: String, moves: int) -> String:
	if effect == "":
		return ""
	var info: Dictionary = EFFECTS[effect]
	if effect == "hearty":
		return "Hearty: %s." % info.text
	return "%s for %d moves: %s." % [info.name, moves, info.text]


func dish_icon(dish: String) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = MEAL_ICONS
	atlas.region = Rect2(int(DISHES[dish].frame) * 32, 0, 32, 32)
	return atlas


## An ItemData for a meal id (made once and kept), or null if it isn't one.
func meal_item(id: String) -> ItemData:
	if _items.has(id):
		return _items[id]
	var meal := parse(id)
	if meal.is_empty():
		return null
	var item := ItemData.new()
	item.id = id
	item.display_name = meal_name(meal)
	var effect := effect_text(meal.effect, meal.moves)
	item.description = DISHES[meal.dish].note + (" " + effect if effect != "" else "")
	item.icon = dish_icon(meal.dish)
	_items[id] = item
	return item


func save_data() -> Dictionary:
	return {"discovered": discovered}


func load_data(data: Dictionary) -> void:
	discovered = {}
	var saved: Dictionary = data.get("discovered", {})
	for dish in saved:
		if DISHES.has(str(dish)):
			var entry: Dictionary = saved[dish]
			discovered[str(dish)] = {"best": int(entry.get("best", 0)), "made": int(entry.get("made", 0))}
