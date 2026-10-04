class_name Barter
extends RefCounted
## Paying for trades with food. A price is an amount of food energy (see
## FoodDB); payment takes the food that will spoil soonest first.


## Total energy of the food the player can pay with.
static func purse() -> int:
	return FoodDB.carried_energy()


static func can_afford(price: int) -> bool:
	return purse() >= price


## Takes food worth at least [param price] energy from the inventory.
## Returns what was taken (item id -> count), or {} if the player can't pay.
static func pay(price: int) -> Dictionary:
	if not can_afford(price):
		return {}
	var foods := FoodDB.edible_in_inventory()
	foods.sort_custom(func(a: String, b: String) -> bool: return _keeps(a) < _keeps(b))
	var taken := {}
	var owed := price
	for id in foods:
		while owed > 0 and Inventory.count(id) > 0:
			Inventory.remove(id)
			taken[id] = int(taken.get(id, 0)) + 1
			owed -= FoodDB.energy(id)
		if owed <= 0:
			break
	return taken


## "3 Miner's Lettuce and 1 Acorn Cake"
static func describe(taken: Dictionary) -> String:
	var parts := PackedStringArray()
	for id: String in taken:
		var item := ItemDB.get_item(id)
		parts.append("%d %s" % [taken[id], item.display_name if item else id])
	if parts.size() <= 1:
		return "".join(parts)
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[-1]


static func _keeps(id: String) -> int:
	var days := Larder.days_left(id)
	return days if days > 0 else 9999
