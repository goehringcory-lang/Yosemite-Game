class_name Footprints
extends Node2D
## Tracks in the snow: while snow lies on the ground, the player, the people
## about the Valley and the deer and bears leave a trail of small dents behind
## them, two feet side by side, that fill back in over a minute or so (faster
## while it's still snowing). World adds one.
##
## Prints are kept in world space, a fixed number at most, and drawn as small
## rects with a multiply blend in a soft snow-shadow blue: on white snow that
## reads as a dent; on the ploughed asphalt or a bare patch it all but vanishes,
## so nothing needs to know where the drifts are. It draws on the painted
## ground's layer, so trees, people and their shadows all draw over the
## tracks. Works the same on both renderers.

## Snow cover below which nobody leaves tracks.
const MIN_SNOW := 0.25
## Most prints kept at once; the oldest go first.
const MAX_PRINTS := 600
## World pixels walked between steps.
const STRIDE := 7.0
## Seconds a print takes to fill in (and while snow is falling).
const LIFE := 70.0
const LIFE_SNOWING := 30.0
## The dent's colour (multiplied over the snow).
const DENT := Color(0.5, 0.6, 0.82)
## Group that anyone besides the player who leaves tracks joins.
const GROUP := "leaves_tracks"

var _pos := PackedVector2Array()
## +1 or -1: which foot, and so which side of the trail.
var _side := PackedFloat32Array()
## Which way the walker was going: 0 across (left/right), 1 up or down.
var _upright := PackedByteArray()
var _born := PackedFloat32Array()
var _next := 0
var _time := 0.0
## Walker -> [last step position, next foot].
var _walkers := {}
var _redraw_wait := 0.0
var _region: Node
var _on := false
## Set over a seam, so the region_changed that follows keeps the tracks.
var _crossed := false


## The painted ground's layer: the region sits first among World's children,
## so at the same z the tracks draw just after its ground and under the rest.
const GROUND_Z := -9


func _ready() -> void:
	name = "Footprints"
	z_as_relative = false
	z_index = GROUND_Z
	var mul := CanvasItemMaterial.new()
	mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	# multiplies what is already there, lit and tinted, so it must not be
	# lit again itself (lights would push the dent brighter than the snow)
	mul.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mul
	visible = false
	var world := get_parent()
	if world and world.has_signal("region_changed"):
		world.region_changed.connect(_on_region_changed.unbind(1))
	if world and world.has_signal("seam_crossed"):
		world.seam_crossed.connect(_on_seam_crossed)


## A new place starts with fresh snow, through a door or at the end of a
## trip; over a seam the tracks in view stay (see _on_seam_crossed).
func _on_region_changed() -> void:
	if _crossed:
		_crossed = false
		return
	clear()


## Walking over a seam the world moved by [param shift]: the tracks move
## with it, and the trail behind you runs on over the edge.
func _on_seam_crossed(shift: Vector2) -> void:
	_crossed = true
	for i in _pos.size():
		_pos[i] += shift
	for id: int in _walkers:
		var last: Array = _walkers[id]
		last[0] += shift
	queue_redraw()


## How many prints are in the snow now (for tests).
func print_count() -> int:
	var n := 0
	for i in _pos.size():
		if _time - _born[i] < _life():
			n += 1
	return n


func clear() -> void:
	_pos.clear()
	_side.clear()
	_upright.clear()
	_born.clear()
	_next = 0
	_walkers.clear()
	queue_redraw()


func _life() -> float:
	return LIFE_SNOWING if Weather.today().snow > 0.0 else LIFE


func _process(delta: float) -> void:
	_time += delta
	var world := get_parent()
	if world == null or not "region" in world:
		return
	var region: Node = world.region
	var on: bool = region != null and not region.indoors and Seasons.snow_cover() >= MIN_SNOW
	if on != _on:
		_on = on
		visible = on
		if not on:
			clear()
	if not on:
		return
	if region != _region:
		_region = region
		z_index = _ground_z(region)
	if _walkers.size() > 64:
		for id: int in _walkers.keys():
			if not is_instance_id_valid(id):
				_walkers.erase(id)
	if world.player:
		_step(world.player, world.player.global_position)
	for walker: Node in get_tree().get_nodes_in_group(GROUP):
		if walker is Node2D and (walker as Node2D).is_visible_in_tree():
			_step(walker, (walker as Node2D).global_position)
	_redraw_wait -= delta
	if _redraw_wait <= 0.0:
		_redraw_wait = 0.25
		queue_redraw()


## The z of [param region]'s painted ground (or its ground tiles).
static func _ground_z(region: Node) -> int:
	for path in ["GroundArt", "GroundPainting", "Map/Ground", "Ground"]:
		var ground := region.get_node_or_null(path) as CanvasItem
		if ground:
			var z := ground.z_index
			if ground.z_as_relative:
				var parent := ground.get_parent() as CanvasItem
				while parent:
					z += parent.z_index
					if not parent.z_as_relative:
						break
					parent = parent.get_parent() as CanvasItem
			return z
	return GROUND_Z


func _step(walker: Node, at: Vector2) -> void:
	var id := walker.get_instance_id()
	var last: Array = _walkers.get(id, [])
	if last.is_empty():
		_walkers[id] = [at, 1.0]
		return
	var from: Vector2 = last[0]
	var gone := at - from
	if gone.length_squared() > 900.0:
		# a jump (a door, a warp): start the trail again here
		_walkers[id] = [at, last[1]]
		return
	if gone.length() < STRIDE:
		return
	var foot: float = last[1]
	_add(at, foot, absf(gone.y) > absf(gone.x))
	_walkers[id] = [at, -foot]


func _add(at: Vector2, foot: float, upright: bool) -> void:
	if _pos.size() < MAX_PRINTS:
		_pos.append(at)
		_side.append(foot)
		_upright.append(1 if upright else 0)
		_born.append(_time)
		return
	_pos[_next] = at
	_side[_next] = foot
	_upright[_next] = 1 if upright else 0
	_born[_next] = _time
	_next = (_next + 1) % MAX_PRINTS


func _draw() -> void:
	var life := _life()
	for i in _pos.size():
		var age := _time - _born[i]
		if age >= life:
			continue
		# fills in: the dent fades back toward white in four steps, so it
		# stays crisp pixel art
		var fade := floorf(pow(age / life, 2.0) * 4.0) / 4.0
		var c := DENT.lerp(Color.WHITE, fade)
		var p := _pos[i].floor()
				# each boot 3 long along the way of walking and 2 wide
		if _upright[i] == 0:
			draw_rect(Rect2(p + Vector2(-1, 2.0 * _side[i] - 1), Vector2(3, 2)), c)
		else:
			draw_rect(Rect2(p + Vector2(2.0 * _side[i] - 1, -1), Vector2(2, 3)), c)
