class_name AhwahneeStyle
extends HubBuilder
## The Ahwahnee look, shared by every hand-made Valley area: the painted
## ground (ahwahnee_ground.gd), the mature trees, plants, rocks and logs
## (ahwahnee_flora_art.gd), and the helpers that scatter them over a terrain
## grid. build_ahwahnee.gd, build_yosemite_village.gd and
## build_curry_village.gd all extend this, so a new area picks up the same
## palette, lighting and dressing by calling load_flora(), _save_ground_art(),
## _fringe_trees() and _scatter_decor().

const Ground = preload("res://tools/hubs/ahwahnee_ground.gd")
const S := "res://assets/sprites/ahwahnee/"

var _flora_consts := {}
var _flora_files: Array = []
var _trunks := {}
var _painter: Ground


## Draws the Ahwahnee flora sprites and reads their collision footprints.
func load_flora() -> void:
	var script: GDScript = load("res://tools/hubs/ahwahnee_flora_art.gd")
	script.new().save_all()
	_flora_consts = script.get_script_constant_map()
	_trunks = _flora_consts.get("TRUNKS", {})
	_flora_files = _flora_consts.get("FILES", [])


# ---------------------------------------------------------------- helpers

func _has(sprite_name: String, dir := S) -> bool:
	return FileAccess.file_exists(ProjectSettings.globalize_path(dir + sprite_name + ".png"))


## Every sprite whose name starts with [param prefix], from the flora list.
func _variants(prefix: String) -> Array:
	var out := []
	for f in _flora_files:
		if f.begins_with(prefix) and _has(f):
			out.append(f)
	return out


func _pick(prefix: String) -> String:
	var v := _variants(prefix)
	return "" if v.is_empty() else v[rng.randi() % v.size()]


## A flora prop at a pixel position; collides if it has a trunk footprint.
func _prop(sprite_name: String, at_pos: Vector2, node_name := "") -> StaticBody2D:
	if sprite_name == "" or not _has(sprite_name):
		return null
	var fp: Vector2 = _trunks.get(sprite_name, Vector2.ZERO)
	var feet: Array = [base_rect(fp)] if fp.x > 0 else []
	for extra: Rect2 in _flora_consts.get("EXTRA_FOOTPRINTS", {}).get(sprite_name, []):
		feet.append(extra)
	var body := prop_body(node_name if node_name != "" else sprite_name.to_pascal_case() + str(_entities.get_child_count()),
		S + sprite_name + ".png", feet)
	# The art's ground line sits a few pixels above the image bottom.
	(body.get_node("Sprite") as Sprite2D).offset.y += int(_flora_consts.get("BASE_INSET", 3))
	body.position = at_pos
	_entities.add_child(body)
	return body


func _tile_of(pos: Vector2) -> Vector2i:
	return Vector2i(pos / T)


## True if the tile and a margin around it are all one of [param types].
func _all_kind(tx: int, ty: int, types: Array, margin := 0) -> bool:
	for dy in range(-margin, margin + 1):
		for dx in range(-margin, margin + 1):
			if not at(tx + dx, ty + dy) in types:
				return false
	return true


func _any_kind(tx: int, ty: int, types: Array, margin: int) -> bool:
	for dy in range(-margin, margin + 1):
		for dx in range(-margin, margin + 1):
			if at(tx + dx, ty + dy) in types:
				return true
	return false


func _smooth(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Draws a trail through [param points] (tile coordinates) with a brush
## [param width] tiles wide.
func _path(points: Array, width: int, type: int, jitter := 0.0) -> void:
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var steps := int(a.distance_to(b) * 2.0) + 1
		for s in steps + 1:
			var p := a.lerp(b, float(s) / steps)
			p += Vector2(noise.get_noise_2d(p.x * 3.0, p.y * 3.0), noise.get_noise_2d(p.y * 3.0 + 50.0, p.x * 3.0)) * jitter
			for dy in range(0, width):
				for dx in range(0, width):
					put(floori(p.x) + dx, floori(p.y) + dy, type)


func _ellipse(cx: float, cy: float, rx: float, ry: float, type: int, edge_noise := 0.0, only_over: Array = []) -> void:
	for y in range(floori(cy - ry - 2), ceili(cy + ry + 3)):
		for x in range(floori(cx - rx - 2), ceili(cx + rx + 3)):
			var e := pow((x + 0.5 - cx) / rx, 2.0) + pow((y + 0.5 - cy) / ry, 2.0)
			e += noise.get_noise_2d(x * 2.0, y * 2.0) * edge_noise
			if e < 1.0 and (only_over.is_empty() or at(x, y) in only_over):
				put(x, y, type)


func _save_ground_art(file_name: String, seed_value: int, rings := [], soils: Array[Rect2i] = []) -> Sprite2D:
	_painter = Ground.new()
	_painter.rings = rings
	_painter.soils = soils
	var im := _painter.paint(kind, w, h, seed_value)
	var path := ProjectSettings.globalize_path(S + file_name + ".png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	im.save_png(path)
	import_assets()
	var sprite := Sprite2D.new()
	sprite.name = "GroundArt"
	sprite.texture = texture(S + file_name + ".png")
	sprite.centered = false
	sprite.z_index = -9
	_root.add_child(sprite)
	_root.move_child(sprite, 0)
	_ground.visible = false
	return sprite


## The back layer sprites (walls, bridges) live here, under the entities.
func _backdrop(sprite_name: String, at_pos: Vector2, z := -8, dir := S) -> Sprite2D:
	if not _has(sprite_name, dir):
		return null
	var sprite := Sprite2D.new()
	sprite.name = sprite_name.to_pascal_case()
	sprite.texture = texture(dir + sprite_name + ".png")
	sprite.centered = false
	sprite.position = at_pos
	sprite.z_index = z
	_root.add_child(sprite)
	return sprite


## Shows a painting of the far view through an overlook's drop (drawn by
## GlacierArt.view_below), with the vista shader.
## The rest are the shader's settings, in the game's 32px pixels (the scene
## migration leaves shader settings as they are): [param anchor] is the
## camera's top-left at the overlook, where the screen's top-left shows the
## painting's pixel [param offset]; [param falls] holds [top, bottom,
## half widths] of each waterfall in the painting, for the shimmer.
func _vista(sprite: Sprite2D, painting_path: String, anchor: Vector2, offset: Vector2, parallax: Vector2, falls: Array) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/vista.gdshader")
	mat.set_shader_parameter("painting", load(painting_path))
	mat.set_shader_parameter("anchor", anchor)
	mat.set_shader_parameter("offset", offset)
	mat.set_shader_parameter("parallax", parallax)
	var lines := PackedVector4Array()
	var widths := PackedVector2Array()
	for f: Array in falls:
		lines.append(Vector4(f[0].x, f[0].y, f[1].x, f[1].y))
		widths.append(f[2])
	lines.resize(6)
	widths.resize(6)
	mat.set_shader_parameter("falls", lines)
	mat.set_shader_parameter("fall_widths", widths)
	mat.set_shader_parameter("fall_count", falls.size())
	sprite.material = mat


func _glow(sprite_name: String, at_pos: Vector2, glow_scale := 1.0, dir := S) -> void:
	if not _has(sprite_name, dir):
		return
	var g := Sprite2D.new()
	g.name = sprite_name.to_pascal_case()
	g.texture = texture(dir + sprite_name + ".png")
	g.centered = false
	g.position = at_pos
	g.z_index = 4
	g.set_script(load("res://scripts/world/night_glow.gd"))
	g.set("strength", glow_scale)
	_root.add_child(g)


## Living touches from scripts/world/ambient_fx.gd: mist, fireflies, sparks.
func _ambient(node_name: String, effect: String, at_pos: Vector2, area: Vector2) -> void:
	var fx := CPUParticles2D.new()
	fx.name = node_name
	fx.set_script(load("res://scripts/world/ambient_fx.gd"))
	fx.set("effect", effect)
	fx.set("area", area)
	fx.position = at_pos
	fx.z_index = 6
	_root.add_child(fx)


func _info(prop_name: String, at_pos: Vector2, size: Vector2, title: String, text: String) -> StaticBody2D:
	## A reading spot with no sprite of its own (a sign painted on something).
	var body := StaticBody2D.new()
	body.name = prop_name
	body.collision_mask = 0
	body.collision_layer = 0
	body.set_script(load("res://scripts/objects/info_sign.gd"))
	body.set("title", title)
	body.set("text", text)
	body.position = at_pos
	_hitbox(body, size)
	_entities.add_child(body)
	return body


func _info_sign(prop_name: String, at_pos: Vector2, title: String, text: String) -> StaticBody2D:
	return sign_prop(prop_name, "res://assets/sprites/info_sign.png", at_pos, Vector2(12, 4), title, text)


func _fringe_trees(zone_kinds: Array, cell: int, keep: float, table: Array, clear_r := 1, min_gap := 20.0, pad_margin := 0) -> int:
	## Scatters trees from [param table] ([prefix, weight] pairs) on a jittered
	## grid over tiles whose ground is in [param zone_kinds].
	var placed: Array[Vector2] = []
	var count := 0
	var total := 0.0
	for e: Array in table:
		total += e[1]
	for cy in range(0, h, cell):
		for cx in range(0, w, cell):
			if rng.randf() > keep:
				continue
			var tx := cx + rng.randi_range(0, cell - 1)
			var ty := cy + rng.randi_range(0, cell - 1)
			if tx < 0 or ty < 0 or tx >= w or ty >= h:
				continue
			if not at(tx, ty) in zone_kinds or no_trees[ty * w + tx]:
				continue
			if _any_kind(tx, ty, [Terrain.RIVER, Terrain.LAKE, Terrain.CREEK, Terrain.BRIDGE, Terrain.TRAIL, Terrain.PAVED, Terrain.PARKING, Terrain.ROAD, Terrain.CLIFF], clear_r):
				continue
			var pos := Vector2(tx * T + rng.randf_range(2.0, 14.0), (ty + 1) * T - rng.randf_range(0.0, 4.0))
			var ok := true
			for p in placed:
				if p.distance_to(pos) < min_gap:
					ok = false
					break
			if not ok:
				continue
			var roll := rng.randf() * total
			var pick_prefix: String = table[-1][0]
			for e: Array in table:
				roll -= e[1]
				if roll <= 0.0:
					pick_prefix = e[0]
					break
			var sp := _pick(pick_prefix)
			if sp == "":
				continue
			placed.append(pos)
			_prop(sp, pos)
			count += 1
	return count


func _scatter_decor(prefix: String, zone_kinds: Array, n: int, region_tiles: Rect2i, min_from_path := 1, walkthrough := true) -> void:
	var tries := 0
	var placed := 0
	while placed < n and tries < n * 30:
		tries += 1
		var tx := rng.randi_range(region_tiles.position.x, region_tiles.end.x - 1)
		var ty := rng.randi_range(region_tiles.position.y, region_tiles.end.y - 1)
		if not at(tx, ty) in zone_kinds or no_trees[ty * w + tx]:
			continue
		if _any_kind(tx, ty, [Terrain.TRAIL, Terrain.PAVED, Terrain.PARKING, Terrain.ROAD, Terrain.BRIDGE, Terrain.RIVER, Terrain.LAKE], min_from_path):
			continue
		_prop(_pick(prefix), Vector2(tx * T + rng.randf_range(2.0, 14.0), (ty + 1) * T - rng.randf_range(0.0, 5.0)))
		placed += 1


## A looping animation from numbered sprites ("prefix_0.png", "prefix_1.png"...).
func _animation(node_name: String, prefix: String, fps: float, at_pos: Vector2, z: int, dir := S) -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", fps)
	frames.set_animation_loop("default", true)
	var n := 0
	while _has("%s_%d" % [prefix, n], dir):
		frames.add_frame("default", texture("%s%s_%d.png" % [dir, prefix, n]))
		n += 1
	if n == 0:
		return null
	var anim := AnimatedSprite2D.new()
	anim.name = node_name
	anim.sprite_frames = frames
	anim.centered = false
	anim.position = at_pos
	anim.z_index = z
	anim.autoplay = "default"
	_root.add_child(anim)
	return anim


## Marks the tiles under and around every placed prop as off limits to trees
## and plants (so a building's picture is never half hidden by a trunk).
func _reserve_entities(pad := 1, front := 4) -> void:
	if no_trees.size() != w * h:
		no_trees.resize(w * h)
	for child in _entities.get_children():
		if not child is Node2D:
			continue
		var pos := (child as Node2D).position
		var reach := Rect2(pos - Vector2(T, T), Vector2(T * 2, T * 2))
		var sprite := child.get_node_or_null("Sprite") as Sprite2D
		if sprite != null and sprite.texture != null:
			var size := sprite.texture.get_size()
			reach = Rect2(pos + sprite.offset - size / 2.0 - Vector2(0, 0), size)
			reach = reach.grow(float(pad) * T)
			# Tall pieces (buildings) keep their fronts clear: a tree standing
			# in front would hide the door.
			if size.y >= 34.0:
				reach.size.y += front * T
		for ty in range(maxi(0, int(reach.position.y / T)), mini(h, int(reach.end.y / T) + 2)):
			for tx in range(maxi(0, int(reach.position.x / T)), mini(w, int(reach.end.x / T) + 1)):
				no_trees[ty * w + tx] = 1
