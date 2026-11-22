class_name HappeningField
extends Node
## Stands today's Happenings in the area you're in (World adds one): the
## person where it's going on, while its hours are on, and for a "find" one
## the lost thing nearby, once they've told you about it. Everything is
## placed on open ground (WalkGrid), and taken away when its hours end or
## you leave the area.

const VISITOR_DIR := "res://data/characters/visitors/%s.tres"
## How often (seconds) it looks again at what should be out.
const CHECK_EVERY := 0.5

## Who's standing here now, and the lost things lying about, by happening id.
var figures: Dictionary = {}
var things: Dictionary = {}
var _region: Region
var _check := 0.0
## Seconds someone takes to fade in when they're put out.
const FADE_IN := 0.4
## Who was out in the area left behind over a seam: still in view, they
## stay until you've walked on out of sight of them.
var _behind: Array[Node2D] = []
var _crossed := false


func _ready() -> void:
	Happenings.changed.connect(refresh)
	var world := _world()
	if world and world.has_signal("seam_crossed"):
		world.seam_crossed.connect(func(_shift: Vector2) -> void: _crossed = true)


func _world() -> Node:
	return get_parent()


func _process(delta: float) -> void:
	var world := _world()
	var region: Region = world.region if world and "region" in world else null
	if region != _region:
		_region = region
		if _crossed:
			_leave_behind()
		else:
			_clear()
		_crossed = false
		refresh()
		return
	_crossed = false
	_retire_behind()
	_check -= delta
	if _check <= 0.0:
		_check = CHECK_EVERY
		refresh()


## Puts out who should be here now and takes away who shouldn't.
func refresh() -> void:
	if _region == null or not is_instance_valid(_region) or not _region.is_inside_tree() or _region.indoors:
		_clear()
		return
	var want := {}
	for happening: Dictionary in Happenings.here_now(_region.region_id):
		want[happening.id] = happening
	for id: String in figures.keys():
		if not want.has(id) or not is_instance_valid(figures[id]):
			_drop(figures, id)
	for id: String in things.keys():
		if not want.has(id) or Happenings.has_found(id) or not is_instance_valid(things[id]):
			_drop(things, id)
	for id: String in want:
		var happening: Dictionary = want[id]
		if not figures.has(id):
			_place_figure(happening)
		if happening.kind == "find" and Happenings.has_asked(id) and not Happenings.has_found(id) \
				and not Happenings.is_done(id) and not things.has(id):
			_place_thing(happening)


## Where a happening's [param near] marker plus [param offset] lands on
## open ground in the area, or INF if the marker's missing.
static func spot_in(region: Region, near: String, offset: Vector2) -> Vector2:
	var marker := region.get_spawn(near)
	if marker == null:
		return Vector2.INF
	var grid := WalkGrid.of(region)
	return grid.nearest_open(marker.global_position + offset)


func _place_figure(happening: Dictionary) -> void:
	var at := spot_in(_region, happening.near, happening.offset)
	if at == Vector2.INF:
		push_warning("Happening %s: no marker %s in %s" % [happening.id, happening.near, _region.region_id])
		return
	var figure := HappeningFigure.new()
	var path := VISITOR_DIR % happening.look
	figure.setup(happening, load(path) if ResourceLoader.exists(path) else null)
	_region.entities.add_child(figure)
	figure.global_position = at
	figures[happening.id] = figure
	_fade_in(figure)


func _place_thing(happening: Dictionary) -> void:
	var thing: Dictionary = happening.thing
	var at := spot_in(_region, thing.near, thing.offset)
	if at == Vector2.INF:
		push_warning("Happening %s: no marker %s in %s" % [happening.id, thing.near, _region.region_id])
		return
	var node := HappeningThing.new()
	node.setup(happening)
	_region.entities.add_child(node)
	node.global_position = at
	things[happening.id] = node
	_fade_in(node)


## Someone (or something) put out where you might be looking comes in
## softly, not all at once.
func _fade_in(node: CanvasItem) -> void:
	node.modulate.a = 0.0
	node.create_tween().tween_property(node, "modulate:a", 1.0, FADE_IN)


func _drop(from: Dictionary, id: String) -> void:
	var node = from.get(id)
	from.erase(id)
	if is_instance_valid(node):
		node.queue_free()


func _clear() -> void:
	for id: String in figures.keys():
		_drop(figures, id)
	for id: String in things.keys():
		_drop(things, id)
	for node in _behind:
		if is_instance_valid(node):
			node.queue_free()
	_behind.clear()


## Over a seam: who's out in the area behind stays there for now.
func _leave_behind() -> void:
	for from: Dictionary in [figures, things]:
		for id: String in from.keys():
			if is_instance_valid(from[id]):
				_behind.append(from[id])
		from.clear()


## Those left behind go once they're out of sight, or their area is.
func _retire_behind() -> void:
	if _behind.is_empty():
		return
	var view := get_viewport().get_visible_rect()
	var camera := get_viewport().get_camera_2d()
	if camera:
		var size := view.size / camera.zoom
		view = Rect2(camera.get_screen_center_position() - size / 2.0, size).grow(64.0)
	for i in range(_behind.size() - 1, -1, -1):
		var node := _behind[i]
		if not is_instance_valid(node):
			_behind.remove_at(i)
		elif not node.is_inside_tree() or not view.has_point(node.global_position):
			node.queue_free()
			_behind.remove_at(i)
