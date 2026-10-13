extends HubBuilder
## Builds the Guardian's cave, the talus cave under the Royal Arches where
## the story ends (see STORY.md, "The lost Guardian"). One room, the size of
## the screen, with the looking-glass against its back wall. Run from the
## project folder:
##
##   godot --headless --path . res://tools/hubs/build_guardian_cave.tscn
##
## It rewrites scenes/regions/guardian_cave.tscn and the art in
## assets/sprites/cave/. The way in is the GuardianCaveMouth door in the
## Ahwahnee's story overlay (scenes/story/content/the_ahwahnee.tscn), which
## opens once Clark has sent you (the "lost_guardian" quest).

const CaveArt = preload("res://tools/hubs/cave_art.gd")
const C := "res://assets/sprites/cave/"
const SCENE := "res://scenes/regions/guardian_cave.tscn"
## Under the Royal Arches, behind the Ahwahnee.
const GEO := Vector2(-119.5712, 37.7482)
## Rows of rock at the back of the room.
const WALL_ROWS := 5


func _ready() -> void:
	print("== cave art")
	CaveArt.new().save_all()
	import_assets()
	print("== the Guardian's cave")
	_build()
	get_tree().quit()


func _build() -> void:
	init_grid(30, 17, Terrain.BUILT)
	fill(0, 0, 29, WALL_ROWS - 1, Terrain.CLIFF)
	fill(0, 16, 29, 16, Terrain.CLIFF)
	fill(0, WALL_ROWS, 0, 15, Terrain.CLIFF)
	fill(29, WALL_ROWS, 29, 15, Terrain.CLIFF)
	fill(14, 16, 15, 16, Terrain.BUILT)
	start_region("GuardianCave", "guardian_cave", "The Gap in the Talus", GEO, true)
	paint_ground()
	var room := Sprite2D.new()
	room.name = "Room"
	room.texture = texture(C + "cave_room.png")
	room.centered = false
	room.z_index = -8
	_root.add_child(room)

	var mirror := prop_body("GuardianMirror", C + "mirror.png", [base_rect(Vector2(30, 10))], Vector2(34, 22))
	mirror.set_script(load("res://scripts/story/guardian_mirror.gd"))
	mirror.position = Vector2(240, 96)
	_entities.add_child(mirror)

	for spot: Array in [["door", 240, 244], ["mirror", 240, 110], ["gathering", 240, 184]]:
		var m := Marker2D.new()
		m.name = spot[0]
		m.position = Vector2(spot[1], spot[2])
		_markers.add_child(m)
	region_exit("ToAhwahnee", Vector2(240, 268), Vector2(44, 10), "The Ahwahnee", "the_ahwahnee", "cave_mouth")
	place_blockers(false)
	pack(_root, SCENE)
