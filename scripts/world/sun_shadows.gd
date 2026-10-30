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

var region: Region
var _casters: Array[CanvasItem] = []
var _scan_in := 0.0
var _painter: Node2D
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
	_painter = Node2D.new()
	_painter.draw.connect(_paint)
	add_child(_painter)


func _process(delta: float) -> void:
	if region == null:
		return
	var strength := _strength()
	visible = strength > 0.01
	if not visible:
		return
	self_modulate = Color(1, 1, 1, strength)
	_scan_in -= delta
	if _scan_in <= 0.0:
		_scan_in = RESCAN
		_scan()
	_view = _view_rect()
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
	_casters.clear()
	if region.entities:
		_collect(region.entities)


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


func _paint() -> void:
	var to_local := _painter.get_global_transform().affine_inverse()
	for caster in _casters:
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
		if not _view.grow(reach).has_point(foot):
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
		_painter.draw_set_transform_matrix(to_local * xform * lay)
		if caster is Sprite2D:
			_painter.draw_texture_rect_region(tex, rect, src, SHADE)
		else:
			_painter.draw_texture_rect(tex, rect, false, SHADE)
	_painter.draw_set_transform_matrix(Transform2D.IDENTITY)


## Gives [param to] its shadows, drawn just under its Entities. Indoors there
## is no sun.
static func attach(to: Region) -> void:
	if to.indoors or to.has_node("SunShadows") or to.entities == null:
		return
	var shadows := SunShadows.new()
	shadows.region = to
	to.add_child(shadows)
	to.move_child(shadows, to.entities.get_index())
