class_name RadianceGI
extends CanvasLayer
## Real-time 2D Global Illumination via Radiance Cascades (High graphics only).
##
## Replaces flat unoccluded light circles with physically plausible 2D light
## transport:
##  - At night outdoors: campfires, streetlamps, lanterns, lit windows, glowing
##    tents, string lights and the player's headlamp cast soft, distance-widening
##    penumbra shadows behind trees, boulders, tents and cabins, with warm light
##    wrapping around nearby surfaces.
##  - Indoors: hearths, stoves and lamps cast living, occluded firelight around
##    furniture at night; by day, back-wall windows (RoomWindows) pour soft
##    daylight and golden-hour bounce into the room.
##  - By day outdoors: sky-visibility from the coarsest cascade adds natural
##    ambient occlusion under dense pine stands and beside boulders/walls, plus
##    a subtle warm bounce in sunlit clearings.
##
## Pipeline (all buffers 256x144 RGBA16F, resolved to 128x72):
##   1. Scene buffer: grounded occluder footprints + HDR emitters.
##   2. Jump Flood Algorithm (seed + 8 flood steps -> 2D Euclidean SDF).
##   3. Four Radiance Cascades (3 -> 2 -> 1 -> 0) sphere-tracing the SDF and
##      merging angularly coarse-to-fine.
##   4. Resolve pass (128x72) + full-screen composite on CanvasLayer 0, sitting
##      above the world canvas (so DayNight/RoomLight don't double-tint it,
##      AirGlow still blooms its bright cores, and Atmosphere grades it on
##      layer 1).
##
## Off on Low graphics (gl_compatibility) and when LitSprites.enabled is false
## (SHOT_UNLIT=1 renderer comparisons).

const GI_SIZE := Vector2i(256, 144)
const RESOLVE_SIZE := Vector2i(128, 72)
const CASCADE_COUNT := 4
const JFA_STEPS := [128, 64, 32, 16, 8, 4, 2, 1]
const RESCAN := 1.5
const MIN_OCCLUDER_HEIGHT := 20.0
const GRID_CELL := 256.0

const SEED_SHADER := preload("res://assets/shaders/gi_jfa_seed.gdshader")
const STEP_SHADER := preload("res://assets/shaders/gi_jfa_step.gdshader")
const SDF_SHADER := preload("res://assets/shaders/gi_sdf.gdshader")
const CASCADE_SHADER := preload("res://assets/shaders/gi_cascade.gdshader")
const RESOLVE_SHADER := preload("res://assets/shaders/gi_resolve.gdshader")
const COMPOSITE_SHADER := preload("res://assets/shaders/gi_composite.gdshader")

## Keywords identifying light fixtures / glow overlays that must not occlude
## their own emission.
const NON_OCCLUDER_HINTS := ["lamp", "light", "glow", "fire", "lantern", "torch", "hearth", "stove", "candle", "flame"]

## Set to false to disable GI (tests or debugging).
static var enabled := true

var _built := false
var _region: Region
var _player: Node
var _tint: CanvasModulate
var _room_light: CanvasModulate
var _scan_in := 0.0
var _view := Rect2(Vector2.ZERO, Vector2(960, 540))

var _occluders: Array[CanvasItem] = []
var _dynamic_occluders: Array[CanvasItem] = []
## Coarse 256px spatial grid of static occluders in region-local space:
## Vector2i -> Array of [CanvasItem, Rect2 (local footprint)].
var _static_grid := {}
var _static_occ_ids := PackedInt64Array()
var _lights: Array[PointLight2D] = []
var _glows: Array[Sprite2D] = []
var _room_windows: RoomWindows
## What each scanned sprite is (instance id -> KIND_*), kept for the region so
## a rescan only re-walks the tree instead of re-testing ~1000 sprites.
var _kinds := {}
const KIND_NONE := 0
const KIND_GLOW := 1
const KIND_STATIC_OCCLUDER := 2
const KIND_DYNAMIC_OCCLUDER := 3

var _viewports: Array[SubViewport] = []
var _scene_vp: SubViewport
var _scene_painter: Node2D
var _cascade_mats: Array[ShaderMaterial] = []
var _composite_rect: ColorRect
var _composite_mat: ShaderMaterial

## Cached last-sent composite uniforms so unchanged values aren't pushed every frame.
var _last_tint := Vector3(-1, -1, -1)
var _last_gi_str := -1.0
var _last_ao_str := -1.0
var _last_ao_col := Vector3(-1, -1, -1)
var _last_bounce_col := Vector3(-1, -1, -1)
var _last_bounce_str := -1.0
var _last_sky_ao := -1.0
var _watched_region: Region
var _watched_entities: Node
var _tree_dirty := true
var _force_scan_in := 12.0


## True when 2D Radiance Cascades GI is active (High graphics / Forward+).
static func active() -> bool:
	return enabled and LitSprites.active()


func _ready() -> void:
	name = "RadianceGI"
	layer = 0
	var world := get_parent()
	if world:
		if world.has_signal("region_changed"):
			world.region_changed.connect(_on_region_changed)
		_tint = world.get_node_or_null("DayNight") as CanvasModulate
		_room_light = world.get_node_or_null("RoomLight") as CanvasModulate
		_player = world.get_node_or_null("Player")
	if active():
		_build_pipeline()


func _watch_region(region: Region) -> void:
	if _watched_region == region:
		return
	if is_instance_valid(_watched_region):
		if _watched_region.child_entered_tree.is_connected(_on_tree_changed):
			_watched_region.child_entered_tree.disconnect(_on_tree_changed)
		if _watched_region.child_exiting_tree.is_connected(_on_tree_changed):
			_watched_region.child_exiting_tree.disconnect(_on_tree_changed)
	if is_instance_valid(_watched_entities):
		if _watched_entities.child_entered_tree.is_connected(_on_tree_changed):
			_watched_entities.child_entered_tree.disconnect(_on_tree_changed)
		if _watched_entities.child_exiting_tree.is_connected(_on_tree_changed):
			_watched_entities.child_exiting_tree.disconnect(_on_tree_changed)
	_watched_region = region
	_watched_entities = region.entities if region != null else null
	if _watched_region != null:
		_watched_region.child_entered_tree.connect(_on_tree_changed)
		_watched_region.child_exiting_tree.connect(_on_tree_changed)
	if _watched_entities != null:
		_watched_entities.child_entered_tree.connect(_on_tree_changed)
		_watched_entities.child_exiting_tree.connect(_on_tree_changed)


func _on_tree_changed(_node: Node) -> void:
	_tree_dirty = true


func _on_region_changed(region: Region) -> void:
	_region = region
	_watch_region(region)
	_kinds.clear()
	_static_grid.clear()
	_static_occ_ids.clear()
	_tree_dirty = false
	_force_scan_in = 12.0
	_scan_in = RESCAN
	_scan()


func _build_pipeline() -> void:
	if _built:
		return
	_built = true

	# 1. Scene buffer: grounded occluder footprints (black, a=1) + HDR emitters.
	_scene_vp = _make_vp("GIScene", GI_SIZE, true)
	_scene_painter = Node2D.new()
	_scene_painter.name = "Painter"
	_scene_painter.draw.connect(_draw_scene)
	_scene_vp.add_child(_scene_painter)

	# 2. Jump Flood Algorithm (seed + 8 flood steps -> SDF).
	var seed_mat := ShaderMaterial.new()
	seed_mat.shader = SEED_SHADER
	seed_mat.set_shader_parameter("scene_tex", _scene_vp.get_texture())
	var prev_vp := _make_pass_vp("GIJfaSeed", GI_SIZE, seed_mat)

	var res_vec := Vector2(GI_SIZE)
	for step_val: int in JFA_STEPS:
		var step_mat := ShaderMaterial.new()
		step_mat.shader = STEP_SHADER
		step_mat.set_shader_parameter("prev_tex", prev_vp.get_texture())
		step_mat.set_shader_parameter("resolution", res_vec)
		step_mat.set_shader_parameter("step_size", float(step_val))
		prev_vp = _make_pass_vp("GIJfa%d" % step_val, GI_SIZE, step_mat)

	var sdf_mat := ShaderMaterial.new()
	sdf_mat.shader = SDF_SHADER
	sdf_mat.set_shader_parameter("jfa_tex", prev_vp.get_texture())
	sdf_mat.set_shader_parameter("resolution", res_vec)
	sdf_mat.set_shader_parameter("max_dist", float(GI_SIZE.x))
	var sdf_vp := _make_pass_vp("GISdf", GI_SIZE, sdf_mat)

	# 3. Radiance Cascades: coarse to fine (3 -> 2 -> 1 -> 0) in tree order.
	_cascade_mats.resize(CASCADE_COUNT)
	var upper_vp: SubViewport = null
	for i in range(CASCADE_COUNT - 1, -1, -1):
		var c_mat := ShaderMaterial.new()
		c_mat.shader = CASCADE_SHADER
		c_mat.set_shader_parameter("scene_tex", _scene_vp.get_texture())
		c_mat.set_shader_parameter("sdf_tex", sdf_vp.get_texture())
		if upper_vp != null:
			c_mat.set_shader_parameter("upper_tex", upper_vp.get_texture())
		c_mat.set_shader_parameter("resolution", res_vec)
		c_mat.set_shader_parameter("max_dist", float(GI_SIZE.x))
		c_mat.set_shader_parameter("cascade_index", i)
		c_mat.set_shader_parameter("cascade_count", CASCADE_COUNT)
		c_mat.set_shader_parameter("base_length", 2.0)
		_cascade_mats[i] = c_mat
		upper_vp = _make_pass_vp("GICascade%d" % i, GI_SIZE, c_mat)

	# 4. Resolve Cascade 0 (128x72 probes) into smooth irradiance + sky AO.
	var resolve_mat := ShaderMaterial.new()
	resolve_mat.shader = RESOLVE_SHADER
	resolve_mat.set_shader_parameter("cascade0_tex", upper_vp.get_texture())
	resolve_mat.set_shader_parameter("c0_resolution", res_vec)
	resolve_mat.set_shader_parameter("probe_grid", Vector2(RESOLVE_SIZE))
	var resolve_vp := _make_pass_vp("GIResolve", RESOLVE_SIZE, resolve_mat)

	# 5. Full-screen composite on CanvasLayer 0 (before AirGlow & Atmosphere).
	_composite_rect = ColorRect.new()
	_composite_rect.name = "GIComposite"
	_composite_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_composite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_composite_mat = ShaderMaterial.new()
	_composite_mat.shader = COMPOSITE_SHADER
	_composite_mat.set_shader_parameter("gi_tex", resolve_vp.get_texture())
	_composite_rect.material = _composite_mat
	add_child(_composite_rect)


func _make_vp(vp_name: String, vp_size: Vector2i, transparent := false) -> SubViewport:
	var vp := SubViewport.new()
	vp.name = vp_name
	vp.size = vp_size
	vp.disable_3d = true
	vp.transparent_bg = transparent
	vp.use_hdr_2d = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	_viewports.append(vp)
	return vp


func _make_pass_vp(vp_name: String, vp_size: Vector2i, mat: ShaderMaterial) -> SubViewport:
	var vp := _make_vp(vp_name, vp_size, false)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.material = mat
	vp.add_child(rect)
	return vp


func _set_running(running: bool) -> void:
	if not _built:
		return
	visible = running
	var mode := SubViewport.UPDATE_ALWAYS if running else SubViewport.UPDATE_DISABLED
	for vp in _viewports:
		if vp.render_target_update_mode != mode:
			vp.render_target_update_mode = mode


func _process(delta: float) -> void:
	var is_on := active()
	if not is_on:
		_set_running(false)
		return
	if not _built:
		_build_pipeline()
	if _region == null:
		var world := get_parent()
		if world and "region" in world:
			_region = world.region
			_watch_region(_region)
			_tree_dirty = true
			_scan_in = 0.0
	if _region == null:
		_set_running(false)
		return

	_set_running(true)

	_scan_in -= delta
	_force_scan_in -= delta
	if _scan_in <= 0.0:
		_scan_in = RESCAN
		if _tree_dirty or _force_scan_in <= 0.0:
			_tree_dirty = false
			_force_scan_in = 12.0
			_scan()

	# Align the 256x144 scene buffer to the current camera view.
	_view = _view_rect()
	var sx := float(GI_SIZE.x) / maxf(_view.size.x, 1.0)
	var sy := float(GI_SIZE.y) / maxf(_view.size.y, 1.0)
	_scene_vp.canvas_transform = Transform2D(0.0, Vector2(sx, sy), 0.0, Vector2(-_view.position.x * sx, -_view.position.y * sy))
	_scene_painter.queue_redraw()

	_update_uniforms()


func _update_uniforms() -> void:
	var indoors := _region != null and _region.indoors
	var daylight := Sun.daylight()
	var golden := Sun.golden()
	var night := Sun.night()
	var weather := Weather.today()
	var clear: float = 1.0 - float(weather.clouds) * 0.7

	# Active tint on the world canvas (for albedo recovery in composite).
	var world_tint := Color.WHITE
	if not indoors and _tint and _tint.visible:
		world_tint = _tint.color
	elif indoors and _room_light and _room_light.visible:
		world_tint = _room_light.color

	# Emissive GI strength: strong at night outdoors and in dim rooms, gentle
	# during indoor daylight (window shafts) and minimal in open midday sun.
	var dark := 0.0
	if not indoors and _tint and _tint.visible:
		var lum := (_tint.color.r + _tint.color.g + _tint.color.b) / 3.0
		dark = clampf((0.92 - lum) / 0.45, 0.0, 1.0)
	elif indoors:
		dark = maxf(RoomLight.level, 0.35 * daylight)

	var gi_str := lerpf(0.18, 1.15, dark) if not indoors else lerpf(0.45, 1.1, RoomLight.level)

	# Daytime sky-occlusion AO outdoors (strongest in clear daylight, fades at night).
	var ao_str := 0.0 if indoors else (daylight * (0.55 + 0.35 * clear) * (1.0 - night))
	var high := _region != null and HighCountry.is_high(_region.region_id)
	var ao_col := Color(0.68, 0.77, 0.96) if high else Color(0.75, 0.81, 0.93)

	# Subtle warm granite / golden-hour bounce in open sunlit spaces outdoors.
	var bounce_str := 0.0 if indoors else (daylight * clear * (0.12 + 0.32 * golden))
	var bounce_col := Color(1.0, 0.95, 0.85).lerp(Color(1.0, 0.78, 0.52), golden)

	# Top cascade sky visibility weight (1.0 outdoors for AO, 0.0 indoors so
	# rooms don't get outdoor sky AO).
	var sky_ao := 0.0 if indoors else 1.0
	if sky_ao != _last_sky_ao and _cascade_mats.size() == CASCADE_COUNT and _cascade_mats[CASCADE_COUNT - 1] != null:
		_last_sky_ao = sky_ao
		var top_mat := _cascade_mats[CASCADE_COUNT - 1]
		top_mat.set_shader_parameter("sky_radiance", Vector3.ZERO)
		top_mat.set_shader_parameter("sky_ao_weight", sky_ao)

	var tint_v := Vector3(world_tint.r, world_tint.g, world_tint.b)
	if tint_v != _last_tint:
		_last_tint = tint_v
		_composite_mat.set_shader_parameter("tint", tint_v)
	if gi_str != _last_gi_str:
		_last_gi_str = gi_str
		_composite_mat.set_shader_parameter("gi_strength", gi_str)
	if ao_str != _last_ao_str:
		_last_ao_str = ao_str
		_composite_mat.set_shader_parameter("ao_strength", ao_str)
	var ao_v := Vector3(ao_col.r, ao_col.g, ao_col.b)
	if ao_v != _last_ao_col:
		_last_ao_col = ao_v
		_composite_mat.set_shader_parameter("ao_color", ao_v)
	var bounce_v := Vector3(bounce_col.r, bounce_col.g, bounce_col.b)
	if bounce_v != _last_bounce_col:
		_last_bounce_col = bounce_v
		_composite_mat.set_shader_parameter("bounce_tint", bounce_v)
	if bounce_str != _last_bounce_str:
		_last_bounce_str = bounce_str
		_composite_mat.set_shader_parameter("bounce_strength", bounce_str)


func _view_rect() -> Rect2:
	var size := get_viewport().get_visible_rect().size
	var camera := get_viewport().get_camera_2d()
	var center := size * 0.5
	if camera:
		size /= camera.zoom
		center = camera.get_screen_center_position()
	return Rect2(center - size * 0.5, size)


func _scan() -> void:
	_occluders.clear()
	_dynamic_occluders.clear()
	_lights.clear()
	_glows.clear()
	_room_windows = null
	if _region == null or not is_instance_valid(_region):
		_static_grid.clear()
		_static_occ_ids.clear()
		return
	var world := get_parent()
	if _player == null or not is_instance_valid(_player):
		_player = world.get_node_or_null("Player") if world else null
	var static_occs: Array[CanvasItem] = []
	var static_ids := PackedInt64Array()
	if _region.entities:
		_collect_entities(_region.entities, _player, static_occs, static_ids)
	if static_ids != _static_occ_ids:
		_static_occ_ids = static_ids
		_rebuild_static_grid(static_occs)
	if _player:
		for i in _player.get_child_count():
			var child := _player.get_child(i)
			if child is PointLight2D:
				_lights.append(child as PointLight2D)
			elif child.get_child_count() > 0:
				for sub in child.find_children("*", "PointLight2D", true, false):
					_lights.append(sub as PointLight2D)
	if _region.indoors:
		_room_windows = _region.get_node_or_null("RoomWindows") as RoomWindows


func _rebuild_static_grid(static_occs: Array[CanvasItem]) -> void:
	_static_grid.clear()
	var to_region := _region.get_global_transform().affine_inverse()
	for item in static_occs:
		var rect := _rect_of(item)
		var local_rect := (to_region * item.get_global_transform()) * rect
		var fp := _footprint_of(local_rect)
		var entry := [item, fp]
		var cx0 := floori(fp.position.x / GRID_CELL)
		var cx1 := floori(fp.end.x / GRID_CELL)
		var cy0 := floori(fp.position.y / GRID_CELL)
		var cy1 := floori(fp.end.y / GRID_CELL)
		for cy in range(cy0, cy1 + 1):
			for cx in range(cx0, cx1 + 1):
				var key := Vector2i(cx, cy)
				var bucket: Variant = _static_grid.get(key)
				if bucket == null:
					_static_grid[key] = [entry]
				else:
					(bucket as Array).append(entry)


func _collect_entities(node: Node, player: Node, static_occs: Array[CanvasItem], static_ids: PackedInt64Array) -> void:
	# _parent_skips is computed lazily only when an uncached sprite is seen: on
	# rescans every existing sprite is already in _kinds, so 0 string/child
	# checks run on the ~1,500 parent props.
	var skip_checked := false
	var skip_parent := false
	var count := node.get_child_count()
	for i in count:
		var child := node.get_child(i)
		if child == player:
			continue
		if child is PointLight2D:
			_lights.append(child as PointLight2D)
			continue
		if child is Sprite2D or child is AnimatedSprite2D:
			var id := child.get_instance_id()
			var kind: int = _kinds.get(id, -1)
			if kind < 0:
				kind = KIND_NONE
				if child is Sprite2D and _is_night_glow(child as Sprite2D):
					kind = KIND_GLOW
				else:
					if not skip_checked:
						skip_checked = true
						skip_parent = _parent_skips(node)
					if not skip_parent and _is_occluder(child as CanvasItem):
						kind = KIND_DYNAMIC_OCCLUDER if _is_dynamic(child as CanvasItem) else KIND_STATIC_OCCLUDER
				_kinds[id] = kind
			if kind == KIND_GLOW:
				_glows.append(child as Sprite2D)
			elif kind == KIND_STATIC_OCCLUDER:
				_occluders.append(child as CanvasItem)
				static_occs.append(child as CanvasItem)
				static_ids.append(id)
			elif kind == KIND_DYNAMIC_OCCLUDER:
				_occluders.append(child as CanvasItem)
				_dynamic_occluders.append(child as CanvasItem)
		if child.get_child_count() > 0:
			_collect_entities(child, player, static_occs, static_ids)


func _is_dynamic(item: CanvasItem) -> bool:
	if item is AnimatedSprite2D or item.has_meta("shadow_moves"):
		return true
	var node: Node = item.get_parent()
	while node != null and node != _region.entities:
		if node is CharacterBody2D or node is RigidBody2D or node is AnimatableBody2D:
			return true
		node = node.get_parent()
	return false


static func _is_night_glow(sprite: Sprite2D) -> bool:
	if sprite.material is CanvasItemMaterial:
		if (sprite.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
			return sprite.name != "Halo" and sprite.texture != null
	return false


## True when sprites under [param parent] are a light's own fixture (the
## parent is named like one or holds a PointLight2D), so they never occlude.
static func _parent_skips(parent: Node) -> bool:
	var p_lower := String(parent.name).to_lower()
	for hint: String in NON_OCCLUDER_HINTS:
		if hint in p_lower:
			return true
	for i in parent.get_child_count():
		if parent.get_child(i) is PointLight2D:
			return true
	return false


## Whether [param item] casts GI shadow. Its parent is checked separately by
## _parent_skips (once per parent).
static func _is_occluder(item: CanvasItem) -> bool:
	if item.material is CanvasItemMaterial and (item.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
		return false
	# Skip light fixtures / flames so lamps and campfires don't occlude themselves.
	var lower_name := item.name.to_lower()
	for hint: String in NON_OCCLUDER_HINTS:
		if hint in lower_name:
			return false
	if item is Sprite2D:
		var tex := (item as Sprite2D).texture
		if tex and tex.resource_path != "":
			var path_lower := tex.resource_path.to_lower()
			for hint: String in NON_OCCLUDER_HINTS:
				if hint in path_lower:
					return false
	var rect := _rect_of(item)
	return rect.size.y >= MIN_OCCLUDER_HEIGHT and rect.end.y > -10.0 and rect.end.y <= 12.0


static func _rect_of(item: CanvasItem) -> Rect2:
	if item is Sprite2D:
		return (item as Sprite2D).get_rect()
	if item is AnimatedSprite2D:
		var anim := item as AnimatedSprite2D
		if anim.sprite_frames and anim.sprite_frames.has_animation(anim.animation):
			var count := anim.sprite_frames.get_frame_count(anim.animation)
			if anim.frame < count:
				var tex := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
				if tex:
					var s := tex.get_size()
					var pos := anim.offset - (s * 0.5 if anim.centered else Vector2.ZERO)
					return Rect2(pos, s)
	return Rect2()


static func _footprint_of(world_rect: Rect2) -> Rect2:
	var w := world_rect.size.x
	var h := world_rect.size.y
	var foot_y := world_rect.end.y
	var cx := world_rect.position.x + w * 0.5
	var fp_w: float
	var fp_h: float
	if w < h * 0.72:
		# Tall narrow sprite (pine/oak trunk, post): occlude trunk base so
		# light passes naturally over the canopy while trunks cast crisp shadows.
		fp_w = clampf(w * 0.36, 6.0, 28.0)
		fp_h = clampf(h * 0.22, 6.0, 24.0)
	else:
		# Wide grounded sprite (cabin, tent, boulder, bench, sofa): occlude
		# core body inset slightly from the front edge so the front face stays lit.
		fp_w = w * 0.78
		fp_h = clampf(h * 0.44, 10.0, 60.0)
	return Rect2(cx - fp_w * 0.5, foot_y - fp_h - 3.0, fp_w, fp_h)


func _draw_scene() -> void:
	var cull := _view.grow(160.0)
	var occ_color := Color(0.0, 0.0, 0.0, 1.0)

	# 1a. Static grounded occluder footprints from the coarse spatial grid.
	if not _static_grid.is_empty() and _region != null and is_instance_valid(_region):
		var reg_origin := _region.global_position
		var local_cull := Rect2(cull.position - reg_origin, cull.size)
		var cx0 := floori(local_cull.position.x / GRID_CELL)
		var cx1 := floori(local_cull.end.x / GRID_CELL)
		var cy0 := floori(local_cull.position.y / GRID_CELL)
		var cy1 := floori(local_cull.end.y / GRID_CELL)
		for cy in range(cy0, cy1 + 1):
			for cx in range(cx0, cx1 + 1):
				var bucket: Variant = _static_grid.get(Vector2i(cx, cy))
				if bucket == null:
					continue
				for entry: Array in bucket:
					var raw: Variant = entry[0]
					if not is_instance_valid(raw):
						continue
					var item := raw as CanvasItem
					if not item.is_visible_in_tree():
						continue
					var fp: Rect2 = entry[1]
					if local_cull.intersects(fp):
						_scene_painter.draw_rect(Rect2(fp.position + reg_origin, fp.size), occ_color)

	# 1b. Dynamic occluders (people, animated props).
	for item in _dynamic_occluders:
		if not is_instance_valid(item) or not item.is_visible_in_tree():
			continue
		var rect := _rect_of(item)
		var world_rect := item.get_global_transform() * rect
		if not cull.intersects(world_rect):
			continue
		_scene_painter.draw_rect(_footprint_of(world_rect), occ_color)

	# 2. NightGlow emitters (lit windows, glowing tents, Curry Village string lights).
	var drew_glow := false
	for glow in _glows:
		if not is_instance_valid(glow) or not glow.is_visible_in_tree():
			continue
		var a := glow.modulate.a
		if a <= 0.02 or glow.texture == null:
			continue
		var rect := glow.get_rect()
		var xform := glow.get_global_transform()
		var world_rect := xform * rect
		if not cull.intersects(world_rect):
			continue
		# Warm HDR window/bulb emission.
		var gain := clampf(a * 1.9, 0.0, 2.2)
		var col := Color(1.0 * gain, 0.74 * gain, 0.38 * gain, 1.0)
		_scene_painter.draw_set_transform_matrix(xform)
		_scene_painter.draw_texture_rect(glow.texture, rect, false, col)
		drew_glow = true
	if drew_glow:
		_scene_painter.draw_set_transform_matrix(Transform2D.IDENTITY)

	# 3. Indoor daylight windows (RoomWindows): soft sky/golden sunlight pouring
	# from back-wall panes around furniture.
	if _room_windows and is_instance_valid(_room_windows) and _room_windows.spec:
		var day := Sun.daylight()
		if day > 0.05:
			var golden := Sun.golden()
			var weather := Weather.today()
			var clear: float = 1.0 - float(weather.clouds) * 0.65
			var win_col := Color(0.85, 0.92, 1.0).lerp(Color(1.0, 0.74, 0.42), golden)
			var win_gain := day * clear * (0.9 + 0.5 * golden)
			var hdr := Color(win_col.r * win_gain, win_col.g * win_gain, win_col.b * win_gain, 1.0)
			var base := _room_windows.global_position
			for pane: Dictionary in _room_windows.spec.get("panes", []):
				var sill := Rect2(
					base.x + float(pane.x) + 2.0,
					base.y + float(pane.y) + float(pane.h) - 8.0,
					maxf(float(pane.w) - 4.0, 6.0),
					10.0,
				)
				if cull.intersects(sill):
					_scene_painter.draw_rect(sill, hdr)

	# 4. NightLight emitters (campfires, streetlamps, lanterns, hearths, headlamp).
	var player := _player if is_instance_valid(_player) else null
	for light in _lights:
		if not is_instance_valid(light) or not light.is_visible_in_tree():
			continue
		var e: float = light.gi_energy if "gi_energy" in light else light.energy
		if e <= 0.01:
			continue
		var pos := light.global_position
		if not cull.has_point(pos):
			continue
		var carried := player != null and light.get_parent() == player
		# Only NightLight has a radius; other lights (headlamp, camp pieces)
		# are plain PointLight2D, so fall back to their texture size.
		var reach: float = light.get("radius") if "radius" in light else light.texture_scale * 64.0
		var r := clampf(reach * 0.095, 5.5, 16.0)
		var gain := e * (0.45 if carried else 1.85)
		var at := pos + Vector2(0.0, 10.0) if carried else pos
		var hdr := Color(light.color.r * gain, light.color.g * gain, light.color.b * gain, 1.0)
		_scene_painter.draw_circle(at, r, hdr)
