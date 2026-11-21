extends Node
## The climbers' side of the gear trade: selling your spare gear to them, the
## piece a Camp 4 climber is after this week, the King Cobra swaps they take
## once a day, and a can shared at the fire after a new route.
##
## Selling never leaves you short for a climb: you always keep as much of a
## piece as the hungriest route in the guidebook asks for (keep_floor), so
## only true spares (the extra cams and draws quests hand out) go. Climbers
## pay in food that keeps, never in cans: King Cobra only flows their way.

const WANT_DAYS := 3
## What a toast at the fire gets you, in turn: gear id or item id -> count.
const TOAST_GIFTS := [
	{"gear": "quickdraw", "count": 2},
	{"item": "beef_jerky", "count": 2},
	{"item": "chocolate_bar", "count": 2},
	{"item": "trail_mix", "count": 2},
]
const CAN := "king_cobra"

## Routes you've shared a can over (route id).
var toasted: Array[String] = []
## Once-a-day offers used: "keeper/offer id" -> the day it was taken.
var swaps_on: Dictionary = {}

var _floor: Dictionary = {}


func _ready() -> void:
	add_to_group("persist")


func start_new_game() -> void:
	toasted = []
	swaps_on = {}


## A day count that keeps going across seasons and years.
static func today() -> int:
	return ((GameClock.year - 1) * 4 + GameClock.season) * GameClock.DAYS_PER_SEASON + GameClock.day


## How many of [param id] you always keep: the most any route asks for.
func keep_floor(id: String) -> int:
	if _floor.is_empty():
		for route in Guidebook.routes():
			for gear: String in route.required_gear:
				_floor[gear] = maxi(int(_floor.get(gear, 0)), int(route.required_gear[gear]))
		_floor["_"] = 0
	return int(_floor.get(id, 0))


## How many of [param id] you could sell: what you own past the floor.
func spare(id: String) -> int:
	var gear := Gear.get_gear(id)
	if gear == null or gear.keepsake or gear.trade_value <= 0:
		return 0
	return maxi(Gear.count(id) - keep_floor(id), 0)


## The piece [param data]'s keeper is after right now ("" if they aren't).
## It changes every WANT_DAYS days.
func wanted(data: ShopData) -> String:
	if data.wants.is_empty():
		return ""
	var turn := today() / WANT_DAYS
	return data.wants[(turn + absi(hash(data.keeper))) % data.wants.size()]


## What [param data]'s keeper gives for one [param id], in energy: their
## share of its value, or all of it for the piece they're after.
func price(data: ShopData, id: String) -> int:
	var gear := Gear.get_gear(id)
	if gear == null:
		return 0
	var rate := 1.0 if id == wanted(data) else data.buy_rate
	return maxi(roundi(gear.trade_value * rate), 1)


## The food they hand over for [param value] energy: the biggest first,
## then the smallest to cover what's left (item id -> count).
static func payment(value: int, pays_with: PackedStringArray) -> Dictionary:
	var foods := Array(pays_with).filter(func(id: String) -> bool: return FoodDB.energy(id) > 0)
	if foods.is_empty():
		return {}
	foods.sort_custom(func(a: String, b: String) -> bool: return FoodDB.energy(a) > FoodDB.energy(b))
	var paid := {}
	var left := value
	for id: String in foods:
		var n := left / FoodDB.energy(id)
		if n > 0:
			paid[id] = n
			left -= n * FoodDB.energy(id)
	# round up with the smallest, so you're never paid less than the price
	if left > 0 or paid.is_empty():
		var smallest: String = foods.back()
		paid[smallest] = int(paid.get(smallest, 0)) + 1
	return paid


## Gear [param data]'s keeper would buy from you now: id -> spare count.
func sellable(data: ShopData) -> Dictionary:
	var result := {}
	for id in data.buys_gear:
		if spare(id) > 0:
			result[id] = spare(id)
	return result


## Sells one [param id] to [param data]'s keeper. Returns the food you got
## (item id -> count), or {} if it isn't yours to sell.
func sell(data: ShopData, id: String) -> Dictionary:
	if not id in data.buys_gear or spare(id) <= 0:
		return {}
	var paid := payment(price(data, id), data.pays_with)
	if paid.is_empty() or Gear.remove(id) == 0:
		return {}
	for food: String in paid:
		Inventory.add(food, int(paid[food]))
	return paid


func _swap_key(data: ShopData, offer: ShopOffer) -> String:
	return "%s/%s" % [data.keeper, offer.id]


## True if [param offer] is a once-a-day one that's been taken today.
func taken_today(data: ShopData, offer: ShopOffer) -> bool:
	return offer.once_a_day and int(swaps_on.get(_swap_key(data, offer), -1)) == today()


func note_trade(data: ShopData, offer: ShopOffer) -> void:
	if offer.once_a_day:
		swaps_on[_swap_key(data, offer)] = today()


## The newest route you've topped out and not yet shared a can over, or
## null. A toast is one per route, so it rewards climbing, not farming.
func toast_route() -> RouteData:
	var ready: RouteData = null
	for route in Guidebook.routes():
		if QuestLog.has_climbed(route.id) and not route.id in toasted:
			ready = route
	return ready


## Shares a can over [param route]: takes one King Cobra and gives the next
## gift in TOAST_GIFTS. Returns the gift, or {} if you have no can.
func toast(route: RouteData) -> Dictionary:
	if route == null or route.id in toasted or not Inventory.remove(CAN):
		return {}
	var gift: Dictionary = TOAST_GIFTS[toasted.size() % TOAST_GIFTS.size()]
	toasted.append(route.id)
	if gift.has("gear"):
		Gear.add(gift.gear, gift.count)
	else:
		Inventory.add(gift.item, gift.count)
	return gift


## "2 Quickdraws"
static func gift_name(gift: Dictionary) -> String:
	var thing: Resource = Gear.get_gear(gift.gear) if gift.has("gear") else ItemDB.get_item(gift.item)
	var name: String = thing.display_name if thing else str(gift.get("gear", gift.get("item", "")))
	return ItemDB.count_name(int(gift.count), name)


func save_data() -> Dictionary:
	return {"toasted": toasted, "swaps_on": swaps_on}


func load_data(data: Dictionary) -> void:
	toasted = []
	for id in data.get("toasted", []):
		toasted.append(str(id))
	swaps_on = {}
	var saved: Dictionary = data.get("swaps_on", {})
	for key in saved:
		swaps_on[str(key)] = int(saved[key])
