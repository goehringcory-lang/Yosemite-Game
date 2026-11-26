extends Node
## The Valley floor's river crossings (tools/seams/river_crossings.py): each
## footbridge and ford lies over the Merced, the player can walk across it
## from the area's arrival, and the far bank it opens up is reachable, with
## its named spot (Place) and its hidden find on it.
## Run: godot --headless --path . res://tests/valley_floor_test.tscn
## Exit code is the number of failed checks.

const WalkCheck := preload("res://scripts/story/find_walk.gd")
const BRIDGE := 18
const CREEK := 13

## Keep in step with CROSSINGS in tools/seams/river_crossings.py.
## [area, kind, x0, y0, x1, y1] in tiles, plus the far bank's Place.
const CROSSINGS := [
	["housekeeping_camp", "bridge", 22, 30, 23, 32, "Housekeeping Beach"],
	["upper_pines", "bridge", 27, 43, 28, 45, "Pines Gravel Bar"],
	["four_mile_trailhead", "ford", 46, 30, 47, 32, "Sentinel Shallows"],
	["leidig_meadow", "ford", 24, 30, 25, 33, "Devil's Elbow"],
]

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	NewGame.reset()
	var walker := WalkCheck.new()
	for c: Array in CROSSINGS:
		var area: String = c[0]
		var region: Region = (load("res://scenes/regions/%s.tscn" % area) as PackedScene).instantiate()
		add_child(region)
		StoryContent.attach(region)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var ground := region.get_ground()
		var blocker := region.get_node("Blocker") as TileMapLayer
		var terrain := BRIDGE if c[1] == "bridge" else CREEK
		var laid := true
		for y in range(c[3], c[5] + 1):
			for x in range(c[2], c[4] + 1):
				var cell := Vector2i(x, y)
				if ground.get_cell_atlas_coords(cell).y != terrain or blocker.get_cell_source_id(cell) != -1:
					laid = false
		check(laid, "%s: the %s's tiles are %s and unblocked" % [area, c[1], "bridge" if terrain == BRIDGE else "creek"])
		var walked := walker.walk(region, WalkCheck.start_of(region).global_position)
		var x_mid: float = (int(c[2]) + int(c[4]) + 1) * 16.0
		var near := Vector2(x_mid, int(c[3]) * 32.0 - 24.0)
		var far := Vector2(x_mid, (int(c[5]) + 1) * 32.0 + 24.0)
		check(WalkCheck.reaches(walked, near, 40.0) and WalkCheck.reaches(walked, far, 40.0),
			"%s: you can walk from the arrival to both ends of the %s" % [area, c[1]])
		var place: Place = null
		for p in region.find_children("*", "Place", true, false):
			if (p as Place).display_name == c[6]:
				place = p
		check(place != null, "%s: the far bank is named %s" % [area, c[6]])
		if place:
			check(place.position.y > far.y - 48.0, "%s: %s lies past the river" % [area, c[6]])
			check(WalkCheck.reaches(walked, place.position, 64.0), "%s: %s can be walked to" % [area, c[6]])
		var finds := 0
		for find: Dictionary in Finds.all():
			if find.region == area and str(find.id).begins_with("floor_") and float(find.pos[1]) > far.y - 48.0:
				finds += 1
		check(finds >= 1, "%s: something is hidden on the far bank (%d)" % [area, finds])
		remove_child(region)
		region.free()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)
