class_name Cabin
extends Node2D
## Your cabin at the homestead, from outside: James Lamon's old log cabin on
## the Guardian's spot, empty and leaky when you arrive. As keepers give you
## things for it (Camp.CABIN) it changes here: a patched roof, then a new
## shake roof and chinked walls, glass in the windows, a window box, a stone
## chimney that smokes, a front porch, a lean-to kitchen, a loft window under
## the roof, and a nameplate over the door.
##
## It draws itself in the sprites' pixel style, like CampPiece, so the
## homestead map never needs a rebuild. The way in is the BuildingDoor in
## scenes/story/doors/lamon_homestead.tscn; the porch chair and mailbox are
## CabinPieces of their own, so you can look at them.

## Where the middle of the front wall's foot stands at the homestead.
const POS := Vector2(752, 290)
## The room inside (scenes/regions/guardian_cabin.tscn).
const ROOM_REGION := "guardian_cabin"
## Map decoration under the cabin and its yard that gives way to it (plants
## and rocks the region scene put there), relative to POS.
const CLEAR := Rect2(-104, -96, 252, 140)

const INK := CampPiece.INK
const LOG := Color("8a5f3a")
const LOG_HI := Color("b0804e")
const LOG_DARK := Color("5a3a22")
const LOG_END := Color("c89a62")
const CHINK := Color("d8c8a0")
const GAP := Color("2a1b14")
const SHAKE_OLD := Color("6e6458")
const SHAKE_OLD_HI := Color("8e8474")
const SHAKE := Color("9a6a3e")
const SHAKE_HI := Color("c08a52")
const SHAKE_DARK := Color("6a4426")
const STONE := Color("a8a296")
const STONE_HI := Color("cfc9bc")
const STONE_DARK := Color("6f6a60")
const PLANK := Color("9a6c40")
const PLANK_HI := Color("c08e58")
const SHUTTER := Color("6a4a30")
const WARM := Color("f6c86a")
const WARM_HI := Color("fde9a8")

var _body: StaticBody2D
var _kitchen_shape: CollisionShape2D
var _chimney_shape: CollisionShape2D
var _light: PointLight2D
var _smoke_t := 0.0


## Puts the cabin (and its chair and mailbox) at the homestead, clearing the
## map's plants and rocks from under it.
static func build(region: Node) -> void:
	if region.entities.has_node("Cabin"):
		return
	var area := Rect2(POS + CLEAR.position, CLEAR.size)
	var dressing: Node = region.entities.get_node_or_null("WildDressing")
	for parent: Node in [region.entities, dressing]:
		if parent == null:
			continue
		for child in parent.get_children():
			if not child is Node2D or (parent == region.entities and not str(child.name).begins_with("Dec_")):
				continue
			if area.has_point((child as Node2D).global_position if child.is_inside_tree() else (child as Node2D).position):
				child.free()
	var cabin := Cabin.new()
	cabin.name = "Cabin"
	cabin.position = POS
	region.entities.add_child(cabin)
	region.entities.add_child(CabinPorch.make())
	for id: String in ["porch_chair", "mailbox"]:
		region.entities.add_child(CabinPiece.make(Camp.get_piece(id), POS + CabinPiece.OUTSIDE_AT[id]))


func _ready() -> void:
	_body = StaticBody2D.new()
	_body.name = "Body"
	_body.collision_mask = 0
	# the log walls, and the chimney at the west end
	_add_shape(Rect2(-84, -46, 168, 46))
	_chimney_shape = _add_shape(Rect2(-106, -30, 24, 30))
	_kitchen_shape = _add_shape(Rect2(84, -40, 58, 40))
	add_child(_body)
	_light = PointLight2D.new()
	_light.name = "WindowLight"
	_light.set_script(load("res://scripts/world/night_light.gd"))
	_light.position = Vector2(0, -26)
	_light.set("radius", 120.0)
	_light.set("strength", 0.8)
	_light.set("flicker", 0.06)
	_light.set("outdoor_only", true)
	add_child(_light)
	Camp.changed.connect(_refresh)
	QuestLog.changed.connect(_refresh)
	GameClock.time_changed.connect(func(_h: int, _m: int) -> void: queue_redraw())
	_refresh()


func _add_shape(rect: Rect2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	_body.add_child(shape)
	return shape


func _refresh() -> void:
	_kitchen_shape.set_deferred("disabled", not Camp.has("kitchen"))
	_chimney_shape.set_deferred("disabled", not Camp.has("hearth"))
	# NightLight owns its visibility: dark behind boards, lit behind glass
	_light.set("strength", 0.8 if Camp.has("glass_windows") else 0.0)
	queue_redraw()


func _process(delta: float) -> void:
	if not Camp.has("hearth") and not Camp.has("kitchen"):
		return
	_smoke_t += delta
	if _smoke_t >= 0.25:
		_smoke_t = 0.0
		queue_redraw()


## The fire's lit in the morning, the evening and all night, and all day in
## winter.
static func fire_lit() -> bool:
	var h := GameClock.hour
	return h < 9 or h >= 17 or GameClock.season == GameClock.Season.WINTER


static func night() -> bool:
	return GameClock.hour >= 19 or GameClock.hour < 6


func _draw() -> void:
	# the trodden yard round the door
	draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 112.0, Color(0.36, 0.25, 0.14, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if Camp.has("hearth"):
		_draw_chimney()
	if Camp.has("kitchen"):
		_draw_lean_to()
	_draw_walls()
	_draw_roof()
	if Camp.has("loft"):
		_draw_dormer()
	_draw_door()
	for x in [-47.0, 47.0]:
		_draw_window(x)
	if Camp.has("window_box"):
		_draw_window_box(-47.0)
	if Camp.has("porch"):
		_draw_porch()
	else:
		# a flat stone for a doorstep
		draw_rect(Rect2(-14, 0, 28, 6).grow(1), INK)
		draw_rect(Rect2(-14, 0, 28, 6), STONE)
		draw_rect(Rect2(-14, 0, 28, 2), STONE_HI)
	if Camp.has("hearth") or Camp.has("kitchen"):
		_draw_smoke()


func _draw_walls() -> void:
	var chinked := Camp.has("shake_roof")
	draw_rect(Rect2(-80, -64, 160, 64).grow(1), INK)
	for i in 8:
		var y := -64.0 + i * 8.0
		draw_rect(Rect2(-80, y, 160, 8), LOG)
		draw_rect(Rect2(-80, y + 1, 160, 1), LOG_HI)
		draw_rect(Rect2(-80, y + 7, 160, 1), CHINK if chinked else GAP)
		if not chinked and i % 3 == 1:
			# daylight through the gaps
			draw_rect(Rect2(-60 + i * 11, y + 7, 9, 1), Color("1a120c"))
		# the log ends past the corners, notched
		for side in [-1.0, 1.0]:
			var x: float = side * 83.0
			draw_circle(Vector2(x, y + 4), 4.5, INK)
			draw_circle(Vector2(x, y + 4), 3.6, LOG_END)
			draw_circle(Vector2(x - 1, y + 3), 1.2, LOG_HI.lightened(0.2))
	# shade under the eaves
	draw_rect(Rect2(-80, -58, 160, 5), Color(0, 0, 0, 0.3))


func _draw_roof() -> void:
	var fresh := Camp.has("shake_roof")
	var body := SHAKE if fresh else SHAKE_OLD
	var hi := SHAKE_HI if fresh else SHAKE_OLD_HI
	var top := -116.0
	var foot := -58.0
	draw_rect(Rect2(-94, top, 188, foot - top).grow(1), INK)
	draw_rect(Rect2(-94, top, 188, foot - top), body)
	# rows of shakes, each row offset half a shake from the one below
	var row := 0
	var y := top + 4.0
	while y < foot:
		var shift := 5.0 if row % 2 == 0 else 0.0
		var x := -94.0 + shift
		while x < 94.0:
			draw_rect(Rect2(x, y, 1, 6), body.darkened(0.3))
			draw_rect(Rect2(x + 1, y, 4, 1), hi)
			x += 10.0
		draw_rect(Rect2(-94, y + 6, 188, 1), body.darkened(0.35))
		y += 7.0
		row += 1
	# the ridge
	draw_rect(Rect2(-96, top - 3, 192, 5).grow(1), INK)
	draw_rect(Rect2(-96, top - 3, 192, 5), body.darkened(0.15))
	draw_rect(Rect2(-96, top - 3, 192, 1), hi)
	# the eave's lit edge
	draw_rect(Rect2(-94, foot - 2, 188, 2), hi)
	if fresh:
		return
	# the old roof's holes (or the wagon sheet over them)
	var holes := [Rect2(-60, -104, 22, 12), Rect2(18, -94, 26, 14), Rect2(-12, -78, 16, 10)]
	if Camp.has("roof_patch"):
		var sheet := Rect2(-66, -106, 116, 40)
		draw_rect(sheet.grow(1), INK)
		draw_rect(sheet, CampPiece.CANVAS)
		draw_rect(Rect2(sheet.position.x, sheet.end.y - 4, sheet.size.x, 4), CampPiece.CANVAS_SHADE)
		for bx in [-62.0, -20.0, 22.0, 46.0]:
			draw_rect(Rect2(bx, sheet.position.y - 1, 3, sheet.size.y + 2), LOG_DARK)
			draw_rect(Rect2(bx, sheet.position.y - 1, 1, sheet.size.y + 2), LOG)
	else:
		for hole: Rect2 in holes:
			draw_rect(hole, GAP)
			# rafters across the gap
			for rx in range(int(hole.position.x) + 4, int(hole.end.x), 8):
				draw_rect(Rect2(rx, hole.position.y, 2, hole.size.y), LOG_DARK)


func _draw_door() -> void:
	draw_rect(Rect2(-12, -46, 24, 46).grow(1), INK)
	draw_rect(Rect2(-12, -46, 24, 46), PLANK)
	for x in [-6.0, 0.0, 6.0]:
		draw_rect(Rect2(x, -46, 1, 46), PLANK.darkened(0.3))
	draw_rect(Rect2(-12, -46, 24, 2), PLANK_HI)
	# a Z brace
	draw_rect(Rect2(-11, -38, 22, 3), PLANK.darkened(0.15))
	draw_rect(Rect2(-11, -12, 22, 3), PLANK.darkened(0.15))
	draw_line(Vector2(-10, -12), Vector2(10, -35), PLANK.darkened(0.25), 2.0)
	if Camp.has("porch"):
		# Anderson's forged latch
		draw_rect(Rect2(5, -24, 6, 2), CampPiece.IRON)
		draw_rect(Rect2(9, -26, 2, 6), CampPiece.IRON_HI)
	else:
		draw_rect(Rect2(6, -23, 3, 3), LOG_DARK)
	if Camp.has("register_stand"):
		# the nameplate: THE GUARDIAN, carved and inked
		draw_rect(Rect2(-22, -57, 44, 8).grow(1), INK)
		draw_rect(Rect2(-22, -57, 44, 8), LOG_END)
		var x := -19.0
		for word: int in [3, 8]:
			for i in word:
				draw_rect(Rect2(x, -55, 2, 4), LOG_DARK)
				draw_rect(Rect2(x, -55, 3, 1), LOG_DARK)
				x += 3.6
			x += 3.0


func _draw_window(x: float) -> void:
	var r := Rect2(x - 13, -44, 26, 22)
	draw_rect(r.grow(2), INK)
	draw_rect(r.grow(1), LOG_DARK)
	if Camp.has("glass_windows"):
		var lit := night() or (fire_lit() and GameClock.hour >= 17)
		var pane := WARM if lit else CampPiece.GLASS
		draw_rect(r, pane)
		if lit:
			draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(8, 6)), WARM_HI)
		else:
			# sky in the glass, and a glint
			draw_rect(Rect2(r.position, Vector2(r.size.x, 8)), Color("e8f2f4"))
			draw_line(r.position + Vector2(4, 14), r.position + Vector2(12, 4), Color(1, 1, 1, 0.8), 1.0)
		draw_rect(Rect2(x - 1, r.position.y, 2, r.size.y), LOG_DARK)
		draw_rect(Rect2(r.position.x, r.position.y + 10, r.size.x, 2), LOG_DARK)
		# shutters folded back either side
		for side in [-1.0, 1.0]:
			var sx: float = x + side * 20.0 - 5.0
			draw_rect(Rect2(sx, -45, 10, 24).grow(1), INK)
			draw_rect(Rect2(sx, -45, 10, 24), Color("4f6a3a"))
			draw_rect(Rect2(sx, -45, 10, 1), Color("6f8a52"))
	else:
		# shut with boards
		draw_rect(r, SHUTTER)
		for i in 4:
			draw_rect(Rect2(r.position.x, r.position.y + i * 5.5, r.size.x, 1), SHUTTER.darkened(0.35))
		draw_line(r.position, r.end, SHUTTER.lightened(0.2), 2.0)
	# the sill
	draw_rect(Rect2(x - 15, -22, 30, 3).grow(1), INK)
	draw_rect(Rect2(x - 15, -22, 30, 3), LOG_END)


func _draw_window_box(x: float) -> void:
	var box := Rect2(x - 15, -19, 30, 7)
	draw_rect(box.grow(1), INK)
	draw_rect(box, Color("7a5434"))
	draw_rect(Rect2(box.position, Vector2(box.size.x, 1)), Color("9a7048"))
	var colors := [Color("d0508a"), Color("f0c040"), Color("8a6ad8"), Color("e8783a"), Color("f4f0e8")]
	for i in 7:
		var fx := box.position.x + 3 + i * 4
		draw_rect(Rect2(fx, -24 + (i % 2) * 2, 1, 5), Color("4f7a34"))
		draw_rect(Rect2(fx - 1, -25 + (i % 2) * 2, 3, 2), colors[i % colors.size()])


func _draw_chimney() -> void:
	var r := Rect2(-106, -130, 22, 130)
	draw_rect(r.grow(1), INK)
	draw_rect(r, STONE)
	var rows := 0
	var y := r.position.y + 2
	while y < 0:
		var shift := 5.0 if rows % 2 == 0 else 0.0
		var x := r.position.x + shift
		while x < r.end.x:
			draw_rect(Rect2(x, y, 9, 6), STONE_DARK)
			draw_rect(Rect2(x + 1, y, 7, 5), STONE if (rows + int(x)) % 3 else STONE_HI)
			x += 10.0
		y += 7.0
		rows += 1
	draw_rect(Rect2(r.position.x - 2, r.position.y - 3, r.size.x + 4, 5).grow(1), INK)
	draw_rect(Rect2(r.position.x - 2, r.position.y - 3, r.size.x + 4, 5), STONE_HI)


func _draw_lean_to() -> void:
	# the kitchen: shorter log walls on the east end under a shed roof
	draw_rect(Rect2(80, -40, 62, 40).grow(1), INK)
	for i in 5:
		var y := -40.0 + i * 8.0
		draw_rect(Rect2(80, y, 62, 8), LOG.darkened(0.06))
		draw_rect(Rect2(80, y + 1, 62, 1), LOG_HI)
		draw_rect(Rect2(80, y + 7, 62, 1), CHINK if Camp.has("shake_roof") else GAP)
	# a little window, lit when the stove is
	var w := Rect2(104, -30, 16, 14)
	draw_rect(w.grow(2), INK)
	draw_rect(w, WARM if fire_lit() else CampPiece.GLASS)
	draw_rect(Rect2(111, -30, 2, 14), LOG_DARK)
	var roof := PackedVector2Array([Vector2(78, -76), Vector2(148, -46), Vector2(148, -38), Vector2(78, -60)])
	var rim := PackedVector2Array([Vector2(77, -78), Vector2(150, -47), Vector2(150, -36), Vector2(77, -58)])
	draw_colored_polygon(rim, INK)
	draw_colored_polygon(roof, SHAKE)
	for i in 6:
		var x := 84.0 + i * 11.0
		var t := (x - 78.0) / 70.0
		draw_line(Vector2(x, -76 + t * 30), Vector2(x, -60 + t * 22), SHAKE_DARK, 1.0)
	# the cookstove's pipe
	draw_rect(Rect2(128, -76, 5, 26), CampPiece.IRON)
	draw_rect(Rect2(127, -78, 7, 3), CampPiece.IRON_HI)


func _draw_dormer() -> void:
	var base := -66.0
	draw_rect(Rect2(-15, -102, 30, 36).grow(1), INK)
	draw_rect(Rect2(-15, -102, 30, 36), LOG)
	var w := Rect2(-8, -94, 16, 14)
	draw_rect(w.grow(1), LOG_DARK)
	draw_rect(w, WARM if night() else CampPiece.GLASS)
	draw_rect(Rect2(-1, -94, 2, 14), LOG_DARK)
	var peak := PackedVector2Array([Vector2(-20, -100), Vector2(0, -118), Vector2(20, -100)])
	draw_colored_polygon(PackedVector2Array([Vector2(-22, -99), Vector2(0, -120), Vector2(22, -99)]), INK)
	draw_colored_polygon(peak, SHAKE if Camp.has("shake_roof") else SHAKE_OLD)
	draw_rect(Rect2(-15, base - 2, 30, 2), Color(0, 0, 0, 0.25))


func _draw_porch() -> void:
	var deck := Rect2(-92, -2, 184, 18)
	draw_rect(deck.grow(1), INK)
	draw_rect(deck, PLANK)
	for x in range(-92, 92, 12):
		draw_rect(Rect2(x, deck.position.y, 1, deck.size.y), PLANK.darkened(0.28))
	draw_rect(Rect2(deck.position.x, deck.position.y, deck.size.x, 2), PLANK_HI)
	draw_rect(Rect2(deck.position.x, deck.end.y - 3, deck.size.x, 3), PLANK.darkened(0.35))
	# steps down to the yard
	for i in 2:
		var s := Rect2(-16 + i * 2, 16 + i * 4, 32 - i * 4, 4)
		draw_rect(s.grow(1), INK)
		draw_rect(s, PLANK_HI if i == 0 else PLANK)


func _draw_smoke() -> void:
	if not fire_lit():
		return
	var t := Time.get_ticks_msec() / 1000.0
	var tops: Array[Vector2] = []
	if Camp.has("hearth"):
		tops.append(Vector2(-95, -134))
	if Camp.has("kitchen"):
		tops.append(Vector2(130, -80))
	for top in tops:
		for i in 4:
			var k := fmod(t * 0.35 + i * 0.25, 1.0)
			var at := top + Vector2(sin(k * 5.0 + i) * 4.0 + k * 10.0, -k * 40.0)
			draw_circle(at, 3.0 + k * 5.0, Color(0.85, 0.85, 0.85, 0.45 * (1.0 - k)))
