extends SceneTree
## Lays the town clutter (assets/sprites/clutter/, drawn by
## town_clutter_art.gd) about Curry Village and Yosemite Village, so their
## plazas, shop fronts and lawns look lived in: suitcases on the
## Registration porch, an ice chest and firewood at the stores, a mailbox at
## the post office, picnic tables and flower beds on the lawns, trash cans
## along the walks, and the patches of lawn worn bare where people cut
## across. Each town gets scenes/regions/dressing/<town>.tscn, a y-sorted
## node the town scene instances in its Entities, so the town's builder
## never has to place these itself.
##
##   godot --headless --path . -s res://tools/hubs/dress_towns.gd
##
## Positions are in world pixels, at the prop's foot (bottom centre).
## Footprints are the solid base, wide x deep; none walks through.

const ART := "res://assets/sprites/clutter/"
const OUT := "res://scenes/regions/dressing/"

## [sprite, x, y, footprint] (footprint ZERO: not solid).
const TOWNS := {
	"curry_village": [
		# the Registration porch: luggage waiting, and the morning paper
		["suitcases", 1052, 1140, Vector2(28, 8)],
		["newspaper_rack", 1166, 1140, Vector2(14, 6)],
		# between the Registration Office and the Pavilion: the kitchen's deliveries
		["milk_cans", 1290, 1118, Vector2(26, 8)],
		["barrel", 1326, 1116, Vector2(20, 8)],
		["crate", 1350, 1122, Vector2(22, 8)],
		# the Pavilion's menu, and a can by its steps
		["sandwich_board", 1566, 1150, Vector2(18, 6)],
		["trash_can", 1398, 1152, Vector2(16, 8)],
		# the Camp Curry Store: ice and firewood by the door
		["ice_chest", 1758, 1144, Vector2(34, 10)],
		["firewood", 1866, 1142, Vector2(30, 10)],
		# a bicycle between the store and the Mountain Shop
		["bicycle", 1990, 1148, Vector2(30, 6)],
		# the Mountain Shop's deliveries, round its east side
		["crate_stack", 2244, 1134, Vector2(38, 10)],
		["crate", 2276, 1150, Vector2(22, 8)],
		["wheelbarrow", 2330, 1150, Vector2(30, 8)],
		# trash cans along the walks
		["trash_can", 1252, 1438, Vector2(16, 8)],
		["trash_can", 2148, 1438, Vector2(16, 8)],
		["trash_can", 1382, 1570, Vector2(16, 8)],
		# the Pizza Deck's back door: flour and cheese come in crates
		["crate", 1172, 1596, Vector2(22, 8)],
		["barrel", 1200, 1602, Vector2(20, 8)],
		# picnic tables on the green, west and east
		["picnic_table", 1100, 1466, Vector2(54, 12)],
		["picnic_table", 2380, 1424, Vector2(54, 12)],
		# flower beds at the green's corners
		["flower_bed_0", 1150, 1372, Vector2(62, 10)],
		["flower_bed_2", 2010, 1478, Vector2(62, 10)],
		# worn lawn where people cut across to the fire and the amphitheater
		["worn_patch_a", 1476, 1338, Vector2.ZERO],
		["worn_patch_b", 1736, 1372, Vector2.ZERO],
		["worn_patch_a", 1960, 1396, Vector2.ZERO],
		["worn_patch_b", 1232, 1500, Vector2.ZERO],
	],
	"yosemite_village": [
		# the Welcome Center's paper box and the post office's mailbox
		["newspaper_rack", 1716, 748, Vector2(14, 6)],
		["mailbox", 2664, 748, Vector2(16, 6)],
		# trash cans along the mall
		["trash_can", 1850, 806, Vector2(16, 8)],
		["trash_can", 2652, 806, Vector2(16, 8)],
		["trash_can", 2160, 1094, Vector2(16, 8)],
		# Degnan's: the day's bread chalked up out front
		["sandwich_board", 2444, 1058, Vector2(18, 6)],
		# the Village Store: firewood, ice, a barrel and its deliveries
		["firewood", 2760, 1068, Vector2(30, 10)],
		["ice_chest", 3010, 1072, Vector2(34, 10)],
		["barrel", 2732, 1112, Vector2(20, 8)],
		["crate_stack", 3086, 1036, Vector2(38, 10)],
		["milk_cans", 3060, 1062, Vector2(26, 8)],
		# a picnic table and flower beds on the lawns
		["picnic_table", 2480, 1024, Vector2(54, 12)],
		["flower_bed_1", 1780, 852, Vector2(62, 10)],
		["flower_bed_0", 2530, 852, Vector2(62, 10)],
		# worn lawn where people cut the corner
		["worn_patch_a", 2240, 1000, Vector2.ZERO],
		["worn_patch_b", 2960, 862, Vector2.ZERO],
	],
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for town: String in TOWNS:
		var root := Node2D.new()
		root.name = "Dressing"
		root.y_sort_enabled = true
		var counts := {}
		for spec: Array in TOWNS[town]:
			var sprite_name: String = spec[0]
			counts[sprite_name] = counts.get(sprite_name, 0) + 1
			var node_name := "%s%d" % [sprite_name.to_pascal_case(), counts[sprite_name]]
			_place(root, node_name, sprite_name, Vector2(spec[1], spec[2]), spec[3])
		var packed := PackedScene.new()
		assert(packed.pack(root) == OK)
		assert(ResourceSaver.save(packed, OUT + town + ".tscn") == OK)
		root.free()
		print("dressed ", town)
	quit()


func _place(root: Node2D, node_name: String, sprite_name: String, at: Vector2, footprint: Vector2) -> void:
	var tex: Texture2D = load(ART + sprite_name + ".png")
	if footprint == Vector2.ZERO:
		# A patch of ground: it sorts at the top of the map, so it lies under
		# everyone, with the picture moved down to where it belongs.
		var decal := Sprite2D.new()
		decal.name = node_name
		decal.texture = tex
		decal.position = Vector2(at.x, 0)
		decal.offset = Vector2(0, at.y - tex.get_height() / 2.0)
		root.add_child(decal)
		decal.owner = root
		return
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = at
	body.collision_mask = 0
	root.add_child(body)
	body.owner = root
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = tex
	sprite.offset = Vector2(0, -tex.get_height() / 2.0)
	body.add_child(sprite)
	sprite.owner = root
	var shape := CollisionShape2D.new()
	shape.name = "Collision"
	var box := RectangleShape2D.new()
	box.size = footprint
	shape.shape = box
	shape.position = Vector2(0, -footprint.y / 2.0)
	body.add_child(shape)
	shape.owner = root
