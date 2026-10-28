class_name HubBuilder
extends Node
## Shared parts for the builders of hand-made hubs (tools/hubs/build_*.gd):
## terrain painting, props with collision, buildings with a door, vendors,
## markers and exits, trees, and saving the scene. The Yosemite Village
## builder has its own copy of most of this; Curry Village and its shops use
## this one.

const Terrain = preload("res://tools/mapgen/terrain.gd")
const Art = preload("res://tools/mapgen/art.gd")
const TILESET := preload("res://assets/tiles/world_tileset.tres")
const T := 16

var w := 100
var h := 64
var kind := PackedInt32Array()
var no_trees := PackedByteArray()
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()

var _root: Region
var _entities: Node2D
var _markers: Node2D
var _places: Node2D
var _exits: Node2D
var _ground: TileMapLayer
var _blocker: TileMapLayer
var _flora: TileMapLayer
var _canopy: TileMapLayer


# ---------------------------------------------------------------- files

func import_assets() -> void:
	var output := []
	OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--import"], output, true)


func save_resource(res: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	assert(ResourceSaver.save(res, path) == OK, "Could not save " + path)
	res.take_over_path(path)


func texture(path: String) -> Texture2D:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)


func pack(root: Node, path: String) -> void:
	for child in root.get_children():
		_own(child, root)
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	save_resource(packed, path)
	root.free()


func _own(node: Node, owner: Node) -> void:
	node.owner = owner
	if node.scene_file_path != "":
		return
	for child in node.get_children():
		_own(child, owner)


# ---------------------------------------------------------------- terrain grid

func init_grid(width: int, height: int, fill: int) -> void:
	w = width
	h = height
	kind.resize(w * h)
	kind.fill(fill)
	no_trees.resize(w * h)
	no_trees.fill(0)


func put(x: int, y: int, type: int) -> void:
	if x >= 0 and y >= 0 and x < w and y < h:
		kind[y * w + x] = type


func at(x: int, y: int) -> int:
	return kind[clampi(y, 0, h - 1) * w + clampi(x, 0, w - 1)]


func fill(x0: int, y0: int, x1: int, y1: int, type: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			put(x, y, type)


func clear_trees(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(maxi(y0, 0), mini(y1, h - 1) + 1):
		for x in range(maxi(x0, 0), mini(x1, w - 1) + 1):
			no_trees[y * w + x] = 1


# ---------------------------------------------------------------- scene skeleton

func start_region(node_name: String, region_id: String, display_name: String, geo_anchor: Vector2, indoors := false) -> void:
	_root = Region.new()
	_root.name = node_name
	_root.y_sort_enabled = true
	_root.region_id = region_id
	_root.hub_id = "yosemite_valley"
	_root.display_name = display_name
	_root.geo_anchor = geo_anchor
	_root.indoors = indoors
	_ground = layer("Ground")
	_ground.z_index = -10
	_blocker = layer("Blocker")
	_blocker.visible = false
	_flora = layer("Flora")
	_flora.y_sort_enabled = true
	_canopy = layer("OakCanopy")
	_canopy.y_sort_enabled = true
	_canopy.set_script(load("res://scripts/world/seasonal_canopy.gd"))
	for l in [_ground, _blocker, _flora, _canopy]:
		_root.add_child(l)
	_entities = group("Entities", true)
	_markers = group("Markers")
	_places = group("Places")
	_exits = group("Exits")


func layer(layer_name: String) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = layer_name
	l.tile_set = TILESET
	return l


func group(group_name: String, y_sort := false) -> Node2D:
	var node := Node2D.new()
	node.name = group_name
	node.y_sort_enabled = y_sort
	_root.add_child(node)
	return node


func paint_ground() -> void:
	for y in h:
		for x in w:
			_ground.set_cell(Vector2i(x, y), Art.SOURCE_TERRAIN, Vector2i((x * 7 + y * 13 + (x * y) % 5) % Art.VARIANTS, kind[y * w + x]))


## Puts a painted picture over the tile ground (which stays underneath, hidden,
## for foraging and the map's data).
func add_ground_painting(path: String) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "GroundPainting"
	sprite.texture = texture(path)
	sprite.centered = false
	sprite.z_index = -9
	_root.add_child(sprite)
	_root.move_child(sprite, 1)
	_ground.visible = false


func tile_pos(x: float, y: float) -> Vector2:
	return Vector2(x * T + T / 2.0, y * T + T / 2.0)


## The point at the bottom center of tile (x, y): where a prop stands.
func foot(x: float, y: float) -> Vector2:
	return Vector2(x * T + T / 2.0, (y + 1.0) * T)


# ---------------------------------------------------------------- props

func _footprint_shape(body: StaticBody2D, shape_name: String, rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	shape.name = shape_name
	var r := RectangleShape2D.new()
	r.size = rect.size
	shape.shape = r
	shape.position = rect.position + rect.size / 2.0
	body.add_child(shape)


func _hitbox(body: Node2D, size: Vector2, offset := Vector2.ZERO) -> void:
	var area := Area2D.new()
	area.name = "Hitbox"
	area.collision_layer = 4
	area.collision_mask = 0
	area.monitoring = false
	var hit := CollisionShape2D.new()
	hit.name = "Shape"
	var r := RectangleShape2D.new()
	r.size = size
	hit.shape = r
	hit.position = Vector2(0, -size.y / 2.0) + offset
	area.add_child(hit)
	body.add_child(area)


## A static prop standing on its base. [param footprints] are rectangles in
## the prop's own space (origin at the bottom center; y is negative upward).
func prop_body(prop_name: String, tex_path: String, footprints: Array, hitbox := Vector2.ZERO) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = prop_name
	body.collision_mask = 0
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture(tex_path)
	sprite.offset = Vector2(0, -sprite.texture.get_height() / 2.0)
	body.add_child(sprite)
	for i in footprints.size():
		_footprint_shape(body, "Collision" if i == 0 else "Collision%d" % i, footprints[i])
	if hitbox.x > 0:
		_hitbox(body, hitbox)
	return body


## A rectangle centered on the base, [param size] wide and deep.
func base_rect(size: Vector2) -> Rect2:
	return Rect2(Vector2(-size.x / 2.0, -size.y), size)


func decor(prop_name: String, tex_path: String, at_pos: Vector2, footprint := Vector2.ZERO) -> StaticBody2D:
	var body := prop_body(prop_name, tex_path, [base_rect(footprint)] if footprint.x > 0 else [])
	body.position = at_pos
	_entities.add_child(body)
	return body


## Makes a prop's sprite play its sheet's [param frames] side-by-side frames.
func animate(body: Node, frames: int, fps: float) -> void:
	var sprite := body.get_node("Sprite") as Sprite2D
	sprite.hframes = frames
	sprite.set_script(load("res://scripts/world/frame_cycle.gd"))
	sprite.set("fps", fps)


## A glow that comes up after dark (see scripts/world/night_light.gd).
func night_light(parent: Node2D, at_pos: Vector2, radius: float, strength := 1.0, flicker := 0.0) -> void:
	var light := PointLight2D.new()
	light.name = "NightLight"
	light.set_script(load("res://scripts/world/night_light.gd"))
	light.position = at_pos
	light.set("radius", radius)
	light.set("strength", strength)
	light.set("flicker", flicker)
	parent.add_child(light)


## Smoke, mist, sparks or fireflies (see scripts/world/ambient_fx.gd).
func ambient(parent: Node2D, effect_name: String, at_pos: Vector2, area := Vector2(2, 1)) -> void:
	var fx := CPUParticles2D.new()
	fx.name = "Fx_" + effect_name
	fx.set_script(load("res://scripts/world/ambient_fx.gd"))
	fx.position = at_pos
	fx.set("effect", effect_name)
	fx.set("area", area)
	parent.add_child(fx)


## A decoration that hangs above everyone (string lights, banners).
func overhead(prop_name: String, tex_path: String, at_pos: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = prop_name
	sprite.texture = texture(tex_path)
	sprite.offset = Vector2(0, -sprite.texture.get_height() / 2.0)
	sprite.position = at_pos
	sprite.z_index = 6
	_entities.add_child(sprite)
	return sprite


## A prop you can read: interact to see its title and text.
func sign_prop(prop_name: String, tex_path: String, at_pos: Vector2, footprint: Vector2, title: String, text: String, script_path := "res://scripts/objects/info_sign.gd") -> StaticBody2D:
	var body := prop_body(prop_name, tex_path, [base_rect(footprint)], Vector2(footprint.x + 6, footprint.y + 10))
	body.set_script(load(script_path))
	body.set("title", title)
	body.set("text", text)
	body.position = at_pos
	_entities.add_child(body)
	return body


## A building sitting on tile row [param base_y], centered on [param tile_x].
## Its wall is solid except for a doorway of [param door_w] pixels at
## [param door_dx] from the center (pass door_w = 0 for a solid wall).
## Interacting at the front reads its sign.
func building(prop_name: String, tex_path: String, tile_x: float, base_y: int, title: String, text: String, door_w := 0, door_dx := 0, wall_frac := 0.36) -> StaticBody2D:
	var tex := texture(tex_path)
	var bw := tex.get_width() - 6
	var bh := tex.get_height() * wall_frac
	var feet: Array = []
	if door_w <= 0:
		feet = [base_rect(Vector2(bw, bh))]
	else:
		var left_end := door_dx - door_w / 2.0
		var right_start := door_dx + door_w / 2.0
		feet.append(Rect2(Vector2(-bw / 2.0, -bh), Vector2(left_end + bw / 2.0, bh)))
		feet.append(Rect2(Vector2(right_start, -bh), Vector2(bw / 2.0 - right_start, bh)))
	var body := prop_body(prop_name, tex_path, feet, Vector2(bw + 6, bh + 10))
	body.set_script(load("res://scripts/objects/info_sign.gd"))
	body.set("title", title)
	body.set("text", text)
	body.position = Vector2(tile_x * T + T / 2.0, base_y * T)
	_entities.add_child(body)
	return body


func instance_scene(path: String, at_pos: Vector2, node_name: String) -> Node2D:
	var node: Node2D = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	node.name = node_name
	node.position = at_pos
	_entities.add_child(node)
	return node


## A trader or shopkeeper. [param sheet] is a 48x96 character sheet (see
## tools/npcgen); empty draws the plain placeholder figure.
func vendor(node_name: String, shop_path: String, at_pos: Vector2, color: Color, sheet := "", reach := Vector2(36, 44), reach_offset := Vector2(0, 30)) -> StaticBody2D:
	var v := StaticBody2D.new()
	v.name = node_name
	v.collision_mask = 0
	v.set_script(load("res://scripts/shop/vendor.gd"))
	v.set("shop", load(shop_path))
	v.set("color", color)
	if sheet != "":
		v.set("sprite_sheet", texture(sheet))
	v.position = at_pos
	_footprint_shape(v, "Collision", Rect2(-4, -4, 8, 4))
	_hitbox(v, reach, reach_offset)
	_entities.add_child(v)
	return v


func shuttle(node_name: String, stop: String, at_pos: Vector2) -> void:
	var node := instance_scene("res://scenes/objects/shuttle_stop.tscn", at_pos, node_name)
	node.set("stop_name", stop)


func marker(marker_name: String, x: float, y: float) -> void:
	var m := Marker2D.new()
	m.name = marker_name
	m.position = tile_pos(x, y)
	_markers.add_child(m)


func place(place_name: String, x: float, y: float, radius_tiles: float, label := true) -> void:
	var p := Marker2D.new()
	p.set_script(load("res://scripts/world/place.gd"))
	p.name = place_name.replace(" ", "").replace("'", "")
	p.position = tile_pos(x, y)
	p.set("display_name", place_name)
	p.set("radius", radius_tiles * T)
	p.set("show_on_map", label)
	_places.add_child(p)


## Walking into this area leaves for another region.
func region_exit(exit_name: String, at_pos: Vector2, size: Vector2, label: String, target_region: String, target_spawn: String) -> Area2D:
	var area := Area2D.new()
	area.set_script(load("res://scripts/world/region_exit.gd"))
	area.name = exit_name
	area.position = at_pos
	area.set("label", label)
	area.set("target_region", target_region)
	area.set("target_spawn", target_spawn)
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var r := RectangleShape2D.new()
	r.size = size
	shape.shape = r
	area.add_child(shape)
	_exits.add_child(area)
	return area


# ---------------------------------------------------------------- trees and walls

func place_trees(options_by_kind: Dictionary, density_by_kind: Dictionary, reserve_pad := Vector2i(3, 2)) -> void:
	var F := Terrain.Flora
	var reserved := {}
	for child in _entities.get_children():
		if child is Node2D:
			var cell := Vector2i((child as Node2D).position / T)
			for dy in range(-reserve_pad.y - 2, 2):
				for dx in range(-reserve_pad.x, reserve_pad.x + 1):
					reserved[cell + Vector2i(dx, dy)] = true
	for y in h:
		for x in w:
			var k := y * w + x
			if no_trees[k] or reserved.has(Vector2i(x, y)):
				continue
			var t := kind[k]
			if not options_by_kind.has(t):
				continue
			var options: Array = options_by_kind[t]
			var density: float = density_by_kind.get(t, 0.1)
			if rng.randf() > density * (0.6 + noise.get_noise_2d(x, y)):
				continue
			var total := 0.0
			for o: Array in options:
				total += o[1]
			var roll := rng.randf() * total
			var pick: int = options[-1][0]
			for o: Array in options:
				roll -= o[1]
				if roll <= 0.0:
					pick = o[0]
					break
			_flora.set_cell(Vector2i(x, y), Art.SOURCE_FLORA, Terrain.frame_coords(pick))
			if pick == F.BLACK_OAK_TRUNK:
				_canopy.set_cell(Vector2i(x, y), Art.SOURCE_FLORA, Terrain.frame_coords(F.BLACK_OAK_CANOPY))


## Walls where unwalkable ground meets walkable ground, and a ring around the
## map.
func place_blockers(ring := true) -> void:
	for y in range(-1, h + 1):
		for x in range(-1, w + 1):
			var inside := x >= 0 and y >= 0 and x < w and y < h
			if inside and not Terrain.is_solid(kind[y * w + x]):
				continue
			if not inside and not ring:
				continue
			var touches := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx >= 0 and ny >= 0 and nx < w and ny < h and not Terrain.is_solid(kind[ny * w + nx]):
						touches = true
			if touches:
				_blocker.set_cell(Vector2i(x, y), Art.SOURCE_BLOCKER, Vector2i.ZERO)


func add_forage(region_id: String, amount_scale: float) -> void:
	var forage := Node2D.new()
	forage.name = "Forage_" + region_id
	forage.y_sort_enabled = true
	forage.set_script(load("res://scripts/world/forage_spawner.gd"))
	_entities.add_child(forage)
	forage.set("ground", _ground)
	forage.set("flora", _flora)
	forage.set("oak_canopy", _canopy)
	forage.set("amount_scale", amount_scale)
