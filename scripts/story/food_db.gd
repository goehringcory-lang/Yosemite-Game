extends Node
## What each food is worth on a climb.
##
## energy: stamina restored when eaten (0 = can't be eaten as is; for
## example, raw acorns are too bitter until leached).
## shelf_life: days it keeps in your pack before spoiling (0 = never).
## Acorns keep for good once they're stored in a chuckah (see Granary).

const FOODS := {
	# Fresh forage: quick energy that spoils fast
	"miners_lettuce": {"energy": 8, "shelf_life": 2},
	"wild_strawberry": {"energy": 10, "shelf_life": 2},
	"manzanita_berries": {"energy": 10, "shelf_life": 3},
	"sierra_onion": {"energy": 6, "shelf_life": 5},
	"yampah": {"energy": 12, "shelf_life": 7},
	"yerba_buena": {"energy": 2, "shelf_life": 3},
	"morel_mushroom": {"energy": 0, "shelf_life": 3}, # must be cooked
	"blue_elderberries": {"energy": 0, "shelf_life": 2}, # must be cooked
	"toyon_berries": {"energy": 0, "shelf_life": 5}, # must be toasted
	# The acorn chain
	"black_oak_acorn": {"energy": 0, "shelf_life": 14},
	"acorn_flour": {"energy": 0, "shelf_life": 5},
	"leached_acorn_meal": {"energy": 0, "shelf_life": 2},
	"acorn_mush": {"energy": 35, "shelf_life": 2},
	"acorn_cake": {"energy": 45, "shelf_life": 10},
	# Campfire dishes
	"elderberry_sauce": {"energy": 18, "shelf_life": 4},
	"manzanita_cider": {"energy": 15, "shelf_life": 2},
	"roasted_morels": {"energy": 20, "shelf_life": 1},
	"toasted_toyon": {"energy": 12, "shelf_life": 5},
	"yerba_buena_tea": {"energy": 8, "shelf_life": 1},
	"spring_greens": {"energy": 36, "shelf_life": 1},
	"bread_pudding": {"energy": 30, "shelf_life": 6},
	"dry_crusts": {"energy": 9, "shelf_life": 30},
	# Gifts and trades from quests
	"lamon_apple": {"energy": 12, "shelf_life": 12},
	"degnan_loaf": {"energy": 25, "shelf_life": 4},
	"pine_nuts": {"energy": 20, "shelf_life": 30},
	# Village Store trail food: keeps well, but less energy than acorn food
	"trail_mix": {"energy": 30, "shelf_life": 20},
	"dried_apples": {"energy": 15, "shelf_life": 30},
	# Camp Curry Store food: more choice than the Village Store, all long-keeping
	"pilot_bread": {"energy": 22, "shelf_life": 60},
	"dried_apricots": {"energy": 18, "shelf_life": 40},
	"chocolate_bar": {"energy": 24, "shelf_life": 60},
	"cheddar_wedge": {"energy": 28, "shelf_life": 12},
	"beef_jerky": {"energy": 32, "shelf_life": 45},
}


func is_food(id: String) -> bool:
	return FOODS.has(id)


func energy(id: String) -> int:
	return FOODS.get(id, {}).get("energy", 0)


func shelf_life(id: String) -> int:
	return FOODS.get(id, {}).get("shelf_life", 0)


func is_edible(id: String) -> bool:
	return energy(id) > 0


## Every edible item the player is carrying, best energy first.
func edible_in_inventory() -> Array[String]:
	var result: Array[String] = []
	for id: String in Inventory.items:
		if is_edible(id):
			result.append(id)
	result.sort_custom(func(a, b): return energy(a) > energy(b))
	return result


## Total energy of everything edible the player is carrying.
func carried_energy() -> int:
	var total := 0
	for id in edible_in_inventory():
		total += energy(id) * Inventory.count(id)
	return total
