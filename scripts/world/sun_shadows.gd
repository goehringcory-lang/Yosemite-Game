class_name SunShadows
extends CanvasGroup
## The shadows things cast on the ground: trees, boulders, buildings, signs,
## people. Each one's sprite is laid flat along the ground, away from the sun
## (see Sun), so the shadows swing west to east through the day, stretch long
## in the morning and evening and shrink at midday, and they're longer in
## winter, when the sun stays low. On full-moon nights the moon casts faint
## ones of its own. Clouds and rain wash them out.
##
## World adds one to each outdoor region, drawn over the ground and under the
## Entities. It's a CanvasGroup, so where two shadows overlap the ground is no
## darker than under one. Nothing is added to the region's scene: the casters
## are found by looking for upright sprites (their feet on the node's origin)
## under Entities, again every couple of seconds for anyone who walks in.
##
## Most casters never move (trees, rocks, buildings), so their shadows are
## painted once and only painted again when the sun has swung far enough to
## shift a shadow's tip, the view nears the edge of what was painted, or one
## of them changes (hidden, freed, new art). Only the people walking about
## (and anything else seen to move) are painted every frame.

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


func _ready() -> void:
	name = "SunShadows"
	fit_margin = 0.0
	clear_margin = 0.0
	_still_painter = Node2D.new()
	_still_painter.draw.connect(_paint_still)
	add_child(_still_painter)
	_painter = Node2D.new()
	_painter.draw.connect(_paint)
	add_child(_painter)


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
	self_modulate = Color(1, 1, 1, strength)
	_scan_in -= delta
	if _scan_in <= 0.0:
		_scan_in = RESCAN
		_scan()
	_view = _view_rect()
	if (_lean - _painted_lean).length() > LEAN_STEP or not _painted_view.encloses(_view) \
			or _still_painter.global_position != _painted_at:
		_dirty = true
	if _dirty:
		_dirty = false
		_painted_lean = _lean
		_painted_view = _view.grow(MARGIN)
		_painted_at = _still_painter.global_position
		_still_painter.queue_redraw()
	_painter.queue_redraw()


## How dark the shadows are now: full in clear sunshine, faint under thin
## cloud, none when it's overcast or the sun is down (unless the moon's up).
func _strength() -> float:
	var weather := Weather.today()
	var clear := 1.0 - smoothstep(0.55, 0.95, weather.clouds)
	var sun := Sun.daylight()
	if sun > 0.0:
		_lean = _lean_toward(Sun.direction(), Sun.height())
		# Low sun gives long, paler shadows.
		return STRENGTH * sun * clear * lerpf(0.75, 1.0, smoothstep(4.0, 20.0, Sun.height()))
	var moon := Sun.night() * Sun.moon() * clear
	if moon > 0.3:
		_lean = _lean_toward(Sun.moon_direction(), 40.0 * Sun.moon_direction().y + 8.0)
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
	_casters = []
	if region.entities:
		_collect(region.entities)
	var to_region := region.get_global_transform().affine_inverse()
	var placed := {}
	_movers.clear()
	_still.clear()
	for caster in _casters:
		var id := caster.get_instance_id()
		var at := to_region * caster.get_global_transform()
		placed[id] = at
		if _moves(caster) or caster.has_meta("shadow_moves") or (_placed.has(id) and _placed[id] != at):
			_movers.append(caster)
			continue
		_still.append(caster)
		if not _placed.has(id):
			# A still caster for the first time: paint again when it changes.
			# A new picture is a change, not motion: every seasonal plant gets
			# one as the season turns, and taking that for animation painted
			# hundreds of them every frame from then on. Frames are motion.
			for signal_name in ["visibility_changed", "tree_exiting", "texture_changed"]:
				if caster.has_signal(signal_name) and not caster.is_connected(signal_name, _changed):
					caster.connect(signal_name, _changed)
			if caster.has_signal("frame_changed") and not caster.is_connected("frame_changed", _animated.bind(caster)):
				caster.connect("frame_changed", _animated.bind(caster), CONNECT_ONE_SHOT)
	# The still ones are painted again every scan in any case, so a change
	# nothing announced (a flip, a new caster) shows within RESCAN.
	_dirty = true
	_placed = placed


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
	for child in node.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
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
	var size := get_viewport_rect().size
	var camera := get_viewport().get_camera_2d()
	var center := size / 2.0
	if camera:
		size /= camera.zoom
		center = camera.get_screen_center_position()
	return Rect2(center - size / 2.0, size)


## The moving casters' shadows, every frame.
func _paint() -> void:
	_paint_casters(_painter, _movers, _view)
	# A clear rectangle over everything the still shadows cover: the group
	# sizes its picture by what its children drew this frame, and without it
	# the still shadows (not drawn again this frame) would be cut off.
	_painter.draw_rect(_painter.get_global_transform().affine_inverse() * _painted_view, Color(0, 0, 0, 0))


## The still casters' shadows, over the view and a margin round it.
func _paint_still() -> void:
	_paint_casters(_still_painter, _still, _painted_view)


func _paint_casters(painter: Node2D, casters: Array[CanvasItem], view: Rect2) -> void:
	var to_local := painter.get_global_transform().affine_inverse()
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
		var reach := rect.size.y * (absf(_lean.x) + absf(_lean.y)) + rect.size.x
		if not view.grow(reach).has_point(foot):
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
		painter.draw_set_transform_matrix(to_local * xform * lay)
		if caster is Sprite2D:
			painter.draw_texture_rect_region(tex, rect, src, SHADE)
		else:
			painter.draw_texture_rect(tex, rect, false, SHADE)
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
