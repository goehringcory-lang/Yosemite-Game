class_name CabinPiece
extends Node2D
## One thing a keeper gave for your cabin (Camp.CABIN) that you can walk up
## to and look at: the rope bed, the table, the hearth, the cookstove and
## the rest inside, and the porch chair and mailbox outside. It isn't there
## until you have it. Like CampPiece it draws itself, so no art files.
##
## The bed's sleeping is a Tent (scripts/objects/tent.gd) laid over it by
## CabinRoom, so it works the way the tent does.

const NAME_PREFIX := "Cabin_"
## Where the outside things stand, from the middle of the cabin's front wall
## (Cabin.POS).
const OUTSIDE_AT := {"porch_chair": Vector2(56, 8), "mailbox": Vector2(-122, 30)}
## Solid footprint by piece (none for things on the wall).
const FOOTPRINT := {
	"rope_bed": Vector2(68, 34), "table": Vector2(64, 22), "bookshelf": Vector2(48, 10), "hearth": Vector2(60, 10),
	"kitchen": Vector2(50, 10), "loft": Vector2(18, 8), "writing_desk": Vector2(40, 14), "register_stand": Vector2(16, 8),
	"mailbox": Vector2(6, 6),
}
## Pieces hung on the wall: you look at them from the floor below.
const ON_WALL := ["valley_map", "prints"]

const INK := CampPiece.INK
const WOOD := CampPiece.WOOD
const WOOD_HI := CampPiece.WOOD_HI
const WOOD_DARK := CampPiece.WOOD_DARK
const IRON := CampPiece.IRON
const IRON_HI := CampPiece.IRON_HI
const STONE := Cabin.STONE
const STONE_HI := Cabin.STONE_HI
const STONE_DARK := Cabin.STONE_DARK
const FLAME := CampPiece.FLAME
const FLAME_HI := CampPiece.FLAME_HI
const PAPER := CampPiece.PAPER
const SHADOW := CampPiece.SHADOW

## A Camp.CABIN entry.
var piece: Dictionary = {}

var _hitbox: Area2D
var _body: StaticBody2D
var _light: PointLight2D
var _tick := 0.0


static func make(for_piece: Dictionary, at: Vector2) -> CabinPiece:
	var node := CabinPiece.new()
	node.piece = for_piece
	node.name = NAME_PREFIX + str(for_piece.id)
	node.position = at
	return node


func _ready() -> void:
	var foot: Vector2 = FOOTPRINT.get(piece.id, Vector2.ZERO)
	if foot.x > 0.0:
		_body = StaticBody2D.new()
		_body.name = "Body"
		_body.collision_mask = 0
		var solid := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = foot
		solid.shape = rect
		solid.position = Vector2(0, -foot.y / 2.0)
		_body.add_child(solid)
		add_child(_body)
	# the bed's own reach is for sleeping (CabinRoom lays a Tent over it)
	_hitbox = Area2D.new()
	_hitbox.name = "Hitbox"
	_hitbox.collision_layer = 4
	_hitbox.collision_mask = 0
	_hitbox.monitoring = false
	var shape := CollisionShape2D.new()
	var reach := RectangleShape2D.new()
	reach.size = Vector2(maxf(foot.x + 12.0, 32.0), 36)
	shape.shape = reach
	shape.position = Vector2(0, 10) if piece.id in ON_WALL else Vector2(0, -14)
	_hitbox.add_child(shape)
	if piece.id != "rope_bed":
		add_child(_hitbox)
	if piece.id == "hearth" or piece.id == "kitchen":
		_light = PointLight2D.new()
		_light.name = "FireLight"
		_light.set_script(load("res://scripts/world/night_light.gd"))
		_light.position = Vector2(0, -18)
		_light.set("radius", 150.0 if piece.id == "hearth" else 100.0)
		_light.set("strength", 0.9)
		_light.set("flicker", 0.15)
		add_child(_light)
	Camp.changed.connect(_refresh)
	QuestLog.changed.connect(_refresh)
	_refresh()


func is_shown() -> bool:
	return Camp.has(piece.id)


func _refresh() -> void:
	var shown := is_shown()
	visible = shown
	if _hitbox.is_inside_tree():
		_hitbox.set_deferred("monitorable", shown)
	if _body:
		for child in _body.get_children():
			(child as CollisionShape2D).set_deferred("disabled", not shown)
	queue_redraw()


func _process(delta: float) -> void:
	if _light == null or not visible:
		return
	_light.visible = Cabin.fire_lit()
	_tick += delta
	if _tick >= 0.18:
		_tick = 0.0
		queue_redraw()


func get_prompt() -> String:
	return "Look at the %s" % str(piece.name).to_lower()


func interact(_player: Player) -> void:
	if not is_shown():
		return
	get_tree().call_group("hud", "show_info", piece.name, Camp.describe(piece.id))


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if not is_shown():
		return
	match piece.id:
		"porch_chair": _draw_chair()
		"mailbox": _draw_mailbox()
		"rope_bed": _draw_bed()
		"table": _draw_table()
		"valley_map": _draw_map()
		"bookshelf": _draw_bookshelf()
		"hearth": _draw_hearth()
		"prints": _draw_prints()
		"kitchen": _draw_stove()
		"loft": _draw_ladder()
		"writing_desk": _draw_desk()
		"register_stand": _draw_register()


func _shadow(width: float, height := 6.0) -> void:
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, height / width))
	draw_circle(Vector2.ZERO, width / 2.0, SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _box(rect: Rect2, fill: Color) -> void:
	draw_rect(rect.grow(1), INK)
	draw_rect(rect, fill)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1)), fill.lightened(0.25))
	draw_rect(Rect2(rect.position.x, rect.end.y - 1, rect.size.x, 1), fill.darkened(0.3))


func _fire(at: Vector2, width: float) -> void:
	if not Cabin.fire_lit():
		# cold ashes and a log
		draw_rect(Rect2(at.x - width / 2.0, at.y - 3, width, 3), Color("5a5550"))
		draw_rect(Rect2(at.x - width / 3.0, at.y - 6, width * 0.66, 3), WOOD_DARK)
		return
	var t := Time.get_ticks_msec() / 160
	draw_rect(Rect2(at.x - width / 2.0, at.y - 4, width, 4), Color("c8502a"))
	for i in 4:
		var h := 7.0 + float((t + i * 3) % 5) * 1.6
		var x := at.x - width / 2.0 + 2 + i * (width - 4) / 4.0
		draw_rect(Rect2(x, at.y - 3 - h, 3, h), FLAME)
		draw_rect(Rect2(x + 1, at.y - 3 - h * 0.6, 1, h * 0.6), FLAME_HI)


func _draw_chair() -> void:
	_shadow(20, 5)
	# incense cedar, with a woven rawhide seat
	var cedar := Color("a0603a")
	draw_rect(Rect2(-8, -26, 3, 26).grow(1), INK)
	draw_rect(Rect2(5, -26, 3, 26).grow(1), INK)
	draw_rect(Rect2(-8, -26, 3, 26), cedar)
	draw_rect(Rect2(5, -26, 3, 26), cedar)
	for y in [-24.0, -19.0]:
		draw_rect(Rect2(-7, y, 14, 2), cedar.lightened(0.15))
	draw_rect(Rect2(-9, -12, 18, 5).grow(1), INK)
	draw_rect(Rect2(-9, -12, 18, 5), Color("d8c4a0"))
	for x in [-6.0, -2.0, 2.0, 6.0]:
		draw_rect(Rect2(x, -12, 1, 5), Color("b8a070"))
	draw_rect(Rect2(-8, -7, 2, 7), cedar.darkened(0.2))
	draw_rect(Rect2(6, -7, 2, 7), cedar.darkened(0.2))


func _draw_mailbox() -> void:
	_shadow(10, 4)
	draw_rect(Rect2(-2, -26, 4, 26).grow(1), INK)
	draw_rect(Rect2(-2, -26, 4, 26), WOOD)
	draw_rect(Rect2(-8, -36, 16, 10).grow(1), INK)
	draw_rect(Rect2(-8, -36, 16, 10), Color("9aa0a0"))
	draw_rect(Rect2(-8, -36, 16, 2), Color("c8cccc"))
	draw_rect(Rect2(-8, -29, 16, 1), Color("6a7070"))
	# the flag's up when there's mail: always, in a cozy game
	draw_rect(Rect2(8, -40, 2, 10), IRON)
	draw_rect(Rect2(8, -40, 6, 4), Color("c83a2a"))


func _draw_bed() -> void:
	_shadow(72, 10)
	# pine frame, head against the west wall
	_box(Rect2(-34, -36, 68, 34), Color("9a6c40"))
	draw_rect(Rect2(-34, -42, 6, 40).grow(1), INK)
	draw_rect(Rect2(-34, -42, 6, 40), Color("8a5a32"))
	# hay tick, pillow and a wool blanket
	draw_rect(Rect2(-27, -33, 58, 28), Color("e4d6a8"))
	draw_rect(Rect2(-26, -31, 12, 22), Color("f2ead2"))
	draw_rect(Rect2(-10, -34, 42, 30).grow(1), INK)
	draw_rect(Rect2(-10, -34, 42, 30), Color("a83a2e"))
	for x in [-4.0, 10.0, 24.0]:
		draw_rect(Rect2(x, -34, 2, 30), Color("2a2a3a"))
	draw_rect(Rect2(-10, -34, 42, 2), Color("c85a48"))
	for x in [-30.0, 30.0]:
		draw_rect(Rect2(x, -2, 3, 4), WOOD_DARK)


func _draw_table() -> void:
	_shadow(70, 10)
	# the bench behind
	_box(Rect2(-28, -36, 56, 5), WOOD)
	var top := Rect2(-32, -28, 64, 18)
	_box(top, Color("b08458"))
	for y in [-22.0, -16.0]:
		draw_rect(Rect2(top.position.x, y, top.size.x, 1), Color("8a6440"))
	for x in [-28.0, 26.0]:
		draw_rect(Rect2(x, -10, 3, 10), WOOD_DARK)
	# the bread box and a loaf
	_box(Rect2(10, -38, 16, 10), Color("8a9aa0"))
	draw_rect(Rect2(12, -36, 12, 2), Color("b8c8cc"))
	draw_rect(Rect2(-18, -25, 14, 6).grow(1), INK)
	draw_rect(Rect2(-18, -25, 14, 6), Color("c8863a"))
	draw_rect(Rect2(-16, -25, 10, 1), Color("e8b060"))
	# a bench in front
	_box(Rect2(-28, -6, 56, 5), WOOD)


func _draw_map() -> void:
	var r := Rect2(-20, -80, 40, 30)
	draw_rect(r.grow(2), INK)
	draw_rect(r.grow(1), WOOD)
	draw_rect(r, Color("e8dcb8"))
	# the valley floor and its walls, contour lines and the river
	for i in 4:
		draw_arc(Vector2(0, -65), 6.0 + i * 4.0, 0.3, PI * 2 - 0.3, 12, Color("a08a60"), 1.0)
	draw_line(Vector2(-18, -60), Vector2(18, -68), Color("4a7ab0"), 1.0)
	draw_rect(Rect2(-12, -76, 10, 5), Color(0.4, 0.55, 0.8, 0.35))
	# a pin in the cabin's spot
	draw_rect(Rect2(3, -63, 2, 2), Color("c83a2a"))


func _draw_bookshelf() -> void:
	_shadow(50, 6)
	var r := Rect2(-24, -84, 48, 84)
	_box(r, WOOD_DARK)
	var colors := [Color("8a2a24"), Color("2a5a3a"), Color("2a3a6a"), Color("c8a050"), Color("5a3a6a"), Color("3a6a6a")]
	for shelf in 3:
		var y := -80.0 + shelf * 27.0
		var x := -21.0
		var i := shelf * 2
		while x < 18.0:
			var w := 3.0 + float(i % 3)
			var h := 18.0 + float((i * 7) % 5)
			draw_rect(Rect2(x, y + 22 - h, w, h), colors[i % colors.size()])
			draw_rect(Rect2(x, y + 22 - h, 1, h), Color(1, 1, 1, 0.15))
			x += w + 1.0
			i += 1
		draw_rect(Rect2(-23, y + 22, 46, 3), WOOD)


func _draw_hearth() -> void:
	# granite surround and river-stone chimney breast up the back wall
	var r := Rect2(-32, -100, 64, 100)
	draw_rect(r.grow(1), Cabin.INK)
	draw_rect(r, STONE)
	var row := 0
	var y := r.position.y + 2
	while y < -2:
		var shift := 6.0 if row % 2 == 0 else 0.0
		var x := r.position.x + shift
		while x < r.end.x - 2:
			draw_rect(Rect2(x, y, 11, 7), STONE_DARK)
			draw_rect(Rect2(x + 1, y, 9, 6), STONE_HI if (row + int(x / 11.0)) % 3 == 0 else STONE)
			x += 12.0
		y += 8.0
		row += 1
	# the mantel, a lantern and a mug
	_box(Rect2(-36, -50, 72, 5), WOOD)
	draw_rect(Rect2(-28, -58, 6, 8), Color("e0d8c8"))
	draw_rect(Rect2(20, -60, 7, 10).grow(1), INK)
	draw_rect(Rect2(20, -60, 7, 10), CampPiece.GLASS)
	draw_rect(Rect2(22, -57, 3, 5), FLAME if Cabin.fire_lit() else Color("c8b48a"))
	# the firebox
	draw_rect(Rect2(-18, -38, 36, 34), Color("1e1612"))
	draw_rect(Rect2(-18, -38, 36, 3), Color("3a2e26"))
	_fire(Vector2(0, -5), 26)
	# the hearthstone apron
	_box(Rect2(-34, -4, 68, 8), STONE_HI)


func _draw_prints() -> void:
	for x in [-14.0, 14.0]:
		var r := Rect2(x - 10, -78, 20, 24)
		draw_rect(r.grow(2), INK)
		draw_rect(r.grow(1), Color("e8e4dc"))
		draw_rect(Rect2(x - 7, -75, 14, 18), Color("2a2a2a"))
		if x < 0.0:
			# Half Dome in snow
			draw_colored_polygon(PackedVector2Array([Vector2(x - 6, -58), Vector2(x - 2, -72), Vector2(x + 4, -72), Vector2(x + 6, -58)]), Color("b8b8b8"))
			draw_rect(Rect2(x - 7, -60, 14, 3), Color("f0f0f0"))
		else:
			# an oak at dawn
			draw_rect(Rect2(x - 7, -75, 14, 6), Color("8a8a8a"))
			draw_circle(Vector2(x, -67), 5.0, Color("4a4a4a"))
			draw_rect(Rect2(x - 1, -64, 2, 7), Color("1a1a1a"))


func _draw_stove() -> void:
	_shadow(52, 8)
	# the pipe up through the lean-to roof
	draw_rect(Rect2(10, -104, 6, 76).grow(1), INK)
	draw_rect(Rect2(10, -104, 6, 76), IRON)
	draw_rect(Rect2(10, -104, 2, 76), IRON_HI)
	var r := Rect2(-24, -34, 48, 30)
	_box(r, IRON)
	draw_rect(Rect2(-24, -34, 48, 3), IRON_HI)
	# burners, the oven door and the firebox
	for x in [-14.0, 0.0]:
		draw_rect(Rect2(x, -33, 9, 2), Color("1a1918"))
	draw_rect(Rect2(-20, -26, 18, 16).grow(1), Color("1a1918"))
	draw_rect(Rect2(-20, -26, 18, 16), Color("4a4644"))
	draw_rect(Rect2(-15, -20, 8, 2), Color("c8b070"))
	draw_rect(Rect2(4, -24, 14, 12), Color("1a1918"))
	if Cabin.fire_lit():
		draw_rect(Rect2(6, -18, 10, 5), FLAME)
		draw_rect(Rect2(8, -17, 6, 2), FLAME_HI)
	for x in [-22.0, 20.0]:
		draw_rect(Rect2(x, -4, 3, 4), IRON)
	# a kettle on top
	draw_rect(Rect2(-14, -42, 12, 8).grow(1), INK)
	draw_rect(Rect2(-14, -42, 12, 8), Color("b87a3a"))
	draw_rect(Rect2(-12, -45, 8, 2), Color("8a5a2a"))


func _draw_ladder() -> void:
	_shadow(20, 4)
	for x in [-8.0, 8.0]:
		draw_rect(Rect2(x - 1.5, -112, 3, 112).grow(1), INK)
		draw_rect(Rect2(x - 1.5, -112, 3, 112), WOOD)
	for i in 9:
		var y := -8.0 - i * 12.0
		draw_rect(Rect2(-8, y, 16, 3), WOOD_HI)
		draw_rect(Rect2(-8, y + 2, 16, 1), WOOD_DARK)
	# Harding's "leftover bolts"
	for i in 3:
		draw_rect(Rect2(9, -30 - i * 36, 2, 2), Color("b8b8a8"))


func _draw_desk() -> void:
	_shadow(46, 8)
	var r := Rect2(-20, -30, 40, 26)
	_box(r, Color("7a4a2a"))
	# the slant top, open, a notebook and the inkwell
	draw_colored_polygon(PackedVector2Array([Vector2(-20, -30), Vector2(20, -30), Vector2(18, -38), Vector2(-18, -38)]), Color("9a6a40"))
	draw_rect(Rect2(-12, -37, 14, 6), PAPER)
	draw_rect(Rect2(-10, -35, 10, 1), Color("8a8a8a"))
	draw_rect(Rect2(8, -38, 4, 4), Color("1a1a2a"))
	draw_line(Vector2(10, -38), Vector2(14, -46), Color("e8e0d0"), 1.0)
	for x in [-18.0, 16.0]:
		draw_rect(Rect2(x, -4, 3, 4), WOOD_DARK)
	# the chair, pulled out
	_box(Rect2(-8, -4, 16, 4), WOOD)


func _draw_register() -> void:
	_shadow(18, 5)
	draw_rect(Rect2(-2, -26, 4, 26).grow(1), INK)
	draw_rect(Rect2(-2, -26, 4, 26), Color("8a6a42"))
	draw_rect(Rect2(-8, -2, 16, 3), Color("6a4a2a"))
	# the lectern and the open Register
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -26), Vector2(12, -26), Vector2(10, -34), Vector2(-10, -34)]), Color("8a6a42"))
	draw_rect(Rect2(-10, -36, 9, 8), PAPER)
	draw_rect(Rect2(1, -36, 9, 8), PAPER.darkened(0.06))
	draw_rect(Rect2(-1, -36, 2, 8), Color("6a2a24"))
	for y in [-34.0, -32.0, -30.0]:
		draw_rect(Rect2(-8, y, 6, 1), Color("8a8070"))
		draw_rect(Rect2(3, y, 6, 1), Color("8a8070"))
