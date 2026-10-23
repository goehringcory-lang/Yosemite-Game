extends HubBuilder
## Builds the insides of the park's main buildings: the Village mall, the
## Lodge and the Chapel, Curry Village's Registration Office and Pavilion, six
## rooms of the Ahwahnee, Glacier Point's snack stand and Geology Hut, El
## Portal's market, post office and lodge, the Wawona Hotel and the History
## Center, and Tuolumne's lodges, store and visitor center. (The Camp Curry
## Store and the Mountain Shop are built with Curry Village.) Run it with
## tools/hubs/rebuild_interiors.sh, which upgrades the art and moves the rooms
## onto the 32px grid:
##
##   tools/hubs/rebuild_interiors.sh
##
## Each room is one entry in rooms() below: its size, floor and walls, what
## hangs on the walls, its furniture, the signs you can read, and its doors.
## The art is drawn by interiors_art.gd into assets/sprites/interiors/, each
## room is written to scenes/regions/<id>.tscn, and the front doors outside
## are written to scenes/story/doors/<region>.tscn: a BuildingDoor on each
## building's doorstep and a spot just outside it (<id>_door) to come back
## out to. Those are placed from where the building stands in its region's
## scene, so they follow a rebuilt hub. Put story NPCs in
## scenes/story/content/<id>.tscn (by marker name), not in the rooms.
##
## Rooms are laid out at the 16px scale, like the other builders: a room of
## 30 x 17 tiles fills the screen.

const InteriorsArt = preload("res://tools/hubs/interiors_art.gd")
const OUT := "res://assets/sprites/interiors/"
const PROPS := "res://assets/sprites/interiors/props/"
const DOORS := "res://scenes/story/doors/"
const SIGN := "res://assets/sprites/info_sign.png"
## What the way out of a building says, by the region it stands in.
const REGION_LABELS := {
	"yosemite_village": "Yosemite Village", "curry_village": "Curry Village", "the_ahwahnee": "The Ahwahnee grounds",
	"glacier_point": "Glacier Point", "el_portal": "El Portal", "wawona": "Wawona", "tuolumne_meadows": "Tuolumne Meadows",
}

var _art: InteriorsArt


func _ready() -> void:
	var only := OS.get_environment("ONLY_ROOMS").split(",", false)
	var specs := rooms()
	_art = InteriorsArt.new()
	print("== interior art")
	_draw_art(specs)
	import_assets()
	print("== interior rooms")
	for spec: Dictionary in specs:
		if only.is_empty() or spec.id in only:
			_build_room(spec)
	print("== building doors")
	_build_doors(specs)
	print("interiors built: %d rooms" % specs.size())
	get_tree().quit()


# ---------------------------------------------------------------- art

func _draw_art(specs: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROPS))
	var done := {}
	for spec: Dictionary in specs:
		_art.room(spec).save_png(ProjectSettings.globalize_path(OUT + spec.id + ".png"))
		for item: Array in spec.get("props", []):
			if item[0] == "sign":
				continue
			var kind: String = item[0] if item[0] != "read" and item[0] != "panel" else (item[1] if item[0] == "read" else "panel")
			var o: Dictionary = _opts_of(item)
			var file := InteriorsArt.prop_file(kind, o)
			if done.has(file):
				continue
			done[file] = true
			_art.prop(kind, o).save_png(ProjectSettings.globalize_path(PROPS + file + ".png"))


## The look options of a prop entry, wherever they sit in it.
func _opts_of(item: Array) -> Dictionary:
	match item[0]:
		"read":
			return item[4]
		"panel":
			return item[5] if item.size() > 5 else {}
		_:
			return item[3] if item.size() > 3 else {}


# ---------------------------------------------------------------- rooms

func _build_room(spec: Dictionary) -> void:
	var size: Vector2i = spec.size
	var rows: int = spec.rows
	var rw := size.x * T
	var rh := size.y * T
	init_grid(size.x, size.y, Terrain.BUILT)
	fill(0, 0, size.x - 1, rows - 1, Terrain.CLIFF)
	fill(0, size.y - 1, size.x - 1, size.y - 1, Terrain.CLIFF)
	fill(0, rows, 0, size.y - 2, Terrain.CLIFF)
	fill(size.x - 1, rows, size.x - 1, size.y - 2, Terrain.CLIFF)
	for door: Dictionary in spec.doors:
		match door.side:
			"front":
				fill(size.x / 2 - 1, size.y - 1, size.x / 2, size.y - 1, Terrain.BUILT)
			"left":
				fill(0, door.row, 0, door.row + 1, Terrain.BUILT)
			"right":
				fill(size.x - 1, door.row, size.x - 1, door.row + 1, Terrain.BUILT)
	var outside := _outside(spec)
	start_region(_node_name(spec.id), spec.id, spec.name, outside.geo, true)
	_root.hub_id = outside.hub
	paint_ground()
	var room := Sprite2D.new()
	room.name = "Room"
	room.texture = texture(OUT + spec.id + ".png")
	room.centered = false
	room.z_index = -8
	_root.add_child(room)
	# beyond the walls, darkness (a room smaller than the screen sits in it)
	var dark := Polygon2D.new()
	dark.name = "Dark"
	dark.color = Color("0e0b0a")
	dark.z_index = -12
	dark.polygon = PackedVector2Array([Vector2(-1200, -1200), Vector2(rw + 1200, -1200), Vector2(rw + 1200, rh + 1200), Vector2(-1200, rh + 1200)])
	_root.add_child(dark)
	var n := 0
	for item: Array in spec.get("props", []):
		n += 1
		_place(item, n)
	var wall_h := rows * T
	for door: Dictionary in spec.doors:
		var to: String = door.to
		var spawn: String = door.spawn
		var label: String = door.label
		match door.side:
			"front":
				_marker_px("door", rw / 2.0, rh - 28)
				region_exit("ToOutside", Vector2(rw / 2.0, rh - 4), Vector2(44, 10), label, to, spawn)
			"left":
				_marker_px(door.spot, 30, door.row * T + 16)
				region_exit("To" + _node_name(to), Vector2(4, door.row * T + 16), Vector2(8, 30), label, to, spawn)
			"right":
				_marker_px(door.spot, rw - 30, door.row * T + 16)
				region_exit("To" + _node_name(to), Vector2(rw - 4, door.row * T + 16), Vector2(8, 30), label, to, spawn)
			"back":
				_marker_px(door.spot, door.x, wall_h + 20)
				var d := _door_node("To" + _node_name(to), label, to, spawn, Vector2(28, 22), Vector2(0, -6))
				d.position = Vector2(door.x, wall_h + 4)
				_entities.add_child(d)
	for spot_name: String in spec.get("spots", {}):
		var p: Vector2 = spec.spots[spot_name]
		_marker_px(spot_name, p.x, p.y)
	place_blockers(false)
	pack(_root, "res://scenes/regions/%s.tscn" % spec.id)


## One entry of a room's props: a piece of furniture, a sign, an exhibit
## panel, or a piece of furniture you can read ("read").
func _place(item: Array, n: int) -> void:
	match item[0]:
		"sign":
			sign_prop("Sign%d" % n, SIGN, Vector2(item[1], item[2]), Vector2(12, 4), item[3], item[4])
		"panel":
			var o: Dictionary = item[5] if item.size() > 5 else {}
			_readable("Panel%d" % n, "panel", o, Vector2(item[1], item[2]), item[3], item[4])
		"read":
			_readable(_node_name(item[1]) + str(n), item[1], item[4], Vector2(item[2], item[3]), item[5], item[6])
		_:
			var o: Dictionary = _opts_of(item)
			var body := prop_body(_node_name(item[0]) + str(n), PROPS + InteriorsArt.prop_file(item[0], o) + ".png", [base_rect(_foot(item[0], o))])
			body.position = Vector2(item[1], item[2])
			_entities.add_child(body)
			if InteriorsArt.frames_of(item[0]) > 1:
				animate(body, InteriorsArt.frames_of(item[0]), 3.0)


func _readable(node_name: String, kind: String, o: Dictionary, at_pos: Vector2, title: String, text: String) -> void:
	var foot := _foot(kind, o)
	var body := prop_body(node_name, PROPS + InteriorsArt.prop_file(kind, o) + ".png", [base_rect(foot)], Vector2(foot.x + 6, foot.y + 12))
	body.set_script(load("res://scripts/objects/info_sign.gd"))
	body.set("title", title)
	body.set("text", text)
	body.position = at_pos
	_entities.add_child(body)
	if InteriorsArt.frames_of(kind) > 1:
		animate(body, InteriorsArt.frames_of(kind), 3.0)


## How much floor a piece takes: [code]foot[/code] if it says, otherwise
## most of its width and a few pixels of depth.
func _foot(kind: String, o: Dictionary) -> Vector2:
	if o.has("foot"):
		return o.foot
	var im := Image.load_from_file(ProjectSettings.globalize_path(PROPS + InteriorsArt.prop_file(kind, o) + ".png"))
	var w := im.get_width() / InteriorsArt.frames_of(kind)
	return Vector2(maxf(6.0, w - 6.0), clampf(im.get_height() * 0.3, 6.0, 14.0))


func _marker_px(marker_name: String, px_x: float, px_y: float) -> void:
	var m := Marker2D.new()
	m.name = marker_name
	m.position = Vector2(px_x, px_y)
	_markers.add_child(m)


## A door you face and interact with: no picture and nothing solid.
func _door_node(node_name: String, label: String, to: String, spawn: String, reach: Vector2, offset: Vector2) -> StaticBody2D:
	var d := StaticBody2D.new()
	d.name = node_name
	d.collision_layer = 0
	d.collision_mask = 0
	d.set_script(load("res://scripts/objects/building_door.gd"))
	d.set("label", label)
	d.set("target_region", to)
	d.set("target_spawn", spawn)
	_hitbox(d, reach, offset)
	return d


func _node_name(id: String) -> String:
	return id.to_pascal_case()


## The region a room's building stands in, and where.
func _outside(spec: Dictionary) -> Dictionary:
	var o: Dictionary = spec.get("outside", {})
	if o.is_empty():
		# an inner room: the same place as the room its front door leads to
		for door: Dictionary in spec.doors:
			if door.side == "front":
				for other: Dictionary in rooms():
					if other.id == door.to:
						return _outside(other)
		return {"hub": "yosemite_valley", "geo": Vector2.ZERO}
	var region: Region = load("res://scenes/regions/%s.tscn" % o.region).instantiate()
	var out := {"hub": region.hub_id, "geo": region.geo_anchor}
	var map := region.get_node_or_null("Map")
	var building := region.find_child(o.node, true, false) as Node2D
	if map and building:
		out.geo = map.call("position_to_lonlat", building.position)
	region.free()
	return out


# ---------------------------------------------------------------- doors outside

## Writes scenes/story/doors/<region>.tscn for every region with a building
## you can go into: a door on each doorstep and a spot just outside. These
## are laid out in the region's own (32px) pixels.
func _build_doors(specs: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOORS))
	var by_region := {}
	for spec: Dictionary in specs:
		if spec.has("outside"):
			var region_id: String = spec.outside.region
			if not by_region.has(region_id):
				by_region[region_id] = []
			by_region[region_id].append(spec)
	for region_id: String in by_region:
		var region: Region = load("res://scenes/regions/%s.tscn" % region_id).instantiate()
		var root := Node2D.new()
		root.name = _node_name(region_id) + "Doors"
		for spec: Dictionary in by_region[region_id]:
			var o: Dictionary = spec.outside
			var nodes: Array = o.get("nodes", [o.node])
			for i in nodes.size():
				var building := region.find_child(nodes[i], true, false) as Node2D
				assert(building != null, "%s has no %s" % [region_id, nodes[i]])
				var at: Vector2 = building.position + o.get("offset", Vector2.ZERO)
				var d := _door_node("DoorTo" + _node_name(spec.id) + ("" if i == 0 else str(i + 1)), o.get("label", spec.name), spec.id, "door",
					Vector2(56, 44), Vector2(0, 2))
				d.position = at
				var hours: Vector2i = o.get("hours", Vector2i(0, 24))
				d.set("open_hour", hours.x)
				d.set("close_hour", hours.y)
				root.add_child(d)
				if i == 0:
					var m := Marker2D.new()
					m.name = spec.id + "_door"
					m.position = at + Vector2(0, o.get("out", 40.0))
					root.add_child(m)
		region.free()
		for child in root.get_children():
			_own(child, root)
		var packed := PackedScene.new()
		assert(packed.pack(root) == OK)
		save_resource(packed, DOORS + region_id + ".tscn")
		root.free()


# ---------------------------------------------------------------- the rooms

## A front door out to [param region]'s spot outside room [param id].
static func front(id: String, label: String, region: String) -> Dictionary:
	return {"side": "front", "to": region, "spawn": id + "_door", "label": label}


## Every room. Furniture entries are [kind, x, y, look]; ["sign", x, y,
## title, text] is a plain sign, ["panel", x, y, title, text, look] an exhibit
## panel, and ["read", kind, x, y, look, title, text] a piece of furniture you
## can read. Positions are the bottom middle of each piece, in 16px pixels.
func rooms() -> Array:
	var out: Array = []
	out.append_array(_village_rooms())
	out.append_array(_curry_rooms())
	out.append_array(_ahwahnee_rooms())
	out.append_array(_glacier_rooms())
	out.append_array(_el_portal_rooms())
	out.append_array(_wawona_rooms())
	out.append_array(_tuolumne_rooms())
	# a room with a building around it opens onto the region outside
	for spec: Dictionary in out:
		if not spec.has("doors"):
			spec.doors = []
		if spec.has("outside") and not spec.doors.any(func(d: Dictionary) -> bool: return d.side == "front"):
			var region_id: String = spec.outside.region
			spec.doors.append(front(spec.id, REGION_LABELS[region_id], region_id))
	return out


func _village_rooms() -> Array:
	const V := "yosemite_village"
	return [
		{"id": "welcome_center", "name": "Valley Welcome Center", "size": Vector2i(30, 17), "rows": 4, "seed": 31,
			"outside": {"region": V, "node": "WelcomeCenter", "hours": Vector2i(9, 17)},
			"floor": ["stone", "9c9284"], "wall": ["boards", "7a5638"], "wainscot": "4a3a2a", "beams": true,
			"deco": [["window", 40, 12, 32, 28, 60, 20], ["window", 408, 12, 32, 28, 60, -20],
				["frame", 150, 10, 80, 40, "map"], ["sign", 240, 4, "WELCOME TO YOSEMITE"], ["frame", 262, 14, 40, 28, "photo"],
				["frame", 312, 14, 30, 28, "painting"], ["flag", 360, 16], ["sconce", 120, 18], ["sconce", 360, 52]],
			"rugs": [[180, 150, 120, 50, "3a5a4a", "e8d8a8", "6a3a2a"]],
			"props": [
				["counter", 240, 100, {"w": 112, "wood": "6a4a30", "books": true, "bell": true}],
				["read", "relief", 240, 182, {"w": 72}, "The Valley from above",
					"A model of Yosemite Valley in relief. Glaciers deepened and widened a river canyon here into a U-shaped valley, and when the last glacier melted, a lake filled it. Sediment filled the lake in, and the flat floor you walk on is its bed."],
				["panel", 92, 150, "A park for all time",
					"In 1864 President Lincoln signed the Yosemite Grant, setting aside the Valley and the Mariposa Grove 'for public use, resort and recreation, inalienable for all time.' It was the first time any government set land aside to protect its scenery. The high country around it became a national park in 1890.", {"color": "3a4a3a"}],
				["panel", 388, 150, "Ask a ranger",
					"Rangers here can tell you which roads are open, where the bears have been seen lately, which trails are snowed in, and when the next ranger walk starts.", {"color": "3a4a3a", "picture": "painting"}],
				["bench", 92, 236, {"w": 48, "back": true}],
				["bench", 388, 236, {"w": 48, "back": true}],
				["spinner", 160, 96, {}],
				["plant", 32 + 14, 92, {}],
				["plant", 434, 92, {}],
			]},
		{"id": "yosemite_museum", "name": "Yosemite Museum", "size": Vector2i(30, 17), "rows": 5, "seed": 37,
			"outside": {"region": V, "node": "YosemiteMuseum", "hours": Vector2i(9, 17)},
			"floor": ["planks", "8a6440"], "wall": ["plaster", "d8c8a4"], "wainscot": "5a3e28", "beams": true,
			"deco": [["baskets", 24, 20, 120], ["baskets", 336, 20, 120], ["frame", 168, 14, 40, 30, "photo"],
				["frame", 272, 14, 40, 30, "photo"], ["sign", 240, 10, "THE PEOPLE OF AHWAHNEE"], ["band", 52, 6, ["6a3a20", "c8a060", "2a1a10", "c8a060"]],
				["sconce", 150, 24], ["sconce", 330, 24]],
			"rugs": [[170, 160, 140, 46, "6a3a20", "e8d8a8", "3a2a1e"]],
			"props": [
				["read", "basket", 240, 140, {"big": true, "look": "great", "foot": Vector2(16, 8)}, "Lucy Telles's great basket",
					"Lucy Telles, a Mono Lake Paiute and Southern Miwok weaver who lived in the Valley, spent about four years on this basket in the early 1930s. It is one of the largest baskets of its kind ever woven, with tens of thousands of stitches of sedge root, bracken fern root and redbud bark."],
				["case", 120, 132, {"w": 64, "contents": "baskets", "wood": "5a3e28"}],
				["case", 360, 132, {"w": 64, "contents": "artifacts", "wood": "5a3e28"}],
				["case", 120, 216, {"w": 64, "contents": "minerals", "wood": "5a3e28"}],
				["case", 360, 216, {"w": 64, "contents": "baskets", "wood": "5a3e28"}],
				["panel", 196, 104, "The museum", "The Yosemite Museum opened in 1926, one of the first buildings in the National Park Service built to be a museum. Its granite ground story and dark timber were meant to sit quietly under the cliffs.", {"color": "3a2a1e"}],
				["panel", 284, 104, "Weavers of the Valley", "Ahwahneechee, Miwok and Paiute weavers made baskets for gathering, cooking and storing acorns, and for trade. In the early 1900s weavers like Lucy Telles and Carrie Bethel made fancy baskets for the Indian Field Days, and their work is kept here.", {"color": "3a2a1e", "picture": "painting"}],
				["basket", 52, 246, {"big": true, "look": "big"}],
				["basket", 428, 246, {}],
			]},
		{"id": "bests_studio", "name": "Best's Studio", "size": Vector2i(30, 17), "rows": 4, "seed": 41,
			"outside": {"region": V, "node": "BestsStudio", "hours": Vector2i(9, 18)},
			"floor": ["planks", "9a7048"], "wall": ["plaster", "e2d6bc"], "wainscot": "6a4a30",
			"deco": [["frame", 30, 12, 36, 28, "photo"], ["frame", 80, 8, 48, 36, "photo"], ["frame", 140, 14, 30, 24, "photo"],
				["frame", 300, 12, 40, 30, "painting"], ["frame", 352, 8, 48, 36, "photo"], ["frame", 412, 12, 36, 28, "photo"],
				["sign", 240, 6, "BEST'S STUDIO"], ["window", 210, 16, 60, 26, 60, 0]],
			"rugs": [[150, 150, 180, 56, "8a2f2f", "e8d8a8", "2f4a34"]],
			"props": [
				["read", "piano", 112, 104, {"color": "3a2418"}, "Virginia Best's piano",
					"Ansel Adams trained as a concert pianist. On his summers in the Valley he played this piano at Best's Studio, and in 1928 he married Virginia Best, the painter Harry Best's daughter, in the studio. For years he couldn't decide between music and photography."],
				["counter", 376, 104, {"w": 80, "register": true, "wood": "5a3a22"}],
				["easel", 160, 226, {"painting": "painting"}],
				["easel", 320, 226, {"painting": "photo", "look": "photo"}],
				["case", 92, 196, {"w": 56, "contents": "photos"}],
				["case", 388, 196, {"w": 56, "contents": "photos"}],
				["panel", 240, 140, "Harry Best", "Harry Best, a painter, opened his studio in the Valley in 1902 and sold his paintings and photographs to visitors. After Ansel and Virginia Adams took it over, it became the Ansel Adams Gallery in 1972. It is the oldest family-run business in a national park.", {"color": "2a1f1a"}],
			]},
		{"id": "wilderness_center", "name": "Wilderness Center", "size": Vector2i(30, 17), "rows": 4, "seed": 43,
			"outside": {"region": V, "node": "WildernessCenter", "hours": Vector2i(8, 17)},
			"floor": ["planks", "8e6a46"], "wall": ["logs", "8a5a36"], "beams": false,
			"deco": [["frame", 32, 10, 120, 40, "map"], ["board", 330, 10, 116, 40], ["sign", 240, 6, "WILDERNESS PERMITS"],
				["pegs", 176, 30, 50, "ropes"], ["sconce", 260, 18]],
			"rugs": [[180, 150, 120, 48, "2f4a34", "e8d8a8", "6a3a2a"]],
			"props": [
				["counter", 240, 102, {"w": 96, "books": true}],
				["read", "canisters", 400, 110, {}, "Bear canisters",
					"Black bears in Yosemite learned long ago that people mean food. In the wilderness you carry your food, toiletries and trash in a hard-sided canister a bear can't open, and keep it well away from your tent at night. A bear that gets human food once keeps coming back for more."],
				["read", "relief", 120, 196, {"w": 64, "look": "high"}, "The high country",
					"Nearly all of Yosemite is wilderness: about 95 percent of the park, more than 700,000 acres, has been protected as wilderness since 1984. You need a permit to stay a night out there, and the trailhead quotas keep the high lakes quiet."],
				["bench", 360, 236, {"w": 48, "back": true}],
				["shelf", 360, 196, {}],
				["sign", 300, 104, "Trail conditions", "The board lists which passes are still snowbound, which bridges are out, and where the bears have been busy. Check it before you set out."],
			]},
		{"id": "valley_post_office", "name": "Yosemite Valley Post Office", "size": Vector2i(30, 17), "rows": 4, "seed": 47,
			"outside": {"region": V, "node": "PostOffice", "hours": Vector2i(9, 17)},
			"floor": ["tile", "c8bca0", "8a7a5a"], "wall": ["granite", "9a9284"],
			"deco": [["pboxes", 24, 12, 140, 46], ["pboxes", 316, 12, 140, 46], ["flag", 220, 12], ["clock", 240, 22], ["sign", 240, 42, "U.S. MAIL"]],
			"props": [
				["counter", 240, 106, {"w": 120, "items": ["scale"], "wood": "5a3e28", "top": "8a6a4a"}],
				["desk", 100, 196, {"w": 48, "look": "writing", "items": "papers"}],
				["desk", 380, 196, {"w": 48, "look": "writing", "items": "papers"}],
				["crates", 430, 140, {}],
				["sign", 172, 104, "Postmarked Yosemite", "A letter mailed here leaves with a Yosemite postmark. Climbers have been writing home from this counter for generations, usually to ask for money or for more food."],
				["bench", 240, 236, {"w": 56}],
			]},
		{"id": "degnans", "name": "Degnan's", "size": Vector2i(30, 17), "rows": 4, "seed": 53,
			"outside": {"region": V, "node": "Degnans", "hours": Vector2i(7, 20)},
			"floor": ["tile", "e0d4b4", "9a3a2a"], "wall": ["stucco", "d8c4a0"], "wainscot": "7a4a2a",
			"deco": [["frame", 160, 8, 60, 36, "menu"], ["frame", 260, 8, 60, 36, "menu"], ["sign", 240, 4, "DEGNAN'S BAKERY"],
				["shelf", 24, 20, 110, "crockery"], ["shelf", 346, 20, 110, "goods"], ["frame", 40, 40, 30, 16, "photo"], ["sconce", 140, 30], ["sconce", 340, 30]],
			"props": [
				["counter", 160, 102, {"w": 112, "items": ["pastries", "cups"], "register": true, "wood": "6a3a22"}],
				["read", "case", 330, 102, {"w": 64, "contents": "pastries", "wood": "6a3a22"}, "Bridget's bread",
					"In the 1880s Bridget Degnan began baking bread in a Dutch oven in her kitchen for the campers who came to her door. She was soon baking fifty loaves a day, then built a brick oven, and the Degnans' bakery and store grew into this place. It has fed the Valley ever since."],
				["case", 420, 102, {"w": 40, "contents": "icecream", "look": "icecream"}],
				["table_round", 96, 190, {"cloth": "c8402e", "set": "tea", "look": "red"}],
				["chair", 74, 188, {}], ["chair", 118, 188, {}],
				["table_round", 384, 190, {"cloth": "c8402e", "set": "tea", "look": "red"}],
				["chair", 362, 188, {}], ["chair", 406, 188, {}],
				["table_round", 96, 240, {"cloth": "e8e0c8", "set": "pizza", "look": "white"}],
				["table_round", 384, 240, {"cloth": "e8e0c8", "set": "pizza", "look": "white"}],
				["cooler", 40, 104, {}],
			]},
		{"id": "village_store_inside", "name": "Village Store", "size": Vector2i(36, 18), "rows": 4, "seed": 59,
			"outside": {"region": V, "node": "VillageStore", "hours": Vector2i(8, 22)},
			"floor": ["planks", "a07a4e"], "wall": ["logs", "7a4f31"], "beams": true,
			"deco": [["shelf", 24, 20, 150, "goods"], ["shelf", 24, 40, 150, "goods"], ["shelf", 400, 20, 152, "goods"], ["shelf", 400, 40, 152, "goods"],
				["sign", 288, 6, "VILLAGE STORE"], ["rack", 200, 20, 64], ["rack", 300, 20, 64], ["antlers", 288, 30], ["sconce", 186, 24], ["sconce", 390, 24]],
			"rugs": [[220, 170, 136, 44, "8a2f2f", "e8d8a8", "2f4a34"]],
			"props": [
				["counter", 288, 110, {"w": 128, "register": true, "items": ["jars"]}],
				["shelf", 80, 150, {}], ["shelf", 80, 214, {}], ["shelf", 496, 150, {}], ["shelf", 496, 214, {}],
				["cooler", 40 + 8, 102, {}], ["cooler", 532, 102, {}],
				["rack", 188, 168, {"w": 40}], ["rack", 388, 168, {"w": 40}],
				["postcards", 172, 236, {}], ["spinner", 404, 236, {"w": 9}],
				["barrels", 532, 266, {}],
				["sign", 230, 104, "The Village Store", "Groceries, firewood, camp stoves, rain ponchos and souvenirs. The store has stood on this side of the river since the 1920s, when the Park Service moved the old village from below Sentinel Rock to here."],
			]},
		{"id": "valley_lodge_lobby", "name": "Yosemite Valley Lodge", "size": Vector2i(32, 17), "rows": 5, "seed": 61,
			"outside": {"region": V, "node": "ValleyLodge"},
			"floor": ["planks", "8a6440"], "wall": ["boards", "6a4a30"], "beams": true,
			"deco": [["tall_window", 300, 100, "valley"], ["frame", 40, 14, 60, 40, "painting"], ["sign", 132, 8, "FRONT DESK"],
				["frame", 440, 18, 40, 30, "photo"], ["sconce", 270, 30], ["sconce", 420, 30]],
			"rugs": [[248, 150, 156, 70, "3a5a4a", "e8d8a8", "6a3a2a"]],
			"props": [
				["counter", 132, 112, {"w": 104, "bell": true, "books": true}],
				["hearth", 452, 102, {"w": 48, "h": 60}],
				["sofa", 326, 168, {"w": 56, "color": "6a3a2a"}],
				["armchair", 270, 200, {"color": "3a5a4a"}], ["armchair", 384, 200, {"color": "3a5a4a"}],
				["coffee_table", 326, 206, {}],
				["luggage", 60, 150, {}],
				["plant", 40, 236, {}],
				["sign", 200, 104, "Yosemite Falls from the lobby",
					"The Lodge stands at the foot of Yosemite Falls, the tallest waterfall in North America: 2,425 feet from the rim to the foot of the lower fall. In spring you can hear it from your room; by late summer it can run dry."],
			]},
		{"id": "yosemite_chapel", "name": "Yosemite Chapel", "size": Vector2i(30, 18), "rows": 5, "seed": 67,
			"outside": {"region": V, "node": "YosemiteChapel", "hours": Vector2i(7, 21)},
			"floor": ["planks", "8a5a34"], "wall": ["boards", "8a6440"], "beams": true, "light": 0.85,
			"deco": [["lancet", 70, 10, 18, 50], ["lancet", 392, 10, 18, 50], ["lancet", 150, 14, 14, 40], ["lancet", 316, 14, 14, 40],
				["cross", 240, 14], ["sconce", 200, 30], ["sconce", 280, 30]],
			"rugs": [[224, 96, 32, 160, "8a2f2f", "c89a3a", "5a1a1a"]],
			"props": [
				["read", "pulpit", 240, 108, {}, "Yosemite Chapel",
					"The chapel was built in 1879 near the old village below Sentinel Rock, and moved here, across the river, in 1901. It is the oldest building in Yosemite Valley still in use, and couples come from all over the world to be married under its bell tower."],
				["piano", 400, 110, {"color": "4a2a1a", "look": "organ"}],
				["pew", 140, 148, {"w": 120}], ["pew", 340, 148, {"w": 120}],
				["pew", 140, 182, {"w": 120}], ["pew", 340, 182, {"w": 120}],
				["pew", 140, 216, {"w": 120}], ["pew", 340, 216, {"w": 120}],
				["plant", 60, 108, {"pot": "c89a3a"}],
			]},
	]


func _curry_rooms() -> Array:
	const CV := "curry_village"
	return [
		{"id": "curry_registration", "name": "Registration Office", "size": Vector2i(30, 17), "rows": 4, "seed": 71,
			"outside": {"region": CV, "node": "Registration"},
			"floor": ["planks", "a07a4e"], "wall": ["lap", "e2d6b0"], "wainscot": "3a5a3a",
			"deco": [["window", 40, 10, 34, 26, 60, 30], ["window", 406, 10, 34, 26, 60, -30], ["sign", 240, 4, "CAMP CURRY - 1899"],
				["clock", 240, 24], ["frame", 130, 10, 50, 34, "photo"], ["frame", 300, 10, 50, 34, "photo"], ["pegs", 190, 36, 40, "coats"]],
			"rugs": [[170, 150, 140, 50, "8a2f2f", "e8d8a8", "2f4a34"]],
			"props": [
				["counter", 240, 102, {"w": 112, "bell": true, "books": true, "register": true}],
				["read", "desk", 400, 104, {"w": 44, "items": "typewriter", "look": "typewriter"}, "Mother Curry",
					"David and Jennie Curry, schoolteachers from Indiana, opened Camp Curry in 1899 with seven tents and a dining tent. It cost two dollars a day. Jennie ran the camp for decades after David died in 1917, and everyone called her Mother Curry."],
				["stove", 72, 104, {}],
				["bench", 96, 236, {"w": 48, "back": true}],
				["bench", 384, 236, {"w": 48, "back": true}],
				["spinner", 140, 104, {}],
				["sign", 320, 180, "Hello, Glacier!", "Every summer night until 1968, the camp's crowd fell silent for David Curry's call up to Glacier Point, and the Firefall came pouring down the cliff. The photographs on the wall show it."],
			]},
		{"id": "curry_pavilion", "name": "Pavilion", "size": Vector2i(36, 18), "rows": 5, "seed": 73,
			"outside": {"region": CV, "node": "Pavilion"},
			"floor": ["planks", "8a6440"], "wall": ["logs", "7a4f31"], "beams": true,
			"deco": [["frame", 120, 12, 70, 40, "menu"], ["frame", 386, 12, 70, 40, "menu"], ["sign", 288, 6, "PAVILION"], ["pegs", 210, 40, 50, "kitchen"],
				["sconce", 60, 30], ["sconce", 516, 30]],
			"props": [
				["counter", 288, 112, {"w": 144, "items": ["cups", "pastries"], "top": "b8b0a0", "look": "serving"}],
				["hearth", 60, 108, {"w": 56, "h": 64}],
				["table_long", 150, 160, {"w": 112, "set": "dinner", "look": "pine"}],
				["table_long", 426, 160, {"w": 112, "set": "dinner", "look": "pine"}],
				["table_long", 150, 226, {"w": 112, "set": "dinner", "look": "pine"}],
				["table_long", 426, 226, {"w": 112, "set": "dinner", "look": "pine"}],
				["bench", 150, 176, {"w": 104}], ["bench", 426, 176, {"w": 104}],
				["bench", 150, 242, {"w": 104}], ["bench", 426, 242, {"w": 104}],
				["sign", 520, 108, "The Pavilion", "Camp Curry's dining hall feeds hundreds of campers every summer evening. In the early days a bugle called them in from the tents."],
			]},
	]


func _ahwahnee_rooms() -> Array:
	const BAND := ["2a1f1a", "c89a3a", "8a2f2f", "e8d8a8"]
	return [
		{"id": "ahwahnee_lobby", "name": "The Ahwahnee: Lobby", "size": Vector2i(30, 17), "rows": 5, "seed": 81,
			"outside": {"region": "the_ahwahnee", "node": "MainEntrance", "label": "The Ahwahnee", "offset": Vector2(-4, -28), "out": 68.0},
			"floor": ["tile", "6a4a32", "2a1f1a"], "wall": ["granite", "8a8278"], "side": "5a3a24", "mat": "8a2f2f",
			"deco": [["band", 54, 10, BAND], ["stained", 160, 10, 24, 30], ["stained", 296, 10, 24, 30], ["sign", 240, 4, "THE AHWAHNEE"],
				["sconce", 120, 24], ["sconce", 360, 24]],
			"rugs": [[168, 128, 144, 80, "8a2f2f", "e8d8a8", "2a1f1a"]],
			"doors": [{"side": "left", "row": 11, "to": "ahwahnee_dining_room", "spawn": "from_lobby", "label": "Dining Room", "spot": "from_dining"},
				{"side": "right", "row": 11, "to": "ahwahnee_great_lounge", "spawn": "from_lobby", "label": "Great Lounge", "spot": "from_lounge"},
				{"side": "back", "x": 240, "to": "ahwahnee_mural_room", "spawn": "door", "label": "Elevator Lobby", "spot": "from_mural", "look": "open"}],
			"props": [
				["counter", 96, 112, {"w": 96, "wood": "4a2a1a", "top": "6a3a22", "bell": true, "books": true, "look": "ahw_desk"}],
				["luggage", 400, 120, {"look": "ahw"}],
				["read", "plant", 360, 110, {"pot": "c89a3a", "look": "ahw_brass"}, "The Ahwahnee",
					"The Ahwahnee opened in July 1927. Gilbert Stanley Underwood built it of granite, steel and concrete stained to look like redwood, so it would fit under the cliffs and never burn like the wooden hotels before it. Two art historians, Phyllis Ackerman and Arthur Upham Pope, chose its decoration, and Jeannette Dyer Spencer drew its patterns from the baskets of the Valley's people."],
				["armchair", 60, 200, {"color": "8a2f2f", "look": "ahw_red"}],
				["armchair", 420, 200, {"color": "8a2f2f", "look": "ahw_red"}],
				["sign", 150, 220, "The floor", "The lobby floor is set with patterns taken from local baskets, like the bands on the beams."],
			]},
		{"id": "ahwahnee_great_lounge", "name": "The Ahwahnee: Great Lounge", "size": Vector2i(44, 20), "rows": 7, "seed": 83,
			"floor": ["planks", "6a4a30"], "wall": ["granite", "8a8278"], "side": "5a3a24", "beams": true, "mat": "8a2f2f",
			"deco": [["tall_window", 150, 40, "valley"], ["tall_window", 210, 40, "dome"], ["tall_window", 450, 40, "valley"], ["tall_window", 510, 40, "dome"],
				["stained", 156, 8, 28, 22], ["stained", 216, 8, 28, 22], ["stained", 456, 8, 28, 22], ["stained", 516, 8, 28, 22],
				["band", 100, 8, BAND]],
			"rugs": [[120, 160, 140, 70, "8a2f2f", "e8d8a8", "2a1f1a"], [440, 160, 140, 70, "2f4a34", "e8d8a8", "2a1f1a"], [290, 240, 124, 40, "c89a3a", "2a1f1a", "8a2f2f"]],
			"doors": [{"side": "left", "row": 14, "to": "ahwahnee_lobby", "spawn": "from_lounge", "label": "Lobby", "spot": "from_lobby"},
				{"side": "back", "x": 352, "to": "ahwahnee_solarium", "spawn": "door", "label": "Solarium", "spot": "from_solarium", "look": "stone"}],
			"spots": {"fireside": Vector2(110, 200)},
			"props": [
				["read", "hearth", 72, 122, {"w": 72, "h": 84, "look": "ahw_great"}, "The Great Lounge",
					"The Great Lounge is 77 feet long, with a fireplace big enough to stand in at each end and ten tall windows looking out at the cliffs. The stained glass above the windows, by Jeannette Dyer Spencer, carries patterns taken from Native baskets."],
				["hearth", 632, 122, {"w": 72, "h": 84, "look": "ahw_great"}],
				["sofa", 190, 174, {"w": 64, "color": "8a2f2f", "pattern": true, "look": "ahw_red"}],
				["sofa", 510, 174, {"w": 64, "color": "2f4a34", "pattern": true, "look": "ahw_green"}],
				["armchair", 130, 214, {"color": "c89a3a", "look": "ahw_gold"}], ["armchair", 250, 214, {"color": "c89a3a", "look": "ahw_gold"}],
				["armchair", 450, 214, {"color": "8a2f2f", "look": "ahw_red"}], ["armchair", 570, 214, {"color": "8a2f2f", "look": "ahw_red"}],
				["coffee_table", 190, 212, {"look": "ahw"}], ["coffee_table", 510, 212, {"look": "ahw"}],
				["read", "piano", 352, 160, {"grand": true, "look": "ahw_grand"}, "The grand piano",
					"A piano has stood in the Great Lounge for most of the hotel's life. Ansel Adams, a pianist before he was a photographer, played for guests here, and in winter the lounge fills for concerts by the fire."],
				["table_round", 352, 262, {"cloth": "e8e0c8", "set": "tea", "look": "ahw_tea"}],
				["chair", 330, 260, {"look": "ahw"}], ["chair", 374, 260, {"look": "ahw"}],
				["lamp", 100, 270, {"look": "ahw"}], ["lamp", 604, 270, {"look": "ahw"}],
				["plant", 290, 128, {"pot": "c89a3a", "look": "ahw_brass"}], ["plant", 414, 128, {"pot": "c89a3a", "look": "ahw_brass"}],
			]},
		{"id": "ahwahnee_solarium", "name": "The Ahwahnee: Solarium", "size": Vector2i(30, 17), "rows": 6, "seed": 87,
			"floor": ["tile", "8a7a5a", "5a4a3a"], "wall": ["granite", "8a8278"], "side": "5a3a24", "mat": "2f4a34",
			"deco": [["tall_window", 40, 60, "meadow"], ["tall_window", 130, 60, "dome"], ["tall_window", 290, 60, "valley"], ["tall_window", 380, 60, "meadow"],
				["band", 2, 4, BAND]],
			"rugs": [[160, 170, 160, 50, "2f4a34", "e8d8a8", "2a1f1a"]],
			"doors": [{"side": "front", "to": "ahwahnee_great_lounge", "spawn": "from_solarium", "label": "Great Lounge"}],
			"props": [
				["sofa", 240, 156, {"w": 64, "color": "c89a3a", "look": "ahw_gold"}],
				["armchair", 170, 196, {"color": "2f4a34", "look": "ahw_green"}], ["armchair", 310, 196, {"color": "2f4a34", "look": "ahw_green"}],
				["coffee_table", 240, 200, {"look": "ahw"}],
				["plant", 40, 120, {"look": "ahw_fern"}], ["plant", 440, 120, {"look": "ahw_fern"}],
				["plant", 40, 236, {"look": "ahw_fern"}], ["plant", 440, 236, {"look": "ahw_fern"}],
				["table_round", 96, 196, {"cloth": "e8e0c8", "set": "vase", "look": "ahw_vase"}],
				["table_round", 384, 196, {"cloth": "e8e0c8", "set": "vase", "look": "ahw_vase"}],
				["sign", 240, 120, "The Solarium", "The Solarium's tall windows face south across Ahwahnee Meadow to Glacier Point and Half Dome. It's the warmest room in the hotel on a winter afternoon."],
			]},
		{"id": "ahwahnee_dining_room", "name": "The Ahwahnee: Dining Room", "size": Vector2i(48, 20), "rows": 7, "seed": 89,
			"floor": ["planks", "5a3e28"], "wall": ["granite", "8a8278"], "side": "5a3a24", "beams": true, "mat": "8a2f2f",
			"deco": [["tall_window", 60, 44, "valley"], ["tall_window", 160, 44, "dome"], ["tall_window", 260, 44, "valley"], ["tall_window", 420, 44, "valley"],
				["tall_window", 520, 44, "dome"], ["tall_window", 620, 44, "forest"], ["band", 100, 8, BAND], ["sign", 384, 30, "THE DINING ROOM"]],
			"doors": [{"side": "right", "row": 14, "to": "ahwahnee_lobby", "spawn": "from_dining", "label": "Lobby", "spot": "from_lobby"}],
			"props": [
				["column", 130, 132, {"h": 90, "look": "ahw"}], ["column", 230, 132, {"h": 90, "look": "ahw"}], ["column", 330, 132, {"h": 90, "look": "ahw"}],
				["column", 440, 132, {"h": 90, "look": "ahw"}], ["column", 540, 132, {"h": 90, "look": "ahw"}], ["column", 640, 132, {"h": 90, "look": "ahw"}],
				["table_long", 180, 174, {"w": 96, "cloth": "f0ece0", "set": "dinner", "look": "ahw_linen"}],
				["table_long", 384, 174, {"w": 96, "cloth": "f0ece0", "set": "dinner", "look": "ahw_linen"}],
				["table_long", 588, 174, {"w": 96, "cloth": "f0ece0", "set": "dinner", "look": "ahw_linen"}],
				["table_long", 180, 238, {"w": 96, "cloth": "f0ece0", "set": "dinner", "look": "ahw_linen"}],
				["table_long", 588, 238, {"w": 96, "cloth": "f0ece0", "set": "dinner", "look": "ahw_linen"}],
				["read", "table_long", 384, 238, {"w": 96, "cloth": "8a2f2f", "set": "dinner", "look": "ahw_feast"}, "The Bracebridge Dinner",
					"Every Christmas since 1927 the Dining Room has held the Bracebridge Dinner, a seven-course feast in the manner of an English manor's Christmas, with carols, a Lord of the Manor and a boar's head. Ansel Adams wrote and directed it from 1929 until 1973."],
				["chair", 156, 190, {"look": "ahw"}], ["chair", 204, 190, {"look": "ahw"}], ["chair", 360, 190, {"look": "ahw"}], ["chair", 408, 190, {"look": "ahw"}],
				["chair", 564, 190, {"look": "ahw"}], ["chair", 612, 190, {"look": "ahw"}],
				["sign", 384, 118, "The Dining Room", "The Dining Room is 130 feet long, with a ceiling 34 feet high held up by sugar pine trusses and granite piers. Its tall windows look out at the cliffs."],
			]},
		{"id": "ahwahnee_mural_room", "name": "The Ahwahnee: Elevator Lobby", "size": Vector2i(30, 17), "rows": 5, "seed": 91,
			"floor": ["tile", "6a4a32", "2a1f1a"], "wall": ["plaster", "c8b890"], "side": "5a3a24", "mat": "8a2f2f",
			"deco": [["mural", 40, 6, 140, 64], ["mural", 300, 6, 140, 64], ["band", 72, 6, BAND]],
			"rugs": [[172, 140, 136, 70, "2f4a34", "c89a3a", "2a1f1a"]],
			"doors": [{"side": "front", "to": "ahwahnee_lobby", "spawn": "from_mural", "label": "Lobby"},
				{"side": "back", "x": 240, "to": "ahwahnee_guest_room", "spawn": "door", "label": "Elevator to the guest floors", "spot": "from_upstairs", "look": "elevator"}],
			"props": [
				["sign", 110, 112, "The mural", "Robert Boardman Howard painted the mural here when the hotel opened: the Valley's wildlife and forests in soft, flat colors, a little like a Japanese screen."],
				["bench", 96, 200, {"w": 48, "back": true, "wood": "4a2a1a", "look": "ahw_dark"}],
				["bench", 384, 200, {"w": 48, "back": true, "wood": "4a2a1a", "look": "ahw_dark"}],
				["plant", 160, 110, {"pot": "c89a3a", "look": "ahw_brass"}], ["plant", 320, 110, {"pot": "c89a3a", "look": "ahw_brass"}],
			]},
		{"id": "ahwahnee_guest_room", "name": "The Ahwahnee: Guest Room", "size": Vector2i(30, 17), "rows": 5, "seed": 93,
			"floor": ["carpet", "4a3a2e", "c89a3a"], "wall": ["plaster", "d8c8a4"], "wainscot": "4a2a1a", "side": "5a3a24", "mat": "8a2f2f",
			"deco": [["tall_window", 300, 80, "dome"], ["band", 4, 4, BAND], ["frame", 60, 16, 50, 36, "painting"], ["sconce", 140, 30], ["sconce", 250, 30]],
			"rugs": [[120, 150, 120, 60, "8a2f2f", "e8d8a8", "2a1f1a"]],
			"doors": [{"side": "front", "to": "ahwahnee_mural_room", "spawn": "from_upstairs", "label": "Elevator"}],
			"props": [
				["bed", 180, 140, {"color": "8a2f2f", "wood": "4a2a1a", "look": "ahw"}],
				["dresser", 80, 108, {"wood": "4a2a1a", "mirror": true, "look": "ahw_mirror"}],
				["armchair", 420, 160, {"color": "c89a3a", "look": "ahw_gold"}],
				["read", "desk", 420, 220, {"w": 40, "items": "lamp", "wood": "4a2a1a", "look": "ahw_lamp"}, "A letter on the desk",
					"Hotel stationery and a pen. Someone has started a letter: 'Half Dome from the window at sunrise, and the whole face goes pink. You should see it.'"],
				["trunk", 260, 140, {"look": "ahw"}],
				["plant", 40, 236, {"look": "ahw"}],
			]},
	]


func _glacier_rooms() -> Array:
	const G := "glacier_point"
	return [
		{"id": "glacier_snack_stand", "name": "Glacier Point Gifts & Snacks", "size": Vector2i(30, 17), "rows": 4, "seed": 101,
			"outside": {"region": G, "node": "SnackStand", "hours": Vector2i(9, 18)},
			"floor": ["planks", "8e6a46"], "wall": ["logs", "8a5a36"], "beams": true,
			"deco": [["window", 32, 10, 60, 30, 60, 20], ["window", 388, 10, 60, 30, 60, -20], ["frame", 140, 10, 60, 36, "menu"],
				["rack", 230, 14, 70], ["frame", 330, 12, 40, 30, "photo"]],
			"props": [
				["counter", 170, 104, {"w": 104, "register": true, "items": ["cups"], "look": "snacks"}],
				["case", 300, 104, {"w": 48, "contents": "icecream", "look": "icecream"}],
				["cooler", 440, 104, {}],
				["rack", 396, 200, {"w": 40}], ["spinner", 440, 236, {}], ["postcards", 56, 236, {}],
				["table_round", 140, 210, {"cloth": "3a5a4a", "look": "green"}], ["chair", 118, 208, {}], ["chair", 162, 208, {}],
				["table_round", 300, 230, {"cloth": "3a5a4a", "look": "green"}], ["chair", 278, 228, {}], ["chair", 322, 228, {}],
				["sign", 80, 104, "Glacier Point", "Hot coffee, ice cream and postcards 3,200 feet above the Valley floor. The road up is open about May to November, and the snack stand with it."],
			]},
		{"id": "geology_hut", "name": "Geology Hut", "size": Vector2i(24, 14), "rows": 4, "seed": 103,
			"outside": {"region": G, "node": "GeologyHut"},
			"floor": ["stone", "8a8478"], "wall": ["stone", "8a8278"], "light": 0.95,
			"deco": [["window", 24, 12, 136, 34, 60, 0], ["window", 216, 12, 136, 34, 60, 0]],
			"props": [
				["read", "telescope", 120, 120, {}, "Half Dome",
					"Through the glass, Half Dome's sheer northwest face, 2,000 feet of it, catches the afternoon sun. The glaciers never covered its top; they ground past below it and steepened the face as the rock peeled away in sheets."],
				["panel", 64, 120, "Reading the view", "The Geology Hut was built in 1924, one of the first places in any national park where visitors could stand and have the scenery explained to them. From here you can see what the glaciers left: hanging valleys, polished domes and the deep U of the Valley.", {"color": "4a4a42"}],
				["panel", 320, 120, "Ice ages", "At least three times, glaciers filled the Valley, the largest reaching nearly to Glacier Point's rim. The last one melted about 15,000 years ago.", {"color": "4a4a42", "picture": "painting"}],
				["read", "relief", 192, 180, {"w": 64, "look": "glacier"}, "The view in miniature",
					"Half Dome, Clouds Rest, Nevada and Vernal falls and the Valley floor in granite and paint, so you can match the model to the real thing outside."],
				["bench", 80, 200, {"w": 48}], ["bench", 304, 200, {"w": 48}],
			]},
	]


func _el_portal_rooms() -> Array:
	const E := "el_portal"
	return [
		{"id": "el_portal_market", "name": "El Portal Market", "size": Vector2i(30, 17), "rows": 4, "seed": 111,
			"outside": {"region": E, "node": "Market", "hours": Vector2i(7, 21)},
			"floor": ["tile", "c8c0a8", "8a8070"], "wall": ["boards", "8a6440"],
			"deco": [["shelf", 24, 20, 150, "goods"], ["shelf", 24, 40, 150, "goods"], ["shelf", 306, 20, 150, "goods"], ["shelf", 306, 40, 150, "goods"],
				["sign", 240, 6, "EL PORTAL MARKET"], ["board", 214, 22, 52, 30]],
			"props": [
				["counter", 400, 132, {"w": 72, "register": true, "items": ["jars"], "look": "market"}],
				["shelf", 120, 150, {}], ["shelf", 120, 214, {}], ["shelf", 240, 150, {}], ["shelf", 240, 214, {}],
				["cooler", 48, 104, {}], ["cooler", 80, 104, {}],
				["barrels", 440, 240, {}], ["crates", 420, 190, {}],
				["sign", 330, 104, "Last stop for groceries", "The last full store before the park boundary. The town grew up at the end of the Yosemite Valley Railroad, which ran from Merced to El Portal from 1907 to 1945."],
			]},
		{"id": "el_portal_post_office", "name": "El Portal Post Office", "size": Vector2i(24, 14), "rows": 4, "seed": 113,
			"outside": {"region": E, "node": "PostOffice", "hours": Vector2i(9, 17)},
			"floor": ["tile", "c8bca0", "8a7a5a"], "wall": ["lap", "d8ccb0"], "wainscot": "4a5a6a",
			"deco": [["pboxes", 24, 12, 100, 40], ["flag", 150, 12], ["clock", 200, 22], ["frame", 260, 14, 60, 36, "notice"], ["sign", 200, 42, "U.S. MAIL"]],
			"props": [
				["counter", 220, 104, {"w": 96, "items": ["scale"], "wood": "5a3e28", "top": "8a6a4a"}],
				["desk", 80, 170, {"w": 48, "look": "writing", "items": "papers"}],
				["sign", 320, 172, "El Portal, CA 95318", "The post office serves the park's staff houses down here on the river. Mail for the Valley used to come up by rail and then by stage."],
			]},
		{"id": "yosemite_view_lodge", "name": "Yosemite View Lodge", "size": Vector2i(30, 17), "rows": 5, "seed": 117,
			"outside": {"region": E, "node": "Lodge", "nodes": ["Lodge", "LodgeB"]},
			"floor": ["carpet", "4a5a4a", "c89a3a"], "wall": ["stone", "8a8278"], "side": "6a4a30",
			"deco": [["tall_window", 180, 120, "forest"], ["sign", 100, 10, "FRONT DESK"], ["frame", 360, 16, 60, 40, "painting"]],
			"rugs": [[180, 160, 120, 50, "6a3a2a", "e8d8a8", "2f4a34"]],
			"props": [
				["counter", 100, 112, {"w": 96, "bell": true, "books": true}],
				["hearth", 400, 104, {"w": 48, "h": 56, "look": "small"}],
				["sofa", 240, 160, {"w": 56, "color": "3a5a4a"}],
				["armchair", 170, 196, {"color": "6a3a2a"}], ["armchair", 310, 196, {"color": "6a3a2a"}],
				["coffee_table", 240, 200, {}],
				["luggage", 60, 236, {}], ["plant", 440, 236, {}],
				["sign", 400, 220, "On the Merced", "The lodge sits right on the Merced River at the park's western edge. In spring the river roars past the rooms; by fall you can wade it."],
			]},
	]


func _wawona_rooms() -> Array:
	const W := "wawona"
	return [
		{"id": "wawona_store", "name": "Wawona Store", "size": Vector2i(30, 17), "rows": 4, "seed": 121,
			"outside": {"region": W, "node": "Store", "hours": Vector2i(8, 20)},
			"floor": ["planks", "9a7048"], "wall": ["boards", "7a5232"],
			"deco": [["shelf", 24, 20, 160, "goods"], ["shelf", 24, 40, 160, "goods"], ["shelf", 296, 20, 160, "goods"], ["shelf", 296, 40, 160, "goods"],
				["sign", 240, 6, "WAWONA STORE"], ["frame", 220, 22, 40, 28, "photo"]],
			"props": [
				["counter", 240, 104, {"w": 96, "register": true, "items": ["jars"]}],
				["stove", 120, 160, {}],
				["barrels", 380, 160, {}], ["crates", 420, 220, {}],
				["shelf", 80, 214, {}], ["postcards", 300, 236, {}], ["cooler", 440, 104, {}],
				["sign", 170, 104, "Wawona", "Wawona is Miwok for 'big tree', or perhaps for the hoot of the owl that guards the sequoias. Stage travelers to the Valley rested here overnight."],
			]},
		{"id": "wawona_hotel_lobby", "name": "Wawona Hotel", "size": Vector2i(32, 17), "rows": 5, "seed": 123,
			"outside": {"region": W, "node": "WawonaHotel"},
			"floor": ["carpet", "6a2a2a", "c89a3a"], "wall": ["lap", "f0e8d4"], "wainscot": "2f4a34", "side": "e0d8c4", "mat": "2f4a34",
			"deco": [["window", 160, 12, 30, 44, 60, 10], ["window", 330, 12, 30, 44, 60, -10], ["frame", 220, 12, 70, 40, "painting"],
				["frame", 40, 16, 40, 30, "portrait"], ["sign", 120, 8, "REGISTER"], ["sconce", 200, 30], ["sconce", 310, 30]],
			"rugs": [[200, 150, 120, 60, "2f4a34", "e8d8a8", "6a2a2a"]],
			"doors": [{"side": "right", "row": 12, "to": "wawona_hotel_dining", "spawn": "from_lobby", "label": "Dining Room", "spot": "from_dining"}],
			"props": [
				["counter", 110, 112, {"w": 88, "bell": true, "books": true, "wood": "5a3a22"}],
				["read", "piano", 430, 112, {"color": "3a2418", "look": "parlor"}, "The parlor piano",
					"For decades a pianist has played old songs of Yosemite and the West in the hotel's Sun Room in the evenings, and the guests sing along."],
				["sofa", 260, 160, {"w": 56, "color": "8a2f2f", "pattern": true, "look": "parlor"}],
				["armchair", 196, 196, {"color": "2f4a34"}], ["armchair", 324, 196, {"color": "2f4a34"}],
				["coffee_table", 260, 200, {}],
				["sign", 60, 220, "The Wawona Hotel", "The main hotel building opened in 1879, on the site of Galen Clark's station, where he had fed and housed travelers since the 1850s. The Washburn brothers built it up into a summer resort with a golf course, a lawn and a fountain, and the stages to the Valley stopped here."],
				["plant", 40, 128, {}], ["lamp", 470, 236, {}],
			]},
		{"id": "wawona_hotel_dining", "name": "Wawona Hotel: Dining Room", "size": Vector2i(32, 17), "rows": 5, "seed": 125,
			"floor": ["planks", "8a6440"], "wall": ["lap", "f0e8d4"], "wainscot": "2f4a34", "side": "e0d8c4", "mat": "2f4a34",
			"deco": [["window", 40, 12, 40, 50, 60, 20], ["window", 140, 12, 40, 50, 60, 10], ["window", 330, 12, 40, 50, 60, -10], ["window", 430, 12, 40, 50, 60, -20],
				["frame", 236, 14, 40, 30, "painting"]],
			"doors": [{"side": "left", "row": 12, "to": "wawona_hotel_lobby", "spawn": "from_dining", "label": "Lobby", "spot": "from_lobby"}],
			"props": [
				["table_round", 120, 160, {"cloth": "f0ece0", "set": "dinner", "look": "linen", "w": 34}],
				["table_round", 256, 160, {"cloth": "f0ece0", "set": "dinner", "look": "linen", "w": 34}],
				["table_round", 392, 160, {"cloth": "f0ece0", "set": "dinner", "look": "linen", "w": 34}],
				["table_round", 120, 226, {"cloth": "f0ece0", "set": "dinner", "look": "linen", "w": 34}],
				["table_round", 256, 226, {"cloth": "f0ece0", "set": "dinner", "look": "linen", "w": 34}],
				["table_round", 392, 226, {"cloth": "f0ece0", "set": "dinner", "look": "linen", "w": 34}],
				["chair", 96, 158, {}], ["chair", 144, 158, {}], ["chair", 232, 158, {}], ["chair", 280, 158, {}], ["chair", 368, 158, {}], ["chair", 416, 158, {}],
				["chair", 96, 224, {}], ["chair", 144, 224, {}], ["chair", 368, 224, {}], ["chair", 416, 224, {}],
				["sign", 256, 110, "The dining room", "Tall windows on three sides look out on the lawn and the meadow. Stage passengers ate here before the last climb to the Valley."],
			]},
		{"id": "hill_studio", "name": "Thomas Hill's Studio", "size": Vector2i(26, 15), "rows": 5, "seed": 127,
			"outside": {"region": W, "node": "HillStudio", "hours": Vector2i(9, 17)},
			"floor": ["planks", "9a7048"], "wall": ["lap", "f0e8d4"], "side": "e0d8c4",
			"deco": [["frame", 24, 6, 110, 60, "painting"], ["frame", 156, 14, 50, 36, "painting"], ["frame", 230, 10, 70, 44, "painting"], ["frame", 320, 16, 60, 40, "painting"]],
			"rugs": [[140, 130, 130, 50, "6a3a20", "e8d8a8", "2f4a34"]],
			"props": [
				["read", "easel", 120, 150, {"painting": "painting"}, "Thomas Hill",
					"Thomas Hill painted Yosemite for half a century, in canvases as big as the walls. He came to Wawona in 1886, built this studio beside the hotel his daughter's husband ran, and painted and sold his work here until he died in 1908."],
				["easel", 300, 150, {"painting": "painting", "look": "two"}],
				["table_long", 208, 196, {"w": 56, "set": "papers", "look": "paints"}],
				["chair", 330, 200, {}],
				["sign", 64, 200, "Driving the Last Spike", "Hill's most famous painting isn't of Yosemite at all: it shows the golden spike being driven at Promontory Summit in 1869 to finish the transcontinental railroad."],
			]},
		{"id": "clark_cottage", "name": "Clark Cottage", "size": Vector2i(26, 15), "rows": 5, "seed": 129,
			"outside": {"region": W, "node": "ClarkCottage"},
			"floor": ["planks", "8a6440"], "wall": ["lap", "f0e8d4"], "wainscot": "2f4a34", "side": "e0d8c4",
			"deco": [["window", 180, 14, 50, 44, 60, 0], ["frame", 60, 16, 40, 32, "portrait"], ["frame", 310, 16, 50, 34, "painting"]],
			"rugs": [[130, 150, 150, 50, "2f4a34", "e8d8a8", "6a2a2a"]],
			"props": [
				["bed", 80, 140, {"color": "f0e8d4", "wood": "4a2a1a", "look": "white"}],
				["bed", 330, 140, {"color": "2f4a34", "wood": "4a2a1a", "look": "green"}],
				["washstand", 210, 104, {}],
				["dresser", 140, 104, {"wood": "4a2a1a", "mirror": true, "look": "mirror"}],
				["trunk", 270, 200, {"color": "3a2a1e", "look": "dark"}],
				["read", "chair", 360, 200, {}, "Clark Cottage",
					"The oldest building in the Wawona Hotel's group, put up in the 1870s and named for Galen Clark, who homesteaded here in 1856 and was the first guardian of the Yosemite Grant."],
			]},
		{"id": "washburn_cottage", "name": "Washburn Cottage", "size": Vector2i(28, 15), "rows": 5, "seed": 131,
			"outside": {"region": W, "node": "WashburnCottage"},
			"floor": ["carpet", "5a4a3a", "c89a3a"], "wall": ["lap", "f0e8d4"], "wainscot": "6a2a2a", "side": "e0d8c4",
			"deco": [["window", 60, 14, 40, 46, 60, 10], ["window", 340, 14, 40, 46, 60, -10], ["frame", 180, 14, 80, 44, "painting"], ["sconce", 140, 30], ["sconce", 300, 30]],
			"rugs": [[150, 140, 150, 56, "6a2a2a", "e8d8a8", "2f4a34"]],
			"props": [
				["sofa", 224, 140, {"w": 56, "color": "6a2a2a", "pattern": true, "look": "rose"}],
				["armchair", 160, 180, {"color": "c89a3a", "look": "gold"}], ["armchair", 288, 180, {"color": "c89a3a", "look": "gold"}],
				["coffee_table", 224, 184, {}],
				["desk", 380, 200, {"w": 40, "items": "lamp", "look": "lamp"}],
				["read", "bookcase", 60, 110, {"w": 34}, "The Washburns",
					"Henry, John and Edward Washburn bought Clark's station in 1875 and ran the Wawona for three generations. They built the stage road on to the Valley and kept a string of fine horses for it."],
				["lamp", 400, 120, {}],
			]},
		{"id": "hodgdon_cabin", "name": "Hodgdon Homestead Cabin", "size": Vector2i(22, 13), "rows": 4, "seed": 133,
			"outside": {"region": W, "node": "HomesteadCabin", "hours": Vector2i(9, 17)},
			"floor": ["planks", "7a5232"], "wall": ["logs", "7a4f31"], "light": 0.85,
			"deco": [["window", 260, 14, 24, 24, 50, -10], ["pegs", 30, 24, 70, "coats"], ["shelf", 130, 18, 80, "crockery"]],
			"rugs": [[120, 120, 100, 40, "8a2f2f", "c89a3a", "3a2a1e"]],
			"props": [
				["stove", 200, 84, {}],
				["bed", 60, 130, {"color": "8a2f2f", "look": "quilt"}],
				["table_long", 210, 140, {"w": 48, "look": "plain"}],
				["chair", 184, 156, {}], ["chair", 236, 156, {}],
				["washstand", 300, 84, {}],
				["read", "trunk", 300, 170, {}, "A homestead cabin",
					"Jeremiah Hodgdon built this log cabin in 1879 at Aspen Valley, up near the Tioga Road, as a summer place for his family and his cattle. It was moved here with the other old buildings of the park to show how its first settlers lived."],
			]},
		{"id": "wells_fargo", "name": "Wells Fargo Office", "size": Vector2i(22, 13), "rows": 4, "seed": 135,
			"outside": {"region": W, "node": "WellsFargo", "hours": Vector2i(9, 17)},
			"floor": ["planks", "8a6440"], "wall": ["boards", "8a6440"],
			"deco": [["frame", 30, 10, 24, 30, "wanted"], ["frame", 66, 10, 24, 30, "wanted"], ["sign", 176, 6, "WELLS FARGO & CO"], ["clock", 176, 24],
				["frame", 260, 12, 60, 30, "map"]],
			"props": [
				["counter", 176, 100, {"w": 112, "items": ["scale"], "wood": "5a3a22"}],
				["read", "safe", 300, 100, {}, "The express office",
					"Wells Fargo carried the mail, gold and parcels on the stage roads, and its agent kept the express office where the stages stopped. Stage robberies were common enough on the Wawona Road that the company kept its wanted posters fresh."],
				["desk", 60, 160, {"w": 40, "items": "telegraph", "look": "telegraph"}],
				["bench", 240, 180, {"w": 48}],
			]},
		{"id": "artist_studio", "name": "Artist's Studio", "size": Vector2i(22, 13), "rows": 4, "seed": 137,
			"outside": {"region": W, "node": "ArtistStudio", "hours": Vector2i(9, 17)},
			"floor": ["planks", "9a7048"], "wall": ["boards", "a0784a"],
			"deco": [["window", 140, 10, 64, 40, 60, 0], ["frame", 30, 14, 50, 34, "painting"], ["frame", 260, 14, 50, 34, "painting"]],
			"props": [
				["read", "easel", 110, 140, {"painting": "painting", "look": "half"}, "An artist's studio",
					"In the late 1800s painters came to Wawona and the Valley every summer and sold their work to the tourists who came in on the stage. Their big paintings and the early photographs did as much as anything to get Yosemite protected."],
				["easel", 240, 140, {"painting": "painting", "look": "two"}],
				["table_long", 176, 104, {"w": 48, "set": "papers", "look": "paints"}],
				["stool", 60, 180, {}],
			]},
		{"id": "blacksmith_shop", "name": "Blacksmith's Shop", "size": Vector2i(24, 14), "rows": 4, "seed": 139,
			"outside": {"region": W, "node": "Blacksmith", "hours": Vector2i(9, 17)},
			"floor": ["dirt", "6a5a48"], "wall": ["boards", "6a4a30"], "light": 0.85,
			"deco": [["pegs", 24, 20, 120, "smithy"], ["pegs", 230, 20, 130, "smithy"]],
			"props": [
				["read", "forge", 192, 96, {}, "The forge",
					"Stage lines and freight wagons needed a smith: horseshoes, wagon tires and iron fittings were made and mended over a coal forge like this one, with a hand bellows to bring up the heat."],
				["anvil", 192, 150, {}],
				["workbench", 70, 140, {}],
				["barrels", 330, 120, {}],
				["crates", 320, 190, {}],
			]},
		{"id": "wawona_jail", "name": "Jail", "size": Vector2i(18, 12), "rows": 4, "seed": 141,
			"outside": {"region": W, "node": "Jail", "hours": Vector2i(9, 17)},
			"floor": ["planks", "6a5a48"], "wall": ["boards", "6a5a48"], "light": 0.75,
			"deco": [["bars", 160, 110, 8], ["frame", 30, 14, 24, 30, "wanted"], ["frame", 66, 14, 24, 30, "wanted"]],
			"props": [
				["read", "cot", 220, 110, {}, "The jail",
					"A one-room lockup of rough boards with a barred cell. Most nights it held a stage passenger who had celebrated too hard at the hotel, or a cowboy with a temper."],
				["desk", 80, 120, {"w": 40}],
				["chair", 80, 150, {}],
			]},
		{"id": "grove_museum", "name": "Mariposa Grove Museum", "size": Vector2i(24, 14), "rows": 4, "seed": 143,
			"outside": {"region": W, "node": "GroveMuseum", "hours": Vector2i(9, 17)},
			"floor": ["planks", "8a6440"], "wall": ["logs", "7a4f31"],
			"deco": [["frame", 30, 10, 60, 34, "photo"], ["frame", 290, 10, 60, 34, "photo"], ["sign", 192, 6, "MARIPOSA GROVE"], ["window", 160, 18, 64, 30, 50, 0]],
			"props": [
				["read", "case", 192, 120, {"w": 72, "contents": "minerals", "look": "cones"}, "Sequoia cones",
					"A giant sequoia's cone is only the size of a hen's egg, and its seeds are as small as flakes of oatmeal. Cones can hang green on the tree for twenty years; fire opens them and clears the ground the seedlings need."],
				["panel", 70, 160, "Galen Clark's cabin", "This cabin was built in 1930 in the style of the one Galen Clark built in the grove. He found the grove in 1857 and spent much of his life guarding it.", {"color": "3a2a1e"}],
				["panel", 314, 160, "The Grizzly Giant", "The Grizzly Giant is around 3,000 years old, one of the oldest living trees in the grove. It was already huge when the Valley's people first named it.", {"color": "3a2a1e", "picture": "painting"}],
				["bench", 192, 160, {"w": 48}],
			]},
	]


func _tuolumne_rooms() -> Array:
	const TM := "tuolumne_meadows"
	return [
		{"id": "parsons_lodge", "name": "Parsons Memorial Lodge", "size": Vector2i(28, 15), "rows": 5, "seed": 151,
			"outside": {"region": TM, "node": "ParsonsLodge", "hours": Vector2i(10, 17)},
			"floor": ["stone", "9a9284"], "wall": ["granite", "8a8278"], "beams": true, "light": 0.9,
			"deco": [["window", 40, 16, 30, 36, 50, 10], ["window", 378, 16, 30, 36, 50, -10], ["frame", 100, 14, 50, 36, "photo"], ["frame", 300, 14, 50, 36, "photo"]],
			"rugs": [[150, 140, 150, 50, "6a3a20", "e8d8a8", "2f4a34"]],
			"props": [
				["read", "hearth", 224, 102, {"w": 64, "h": 66, "look": "lodge"}, "Parsons Memorial Lodge",
					"The Sierra Club built this lodge of the meadow's own granite in 1915, in memory of Edward Taylor Parsons, a club director who loved Tuolumne. The club had fought to save Hetch Hetchy, just north of here, and lost it to a dam two years before."],
				["bench", 160, 170, {"w": 56, "back": true}], ["bench", 288, 170, {"w": 56, "back": true}],
				["bench", 160, 206, {"w": 56, "back": true}], ["bench", 288, 206, {"w": 56, "back": true}],
				["bookcase", 60, 110, {"w": 34}], ["bookcase", 388, 110, {"w": 34, "look": "curios"}],
			]},
		{"id": "mccauley_cabin", "name": "McCauley Cabin", "size": Vector2i(22, 13), "rows": 4, "seed": 153,
			"outside": {"region": TM, "node": "McCauleyCabin", "hours": Vector2i(9, 17)},
			"floor": ["planks", "7a5232"], "wall": ["logs", "7a4f31"], "light": 0.85,
			"deco": [["window", 140, 14, 30, 24, 50, 0], ["pegs", 30, 24, 80, "coats"], ["shelf", 220, 18, 100, "crockery"]],
			"props": [
				["stove", 280, 84, {}],
				["cot", 50, 140, {}], ["cot", 80, 140, {"color": "8a5a3a", "look": "brown"}],
				["table_long", 210, 140, {"w": 48, "look": "plain"}],
				["chair", 184, 156, {}], ["chair", 236, 156, {}],
				["read", "trunk", 300, 170, {}, "The McCauley Cabin",
					"A log cabin from the turn of the century, when the McCauley family ran cattle in Tuolumne's meadows in summer. Soda Springs bubbles up in its log enclosure just outside."],
			]},
		{"id": "tuolumne_visitor_center", "name": "Tuolumne Meadows Visitor Center", "size": Vector2i(30, 17), "rows": 4, "seed": 155,
			"outside": {"region": TM, "node": "VisitorCenter", "hours": Vector2i(9, 17)},
			"floor": ["planks", "8e6a46"], "wall": ["stone", "8a8278"], "beams": true,
			"deco": [["frame", 40, 10, 100, 40, "map"], ["frame", 340, 10, 100, 40, "painting"], ["sign", 240, 6, "TUOLUMNE MEADOWS"], ["window", 200, 18, 80, 30, 60, 0]],
			"rugs": [[180, 150, 120, 50, "2f4a34", "e8d8a8", "6a3a2a"]],
			"props": [
				["counter", 240, 104, {"w": 96, "books": true}],
				["read", "relief", 240, 190, {"w": 72, "look": "tuolumne"}, "Tuolumne's ice",
					"A great ice cap once covered all of this, a thousand feet deep, and its glaciers flowed out of here down the Tuolumne and Merced canyons. The domes around the meadow, like Lembert and Pothole, are rounded on the side the ice came from and plucked steep on the far side."],
				["panel", 92, 150, "Tuolumne Meadows", "At 8,600 feet, Tuolumne Meadows is one of the largest high meadows in the Sierra Nevada. Snow covers it from November to June, and the Tioga Road over it closes all winter.", {"color": "3a4a3a", "picture": "painting"}],
				["case", 388, 150, {"w": 56, "contents": "books", "look": "books"}],
				["bench", 92, 236, {"w": 48, "back": true}], ["bench", 388, 236, {"w": 48, "back": true}],
			]},
		{"id": "tuolumne_store", "name": "Tuolumne Meadows Store & Grill", "size": Vector2i(30, 17), "rows": 4, "seed": 157,
			"outside": {"region": TM, "node": "Store", "hours": Vector2i(8, 20)},
			"floor": ["planks", "9a7048"], "wall": ["canvas", "e8e0cc"], "side": "d8d0bc",
			"deco": [["shelf", 30, 22, 140, "goods"], ["shelf", 30, 42, 140, "goods"], ["frame", 220, 14, 60, 36, "menu"], ["shelf", 310, 22, 140, "goods"]],
			"props": [
				["counter", 380, 110, {"w": 96, "register": true, "items": ["cups", "lamp"], "top": "b8b0a0", "look": "grill"}],
				["shelf", 100, 150, {}], ["shelf", 100, 214, {}],
				["cooler", 240, 104, {}],
				["table_long", 330, 190, {"w": 64, "look": "picnic"}], ["bench", 330, 206, {"w": 64}],
				["table_long", 330, 240, {"w": 64, "look": "picnic"}],
				["stove", 200, 236, {}],
				["sign", 260, 104, "Under canvas", "The store and grill stand under a canvas roof on a frame, packed up every fall before the snow and put back up when the Tioga Road opens. Climbers and backpackers swap news over burgers out front."],
			]},
		{"id": "tuolumne_lodge", "name": "Tuolumne Meadows Lodge", "size": Vector2i(30, 17), "rows": 4, "seed": 159,
			"outside": {"region": TM, "node": "LodgeTent", "hours": Vector2i(6, 22)},
			"floor": ["planks", "8a6440"], "wall": ["canvas", "e8e0cc"], "side": "d8d0bc",
			"deco": [["frame", 200, 12, 80, 36, "menu"], ["pegs", 40, 30, 120, "kitchen"], ["pegs", 320, 30, 120, "coats"]],
			"props": [
				["stove", 80, 104, {}], ["stove", 400, 104, {}],
				["table_long", 150, 150, {"w": 112, "cloth": "c8402e", "set": "dinner", "look": "check"}],
				["table_long", 330, 150, {"w": 112, "cloth": "c8402e", "set": "dinner", "look": "check"}],
				["table_long", 150, 214, {"w": 112, "cloth": "c8402e", "set": "dinner", "look": "check"}],
				["table_long", 330, 214, {"w": 112, "cloth": "c8402e", "set": "dinner", "look": "check"}],
				["bench", 150, 166, {"w": 104}], ["bench", 330, 166, {"w": 104}], ["bench", 150, 230, {"w": 104}], ["bench", 330, 230, {"w": 104}],
				["sign", 240, 104, "The dining tent", "The lodge's guests sleep in canvas tent cabins on the Dana Fork and eat family-style here, at long tables by the wood stoves. Breakfast before the Lyell Canyon trail, supper after."],
			]},
	]
