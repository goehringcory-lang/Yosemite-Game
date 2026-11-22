class_name TradeValues
extends RefCounted
## What everything you carry is worth in a trade, and to whom.
##
## The unit is the old food currency: 1 = 1 energy of food, so ShopOffer
## prices keep their meaning. Every item has a base value ([method base]):
##
## - Food you can eat: its energy, a little more if it keeps (x1.1 for 4 to
##   14 days, x1.2 for longer).
## - Things you can't eat as they are (raw fish, mushrooms that want the pot,
##   cattail root): 70% of what they give in the pot (Cooking.INGREDIENTS),
##   so cooking still adds a little.
## - Raw acorns and the acorn chain, which only pay off after leaching: by
##   hand (ACORN_CHAIN).
## - Quest and story things, keepsakes and litter: not for trade (0).
##
## What a buyer pays ([method worth_to]) is the base times their tastes
## (ShopData.tastes, TASTES), the season (forage is cheap at its peak and
## dear out of season, SEASON_FACTOR), how fresh it is (half on its last
## day), and how much of the same sort they've taken lately (Market's glut,
## so the tenth basket of greens is worth less than the first).
##
## King Cobra is the climbers' currency: a can is worth 20, climbers pay
## half again for one, but each can they take makes the next worth a
## quarter less (Market.COBRA_STEP) until a day or two passes.

## Raw forage and fish: what share of their pot energy they trade for.
const RAW_SHARE := 0.7
## Cooked meals from the pot: what share of their energy they trade for.
const MEAL_SHARE := 0.8
## Hand-set values for things the rules above can't price.
const ACORN_CHAIN := {"black_oak_acorn": 3, "acorn_flour": 8, "leached_acorn_meal": 15}
## Items with a value of their own, whatever else they are.
const SET_VALUES := {"king_cobra": 20, "litter": 0,
	# Curios found off the trail (hidden finds): odd old things people
	# collect. Climbers want the piton and the headlamp.
	"rusty_piton": 18, "lost_headlamp": 25, "railroad_spike": 10, "ski_wax_tin": 8, "glass_insulator": 14}
const CURIOS := ["rusty_piton", "lost_headlamp", "railroad_spike", "ski_wax_tin", "glass_insulator"]
## Fish caught on the fly rod (Fishing).
const FISH := ["brown_trout", "brook_trout"]
## The climber's favorite snacks off the store shelf.
const CLIMBER_SNACKS := ["chocolate_bar", "beef_jerky", "cheddar_wedge"]
## Food from the stores that isn't in any shop now: gifts people bake or
## grow for you. They trade like store food.
const GIFT_FOODS := ["lamon_apple", "degnan_loaf", "pine_nuts"]

## Buyers' tastes, by ShopData.tastes: a multiplier per sort of thing
## ([method sort_of]: "fresh", "wild", "fish", "cooked", "store", "cobra",
## "curio")
## or per item id (an id wins over its sort). Unlisted = 1.0. They stay
## between 0.5 and 1.5, so no one buyer makes a thing worthless or a gold
## mine.
const TASTES := {
	# Camp 4: hungry, broke, and short on stoves. Cans and candy bars, please.
	"climber": {"cobra": 1.5, "chocolate_bar": 1.15, "beef_jerky": 1.15, "cheddar_wedge": 1.15,
		"fresh": 0.6, "wild": 0.7, "fish": 0.7, "rusty_piton": 1.4, "lost_headlamp": 1.5, "curio": 0.8},
	# The stores swap fresh forage for food that keeps (it's what they're
	# for), but buy their own kind of goods back cheap, and never over half
	# their own price for what they stock (STORE_BUYBACK).
	"store": {"fresh": 0.9, "wild": 0.8, "fish": 0.7, "cooked": 0.8, "store": 0.6, "cobra": 0.6},
	# Marty outfits climbers: he'll take fresh food, but not your fish.
	"outfitter": {"fish": 0.8, "rusty_piton": 1.2, "lost_headlamp": 1.2},
	# Greg: a fisherman who'd rather not catch his own supper every night.
	"angler": {"fish": 1.5, "fresh": 0.8, "wild": 0.8, "cooked": 0.8, "store": 0.8, "cobra": 0.8},
}
## A store pays at most this share of its own shelf price for something it sells.
const STORE_BUYBACK := 0.5
## Forage in its main season, at the lean edges of it, and out of season
## (kept from another time of year: nuts and roots laid by, rose hips).
const SEASON_FACTOR := {"peak": 0.85, "lean": 1.0, "off": 1.3}
## On its last day before spoiling, food trades for half.
const LAST_DAY_FACTOR := 0.5
## Every shop, for what the stores stock (STORE_BUYBACK) and the tests.
const SHOPS := ["res://data/shops/curry_store.tres", "res://data/shops/village_store.tres",
	"res://data/shops/curry_mountain_shop.tres", "res://data/shops/camp4_rack.tres",
	"res://data/shops/camp4_bigwall.tres", "res://data/shops/greg_flies.tres"]

static var _shelf_prices: Dictionary = {}


## Can [param id] be offered in a trade at all?
static func tradeable(id: String) -> bool:
	return base(id) > 0


## What [param id] is worth before anyone's tastes, as a float of energy units.
static func base(id: String) -> float:
	if SET_VALUES.has(id):
		return float(SET_VALUES[id])
	if ACORN_CHAIN.has(id):
		return float(ACORN_CHAIN[id])
	if id.begins_with(Cooking.PREFIX):
		return Cooking.meal_energy(id) * MEAL_SHARE * keep_factor(Cooking.meal_shelf_life(id)) if Cooking.is_meal(id) else 0.0
	if not FoodDB.FOODS.has(id):
		return 0.0 # story items, keepsakes
	var energy := FoodDB.energy(id)
	if energy > 0:
		return energy * keep_factor(int(FoodDB.FOODS[id].shelf_life))
	var pot: int = Cooking.INGREDIENTS.get(id, {}).get("energy", 0)
	return pot * RAW_SHARE


## x1.0 for food that spoils within 3 days, x1.1 up to two weeks, x1.2 longer
## (0 = never spoils).
static func keep_factor(shelf_life: int) -> float:
	if shelf_life <= 0 or shelf_life >= 15:
		return 1.2
	return 1.1 if shelf_life >= 4 else 1.0


## Which sort of thing [param id] is, for tastes and gluts: "cobra",
## "curio" (odd old finds),
## "fish", "fresh" (wild food that spoils within 4 days), "wild" (wild food
## that keeps), "cooked" (made at a campfire or the pot), "store" (bought or
## given), or "" (not for trade).
static func sort_of(id: String) -> String:
	if not tradeable(id):
		return ""
	if id == "king_cobra":
		return "cobra"
	if id in CURIOS:
		return "curio"
	if id in FISH:
		return "fish"
	if id.begins_with(Cooking.PREFIX) or ACORN_CHAIN.has(id) and id != "black_oak_acorn":
		return "cooked"
	var item := ItemDB.get_item(id)
	if item and item.forage_per_day > 0:
		return "fresh" if int(FoodDB.FOODS.get(id, {}).get("shelf_life", 0)) <= 4 else "wild"
	if id in GIFT_FOODS or _shelf_prices_all().has(id):
		return "store"
	return "cooked" # the campfire dishes in data/food


## How [param tastes] (a ShopData.tastes profile) feel about [param id].
static func taste(tastes: String, id: String) -> float:
	var profile: Dictionary = TASTES.get(tastes, {})
	if profile.has(id):
		return float(profile[id])
	return float(profile.get(sort_of(id), 1.0))


## Forage's season factor today: peak, lean or off (SEASON_FACTOR); 1.0 for
## anything that isn't forage.
static func season_factor(id: String, season := -1) -> float:
	var item := ItemDB.get_item(id)
	if item == null or item.forage_per_day <= 0:
		return 1.0
	var s := GameClock.season if season < 0 else season
	if item.forage_seasons & (1 << s):
		return SEASON_FACTOR.peak
	if item.lean_seasons & (1 << s):
		return SEASON_FACTOR.lean
	return SEASON_FACTOR.off


## What one unit of [param id] is worth to the buyer selling from
## [param data] (null = anyone, at base tastes), [param days_left] days from
## spoiling (0 = doesn't spoil), with [param extra_glut] more of its sort
## already handed over in this same trade.
static func worth_to(data: ShopData, id: String, days_left := 0, extra_glut := 0.0) -> float:
	var value := base(id)
	if value <= 0.0:
		return 0.0
	var tastes := data.tastes if data else ""
	value *= taste(tastes, id) * season_factor(id)
	if Camp.has("workbench") and tastes in ["climber", "outfitter"]:
		value *= 1.15
	if days_left == 1 and FoodDB.shelf_life(id) > 1:
		value *= LAST_DAY_FACTOR
	value *= Market.appetite(Market.key_of(data), sort_of(id), extra_glut)
	if tastes == "store":
		value *= 1.0 + Perks.bonus("gallery_eye")
	if tastes == "store" and data:
		var shelf := _shelf_price(data, id)
		if shelf > 0:
			value = minf(value, shelf * STORE_BUYBACK)
	return value


## A whole-number value for menus.
static func shown(value: float) -> int:
	return int(floor(value + 0.0001))


## What a piece of gear is worth (GearData.trade_value, set by the gear
## trades; 0 if it has none).
static func gear_value(id: String) -> int:
	var gear := Gear.get_gear(id)
	if gear == null:
		return 0
	var value: Variant = gear.get("trade_value")
	return int(value) if value != null else 0


## What [param data] sells [param id] for, 0 if it doesn't.
static func _shelf_price(data: ShopData, id: String) -> int:
	for offer in data.offers:
		if offer.kind == "item" and offer.id == id and offer.trade.is_empty():
			return offer.price
	return 0


## Every item a shop sells for a price, as id -> the lowest price.
static func _shelf_prices_all() -> Dictionary:
	if _shelf_prices.is_empty():
		for path: String in SHOPS:
			var data: ShopData = load(path)
			for offer in data.offers:
				if offer.kind == "item" and offer.trade.is_empty():
					_shelf_prices[offer.id] = mini(int(_shelf_prices.get(offer.id, offer.price)), offer.price)
	return _shelf_prices


## The lowest price any shop sells [param id] for (0 = no shop does).
static func cheapest_shelf_price(id: String) -> int:
	return int(_shelf_prices_all().get(id, 0))
