extends "res://tools/hubs/build_valley_floor.gd"
## What the hand-made hubs outside the Valley share (build_el_portal.gd,
## build_wawona.gd): the Valley floor builder's helpers (walls, water,
## bridges, roads out), with the foothill and Big Tree flora of
## foothill_flora_art.gd added to the Ahwahnee flora, and their oaks marked
## as oaks for foraging. Each hub's builder overrides _ready().

const FoothillFlora = preload("res://tools/hubs/foothill_flora_art.gd")


## The Ahwahnee flora plus the foothill and Big Tree flora, so _pick(),
## _prop() and _fringe_trees() scatter either.
func load_flora() -> void:
	super.load_flora()
	FoothillFlora.new().save_all()
	_trunks = _trunks.duplicate()
	_trunks.merge(FoothillFlora.TRUNKS)
	_flora_files = _flora_files.duplicate()
	_flora_files.append_array(FoothillFlora.FILES)
	var extra: Dictionary = _flora_consts.get("EXTRA_FOOTPRINTS", {}).duplicate()
	extra.merge(FoothillFlora.EXTRA_FOOTPRINTS)
	_flora_consts = _flora_consts.duplicate()
	_flora_consts["EXTRA_FOOTPRINTS"] = extra


## Starts a hub's region: like start_region, but the hub is its own.
func start_hub(node_name: String, hub: String, display_name: String, geo: Vector2) -> void:
	start_region(node_name, hub, display_name, geo)
	_root.hub_id = hub


## Every oak in the region joins the "black_oak" group, as the Valley's black
## oaks do, so the ground under them counts as oak woodland for foraging
## and the press book.
func _mark_oaks() -> void:
	for child in _entities.get_children():
		var sprite := child.get_node_or_null("Sprite") as Sprite2D
		if sprite and sprite.texture and "_oak_" in sprite.texture.resource_path.get_file():
			child.add_to_group("black_oak", true)


## A prop from [param dir] at a pixel position with the given footprints
## (Rect2s in the prop's space, y up from its base).
func _solid(node_name: String, path: String, at_pos: Vector2, feet: Array) -> StaticBody2D:
	var body := prop_body(node_name, path, feet)
	body.position = at_pos
	_entities.add_child(body)
	return body


## A building with its windows lit after dark.
func _lit(node_name: String, dir: String, sprite_name: String, tile_x: float, base_y: int, title: String, text: String) -> StaticBody2D:
	var body := building(node_name, dir + sprite_name + ".png", tile_x, base_y, title, text)
	var tex := (body.get_node("Sprite") as Sprite2D).texture
	if _has(sprite_name + "_glow", dir):
		var g := Sprite2D.new()
		g.name = node_name + "Glow"
		g.texture = texture(dir + sprite_name + "_glow.png")
		g.centered = false
		g.position = body.position - Vector2(tex.get_width() / 2.0, tex.get_height())
		g.z_index = 4
		g.set_script(load("res://scripts/world/night_glow.gd"))
		g.set("strength", 1.0)
		_root.add_child(g)
	return body


## A road off the map that only says where it goes (out of the park).
func _road_out(exit_name: String, at_pos: Vector2, size: Vector2, label: String, message: String) -> void:
	region_exit(exit_name, at_pos, size, label, "", "").set("message", message)
