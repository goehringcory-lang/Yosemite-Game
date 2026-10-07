extends Node
## Tracks how fresh each perishable item in the Inventory is, and spoils it
## overnight when its shelf life runs out.
##
## The Inventory only stores counts, so the Larder watches it and keeps a
## matching list of "days left" per unit. New items arrive fresh; when items
## are used, the oldest go first.

## Item id -> Array of days left for each unit, oldest (smallest) first.
var batches: Dictionary = {}


func _ready() -> void:
	add_to_group("persist")
	Inventory.changed.connect(_reconcile)
	GameClock.day_started.connect(_on_day_started.unbind(3))


func days_left(id: String) -> int:
	var list: Array = batches.get(id, [])
	return list[0] if not list.is_empty() else 0


## Brings the batches back in line with the Inventory's counts.
func _reconcile() -> void:
	for id: String in batches.keys():
		if not Inventory.items.has(id):
			batches.erase(id)
	for id: String in Inventory.items:
		var life := FoodDB.shelf_life(id)
		if life <= 0:
			continue
		var list: Array = batches.get(id, [])
		var have := Inventory.count(id)
		while list.size() < have:
			list.append(life) # fresh items are the newest, so they go last
		while list.size() > have:
			list.pop_front() # the oldest get used first
		batches[id] = list


func _on_day_started() -> void:
	var spoiled := {}
	for id: String in batches:
		var list: Array = batches[id]
		for i in list.size():
			list[i] -= 1
		while not list.is_empty() and list[0] <= 0:
			list.pop_front()
			spoiled[id] = spoiled.get(id, 0) + 1
	if spoiled.is_empty():
		return
	var names := PackedStringArray()
	for id: String in spoiled:
		Inventory.remove(id, spoiled[id])
		var item := ItemDB.get_item(id)
		names.append(ItemDB.count_name(spoiled[id], item.display_name if item else id))
	get_tree().call_group("hud", "show_message", "Spoiled overnight: %s." % ", ".join(names))


func save_data() -> Dictionary:
	return {"batches": batches}


func load_data(data: Dictionary) -> void:
	batches = {}
	var saved: Dictionary = data.get("batches", {})
	for id in saved:
		var list: Array = []
		for days in saved[id]:
			list.append(int(days))
		batches[str(id)] = list
	_reconcile()
