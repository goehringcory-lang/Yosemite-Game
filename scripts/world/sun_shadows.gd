class_name SunShadows
extends Node2D
## The shadows things cast on the ground: trees, boulders, buildings, signs,
## people. Each one's sprite is laid flat along the ground, away from the sun
## (see Sun), so the shadows swing west to east through the day, stretch long
## in the morning and evening and shrink at midday, and they're longer in
## winter, when the sun stays low. On full-moon nights the moon casts faint
## ones of its own. Clouds and rain wash them out.
##
## World adds one to each outdoor region, drawn over the ground and under the
## Entities. Where two shadows overlap the ground is no darker than under
## one. Nothing is added to the region's scene: the casters
## are found by looking for upright sprites (their feet on the node's origin)
## under Entities, again every couple of seconds for anyone who walks in.
##
## Most casters never move (trees, rocks, buildings), so their shadows are
## painted once and only painted again when the sun has swung far enough to
## shift a shadow's tip, the view nears the edge of what was painted, or one
## of them changes (hidden, freed, new art). Only the people walking about
## (and anything else seen to move) are painted every frame.
##
## The still shadows are baked into a picture (a SubViewport at the window's
## own resolution, rendered only when they're painted again) and laid on the
## ground as one sprite, so a frame draws one picture, not every tree's
## shadow again. The moving ones are drawn in a small CanvasGroup on top,
## left out wherever a still shadow already lies, so a person walking under a
## tree's shadow doesn't darken it twice. (One CanvasGroup over all the
## shadows cost a full-screen pass every frame.)

## Colour and strength of a midday shadow (a cool, blue-grey shade).
const SHADE := Color(0.1, 0.11, 0.22)
const STRENGTH := 0.4
## Longest a shadow gets, as a multiple of the caster's height.
const MAX_LENGTH := 1.7
## Ground is seen at a slant, so a shadow lying north-south looks shorter.
const SLANT := 0.62
## How often to look for new casters (seconds).
const RESCAN := 2.0
## Upright sprites at least this tall cast a shadow.
const MIN_HEIGHT := 20.0
## How far the still shadows are painted past the view, in world pixels, so
## walking about doesn't paint them again every step.
const MARGIN := 192.0
## How much the lean may change before the still shadows are painted again:
## the tip of a 200 pixel tall tree's shadow moves half a pixel.
const LEAN_STEP := 0.0025
## Widest the baked still shadows get, in pixels (a texture any graphics card
## takes).
const MAX_BAKE := 4096

var region: Region
var _casters: Array[CanvasItem] = []
## The casters that move (people, and anything seen moving since the last
## scan), painted every frame; the rest are painted by _still_painter.
var _movers: Array[CanvasItem] = []
var _still: Array[CanvasItem] = []
## Where each caster stood in the region at the last scan (instance id ->
## Transform2D), to notice still ones that moved.
var _placed := {}
var _scan_in := 0.0
var _painter: Node2D
var _still_painter: Node2D
## The baked still shadows (white where a shadow lies), its picture on the
## ground, and the group the movers' shadows are drawn in.
var _bake: SubViewport
var _still_sprite: Sprite2D
var _still_mat: ShaderMaterial
var _movers_group: CanvasGroup
var _mover_mat: ShaderMaterial
## Window pixels per world pixel the bake was made at.
var _bake_scale := 0.0
## Which casters were still at the last scan: only a change there paints the
## still shadows again.
var _still_ids := PackedInt64Array()
## The still shadows need painting again.
var _dirty := true
## What the still shadows were last painted for.
var _painted_lean := Vector2.INF
var _painted_view := Rect2()
var _painted_at := Vector2.INF
## Ground offset of a shadow per pixel of height (x east, y south).
var _lean := Vector2.ZERO
## Where a pixel of width lands, for round casters (trees, people). Flat-faced
## ones (buildings, wide rocks) keep their width east-west.
var _across := Vector2.RIGHT
var _view := Rect2()
## Cached upright test per Sprite2D instance id (invalidated if texture changes).
var _upright_tex := {}
var _upright_ok := {}
## Cached _moves() result per caster instance id.
var _moves_cache := {}
## Last pushed shader/modulate state to avoid redundant uniform uploads.
var _last_hq := -1
var _last_penumbra := -1.0
var _last_shade := Color(-1, -1, -1, -1)
var _last_strength := -1.0
var _had_movers := true
## Set when region.entities adds/removes a child so _scan() only walks the tree
## when something changed (plus a slow fallback for deep subtree edits).
var _entities_dirty := true
var _force_scan_in := 12.0


const STILL_SHADER := preload("res://assets/shaders/shadow_still.gdshader")
const MOVER_SHADER := preload("res://assets/shaders/shadow_mover.gdshader")


func _ready() -> void:
	name = "SunShadows"
	if region and region.entities:
		region.entities.child_entered_tree.connect(_on_entities_changed)
		region.entities.child_exiting_tree.connect(_on_entities_changed)
	_bake = SubViewport.new()
	_bake.transparent_bg = true
	_bake.disable_3d = true
	_bake.snap_2d_transforms_to_pixel = true
	_bake.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_bake.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_bake.size = Vector2i(2, 2)
	add_child(_bake)
	_still_painter = Node2D.new()
	_still_painter.draw.connect(_paint_still)
	_bake.add_child(_still_painter)
	_still_sprite = Sprite2D.new()
	_still_sprite.centered = false
	_still_sprite.texture = _bake.get_texture()
	_still_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_still_mat = ShaderMaterial.new()
	_still_mat.shader = STILL_SHADER
	_still_mat.set_shader_parameter("shade", SHADE)
	_last_shade = SHADE
	_still_sprite.material = _still_mat
	add_child(_still_sprite)
	_movers_group = CanvasGroup.new()
	_movers_group.fit_margin = 0.0
	_movers_group.clear_margin = 0.0
	add_child(_movers_group)
	_painter = Node2D.new()
	_painter.draw.connect(_paint)
	_mover_mat = ShaderMaterial.new()
	_mover_mat.shader = MOVER_SHADER
	_mover_mat.set_shader_parameter("still", _bake.get_texture())
	_painter.material = _mover_mat
	_movers_group.add_child(_painter)


func _on_entities_changed(_node: Node) -> void:
	_entities_dirty = true
	_scan_in = 0.0


func _process(delta: float) -> void:
	if region == null:
		return
	var strength := _strength()
	var was_visible := visible
	visible = strength > 0.01
	if not visible:
		return
	if not was_visible:
		_dirty = true
	var hq := LitSprites.active()
	var hq_int := 1 if hq else 0
	if hq_int != _last_hq:
		_last_hq = hq_int
		_still_mat.set_shader_parameter("high_quality", hq)
	if hq:
		# Soften penumbra as the sun drops low; cool-cobalt shade at golden hour.
		var low := 1.0 - clampf((Sun.height() - 6.0) / 36.0, 0.0, 1.0)
		var penumbra := lerpf(1.35, 3.2, low) * maxf(_bake_scale * 0.5, 0.75)
		if absf(penumbra - _last_penumbra) > 0.005:
			_last_penumbra = penumbra
			_still_mat.set_shader_parameter("penumbra", penumbra)
		var golden_shade := Color(0.11, 0.12, 0.28)
		var night_shade := Color(0.06, 0.09, 0.18)
		var tint := SHADE.lerp(golden_shade, Sun.golden() * 0.7).lerp(night_shade, Sun.night())
		if tint != _last_shade:
			_last_shade = tint
			_still_mat.set_shader_parameter("shade", tint)
	elif _last_shade != SHADE:
		_last_shade = SHADE
		_still_mat.set_shader_parameter("shade", SHADE)
	if absf(strength - _last_strength) > 0.0005:
		_last_strength = strength
		var mod := Color(1, 1, 1, strength)
		_still_sprite.self_modulate = mod
		_movers_group.self_modulate = mod
	_scan_in -= delta
	_force_scan_in -= delta
	if _scan_in <= 0.0:
		_scan_in = RESCAN
		if _entities_dirty or _force_scan_in <= 0.0:
			_entities_dirty = false
			_force_scan_in = 12.0
			_scan()
	var vp := get_viewport()
	var camera := vp.get_camera_2d()
	_view = _view_rect_for(vp, camera)
	var scale_now := _window_scale_for(vp, camera)
	if (_lean - _painted_lean).length() > LEAN_STEP or not _painted_view.encloses(_view) \
			or global_position != _painted_at or scale_now != _bake_scale:
		_dirty = true
	if _dirty:
		_dirty = false
		_painted_lean = _lean
		# whole world pixels, so the baked picture lies on the art's grid
		var grown := _view.grow(MARGIN)
		_painted_view = Rect2(grown.position.floor(), grown.size.ceil())
		_painted_at = global_position
		_bake_scale = scale_now
		_rebake()
	if not _movers.is_empty():
		_had_movers = true
		_painter.queue_redraw()
	elif _had_movers:
		_had_movers = false
		_painter.queue_redraw()


## Window pixels per world pixel: 2 for a 1920x1080 window over the 960x540
## view (the canvas is drawn at the window's size), 1 on Low (drawn at
## 960x540 and scaled up), more when the camera zooms in.
func _window_scale() -> float:
	var vp := get_viewport()
	return _window_scale_for(vp, vp.get_camera_2d())


func _window_scale_for(vp: Viewport, camera: Camera2D) -> float:
	var k := vp.get_final_transform().get_scale().x
	if camera:
		k *= camera.zoom.x
	return clampf(k, 0.25, 8.0)


## Paints the still shadows again into the bake, and lays it where they lie.
func _rebake() -> void:
	var k := _bake_scale
	var size := Vector2i((_painted_view.size * k).ceil())
	if size.x > MAX_BAKE or size.y > MAX_BAKE:
		k = minf(k * MAX_BAKE / float(size.x), k * MAX_BAKE / float(size.y))
		size = Vector2i((_painted_view.size * k).ceil())
	_bake.size = size.max(Vector2i(2, 2))
	# bake pixels from the canvas's (world) coordinates
	_bake.canvas_transform = Transform2D(0.0, Vector2(k, k), 0.0, -_painted_view.position * k)
	_still_sprite.global_transform = Transform2D(0.0, Vector2(1.0 / k, 1.0 / k), 0.0, _painted_view.position)
	var world_size := Vector2(_bake.size) / k
	_still_mat.set_shader_parameter("bake_origin", _painted_view.position)
	_still_mat.set_shader_parameter("bake_size", world_size)
	_mover_mat.set_shader_parameter("still_origin", _painted_view.position)
	_mover_mat.set_shader_parameter("still_size", world_size)
	_still_painter.queue_redraw()
	_bake.render_target_update_mode = SubViewport.UPDATE_ONCE


## How dark the shadows are now: full in clear sunshine, faint under thin
## cloud, none when it's overcast or the sun is down (unless the moon's up).
func _strength() -> float:
	var weather := Weather.today()
	var clear := 1.0 - smoothstep(0.55, 0.95, weather.clouds)
	var sun := Sun.daylight()
	if sun > 0.0:
		var height := Sun.height()
		_lean = _lean_toward(Sun.direction(), height)
		# Low sun gives long, paler shadows.
		return STRENGTH * sun * clear * lerpf(0.75, 1.0, smoothstep(4.0, 20.0, height))
	var moon := Sun.night() * Sun.moon() * clear
	if moon > 0.3:
		var mdir := Sun.moon_direction()
		_lean = _lean_toward(mdir, 40.0 * mdir.y + 8.0)
		return STRENGTH * 0.5 * smoothstep(0.3, 0.9, moon)
	return 0.0


## The shadow of a point one pixel up, for light from [param toward] at
## [param degrees] above the horizon. Also sets [member _across], the way a
## round caster's width lies on the ground (square to the shadow).
func _lean_toward(toward: Vector2, degrees: float) -> Vector2:
	var length := minf(1.0 / tan(deg_to_rad(maxf(degrees, 4.0))), MAX_LENGTH)
	var away := -toward
	var across := Vector2(-away.y, away.x)
	if across.x < 0.0:
		across = -across
	_across = Vector2(across.x, across.y * SLANT)
	return Vector2(away.x, away.y * SLANT) * length


func _scan() -> void:
	_casters.clear()
	if region.entities:
		_collect(region.entities)
	var reg_xform := region.get_global_transform()
	var reg_identity := reg_xform == Transform2D.IDENTITY
	var to_region := Transform2D.IDENTITY if reg_identity else reg_xform.affine_inverse()
	var placed := {}
	_movers.clear()
	_still.clear()
	for caster in _casters:
		var id := caster.get_instance_id()
		var at := caster.get_global_transform() if reg_identity else to_region * caster.get_global_transform()
		placed[id] = at
		var is_mover: bool
		if _moves_cache.has(id):
			is_mover = _moves_cache[id]
		else:
			is_mover = _moves(caster)
			_moves_cache[id] = is_mover
		if is_mover or caster.has_meta("shadow_moves") or (_placed.has(id) and _placed[id] != at):
			_movers.append(caster)
			continue
		_still.append(caster)
		if not _placed.has(id):
			# a still caster for the first time: paint again when it changes
			if not caster.is_connected("visibility_changed", _changed):
				caster.connect("visibility_changed", _changed)
			if not caster.is_connected("tree_exiting", _changed):
				caster.connect("tree_exiting", _changed)
			if caster.has_signal("texture_changed"):
				var cb := _animated.bind(caster)
				if not caster.is_connected("texture_changed", cb):
					caster.connect("texture_changed", cb, CONNECT_ONE_SHOT)
			if caster.has_signal("frame_changed"):
				var cb := _animated.bind(caster)
				if not caster.is_connected("frame_changed", cb):
					caster.connect("frame_changed", cb, CONNECT_ONE_SHOT)
	# Paint the still ones again only when they've changed: one came or
	# went, or one moved (and so is a mover now). A change nothing
	# announced (a flip) shows the next time they're painted.
	var still_count := _still.size()
	var ids := PackedInt64Array()
	ids.resize(still_count)
	for i in still_count:
		ids[i] = _still[i].get_instance_id()
	if ids != _still_ids:
		_still_ids = ids
		_dirty = true
	_placed = placed
	if _upright_tex.size() > _casters.size() * 3 + 512:
		_upright_tex.clear()
		_upright_ok.clear()
		_moves_cache.clear()


func _changed() -> void:
	_dirty = true


## A still caster changed its picture (a flag waving, a sign turning): from
## now on it's painted every frame with the people.
func _animated(caster: CanvasItem) -> void:
	caster.set_meta("shadow_moves", true)
	var i := _still.find(caster)
	if i >= 0:
		_still.remove_at(i)
		_movers.append(caster)
		_dirty = true


## People walk about (and anything animated changes shape), so their shadows
## are painted every frame.
func _moves(caster: CanvasItem) -> bool:
	if caster is AnimatedSprite2D:
		return true
	var node: Node = caster
	while node != null and node != region.entities:
		if node is CharacterBody2D or node is RigidBody2D or node is AnimatableBody2D:
			return true
		node = node.get_parent()
	return false


func _collect(node: Node) -> void:
	for i in node.get_child_count():
		var child := node.get_child(i)
		if child is Sprite2D:
			var sprite := child as Sprite2D
			var tex := sprite.texture
			if tex == null:
				continue
			var id := sprite.get_instance_id()
			if _upright_tex.get(id) == tex:
				if _upright_ok[id]:
					_casters.append(sprite)
			else:
				var ok := _is_upright(sprite)
				_upright_tex[id] = tex
				_upright_ok[id] = ok
				if ok:
					_casters.append(sprite)
		elif child is AnimatedSprite2D:
			if _is_upright(child):
				_casters.append(child)
		elif child is CanvasItem and child.get_child_count() > 0:
			_collect(child)


## A sprite standing on its node's origin: its art sits above the origin,
## like a tree's trunk on the ground, not centred on it like a rug or puddle.
static func _is_upright(sprite: CanvasItem) -> bool:
	if sprite.material is CanvasItemMaterial and (sprite.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
		return false
	var rect := _rect_of(sprite)
	return rect.size.y >= MIN_HEIGHT and rect.end.y > -10.0 and rect.end.y <= 7.0


static func _rect_of(sprite: CanvasItem) -> Rect2:
	if sprite is Sprite2D:
		return (sprite as Sprite2D).get_rect()
	var anim := sprite as AnimatedSprite2D
	var tex := _frame_texture(anim)
	if tex == null:
		return Rect2()
	var size := tex.get_size()
	var pos := anim.offset - (size / 2.0 if anim.centered else Vector2.ZERO)
	return Rect2(pos, size)


static func _frame_texture(anim: AnimatedSprite2D) -> Texture2D:
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(anim.animation):
		return null
	if anim.frame >= anim.sprite_frames.get_frame_count(anim.animation):
		return null
	return anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)


func _view_rect() -> Rect2:
	var vp := get_viewport()
	return _view_rect_for(vp, vp.get_camera_2d())


func _view_rect_for(vp: Viewport, camera: Camera2D) -> Rect2:
	var size := vp.get_visible_rect().size
	var center := size / 2.0
	if camera:
		size /= camera.zoom
		center = camera.get_screen_center_position()
	return Rect2(center - size / 2.0, size)


## The moving casters' shadows, every frame.
func _paint() -> void:
	if _movers.is_empty():
		return
	_paint_casters(_painter.get_global_transform().affine_inverse(), _painter, _movers, _view, SHADE)


## The still casters' shadows, over the view and a margin round it, in white
## into the bake (whose canvas transform takes world pixels to its own).
func _paint_still() -> void:
	_paint_casters(Transform2D.IDENTITY, _still_painter, _still, _painted_view, Color.WHITE)


func _paint_casters(to_local: Transform2D, painter: Node2D, casters: Array[CanvasItem], view: Rect2, color: Color) -> void:
	var vx0 := view.position.x
	var vy0 := view.position.y
	var vx1 := view.end.x
	var vy1 := view.end.y
	var lean_reach := absf(_lean.x) + absf(_lean.y)
	var identity_local := to_local == Transform2D.IDENTITY
	for caster in casters:
		if not is_instance_valid(caster) or not caster.is_visible_in_tree():
			continue
		var tex: Texture2D
		var src := Rect2()
		var flip := false
		if caster is Sprite2D:
			var sprite := caster as Sprite2D
			tex = sprite.texture
			if tex == null:
				continue
			var base := sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO, tex.get_size())
			var cell := base.size / Vector2(sprite.hframes, sprite.vframes)
			src = Rect2(base.position + cell * Vector2(sprite.frame_coords), cell)
			flip = sprite.flip_h
		else:
			var anim := caster as AnimatedSprite2D
			tex = _frame_texture(anim)
			if tex == null:
				continue
			src = Rect2(Vector2.ZERO, tex.get_size())
			flip = anim.flip_h
		var rect := _rect_of(caster)
		var xform := caster.get_global_transform()
		# Skip shadows that can't reach the view.
		var foot := xform.origin
		var reach := rect.size.y * lean_reach + rect.size.x
		if foot.x < vx0 - reach or foot.x > vx1 + reach or foot.y < vy0 - reach or foot.y > vy1 + reach:
			continue
		# Lay the sprite on the ground: a point h pixels above the feet lands
		# h * _lean from them; its width runs square to the shadow if it's
		# round, east-west if it's a wide, flat-faced thing like a building.
		var feet := minf(rect.end.y - 2.0, 2.0)
		var mid := rect.get_center().x
		var across := Vector2.RIGHT if rect.size.x > rect.size.y * 0.9 else _across
		var lay := Transform2D(across, -_lean, Vector2(mid, feet) - across * mid + _lean * feet)
		if flip:
			lay = lay * Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2(2.0 * mid, 0))
		painter.draw_set_transform_matrix(xform * lay if identity_local else to_local * xform * lay)
		if caster is Sprite2D:
			painter.draw_texture_rect_region(tex, rect, src, color)
		else:
			painter.draw_texture_rect(tex, rect, false, color)
	painter.draw_set_transform_matrix(Transform2D.IDENTITY)


## Gives [param to] its shadows, drawn just under its Entities. Indoors there
## is no sun.
static func attach(to: Region) -> void:
	if to.indoors or to.has_node("SunShadows") or to.entities == null:
		return
	var shadows := SunShadows.new()
	shadows.region = to
	to.add_child(shadows)
	to.move_child(shadows, to.entities.get_index())
