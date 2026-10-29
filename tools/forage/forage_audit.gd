extends Node
## Prints how much wild food each region grows per day, by season: which
## forage items can land there (its habitats), how many of each, and their
## energy raw and in the pot. For balancing forage against what quests, board
## notes and climbs ask for.
##   godot --headless --path . res://tools/forage/forage_audit.tscn

const REGIONS := "res://scenes/regions/"
const SEASONS := ["Spring", "Summer", "Fall", "Winter"]


func _ready() -> void:
	await get_tree().process_frame
	var totals := [{}, {}, {}, {}]
	for file in DirAccess.get_files_at(REGIONS):
		if not file.ends_with(".tscn"):
			continue
		var scene: PackedScene = load(REGIONS + file)
		var region := scene.instantiate()
		add_child(region)
		var spawner := _find_spawner(region)
		if spawner == null:
			region.free()
			continue
		var habitats := spawner.habitats()
		var line := PackedStringArray()
		for habitat in habitats:
			line.append("%s:%d" % [ItemData.Habitat.keys()[habitat], habitats[habitat].size()])
		print("\n== %s (x%.1f)  %s" % [file.get_basename(), spawner.amount_scale, " ".join(line)])
		for season in 4:
			var parts := PackedStringArray()
			var energy := 0
			for item in ItemDB.forage_items():
				if not item.is_forageable_in(season) or habitats.get(item.habitat, []).is_empty():
					continue
				var n: int = item.forage_count(season, spawner.amount_scale)
				parts.append("%s %d" % [item.id, n])
				energy += n * _best_energy(item.id)
				totals[season][item.id] = totals[season].get(item.id, 0) + n
			print("  %-6s %3d energy/day: %s" % [SEASONS[season], energy, ", ".join(parts)])
		region.free()
	print("\n== Whole park, a day in each region")
	for season in 4:
		var parts := PackedStringArray()
		for id: String in totals[season]:
			parts.append("%s %d" % [id, totals[season][id]])
		print("  %-6s %s" % [SEASONS[season], ", ".join(parts)])
	get_tree().quit()


## Energy raw, or in the pot if that's better (some forage must be cooked).
func _best_energy(id: String) -> int:
	return maxi(FoodDB.energy(id), int(Cooking.INGREDIENTS.get(id, {}).get("energy", 0)))


func _find_spawner(node: Node) -> ForageSpawner:
	if node is ForageSpawner:
		return node
	for child in node.get_children():
		var found := _find_spawner(child)
		if found:
			return found
	return null
