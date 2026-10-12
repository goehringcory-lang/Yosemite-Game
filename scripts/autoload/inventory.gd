extends Node
## What the player is carrying, as item id -> count.

signal changed
## Sent when the player gets something, so the HUD can show it.
signal added(id: String, amount: int)

var items: Dictionary = {}


func start_new_game() -> void:
	items = {}
	changed.emit()


func count(id: String) -> int:
	return items.get(id, 0)


func add(id: String, amount := 1) -> void:
	items[id] = count(id) + amount
	changed.emit()
	added.emit(id, amount)


func remove(id: String, amount := 1) -> bool:
	if count(id) < amount:
		return false
	items[id] -= amount
	if items[id] <= 0:
		items.erase(id)
	changed.emit()
	return true


func save_data() -> Dictionary:
	return {"items": items}


func load_data(data: Dictionary) -> void:
	items = {}
	var saved_items: Dictionary = data.get("items", {})
	for id in saved_items:
		# Older saves can hold seed packets from the farming days; drop them.
		if ItemDB.get_item(str(id)):
			items[str(id)] = int(saved_items[id])
	changed.emit()
