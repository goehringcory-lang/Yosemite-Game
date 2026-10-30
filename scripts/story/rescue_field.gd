class_name RescueField
extends Node
## Out in the park on a rescue call (Rescues): World adds one. While a
## search is on, it lays the fresh prints in the call's region, from the
## spot the person was last seen to wherever they've got to, and puts them
## there (RescueSubject). The prints show only close to you, as if you're
## reading the ground, so you follow them step by step. While you carry
## someone, it puts them on your back.

## The prints are drawn by a node first in the region's Entities: over the
## ground and its grass, under people and props.
const UNDER := -100000.0
## Pixels between two prints along the way, and how far apart left and
## right feet fall.
const STRIDE := 22.0
const GAIT := 4.0
## Prints show fully within READ of you and fade out by READ_FADE.
const READ := 150.0
const READ_FADE := 250.0
const VISITOR_DIR := "res://data/characters/visitors/%s.tres"

## The prints: [position, direction] each, in the region's coordinates.
var prints: Array = []
var subject: RescueSubject
var _tracks: Node2D
var _region: Region
var _call := ""
var _rider: Sprite2D


func _ready() -> void:
	Rescues.changed.connect(_refresh)


func _world() -> Node:
	return get_parent()


func _process(_delta: float) -> void:
	var world := _world()
	var region: Region = world.region if world and "region" in world else null
	if region != _region:
		_region = region
		_clear()
		_refresh()
	if is_instance_valid(_tracks):
		_tracks.queue_redraw()


## Lays the prints and places the person when you're in the call's region
## with a search on, and clears them otherwise.
func _refresh() -> void:
	_update_rider()
	var call := Rescues.active_call()
	var searching := Rescues.current_stage() in ["search", "feed"]
	if not searching or _region == null or call.get("region", "") != _region.region_id:
		_clear()
		return
	if _call == call.id and is_instance_valid(subject):
		return
	_clear()
	_call = call.id
	_place(call)


func _place(call: Dictionary) -> void:
	var start_marker := _region.get_spawn(call.start)
	var near := _region.get_spawn(call.near)
	if start_marker == null or near == null:
		push_warning("Rescue call %s: no marker %s or %s in %s" % [call.id, call.start, call.near, _region.region_id])
		return
	var grid := WalkGrid.of(_region)
	var at := grid.nearest_open(near.global_position + Vector2(call.offset))
	var from := grid.nearest_open(start_marker.global_position)
	lay_prints(from, grid.route(from, at))
	# y-sorted to the very top of Entities, so drawn before everything in it
	_tracks = Node2D.new()
	_tracks.name = "RescueTracks"
	_tracks.position = Vector2(0, UNDER)
	_tracks.draw.connect(_draw_prints)
	_region.entities.add_child(_tracks)
	subject = RescueSubject.new()
	subject.name = "RescueSubject"
	subject.setup(call, _visitor(call))
	_region.entities.add_child(subject)
	subject.global_position = at


## Prints from [param from] along [param path] (the turning points), a
## stride apart, left and right of the line.
func lay_prints(from: Vector2, path: PackedVector2Array) -> void:
	prints = []
	var here := from
	var left := false
	var carry := 0.0
	for point in path:
		var leg := point - here
		var length := leg.length()
		if length <= 0.0:
			continue
		var dir := leg / length
		var side := Vector2(-dir.y, dir.x)
		var d := STRIDE - carry
		while d <= length:
			left = not left
			prints.append([here + dir * d + side * (GAIT if left else -GAIT), dir])
			d += STRIDE
		carry = length - (d - STRIDE)
		here = point


func _clear() -> void:
	prints = []
	_call = ""
	if is_instance_valid(subject):
		subject.queue_free()
	subject = null
	if is_instance_valid(_tracks):
		_tracks.queue_free()
	_tracks = null


func _visitor(call: Dictionary) -> CharacterData:
	var path := VISITOR_DIR % call.get("look", "")
	return load(path) if ResourceLoader.exists(path) else null


## Whoever you're carrying rides on your back, a little behind you.
func _update_rider() -> void:
	var world := _world()
	var player: Player = world.player if world and "player" in world else null
	if player == null:
		return
	var carrying := Rescues.current_stage() == "carry"
	if not carrying:
		if is_instance_valid(_rider):
			_rider.queue_free()
		_rider = null
		return
	if is_instance_valid(_rider):
		return
	var visitor := _visitor(Rescues.active_call())
	if visitor == null or visitor.sprite_sheet == null:
		return
	_rider = Sprite2D.new()
	_rider.name = "RescueRider"
	CharacterSheet.setup(_rider, visitor.sprite_sheet)
	# their back, over your shoulders, arms up round your neck
	_rider.frame = CharacterSheet.frame(visitor.sprite_sheet, Vector2i.UP, CharacterSheet.Col.CARRY)
	_rider.offset = Vector2(0, -22)
	_rider.position = Vector2(0, -22)
	_rider.scale = Vector2(0.75, 0.75)
	_rider.z_index = 1
	player.add_child(_rider)


func _draw_prints() -> void:
	if prints.is_empty():
		return
	_tracks.draw_set_transform(Vector2(0, -UNDER))
	var world := _world()
	var player: Player = world.player if world and "player" in world else null
	var eye := player.global_position if player else Vector2.INF
	var color := _print_color()
	for p: Array in prints:
		var at: Vector2 = p[0]
		var fade := clampf((READ_FADE - at.distance_to(eye)) / (READ_FADE - READ), 0.0, 1.0)
		if fade <= 0.0:
			continue
		var dir: Vector2 = p[1]
		var c := Color(color, color.a * fade)
		# a boot print, the size of a person's foot on this map: a sole and
		# a heel with the arch between, toe pointing the way they went
		_tracks.draw_colored_polygon(_patch(at + dir * 2.5, dir, 3.5, 2.5), c)
		_tracks.draw_colored_polygon(_patch(at - dir * 3.5, dir, 1.5, 2.0), c)


## The four corners of a patch [param half_long] along [param dir] and
## [param half_wide] across it, around [param center], on whole pixels.
static func _patch(center: Vector2, dir: Vector2, half_long: float, half_wide: float) -> PackedVector2Array:
	var side := Vector2(-dir.y, dir.x)
	var out := PackedVector2Array()
	for corner in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(-1, 1)]:
		out.append((center + dir * half_long * corner.x + side * half_wide * corner.y).round())
	return out


## Dark in dust, blue-grey in snow, deep in winter mud.
func _print_color() -> Color:
	var weather := Weather.today()
	if weather.snow > 0.0 or GameClock.season == GameClock.Season.WINTER:
		return Color(0.4, 0.47, 0.62, 0.9)
	if weather.rain > 0.0:
		return Color(0.2, 0.15, 0.1, 0.9)
	return Color(0.24, 0.17, 0.1, 0.85)
