extends Node
## Registry of every item in the game.
##
## To add an item: create a new ItemData resource in res://data/items/
## (right-click > New Resource > ItemData), then add it to ITEMS below.
## Foods also need an entry in FoodDB for their energy and shelf life.

const ITEMS := [
	# Wild forage
	preload("res://data/items/wild_strawberry.tres"),
	preload("res://data/items/miners_lettuce.tres"),
	preload("res://data/items/sierra_onion.tres"),
	preload("res://data/items/yampah.tres"),
	preload("res://data/items/black_oak_acorn.tres"),
	preload("res://data/items/manzanita_berries.tres"),
	preload("res://data/items/morel_mushroom.tres"),
	preload("res://data/items/blue_elderberries.tres"),
	preload("res://data/items/yerba_buena.tres"),
	preload("res://data/items/toyon_berries.tres"),
	preload("res://data/items/california_blackberry.tres"),
	preload("res://data/items/whitebark_raspberry.tres"),
	preload("res://data/items/thimbleberry.tres"),
	preload("res://data/items/sierra_gooseberry.tres"),
	preload("res://data/items/sierra_bilberry.tres"),
	preload("res://data/items/wood_rose_hips.tres"),
	preload("res://data/items/chanterelle.tres"),
	preload("res://data/items/king_bolete.tres"),
	preload("res://data/items/coyote_mint.tres"),
	# Caught on a fly rod (Fishing), and picked up on Facelift day (Festivals)
	preload("res://data/items/brown_trout.tres"),
	preload("res://data/items/brook_trout.tres"),
	preload("res://data/items/litter.tres"),
	# Prepared food (see Recipes)
	preload("res://data/food/acorn_flour.tres"),
	preload("res://data/food/leached_acorn_meal.tres"),
	preload("res://data/food/acorn_mush.tres"),
	preload("res://data/food/acorn_cake.tres"),
	preload("res://data/food/elderberry_sauce.tres"),
	preload("res://data/food/manzanita_cider.tres"),
	preload("res://data/food/roasted_morels.tres"),
	preload("res://data/food/toasted_toyon.tres"),
	preload("res://data/food/yerba_buena_tea.tres"),
	preload("res://data/food/spring_greens.tres"),
	preload("res://data/food/bread_pudding.tres"),
	preload("res://data/food/dry_crusts.tres"),
	# Story items: gifts, trades, and materials from quests
	preload("res://data/story_items/lamon_apple.tres"),
	preload("res://data/story_items/degnan_loaf.tres"),
	preload("res://data/story_items/pine_nuts.tres"),
	preload("res://data/story_items/model_a_axle.tres"),
	preload("res://data/story_items/anderson_eyebolt.tres"),
	preload("res://data/story_items/sourdough_starter.tres"),
	preload("res://data/story_items/sequoia_cone.tres"),
	preload("res://data/story_items/flour_sack.tres"),
	preload("res://data/story_items/rental_shoes.tres"),
	preload("res://data/story_items/chongo_book.tres"),
	preload("res://data/story_items/travel_slackline.tres"),
	# Village Store trail food (see data/shops/village_store.tres)
	preload("res://data/food/trail_mix.tres"),
	preload("res://data/food/dried_apples.tres"),
	# Camp Curry Store food (see data/shops/curry_store.tres)
	preload("res://data/food/pilot_bread.tres"),
	preload("res://data/food/cheddar_wedge.tres"),
	preload("res://data/food/dried_apricots.tres"),
	preload("res://data/food/beef_jerky.tres"),
	preload("res://data/food/chocolate_bar.tres"),
	preload("res://data/food/king_cobra.tres"),
]

var _by_id: Dictionary = {}


func _ready() -> void:
	for item: ItemData in ITEMS:
		_by_id[item.id] = item


## Returns null if [param id] isn't a registered item. Meals cooked in the
## pot aren't in ITEMS: Cooking makes their ItemData from the id.
func get_item(id: String) -> ItemData:
	var item: ItemData = _by_id.get(id)
	if item == null and id.begins_with(Cooking.PREFIX):
		return Cooking.meal_item(id)
	return item


## Words that don't take an "s": "3 Trail Mix", "2 Pilot Bread".
const MASS_NOUNS := ["Mix", "Jerky", "Tea", "Mush", "Flour", "Meal", "Cider", "Sauce", "Lettuce", "Yampah", "Buena", "Toyon", "Pilot Bread", "Mint", "Fruit"]
## Names with their own plural.
const PLURALS := {"Degnan's Bread": "loaves of Degnan's Bread"}


## "1 Cam", "2 Cams", "3 Wild Strawberries", "2 Trail Mix": a count and a
## name for messages. Names already plural ("Aiders", "Pine Nuts") stay put.
static func count_name(n: int, name: String) -> String:
	if n == 1:
		return "1 %s" % name
	if PLURALS.has(name):
		return "%d %s" % [n, PLURALS[name]]
	if name.ends_with("s") or MASS_NOUNS.any(func(word: String) -> bool: return name.ends_with(word)):
		return "%d %s" % [n, name]
	if name.ends_with("y") and not name.ends_with("ey"):
		return "%d %sies" % [n, name.left(-1)]
	if name.ends_with("ss") or name.ends_with("x") or name.ends_with("sh"):
		return "%d %ses" % [n, name]
	return "%d %ss" % [n, name]


func forage_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item: ItemData in ITEMS:
		if item.forage_per_day > 0:
			result.append(item)
	return result
