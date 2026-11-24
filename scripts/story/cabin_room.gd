class_name CabinRoom
extends Node2D
## The inside of your cabin (the guardian_cabin region): log walls, a plank
## floor, two windows and the door, drawn here so the room can change as
## keepers fix it up and furnish it (Camp.CABIN). The scene itself
## (tools/hubs/build_cabin.gd) only holds the walls' tiles, the way out and
## the spots; Camp.dress calls [method furnish] to add this, the furniture
## (CabinPiece) and the bed you sleep in.
##
## The room is sized for the finished cabin: the lean-to kitchen through
## the east wall is shut off (a wall and darkness) until Bridget Degnan
## builds it.

## Tile size, and the room's size in tiles (walls included).
const T := 32
const W := 24
const H := 12
## The main room's floor, and the kitchen's.
const MAIN := Rect2(32, 96, 448, 256)
const KITCHEN := Rect2(512, 96, 224, 256)
## The way between them, through the east wall.
const DOORWAY := Rect2(480, 192, 32, 64)
## The front door's gap in the south wall.
const DOOR_X := Vector2(224, 288)
## Windows in the back wall (centres).
const WINDOWS := [128.0, 384.0]
const KITCHEN_WINDOW := 680.0
## Where you wake after sleeping in the bed (a marker in the scene).
const BED_SPOT := "bed"

const INK := CampPiece.INK
const LOG := Cabin.LOG
const LOG_HI := Cabin.LOG_HI
const LOG_DARK := Cabin.LOG_DARK
const LOG_END := Cabin.LOG_END
const CHINK := Cabin.CHINK
const GAP := Cabin.GAP
const FLOOR := Color("8a6440")
const FLOOR_HI := Color("a07650")
const FLOOR_DARK := Color("5e4228")

var _doorway: StaticBody2D
var _bed: StaticBody2D


## Furnishes the cabin region: the room's picture, every inside thing keepers
## can give, the bed, and the wall that shuts off the kitchen.
static func furnish(region: Node) -> void:
	var room := CabinRoom.new()
	room.name = "CabinRoom"
	room._bed = _make_bed()
	region.entities.add_child(room)
	# a sibling in Entities, there before World looks for beds and tents
	region.entities.add_child(room._bed)
	for part: Dictionary in Camp.CABIN:
		if part.where != "outside" and part.has("pos"):
			region.entities.add_child(CabinPiece.make(part, part.pos))


## The bed sleeps like the tent does (World connects anything with
## sleep_requested), from the day Lamon gives it.
static func _make_bed() -> StaticBody2D:
	var bed := StaticBody2D.new()
	bed.name = "Bed"
	bed.set_script(load("res://scripts/objects/tent.gd"))
	bed.collision_layer = 0
	bed.collision_mask = 0
	bed.position = Camp.get_piece("rope_bed").pos
	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 4
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	var reach := CollisionShape2D.new()
	var reach_rect := RectangleShape2D.new()
	reach_rect.size = Vector2(84, 52)
	reach.shape = reach_rect
	reach.position = Vector2(0, -16)
	hitbox.add_child(reach)
	bed.add_child(hitbox)
	return bed


func _ready() -> void:
	z_index = -8
	_doorway = StaticBody2D.new()
	_doorway.name = "KitchenWall"
	_doorway.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = DOORWAY.size
	shape.shape = rect
	shape.position = DOORWAY.get_center()
	_doorway.add_child(shape)
	add_child(_doorway)
	Camp.changed.connect(_refresh)
	QuestLog.changed.connect(_refresh)
	GameClock.time_changed.connect(func(_h: int, _m: int) -> void: queue_redraw())
	_refresh()


## The bed you sleep in, once you have one.
func bed() -> StaticBody2D:
	return _bed


func _refresh() -> void:
	var kitchen := Camp.has("kitchen")
	for child in _doorway.get_children():
		(child as CollisionShape2D).set_deferred("disabled", kitchen)
	var hitbox := _bed.get_node("Hitbox") as Area2D
	hitbox.set_deferred("monitorable", Camp.has("rope_bed"))
	queue_redraw()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	var kitchen := Camp.has("kitchen")
	_draw_back_wall(Rect2(32, 0, 448, 96))
	_draw_floor(MAIN)
	if kitchen:
		_draw_back_wall(Rect2(512, 0, 224, 96))
		_draw_floor(KITCHEN)
		_draw_floor(DOORWAY)
		_draw_kitchen_things()
	for x: float in WINDOWS:
		_draw_window(x, 40.0)
	if kitchen:
		_draw_window(KITCHEN_WINDOW, 32.0)
	if not Camp.has("roof_patch") and not Camp.has("shake_roof"):
		_draw_leaks()
	if Camp.has("hearth"):
		_draw_rug(Vector2(256, 176))
	if Camp.has("loft"):
		_draw_loft()
	# the walls' tops: west, east (or the partition), the kitchen's east,
	# and the front wall with the door's gap
	_draw_wall_top(Rect2(0, 0, 32, 384))
	if kitchen:
		_draw_wall_top(Rect2(480, 0, 32, DOORWAY.position.y))
		_draw_wall_top(Rect2(480, DOORWAY.end.y, 32, 384 - DOORWAY.end.y))
		_draw_wall_top(Rect2(736, 0, 32, 384))
		_draw_wall_top(Rect2(DOOR_X.y, 352, 768 - DOOR_X.y, 32))
	else:
		_draw_wall_top(Rect2(480, 0, 32, 384))
		_draw_wall_top(Rect2(DOOR_X.y, 352, 512 - DOOR_X.y, 32))
	_draw_wall_top(Rect2(0, 352, DOOR_X.x, 32))
	# the threshold
	draw_rect(Rect2(DOOR_X.x, 352, DOOR_X.y - DOOR_X.x, 32), FLOOR_DARK)
	draw_rect(Rect2(DOOR_X.x, 352, DOOR_X.y - DOOR_X.x, 3), FLOOR_HI)


func _draw_back_wall(r: Rect2) -> void:
	var chinked := Camp.has("shake_roof")
	draw_rect(r, LOG)
	var logs := 8
	var h := r.size.y / logs
	for i in logs:
		var y := r.position.y + i * h
		draw_rect(Rect2(r.position.x, y + 1, r.size.x, 2), LOG_HI)
		draw_rect(Rect2(r.position.x, y + h - 2, r.size.x, 2), CHINK if chinked else GAP)
		# the grain
		for x in range(int(r.position.x) + (i * 37) % 50, int(r.end.x), 53):
			draw_rect(Rect2(x, y + 5, 14, 1), LOG_DARK)
		if not chinked and i % 2 == 1:
			# daylight through the gaps
			for x in range(int(r.position.x) + 20 + i * 13, int(r.end.x) - 20, 97):
				draw_rect(Rect2(x, y + h - 2, 10, 1), Color("f0e0b0"))
	# the wall's foot: a dark sill log
	draw_rect(Rect2(r.position.x, r.end.y - 6, r.size.x, 6), LOG_DARK)
	draw_rect(Rect2(r.position.x, r.end.y - 6, r.size.x, 1), LOG)


func _draw_floor(r: Rect2) -> void:
	draw_rect(r, FLOOR)
	var row := 0
	var y := r.position.y
	while y < r.end.y:
		draw_rect(Rect2(r.position.x, y, r.size.x, 1), FLOOR_DARK)
		draw_rect(Rect2(r.position.x, y + 1, r.size.x, 1), FLOOR_HI)
		var x := r.position.x + float((row * 71) % 96)
		while x < r.end.x:
			draw_rect(Rect2(x, y, 1, 16), FLOOR_DARK)
			x += 96.0
		y += 16.0
		row += 1
	# shade under the back wall
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 8), Color(0, 0, 0, 0.18))


func _draw_wall_top(r: Rect2) -> void:
	draw_rect(r, Color("2e2018"))
	draw_rect(r.grow(-3), LOG_DARK)
	draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, 2)), LOG)


## The sky outside at this hour.
func _sky() -> Color:
	var h := GameClock.hour
	if h >= 20 or h < 5:
		return Color("1c2848")
	if h < 7:
		return Color("e8a878")
	if h >= 18:
		return Color("f0a060")
	return Color("a8d4ec")


func _draw_window(x: float, width: float) -> void:
	var r := Rect2(x - width / 2.0, 20, width, 46)
	draw_rect(r.grow(3), INK)
	draw_rect(r.grow(2), LOG_END)
	if Camp.has("glass_windows"):
		var sky := _sky()
		draw_rect(r, sky)
		# the far wall of the valley and the treetops
		draw_rect(Rect2(r.position.x, r.position.y + 22, r.size.x, 10), sky.darkened(0.25).lerp(Color("8c877c"), 0.5))
		for i in int(width / 8.0):
			var tx := r.position.x + 4 + i * 8
			draw_colored_polygon(PackedVector2Array([Vector2(tx - 4, r.end.y), Vector2(tx, r.end.y - 14 - (i % 2) * 4), Vector2(tx + 4, r.end.y)]), Color("2f5a34").lerp(sky, 0.15))
		if sky == Color("1c2848"):
			for i in 4:
				draw_rect(Rect2(r.position.x + 5 + i * 9, r.position.y + 4 + (i % 2) * 7, 1, 1), Color("f4f0d0"))
		draw_rect(Rect2(x - 1, r.position.y, 2, r.size.y), LOG_DARK)
		for k in 2:
			draw_rect(Rect2(r.position.x, r.position.y + 15 + k * 15, r.size.x, 2), LOG_DARK)
		draw_line(r.position + Vector2(4, 12), r.position + Vector2(10, 4), Color(1, 1, 1, 0.6), 1.0)
		# a pale shaft of day on the floor below
		if GameClock.hour >= 7 and GameClock.hour < 18:
			draw_colored_polygon(PackedVector2Array([Vector2(r.position.x, 96), Vector2(r.end.x, 96),
				Vector2(r.end.x + 18, 150), Vector2(r.position.x + 18, 150)]), Color(1.0, 0.95, 0.8, 0.12))
	else:
		# shutters, light at the cracks by day
		draw_rect(r, Color("5a3e28"))
		for i in 5:
			draw_rect(Rect2(r.position.x + i * width / 5.0, r.position.y, 1, r.size.y), Color("3a2818"))
		if GameClock.hour >= 7 and GameClock.hour < 18:
			draw_rect(Rect2(x - 1, r.position.y, 1, r.size.y), Color("f0e0b0"))
		draw_rect(Rect2(r.position.x, r.position.y + 10, r.size.x, 3), Color("6a4a30"))
		draw_rect(Rect2(r.position.x, r.end.y - 13, r.size.x, 3), Color("6a4a30"))
	draw_rect(Rect2(r.position.x - 4, r.end.y + 2, r.size.x + 8, 4), LOG_END)


func _draw_leaks() -> void:
	# the old roof lets the weather in: sun spots by day, a puddle, leaves
	if GameClock.hour >= 7 and GameClock.hour < 18:
		for spot: Vector2 in [Vector2(150, 200), Vector2(330, 160), Vector2(260, 290)]:
			draw_set_transform(spot, 0.0, Vector2(1.0, 0.5))
			draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.95, 0.75, 0.22))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(Vector2(352, 240), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 18.0, Color(0.45, 0.6, 0.7, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for leaf: Vector2 in [Vector2(80, 300), Vector2(96, 312), Vector2(200, 130), Vector2(420, 320), Vector2(300, 200), Vector2(440, 140)]:
		draw_rect(Rect2(leaf, Vector2(4, 2)), Color("b8862e"))
		draw_rect(Rect2(leaf + Vector2(1, 1), Vector2(2, 2)), Color("8a5a22"))


func _draw_rug(at: Vector2) -> void:
	var colors := [Color("6a3a2a"), Color("c89a52"), Color("3a5a4a"), Color("b8402e")]
	for i in 4:
		draw_set_transform(at, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 54.0 - i * 11.0, colors[i])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_loft() -> void:
	# the loft's edge across the top of the back wall, a bedroll showing
	var r := Rect2(392, 0, 88, 30)
	draw_rect(r, LOG_DARK)
	draw_rect(Rect2(r.position.x, r.end.y - 8, r.size.x, 8), Color("9a6c40"))
	draw_rect(Rect2(r.position.x, r.end.y - 8, r.size.x, 1), FLOOR_HI)
	draw_rect(Rect2(404, 8, 36, 12), Color("3f6fa8"))
	draw_rect(Rect2(404, 8, 36, 2), Color("6c98cc"))
	for x in range(396, 480, 12):
		draw_rect(Rect2(x, r.end.y - 18, 2, 10), LOG_END)
	draw_rect(Rect2(r.position.x, r.end.y - 20, r.size.x, 3), LOG_END)


func _draw_kitchen_things() -> void:
	# a dry sink and a shelf of crocks along the back wall
	var sink := Rect2(648, 70, 64, 30)
	draw_rect(sink.grow(1), INK)
	draw_rect(sink, Color("7a5434"))
	draw_rect(Rect2(652, 72, 56, 8), Color("5a6a70"))
	draw_rect(Rect2(652, 72, 56, 2), Color("8a9aa0"))
	draw_rect(Rect2(540, 34, 72, 4), Color("7a5434"))
	for i in 5:
		var c := Rect2(544 + i * 14, 22, 10, 12)
		draw_rect(c.grow(1), INK)
		draw_rect(c, [Color("d8ccb0"), Color("8a5a3a"), Color("c8b890")][i % 3])
	# strings of drying apples and chilies
	for i in 6:
		draw_rect(Rect2(540 + i * 4, 44 + (i % 2) * 2, 3, 3), Color("b83a2a") if i % 2 else Color("e0b040"))
