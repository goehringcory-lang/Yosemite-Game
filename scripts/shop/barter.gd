class_name Barter
extends RefCounted
## Paying for trades with whatever you carry.
##
## A price is in energy units (1 = 1 energy of food). Traders take anything
## with a trade value (TradeValues): food, forage, fish, store goods, cans
## of King Cobra, each worth what that trader thinks of it (their tastes,
## the season, how fresh it is, and how much of it they've had lately). A
## trader never takes story things, or what a quest or a board note you've
## taken still needs ([method reserved]).
##
## People who are going to eat what you give them (Muir's supper, a hurt
## climber) want food: [method pay_food] pays in food energy, the soonest
## to spoil first, as all trades did before.


## What everything tradeable you carry is worth to the trader selling from
## [param data] (null = anyone), plus your tab with them.
static func purse(data: ShopData = null) -> int:
	var total := 0.0
	var extra := {}
	var have := goods()
	for id: String in _sorted(have):
		for unit in int(have[id]):
			total += _unit_worth(data, id, unit, extra)
	return TradeValues.shown(total) + Market.tab(Market.key_of(data))


static func can_afford(price: int, data: ShopData = null) -> bool:
	return not plan(price, data).is_empty()


## What paying [param price] to [param data] would take, without taking it:
## {"taken": item id -> count, "value": what that's worth to them, "tab":
## credit used, "change": what goes on the tab after}. {} if you can't.
## It takes the fewest, cheapest-to-you goods that cover the price: first
## whatever spoils within 3 days, then what the trader prizes most against
## its usual worth, King Cobra last unless they love it, and it finishes
## with the smallest thing that covers what's left, so little goes over.
static func plan(price: int, data: ShopData = null) -> Dictionary:
	var key := Market.key_of(data)
	var credit := mini(Market.tab(key), price)
	var owed := float(price - credit)
	var taken := {}
	var extra := {}
	var value := 0.0
	var left := goods()
	while owed > 0.0001:
		var best := ""
		var best_worth := 0.0
		var best_rank := []
		var closer := ""
		var closer_worth := INF
		for id: String in _sorted(left):
			if int(left[id]) <= 0:
				continue
			var unit := int(taken.get(id, 0))
			var worth := _unit_worth(data, id, unit, extra, false)
			if worth <= 0.0:
				continue
			# the smallest single thing that settles it
			if worth >= owed - 0.0001 and worth < closer_worth and not _cobra_kept(data, id):
				closer = id
				closer_worth = worth
			var rank := _rank(data, id, unit, worth)
			if best == "" or _before(rank, best_rank):
				best = id
				best_worth = worth
				best_rank = rank
		var pick := closer if closer != "" else best
		if pick == "":
			return {}
		var worth := closer_worth if closer != "" else best_worth
		taken[pick] = int(taken.get(pick, 0)) + 1
		left[pick] = int(left[pick]) - 1
		var sort := TradeValues.sort_of(pick)
		extra[sort] = float(extra.get(sort, 0.0)) + 1.0
		value += worth
		owed -= worth
	var change := mini(TradeValues.shown(-owed), Market.TAB_CAP)
	return {"taken": taken, "value": TradeValues.shown(value), "tab": credit, "change": change}


## Pays [param price] to the trader selling from [param data]: takes the
## goods [method plan] picks, notes the trader's glut, and settles the tab.
## Returns what was taken (item id -> count; empty with only the tab used,
## see [method last_tab_used]), or {} if the player can't pay.
static func pay(price: int, data: ShopData = null) -> Dictionary:
	var p := plan(price, data)
	if p.is_empty():
		return {}
	var key := Market.key_of(data)
	for id: String in p.taken:
		Inventory.remove(id, int(p.taken[id]))
		Market.took(key, TradeValues.sort_of(id), float(p.taken[id]))
	Market.set_tab(key, Market.tab(key) - int(p.tab) + int(p.change))
	var paid: Dictionary = p.taken.duplicate()
	if int(p.tab) > 0:
		paid["tab"] = int(p.tab)
	return paid


## Food energy you carry (FoodDB.carried_energy), for people who'll eat it.
static func food_purse() -> int:
	return FoodDB.carried_energy()


static func can_afford_food(energy: int) -> bool:
	return food_purse() >= energy


## Takes food worth at least [param energy] energy from the pack, the food
## that will spoil soonest first. Returns what was taken (item id -> count),
## or {} if the player can't.
static func pay_food(energy: int) -> Dictionary:
	if not can_afford_food(energy):
		return {}
	var foods := FoodDB.edible_in_inventory()
	foods.sort_custom(func(a: String, b: String) -> bool: return _keeps(a) < _keeps(b))
	var taken := {}
	var owed := energy
	for id in foods:
		while owed > 0 and Inventory.count(id) > 0:
			Inventory.remove(id)
			taken[id] = int(taken.get(id, 0)) + 1
			owed -= FoodDB.energy(id)
		if owed <= 0:
			break
	return taken


## "3 Miner's Lettuce and 1 Acorn Cake" (a "tab" entry reads "12 off your tab").
static func describe(taken: Dictionary) -> String:
	var parts := PackedStringArray()
	for id: String in taken:
		if id == "tab":
			parts.append("%d off your tab" % int(taken[id]))
			continue
		var item := ItemDB.get_item(id)
		parts.append(ItemDB.count_name(taken[id], item.display_name if item else id))
	if parts.size() <= 1:
		return "".join(parts)
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[-1]


## Items no trader takes from you right now: what an active quest step or a
## board note you've taken asks for (up to the count it asks).
static func reserved() -> Dictionary:
	var out := {}
	for quest_id: String in QuestLog.active:
		var quest := QuestLog.get_quest(quest_id)
		if quest == null:
			continue
		var step := QuestLog.current_step(quest)
		if step.get("type", "") == "have":
			out[step.item] = int(out.get(step.item, 0)) + int(step.get("count", 1))
	for entry: Dictionary in BoardRequests.open_notes():
		var note: Dictionary = entry.note
		out[note.item] = int(out.get(note.item, 0)) + int(note.count)
	return out


## What you could trade: tradeable items, less what's reserved, as id -> count.
static func goods() -> Dictionary:
	var out := {}
	var keep := reserved()
	for id: String in Inventory.items:
		if not TradeValues.tradeable(id):
			continue
		var n := Inventory.count(id) - int(keep.get(id, 0))
		if n > 0:
			out[id] = n
	return out


static func _sorted(have: Dictionary) -> Array:
	var ids := have.keys()
	ids.sort()
	return ids


## The worth of the [param unit]th unit of [param id] handed over (units go
## oldest first, as Larder spends them), with [param extra] already given in
## this trade by sort. With [param add], counts it into [param extra].
static func _unit_worth(data: ShopData, id: String, unit: int, extra: Dictionary, add := true) -> float:
	var sort := TradeValues.sort_of(id)
	var worth := TradeValues.worth_to(data, id, _days_left(id, unit), float(extra.get(sort, 0.0)))
	if add:
		extra[sort] = float(extra.get(sort, 0.0)) + 1.0
	return worth


## Days until the [param unit]th oldest [param id] spoils (0 = it doesn't).
static func _days_left(id: String, unit: int) -> int:
	var list: Array = Larder.batches.get(id, [])
	return int(list[unit]) if unit < list.size() else 0


## Sort key for which unit goes next (smaller first): spoiling soon, then
## what the trader prizes most for its usual worth, then King Cobra last
## (unless it's prized), then the soonest to spoil.
static func _rank(data: ShopData, id: String, unit: int, worth: float) -> Array:
	var days := _days_left(id, unit)
	var soon := 0 if days > 0 and days <= 3 else 1
	var base := TradeValues.base(id)
	var prized := worth / base if base > 0.0 else 0.0
	var cobra_last := 1 if _cobra_kept(data, id) else 0
	return [soon, cobra_last, -prized, days if days > 0 else 9999, id]


## King Cobra goes last to anyone who doesn't prize it.
static func _cobra_kept(data: ShopData, id: String) -> bool:
	return id == "king_cobra" and TradeValues.taste(data.tastes if data else "", id) <= 1.0


static func _before(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] < b[i]
	return false


static func _keeps(id: String) -> int:
	var days := Larder.days_left(id)
	return days if days > 0 else 9999
