class_name FishingWater
extends Node2D
## A named stretch of river with fish of its own (see Fishing.FISH "waters"):
##   "rapids"  white water tumbling over boulders. Rainbow trout hold in the
##             current here, and a fish hooked in it fights harder.
##   "hole"    a deep, slow pool where the river widens (the banks were cut
##             back by tools/fishing/river_pools.py). The big brown trout and
##             the Sacramento suckers lie on the bottom, and fish run larger.
## Everywhere else on a river is a plain "run".
##
## Place one in a story overlay with its top-left corner at [member position]
## and [member size] covering the water: the rapids draw their foam and
## rocks, a hole its slow rings and the odd rising trout. A cast whose fly
## lands inside fishes it (Fishing.water_at).

const RUN := "run"
const FOAM := Color(0.94, 0.97, 1.0, 0.85)
const FOAM_SOFT := Color(0.86, 0.93, 0.97, 0.45)
const ROCK := Color("6e6a64")
const ROCK_LIGHT := Color("9a958c")
const ROCK_DARK := Color("47433e")
const RING := Color(0.85, 0.95, 1.0, 0.5)
## How far past its oval a hole's ragged shore can reach, in pixels.
const EDGE := 16.0

@export_enum("rapids", "hole") var kind := "hole"
## The water's extent from [member position], in pixels.
@export var size := Vector2(256, 96)
## What it's called, for the "Fish" prompt and the catch ("Merced Rapids").
@export var title := ""
## Which way the river runs here (rapids' foam streams this way).
@export var flow := Vector2.RIGHT

var _time := 0.0
var _rng := RandomNumberGenerator.new()
## Boulders in the rapids: [center, radius], laid out once from the name.
var _rocks: Array = []
## Foam streaks: [start offset, length, speed, row].
var _streaks: Array = []
## White caps in the rapids: [position, phase].
var _caps: Array = []
## Rings spreading on a hole: [center, age].
var _rings: Array = []
var _next_ring := 1.0


func _ready() -> void:
	add_to_group("fishing_water")
	# over the ground picture, under everyone standing on the bank
	z_index = -5
	_rng.seed = hash(name)
	if kind == "rapids":
		var count := maxi(4, int(size.x * size.y / 3200.0))
		for i in count:
			var at := Vector2(_rng.randf_range(0.08, 0.92) * size.x, _rng.randf_range(0.2, 0.85) * size.y)
			_rocks.append([at, _rng.randf_range(6.0, 13.0)])
		for i in int(size.x * size.y / 260.0):
			_streaks.append([_rng.randf() * size.x, _rng.randf_range(4.0, 16.0), _rng.randf_range(40.0, 90.0), _rng.randf_range(0.05, 0.95) * size.y])
		# white caps: standing waves that stay put and flicker
		for i in int(size.x * size.y / 700.0):
			_caps.append([Vector2(_rng.randf() * size.x, _rng.randf_range(0.1, 0.9) * size.y), _rng.randf() * TAU])


## The FishingWater whose water holds [param at], or null on a plain run.
static func at(tree: SceneTree, point: Vector2) -> FishingWater:
	for node in tree.get_nodes_in_group("fishing_water"):
		var water := node as FishingWater
		if water and water.is_visible_in_tree() and water.contains(point):
			return water
	return null


## "rapids", "hole" or "run" for the water at [param point].
static func kind_at(tree: SceneTree, point: Vector2) -> String:
	var water := at(tree, point)
	return water.kind if water else RUN


## True if [param point] (global) is inside this stretch: an oval for a
## hole (a little past its edge, where the cut bank wanders out), the whole
## box for rapids.
func contains(point: Vector2) -> bool:
	var local := to_local(point)
	if kind == "rapids":
		return Rect2(Vector2.ZERO, size).has_point(local)
	var half := size / 2.0
	var d := (local - half) / (half + Vector2(EDGE, EDGE))
	return d.length_squared() <= 1.0


func _process(delta: float) -> void:
	_time += delta
	if kind == "hole":
		_next_ring -= delta
		if _next_ring <= 0.0:
			_next_ring = _rng.randf_range(1.2, 3.5)
			var a := _rng.randf() * TAU
			var r := sqrt(_rng.randf()) * 0.6
			_rings.append([size / 2.0 + Vector2(cos(a), sin(a)) * r * size / 2.0, 0.0])
		for ring: Array in _rings:
			ring[1] += delta
		_rings = _rings.filter(func(ring: Array) -> bool: return ring[1] < 2.4)
	queue_redraw()


func _draw() -> void:
	if kind == "rapids":
		_draw_rapids()
	else:
		_draw_hole()


## Foam streaming downstream between the boulders, and a cushion of white
## water piled up against each rock.
func _draw_rapids() -> void:
	var dir := flow.normalized() if flow != Vector2.ZERO else Vector2.RIGHT
	var along := absf(dir.x) >= absf(dir.y)
	var span := size.x if along else size.y
	for streak: Array in _streaks:
		var pos := fposmod(float(streak[0]) + _time * float(streak[2]) * (signf(dir.x) if along else signf(dir.y)), span)
		var length: float = streak[1]
		var row: float = streak[3]
		var wobble := sin(_time * 3.0 + row) * 1.5
		var rect := Rect2(roundf(pos), roundf(row + wobble), roundf(length), 2) if along else Rect2(roundf(row + wobble), roundf(pos), 2, roundf(length))
		rect = rect.intersection(Rect2(Vector2.ZERO, size))
		draw_rect(rect, FOAM_SOFT if int(row) % 3 == 0 else FOAM)
	for cap: Array in _caps:
		var lit := sin(_time * 4.0 + float(cap[1]))
		if lit < -0.2:
			continue
		var at: Vector2 = (cap[0] as Vector2).round()
		# a little chevron of white water, pointing upstream
		var back := -dir.round() * 2.0
		draw_rect(Rect2(at, Vector2(3, 2)), FOAM if lit > 0.4 else FOAM_SOFT)
		draw_rect(Rect2(at + back + Vector2(0, -2), Vector2(2, 2)), FOAM_SOFT)
		draw_rect(Rect2(at + back + Vector2(0, 2), Vector2(2, 2)), FOAM_SOFT)
	for rock: Array in _rocks:
		var c: Vector2 = rock[0]
		var r: float = rock[1]
		# white water piling up on the upstream side
		var up := -dir * r * 0.7
		var surge := 1.0 + sin(_time * 5.0 + c.x) * 0.15
		draw_circle(c + up, r * 1.15 * surge, FOAM)
		# a lumpy granite boulder: two humps, lit from the upper left
		var hump := c + Vector2(r * 0.55, r * 0.25)
		draw_circle(hump, r * 0.7, ROCK_DARK)
		draw_circle(c, r, ROCK_DARK)
		draw_circle(hump - Vector2(1, 1), r * 0.7 - 1.5, ROCK)
		draw_circle(c - Vector2(1, 1), r - 1.5, ROCK)
		draw_rect(Rect2((c - Vector2(r * 0.55, r * 0.6)).round(), Vector2(roundf(r * 0.6), roundf(r * 0.35))), ROCK_LIGHT)
		draw_rect(Rect2((c + Vector2(-r, r * 0.35)).round(), Vector2(roundf(r * 1.8), 2)), Color(ROCK_DARK, 0.9))
		# a tail of foam below it
		for i in 3:
			var t := fposmod(_time * 1.6 + i / 3.0, 1.0)
			draw_circle(c + dir * (r + 4.0 + t * 22.0), r * (0.6 - t * 0.4), Color(FOAM, 0.8 * (1.0 - t)))


## Slow rings where something sipped a bug off the surface.
func _draw_hole() -> void:
	for ring: Array in _rings:
		var age: float = ring[1]
		var radius := 3.0 + age * 9.0
		var fade := 1.0 - age / 2.4
		draw_arc(ring[0], radius, 0.0, TAU, 20, Color(RING, RING.a * fade), 1.0)
		if age < 0.25:
			draw_circle(ring[0], 2.0, Color(RING, 0.8))
