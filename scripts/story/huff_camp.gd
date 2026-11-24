class_name HuffCamp
extends RefCounted
## HUFF: the small seasonal-employee tent community tucked in the pines just
## behind Curry Village's east cabin rows and north of the Lamon Orchard.
##
## StoryContent.attach() calls dress() when Curry Village first loads, so it
## needs no edits to the generated curry_village.tscn scene and survives map
## rebuilds.

const NPC_SCENE := preload("res://scenes/story/npc.tscn")
const NIGHT_LIGHT := preload("res://scripts/world/night_light.gd")
const CS := "res://assets/sprites/curry/"
const B := "res://assets/sprites/buildings/"
const LAMP_TEX := "res://assets/sprites/ahwahnee/lamp_wrought.png"

## Center of HUFF in Curry Village's 32px world pixels.
const CENTER := Vector2(2916.0, 616.0)
## Clearing bounds to clear overlapping forest clutter, plus entry approaches
## from Curry Village's east cabin path and the Lamon Orchard.
const CLEARING := Rect2(2710.0, 456.0, 424.0, 336.0)
const WEST_APPROACH := Rect2(2560.0, 562.0, 168.0, 124.0)
const SOUTH_APPROACH := Rect2(2836.0, 760.0, 128.0, 96.0)

const SIGN_TEXT := "HUFF — Curry Village employee tent housing. Tucked in the pines behind the guest rows, where cooks, housekeepers, dishwashers and pool staff bunk down in canvas tents for the season. Laundry on the line, coolers chained to the bear box, and somebody always has a speaker."
const BEAR_BOX_TEXT := "HUFF employee bear box. Packed tight with ramen, tortillas, hot sauce, and a six-pack of King Cobra with someone's initials written on every can in Sharpie."


## Builds HUFF in [param region] if it is Curry Village. Safe to call once.
static func dress(region: Region) -> void:
	if region.region_id != "curry_village" or region.has_meta("huff_dressed"):
		return
	region.set_meta("huff_dressed", true)
	_clear_patch(region)
	_place_place(region)
	_place_tents(region)
	_place_props(region)
	_place_residents(region)


## Removes overlapping generated trees, shrubs, ferns, rocks and logs inside
## HUFF's clearing and entry walkways while leaving the surrounding pines intact.
static func _clear_patch(region: Region) -> void:
	var keep_prefixes := ["Cabin", "AppleTree", "OrchardFence", "PathLamp", "TentCabin"]
	for child in region.entities.get_children():
		if not child is Node2D:
			continue
		var pos := (child as Node2D).position
		if not (CLEARING.has_point(pos) or WEST_APPROACH.has_point(pos) or SOUTH_APPROACH.has_point(pos)):
			continue
		var n := String(child.name)
		var keep := false
		for prefix: String in keep_prefixes:
			if n.begins_with(prefix):
				keep = true
				break
		if keep:
			continue
		if n.begins_with("Tree") or n.begins_with("Plant") or n.begins_with("Rock") or n.begins_with("Log"):
			child.get_parent().remove_child(child)
			child.free()


## Adds the "HUFF" Place node so the location banner names it and Discoveries
## can log it.
static func _place_place(region: Region) -> void:
	var parent := region.get_node_or_null("Places")
	if parent == null:
		parent = region
	var place := Place.new()
	place.name = "HUFF"
	place.display_name = "HUFF"
	place.position = CENTER
	place.radius = 190.0
	place.show_banner = true
	place.show_on_map = false
	parent.add_child(place)
	# Named marker so scripts, tests and travel can find HUFF directly.
	var markers := region.get_node_or_null("Markers")
	if markers == null:
		markers = region.entities
	var mark := Marker2D.new()
	mark.name = "huff"
	mark.position = Vector2(2892.0, 628.0)
	markers.add_child(mark)


## Six employee tents: four canvas tent cabins and two personal dome tents
## ringed around a small shared clearing.
static func _place_tents(region: Region) -> void:
	var cabins := [
		["HuffTentCabin0", CS + "tent_cabin_7.png", Vector2(2796, 528)],
		["HuffTentCabin1", CS + "tent_cabin_19.png", Vector2(2924, 514)],
		["HuffTentCabin2", CS + "tent_cabin_31.png", Vector2(3052, 532)],
		["HuffTentCabin3", CS + "tent_cabin_44.png", Vector2(2814, 738)],
	]
	for c: Array in cabins:
		var body := _prop_body(c[0], c[1], c[2], Vector2(60, 18), Vector2(0, -9))
		_add_light(body, Vector2(0, -40), 52.0, 0.7)
		region.entities.add_child(body)
	var domes := [
		["HuffTentDome0", B + "camp4_tent_dome_1.png", Vector2(3070, 646)],
		["HuffTentDome1", B + "camp4_tent_dome_3.png", Vector2(3032, 742)],
	]
	for d: Array in domes:
		var body := _prop_body(d[0], d[1], d[2], Vector2(46, 16), Vector2(0, -8))
		_add_light(body, Vector2(0, -24), 44.0, 0.65)
		region.entities.add_child(body)


## Community signpost, employee bear box, clothesline, cooler, bike rack, table,
## camp chairs, woodpile and a warm lamp post.
static func _place_props(region: Region) -> void:
	# Entrance signpost with dynamic after-10PM party area hint.
	var sign_body := _prop_body("HuffSign", CS + "trail_post.png", Vector2(2738, 624), Vector2(16, 8), Vector2(0, -4))
	sign_body.set_script(HuffSign)
	sign_body.set("title", "HUFF")
	sign_body.set("text", SIGN_TEXT)
	_add_hitbox(sign_body, Vector2(44, 34), Vector2(0, -14))
	region.entities.add_child(sign_body)

	# Readable HUFF employee bear box.
	var bear_box := _prop_body("HuffBearBox", B + "bear_box.png", Vector2(2858, 566), Vector2(28, 12), Vector2(0, -6))
	EasterEggs.make_readable(bear_box, "HUFF Bear Box", BEAR_BOX_TEXT, Vector2(40, 32), Vector2(0, -12))
	region.entities.add_child(bear_box)

	# Everyday seasonal-worker camp props.
	var props := [
		["HuffCooler", CS + "cooler.png", Vector2(2896, 568), Vector2(24, 10), Vector2(0, -5)],
		["HuffClothesline", CS + "clothesline.png", Vector2(2984, 558), Vector2(64, 10), Vector2(0, -5)],
		["HuffTable", CS + "patio_table.png", Vector2(2926, 636), Vector2(36, 14), Vector2(0, -7)],
		["HuffChair0", CS + "chair_0.png", Vector2(2872, 646), Vector2(16, 8), Vector2(0, -4)],
		["HuffChair1", CS + "chair_2.png", Vector2(2980, 644), Vector2(16, 8), Vector2(0, -4)],
		["HuffBikeRack", CS + "bike_rack.png", Vector2(2750, 694), Vector2(56, 10), Vector2(0, -5)],
		["HuffWoodpile", CS + "woodpile.png", Vector2(2918, 748), Vector2(34, 12), Vector2(0, -6)],
	]
	for p: Array in props:
		region.entities.add_child(_prop_body(p[0], p[1], p[2], p[3], p[4]))

	# Warm lamp post in the middle of the tents.
	var lamp := _prop_body("HuffLamp", LAMP_TEX, Vector2(2848, 614), Vector2(12, 8), Vector2(0, -4))
	_add_light(lamp, Vector2(0, -52), 96.0, 1.0)
	region.entities.add_child(lamp)


## Four HUFF employees living and strolling around the tents by day/evening.
static func _place_residents(region: Region) -> void:
	var spots: Array[Vector2] = [
		Vector2(2892, 672), # Rico
		Vector2(2956, 606), # Macy
		Vector2(2832, 594), # Devon
		Vector2(2996, 676), # Tessa
	]
	for i in HuffParty.CREW_PATHS.size():
		var data := load(HuffParty.CREW_PATHS[i]) as CharacterData
		if data == null:
			continue
		var raw: Node = NPC_SCENE.instantiate()
		raw.set_script(HuffResident)
		var npc := raw as HuffResident
		npc.name = "HuffResident_" + data.id
		npc.character = data
		npc.position = spots[i]
		npc.wander_radius = 36.0
		region.entities.add_child(npc)


static func _prop_body(node_name: String, tex_path: String, at: Vector2, col_size: Vector2, col_pos: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = at
	body.collision_mask = 0
	var tex := load(tex_path) as Texture2D
	var sp := Sprite2D.new()
	sp.name = "Sprite"
	sp.texture = tex
	if tex:
		sp.offset = Vector2(0, -tex.get_height() / 2.0)
	body.add_child(sp)
	var col := CollisionShape2D.new()
	col.name = "Collision"
	var rect := RectangleShape2D.new()
	rect.size = col_size
	col.shape = rect
	col.position = col_pos
	body.add_child(col)
	return body


static func _add_light(parent: Node, at: Vector2, radius: float, strength: float) -> void:
	var light := PointLight2D.new()
	light.name = "NightLight"
	light.set_script(NIGHT_LIGHT)
	light.position = at
	light.set("radius", radius)
	light.set("strength", strength)
	parent.add_child(light)


static func _add_hitbox(body: Node, hit_size: Vector2, hit_center: Vector2) -> void:
	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 4
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = hit_size
	shape.shape = rect
	shape.position = hit_center
	hitbox.add_child(shape)
	body.add_child(hitbox)
