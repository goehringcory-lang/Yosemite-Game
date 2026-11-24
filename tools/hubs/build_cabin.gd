extends SceneTree
## Writes your cabin's room (scenes/regions/guardian_cabin.tscn) and its
## front door at the homestead (scenes/story/doors/lamon_homestead.tscn).
## The room scene only holds the walls' tiles, the spots and the way out:
## CabinRoom draws the room and Camp.dress furnishes it, so it can change as
## keepers fix the cabin up. Run it again after moving the cabin (Cabin.POS)
## or changing the room's size (CabinRoom):
##
##   godot --headless --path . -s res://tools/hubs/build_cabin.gd

const Terrain = preload("res://scripts/world/terrain.gd")
const Art = preload("res://tools/mapgen/art.gd")
const TILESET := preload("res://assets/tiles/world_tileset.tres")
const ROOM_PATH := "res://scenes/regions/guardian_cabin.tscn"
const DOORS_PATH := "res://scenes/story/doors/lamon_homestead.tscn"
const HOMESTEAD_GEO := Vector2(-119.5676, 37.7356)


func _initialize() -> void:
	_build_room()
	_build_door()
	print("cabin built")
	quit()


func _solid(x: int, y: int) -> bool:
	var w := CabinRoom.W
	var h := CabinRoom.H
	if y <= 2 or x == 0 or x == w - 1:
		return true
	if y == h - 1:
		# the front door's gap
		return not (x * CabinRoom.T >= int(CabinRoom.DOOR_X.x) and x * CabinRoom.T < int(CabinRoom.DOOR_X.y))
	if x * CabinRoom.T == int(CabinRoom.DOORWAY.position.x):
		# the east wall, with the way through to the kitchen
		var top := int(CabinRoom.DOORWAY.position.y) / CabinRoom.T
		var bottom := int(CabinRoom.DOORWAY.end.y) / CabinRoom.T
		return not (y >= top and y < bottom)
	return false


func _build_room() -> void:
	var root := Region.new()
	root.name = "GuardianCabin"
	root.y_sort_enabled = true
	root.region_id = Cabin.ROOM_REGION
	root.hub_id = "yosemite_valley"
	root.display_name = "Your cabin"
	root.geo_anchor = HOMESTEAD_GEO
	root.indoors = true
	var ground := _layer("Ground")
	ground.z_index = -10
	# CabinRoom draws the floor and walls; the tiles are only for the map's data
	ground.visible = false
	var blocker := _layer("Blocker")
	blocker.visible = false
	root.add_child(ground)
	root.add_child(blocker)
	for y in CabinRoom.H:
		for x in CabinRoom.W:
			var solid := _solid(x, y)
			var kind := Terrain.CLIFF if solid else Terrain.BUILT
			ground.set_cell(Vector2i(x, y), Art.SOURCE_TERRAIN, Vector2i((x * 7 + y * 13 + (x * y) % 5) % Art.VARIANTS, kind))
			if solid:
				blocker.set_cell(Vector2i(x, y), Art.SOURCE_BLOCKER, Vector2i.ZERO)
	var entities := _group(root, "Entities", true)
	entities.name = "Entities"
	var markers := _group(root, "Markers")
	var door_x: float = (CabinRoom.DOOR_X.x + CabinRoom.DOOR_X.y) / 2.0
	_marker(markers, "door", Vector2(door_x, 320))
	var bed := Vector2.ZERO
	for part: Dictionary in preload("res://scripts/story/guardian_camp.gd").CABIN:
		if part.id == "rope_bed":
			bed = part.pos
	_marker(markers, CabinRoom.BED_SPOT, bed + Vector2(56, 24))
	var exits := _group(root, "Exits")
	var exit := Area2D.new()
	exit.set_script(load("res://scripts/world/region_exit.gd"))
	exit.name = "ToOutside"
	exit.position = Vector2(door_x, CabinRoom.H * CabinRoom.T - 8)
	exit.set("label", "Lamon Homestead")
	exit.set("target_region", "lamon_homestead")
	exit.set("target_spawn", "guardian_cabin_door")
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(CabinRoom.DOOR_X.y - CabinRoom.DOOR_X.x, 16)
	shape.shape = rect
	exit.add_child(shape)
	exits.add_child(exit)
	# beyond the walls, darkness
	var dark := Polygon2D.new()
	dark.name = "Dark"
	dark.color = Color("0e0b0a")
	dark.z_index = -12
	dark.polygon = PackedVector2Array([Vector2(-1200, -1200), Vector2(2000, -1200), Vector2(2000, 1600), Vector2(-1200, 1600)])
	root.add_child(dark)
	_save(root, ROOM_PATH)


func _build_door() -> void:
	var root := Node2D.new()
	root.name = "LamonHomesteadDoors"
	var door := StaticBody2D.new()
	door.set_script(load("res://scripts/objects/building_door.gd"))
	door.name = "DoorToGuardianCabin"
	door.position = Cabin.POS + Vector2(0, 2)
	door.collision_layer = 0
	door.collision_mask = 0
	door.set("label", "Your cabin")
	door.set("target_region", Cabin.ROOM_REGION)
	door.set("target_spawn", "door")
	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 4
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 44)
	shape.shape = rect
	shape.position = Vector2(0, -20)
	hitbox.add_child(shape)
	door.add_child(hitbox)
	root.add_child(door)
	var spot := Marker2D.new()
	spot.name = "guardian_cabin_door"
	spot.position = Cabin.POS + Vector2(0, 40)
	root.add_child(spot)
	_save(root, DOORS_PATH)


func _layer(layer_name: String) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = layer_name
	l.tile_set = TILESET
	return l


func _group(root: Node, group_name: String, y_sort := false) -> Node2D:
	var node := Node2D.new()
	node.name = group_name
	node.y_sort_enabled = y_sort
	root.add_child(node)
	return node


func _marker(parent: Node, marker_name: String, at: Vector2) -> void:
	var m := Marker2D.new()
	m.name = marker_name
	m.position = at
	parent.add_child(m)


func _save(root: Node, path: String) -> void:
	for child in root.find_children("*", "", true, false):
		child.owner = root
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, path) == OK)
	root.free()
