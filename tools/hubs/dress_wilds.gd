extends Node
## Lays the ground clutter of the hubs and areas outside the two towns
## (tools/hubs/wild_clutter_art.gd), so the forest floor between the
## landmarks isn't a bare sweep of sand: drifts of needles and cones under
## the lodgepoles, twigs and ferns under the Wawona pines, leaf litter and
## dry grass in the El Portal foothills, polished slabs and lichen on the
## granite, a log or a stump now and then, and at every campsite somebody's
## gear (no two sites alike). Each area gets
## scenes/regions/dressing/wild/<region>.tscn, which Region adds to its
## Entities as "WildDressing" when it loads, so no builder has to place
## these and a rebuild never loses them.
##
##   godot --headless --path . res://tools/hubs/dress_wilds.tscn -- [region ids]
##
## (tools/hubs/rebuild_wild_dressing.sh draws the art first.)
##
## What it never does: put anything on a road, trail, lot, bridge or paving;
## put a solid prop anywhere a person couldn't walk round it on every side
## (a solid prop needs open ground two tiles all round); or crowd a spot,
## door, sign, exit or story spot (nothing within SPOT_CLEAR of them). The
## layout is seeded, so a re-run gives the same scene.

const Terrain := preload("res://tools/mapgen/terrain.gd")
const WildArt := preload("res://tools/hubs/wild_clutter_art.gd")
const ART := "res://assets/sprites/clutter/"
const FLORA := "res://assets/sprites/ahwahnee/"
const OUT := "res://scenes/regions/dressing/wild/"
const TILE := 32
## Nothing within this many pixels of a named spot, door, exit or story spot.
const SPOT_CLEAR := 96.0
## Solid props keep a little further off.
const SOLID_CLEAR := 160.0
## No two things closer than this (pixels).
const SPACING := 40.0

## Region -> seed. The areas outside the towns, and Yosemite Village for
## Camp 4 and the woods round the village.
const REGIONS := {
	"tuolumne_meadows": 8600, "wawona": 1856, "el_portal": 1907, "glacier_point": 1872,
	"yosemite_village": 1940, "upper_pines": 1964, "housekeeping_camp": 1926,
	"el_capitan_meadow": 1958, "leidig_meadow": 1890, "four_mile_trailhead": 1872,
	"bridalveil_fall": 1851, "tunnel_view": 1933, "ahwahnee_meadow": 1927,
	"happy_isles": 1885, "mirror_lake": 1870, "tenaya_creek": 1852, "ahwahnee_trail": 1928,
	"lamon_homestead": 1859, "crows_camp": 1960,
}

## Terrain -> [chance a tile gets a flat thing, chance of an upright one,
## chance of a solid one], and what each draws from (repeats weight a pick).
const LOOKS := {
	Terrain.SUBALPINE: [0.07, 0.012, 0.004],
	Terrain.FOREST: [0.06, 0.016, 0.004],
	Terrain.FIR: [0.06, 0.01, 0.004],
	Terrain.FOOTHILL: [0.04, 0.03, 0.002],
	Terrain.SCRUB: [0.03, 0.01, 0.0],
	Terrain.GRANITE: [0.05, 0.0, 0.004],
	Terrain.MEADOW: [0.006, 0.012, 0.0],
	Terrain.WET_MEADOW: [0.0, 0.012, 0.0],
	Terrain.CAMP: [0.05, 0.0, 0.0],
	Terrain.SAND: [0.03, 0.0, 0.0],
}
const FLAT := {
	Terrain.SUBALPINE: ["wild_needles_a", "wild_needles_a", "wild_needles_b", "wild_cones", "wild_cones", "wild_twigs", "wild_slab_b", "wild_pebbles"],
	Terrain.FOREST: ["wild_needles_a", "wild_needles_b", "wild_cones", "wild_twigs", "wild_twigs", "wild_leaves", "wild_pebbles"],
	Terrain.FIR: ["wild_needles_a", "wild_needles_b", "wild_cones", "wild_cones", "wild_twigs", "wild_slab_b"],
	Terrain.FOOTHILL: ["wild_leaves", "wild_leaves", "wild_pebbles", "wild_twigs", "wild_lichen"],
	Terrain.SCRUB: ["wild_pebbles", "wild_twigs", "wild_lichen"],
	Terrain.GRANITE: ["wild_pebbles", "wild_lichen", "wild_lichen", "wild_slab_a", "wild_slab_b"],
	Terrain.MEADOW: ["wild_pebbles"],
	Terrain.CAMP: ["wild_needles_b", "wild_cones", "wild_pebbles", "wild_twigs"],
	Terrain.SAND: ["wild_pebbles", "wild_twigs"],
}
## Upright, not solid: [art dir, sprite].
const UPRIGHT := {
	Terrain.SUBALPINE: [["c", "wild_sedge"], ["c", "wild_seedling"], ["c", "wild_seedling"]],
	Terrain.FOREST: [["f", "plant_fern_a"], ["f", "plant_fern_b"], ["f", "plant_mushrooms"], ["c", "wild_seedling"], ["f", "plant_bracken"]],
	Terrain.FIR: [["c", "wild_seedling"], ["c", "wild_sedge"]],
	Terrain.FOOTHILL: [["c", "wild_dry_grass"], ["c", "wild_dry_grass"], ["c", "wild_dry_grass"], ["c", "wild_sedge"]],
	Terrain.SCRUB: [["c", "wild_dry_grass"]],
	Terrain.MEADOW: [["c", "wild_sedge"], ["f", "plant_wildflowers_a"], ["f", "plant_wildflowers_c"]],
	Terrain.WET_MEADOW: [["c", "wild_sedge"], ["f", "plant_cornlily"]],
}
## Solid: [art dir, sprite, footprint].
const SOLID := {
	Terrain.SUBALPINE: [["f", "log_fallen_a", Vector2(60, 14)], ["f", "log_fallen_b", Vector2(60, 14)], ["f", "log_stump", Vector2(24, 12)], ["f", "rock_granite_c", Vector2(36, 16)]],
	Terrain.FOREST: [["f", "log_fallen_a", Vector2(60, 14)], ["f", "log_stump", Vector2(24, 12)], ["f", "rock_mossy_a", Vector2(36, 16)], ["f", "rock_mossy_b", Vector2(36, 16)]],
	Terrain.FIR: [["f", "log_fallen_b", Vector2(60, 14)], ["f", "log_stump", Vector2(24, 12)], ["f", "rock_granite_d", Vector2(36, 16)]],
	Terrain.FOOTHILL: [["f", "rock_granite_a", Vector2(36, 16)], ["f", "log_stump", Vector2(24, 12)]],
	Terrain.GRANITE: [["f", "rock_granite_a", Vector2(36, 16)], ["f", "rock_granite_b", Vector2(36, 16)]],
}
## Ground nothing goes on, or next to.
const KEEP_OFF := [Terrain.ROAD, Terrain.TRAIL, Terrain.PARKING, Terrain.BRIDGE, Terrain.PAVED, Terrain.BUILT,
	Terrain.CLIFF, Terrain.TALUS, Terrain.SCREE, Terrain.RIVER, Terrain.LAKE, Terrain.CREEK, Terrain.FALLS, Terrain.LAWN]
## What a campsite might have out, beside its table. [sprite, footprint].
const CAMP_GEAR := [["camp_cooler", Vector2(28, 10)], ["camp_chair", Vector2(16, 8)], ["camp_lantern", Vector2(8, 6)],
	["camp_jug", Vector2(14, 8)], ["camp_stove", Vector2(22, 8)], ["camp_boots", Vector2(16, 6)],
	["camp_clothesline", Vector2(56, 6)], ["firewood", Vector2(30, 10)], ["camp_chair", Vector2(16, 8)]]
## Camp 4 is the climbers' camp: their tents have pads, ropes and haul bags out.
const CLIMBER_GEAR := [["camp_crashpad", Vector2(34, 10)], ["camp_rope", Vector2(22, 8)], ["camp_haulbag", Vector2(16, 8)],
	["camp_stove", Vector2(22, 8)], ["camp_jug", Vector2(14, 8)], ["camp_rope", Vector2(22, 8)], ["camp_chair", Vector2(16, 8)]]

var _region: Region
var _space: PhysicsDirectSpaceState2D
var _taken: Array[Vector2] = []
var _clear: Array[Vector2] = []
var _ground: TileMapLayer
var _rng := RandomNumberGenerator.new()
var _textures := {}


func _ready() -> void:
	var wanted := Array(OS.get_cmdline_user_args())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for region_id: String in REGIONS:
		if not wanted.is_empty() and region_id not in wanted:
			continue
		await _dress(region_id, REGIONS[region_id])
	get_tree().quit()


func _dress(region_id: String, seed_value: int) -> void:
	var path := "res://scenes/regions/%s.tscn" % region_id
	if not ResourceLoader.exists(path):
		push_warning("no region " + region_id)
		return
	_region = (load(path) as PackedScene).instantiate()
	add_child(_region)
	# Region adds the last layout as it loads; lay out afresh without it, so
	# a re-run gives the same scene
	var old := _region.entities.get_node_or_null("WildDressing")
	if old:
		old.free()
	var overlay_path := "res://scenes/story/content/%s.tscn" % region_id
	if ResourceLoader.exists(overlay_path):
		_region.entities.add_child((load(overlay_path) as PackedScene).instantiate())
	# let the bodies reach the physics space
	for i in 3:
		await get_tree().physics_frame
	_space = _region.get_world_2d().direct_space_state
	_ground = _region.get_ground()
	_rng.seed = seed_value
	_taken.clear()
	_clear = _spots()

	var root := Node2D.new()
	root.name = "WildDressing"
	root.y_sort_enabled = true
	var flat := Node2D.new()
	flat.name = "GroundDetail"
	flat.z_index = -8
	root.add_child(flat)
	flat.owner = root
	var counts := {"flat": 0, "upright": 0, "solid": 0, "camp": 0}
	counts.camp = _campsites(root)
	for cell in _ground.get_used_cells():
		var kind := _kind(cell)
		if not LOOKS.has(kind) or _near_keep_off(cell, 1):
			continue
		var odds: Array = LOOKS[kind]
		var roll := _rng.randf()
		var at := (Vector2(cell) + Vector2(_rng.randf_range(0.2, 0.8), _rng.randf_range(0.3, 0.9))) * TILE
		if roll < odds[2] and SOLID.has(kind):
			var pick: Array = SOLID[kind][_rng.randi() % SOLID[kind].size()]
			if _solid_fits(cell, at, pick[2]):
				_solid(root, pick[1], _dir(pick[0]), at, pick[2])
				counts.solid += 1
		elif roll < odds[2] + odds[1] and UPRIGHT.has(kind):
			var pick: Array = UPRIGHT[kind][_rng.randi() % UPRIGHT[kind].size()]
			if _open(at, Vector2(16, 8)) and _spaced(at, SPACING):
				_upright(root, pick[1], _dir(pick[0]), at)
				counts.upright += 1
		elif roll < odds[2] + odds[1] + odds[0] and FLAT.has(kind):
			var list: Array = FLAT[kind]
			var sprite: String = list[_rng.randi() % list.size()]
			if _open(at, Vector2(12, 6)) and _spaced(at, SPACING * 0.6):
				_flat(flat, sprite, at)
				counts.flat += 1
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, OUT + region_id + ".tscn") == OK)
	root.free()
	_region.queue_free()
	await get_tree().process_frame
	print("dressed %s: %d flat, %d upright, %d solid, %d camp gear" % [region_id, counts.flat, counts.upright, counts.solid, counts.camp])


## Every spot to keep clear: named spots, doors, exits, signs, climbs,
## stations, the people and their spots, and the story overlay's things.
func _spots() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for node in _region.find_children("*", "Node2D", true, false):
		if node is Marker2D or node is Area2D or node is NPC or node is Vendor or node is ClimbStart:
			out.append((node as Node2D).global_position)
		elif node.get_script() != null and node is StaticBody2D and not _is_scenery(node):
			# anything scripted (a sign, a station, a door, a tent) is something you use
			out.append((node as Node2D).global_position)
	return out


## Plain scenery: a tree, a rock, a building with no script of its own.
static func _is_scenery(node: Node) -> bool:
	var script := node.get_script() as Script
	return script != null and script.resource_path.ends_with("seasonal_sprite.gd")


func _kind(cell: Vector2i) -> int:
	if _ground.get_cell_source_id(cell) < 0:
		return -1
	return _ground.get_cell_atlas_coords(cell).y


func _near_keep_off(cell: Vector2i, reach: int) -> bool:
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var k := _kind(cell + Vector2i(dx, dy))
			if k < 0 or k in KEEP_OFF:
				return true
	return false


## Nothing solid or usable (trees, rocks, buildings, signs, exits) touches a
## box this size at [param at] (bottom centre), and it's clear of the spots.
func _open(at: Vector2, size: Vector2, clear := SPOT_CLEAR) -> bool:
	for spot in _clear:
		if spot.distance_to(at) < clear:
			return false
	var query := PhysicsShapeQueryParameters2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	query.shape = box
	query.transform = Transform2D(0.0, at - Vector2(0, size.y / 2.0))
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_areas = true
	return _space.intersect_shape(query, 1).is_empty()


func _spaced(at: Vector2, gap: float) -> bool:
	for other in _taken:
		if other.distance_to(at) < gap:
			return false
	return true


## A solid prop needs open, natural ground two tiles all round, and its box
## (fattened by a person's width either side) clear of everything else, so
## it never narrows a way through.
func _solid_fits(cell: Vector2i, at: Vector2, foot: Vector2) -> bool:
	if _near_keep_off(cell, 2):
		return false
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if not LOOKS.has(_kind(cell + Vector2i(dx, dy))):
				return false
	return _open(at, foot + Vector2(64, 40), SOLID_CLEAR) and _spaced(at, SPACING * 2.0)


func _dir(code: String) -> String:
	return ART if code == "c" else FLORA


func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]


func _name(root: Node, base: String) -> String:
	var i := 1
	while root.has_node(base.to_pascal_case() + str(i)):
		i += 1
	return base.to_pascal_case() + str(i)


func _flat(parent: Node2D, sprite_name: String, at: Vector2) -> void:
	var s := Sprite2D.new()
	s.name = _name(parent, sprite_name)
	s.texture = _texture(ART + sprite_name + ".png")
	s.position = at.round()
	s.flip_h = _rng.randf() < 0.5
	s.use_parent_material = true
	parent.add_child(s)
	s.owner = parent.owner if parent.owner else parent
	_taken.append(at)


func _upright(root: Node2D, sprite_name: String, dir: String, at: Vector2) -> void:
	var tex := _texture(dir + sprite_name + ".png")
	var s := Sprite2D.new()
	s.name = _name(root, sprite_name)
	s.texture = tex
	s.position = at.round()
	s.offset = Vector2(0, -tex.get_height() / 2.0 + 2)
	s.flip_h = _rng.randf() < 0.5
	root.add_child(s)
	s.owner = root
	_taken.append(at)


func _solid(root: Node2D, sprite_name: String, dir: String, at: Vector2, foot: Vector2) -> void:
	var tex := _texture(dir + sprite_name + ".png")
	var body := StaticBody2D.new()
	body.name = _name(root, sprite_name)
	body.position = at.round()
	body.collision_mask = 0
	root.add_child(body)
	body.owner = root
	var s := Sprite2D.new()
	s.name = "Sprite"
	s.texture = tex
	s.offset = Vector2(0, -tex.get_height() / 2.0 + 2)
	s.flip_h = _rng.randf() < 0.5
	body.add_child(s)
	s.owner = root
	var shape := CollisionShape2D.new()
	shape.name = "Collision"
	var box := RectangleShape2D.new()
	box.size = foot
	shape.shape = box
	shape.position = Vector2(0, -foot.y / 2.0)
	body.add_child(shape)
	shape.owner = root
	_taken.append(at)
	# so the next prop sees this one
	_clear.append(at)


## Gear beside each campsite's picnic table (or, at Camp 4, each tent): two
## or three things, picked so no two sites look alike, each where it touches
## nothing.
func _campsites(root: Node2D) -> int:
	var anchors: Array[Node2D] = []
	var climbers: Array[bool] = []
	for node in _region.entities.get_children():
		if node is Node2D and String(node.name).begins_with("Table"):
			anchors.append(node)
			climbers.append(false)
	# Camp 4's walk-in sites are SiteNTent... (build_yosemite_village.gd)
	var site := RegEx.create_from_string("^Site\\d+Tent")
	for node in _region.entities.get_children():
		if node is Node2D and site.search(String(node.name)) != null:
			anchors.append(node)
			climbers.append(true)
	var placed := 0
	for i in anchors.size():
		var anchor := anchors[i]
		var gear_list: Array = CLIMBER_GEAR if climbers[i] else CAMP_GEAR
		var wanted := 2 + (i % 2)
		var offsets := [Vector2(-52, -4), Vector2(54, -6), Vector2(-34, -34), Vector2(40, -36), Vector2(70, -22), Vector2(-70, -20)]
		if climbers[i]:
			# in front of a tent rather than up beside a table
			offsets = [Vector2(-44, 20), Vector2(46, 18), Vector2(-64, -2), Vector2(64, 0), Vector2(0, 34)]
		var start := (i * 5 + 3) % gear_list.size()
		var got := 0
		for k in gear_list.size():
			if got >= wanted:
				break
			var gear: Array = gear_list[(start + k * 4) % gear_list.size()]
			for o: Vector2 in offsets:
				var at := anchor.global_position + o
				var cell := _ground.local_to_map(_ground.to_local(at))
				# campsites are busy places: only keep clear of spots, things and paths
				if not _near_keep_off(cell, 0) and _open(at, gear[1] + Vector2(12, 12), 40.0) and _spaced(at, 30.0):
					_solid(root, gear[0], ART, at, gear[1])
					got += 1
					placed += 1
					break
	return placed
