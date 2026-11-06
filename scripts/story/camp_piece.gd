class_name CampPiece
extends Node2D
## One thing at the Guardian's camp (Camp.PIECES): the chest, the canvas
## tent, the lantern, the keepsake shelf, the summit cairn and the rest. It
## isn't there until you have it, and then it stays. Look at it to read where
## it came from; the chest opens to put things away and take them out.
##
## It draws itself in the sprites' pixel style (shaded from the upper left,
## a dark rim), so the homestead map never needs a rebuild. Some pieces show
## what you've done: your rope on the gear rack, a stone for each summit, the
## outline of your best fish, a keepsake for every main-line quest.

const NAME_PREFIX := "Camp_"
## The chest's menu shows this many things a page.
const PAGE := 6

## A Camp.PIECES entry.
var piece: Dictionary = {}

var _hitbox: Area2D
var _body: StaticBody2D
var _busy := false


static func make(for_piece: Dictionary) -> CampPiece:
	var node := CampPiece.new()
	node.piece = for_piece
	node.name = node_name(for_piece.id)
	node.position = for_piece.pos
	return node


static func node_name(id: String) -> String:
	return NAME_PREFIX + id


## Footprint (solid) and reach, by piece. Small things you can walk round
## have no body.
const FOOTPRINT := {
	"chest": Vector2(26, 10), "gear_rack": Vector2(36, 8), "wall_tent": Vector2(0, 0),
	"keepsake_shelf": Vector2(44, 8), "print": Vector2(14, 6), "hammock": Vector2(70, 10),
	"bird_bath": Vector2(22, 8), "woodpile": Vector2(40, 12), "bear_box": Vector2(30, 10),
	"fish_board": Vector2(8, 6), "press_frames": Vector2(80, 6), "summit_cairn": Vector2(22, 8),
	"guardian_sign": Vector2(10, 6), "lantern": Vector2(6, 6),
}


func _ready() -> void:
	z_index = 0
	var foot: Vector2 = FOOTPRINT.get(piece.id, Vector2.ZERO)
	if foot.x > 0.0:
		_body = StaticBody2D.new()
		_body.name = "Body"
		_body.collision_mask = 0
		var solid := CollisionShape2D.new()
		var solid_rect := RectangleShape2D.new()
		solid_rect.size = foot
		solid.shape = solid_rect
		solid.position = Vector2(0, -foot.y / 2.0)
		_body.add_child(solid)
		add_child(_body)
	if piece.id != "wall_tent" and piece.id != "pot_crane":
		_hitbox = Area2D.new()
		_hitbox.name = "Hitbox"
		_hitbox.collision_layer = 4
		_hitbox.collision_mask = 0
		_hitbox.monitoring = false
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(maxf(foot.x + 16.0, 32.0), 36)
		shape.shape = rect
		shape.position = Vector2(0, -14)
		_hitbox.add_child(shape)
		add_child(_hitbox)
	if piece.id == "lantern":
		var light := PointLight2D.new()
		light.name = "NightLight"
		light.set_script(load("res://scripts/world/night_light.gd"))
		light.position = Vector2(0, -34)
		light.set("radius", 110.0)
		light.set("strength", 0.9)
		light.set("flicker", 0.12)
		add_child(light)
	Camp.changed.connect(_refresh)
	QuestLog.changed.connect(_refresh)
	Gear.changed.connect(_refresh)
	Herbarium.changed.connect(_refresh)
	Achievements.changed.connect(_refresh)
	GameClock.time_changed.connect(func(_h: int, _m: int) -> void: queue_redraw())
	_refresh()


func is_shown() -> bool:
	return Camp.has(piece.id)


func _refresh() -> void:
	var shown := is_shown()
	visible = shown
	if _hitbox:
		_hitbox.set_deferred("monitorable", shown)
	if _body:
		_body.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED
		for child in _body.get_children():
			(child as CollisionShape2D).set_deferred("disabled", not shown)
	if piece.id == "wall_tent":
		# the canvas tent stands where the little one was, and you still sleep in it
		var tent := get_parent().get_node_or_null("Tent") if get_parent() else null
		if tent and tent.has_node("Sprite"):
			tent.get_node("Sprite").visible = not shown
	queue_redraw()


func get_prompt() -> String:
	if piece.id == "chest":
		return "Open the chest"
	return "Look at the %s" % str(piece.name).to_lower() if piece.id != "guardian_sign" else "Read the sign"


func interact(player: Player) -> void:
	if not is_shown() or _busy:
		return
	if piece.id == "chest":
		await open_chest(player)
		return
	get_tree().call_group("hud", "show_info", piece.name, Camp.describe(piece.id))


# ------------------------------------------------------------------ the chest

## The chest's menu: put things away, take them out, until you walk off.
func open_chest(player: Player) -> void:
	_busy = true
	player.can_act = false
	var box := DialogueBox.open(player)
	var cursor := 0
	while true:
		var prompt := "Your apple-box chest. %d of %d spaces used." % [Camp.chest.size(), Camp.chest_spaces()]
		var choice := await box.choose(prompt, ["Put things away", "Take things out", "Close the lid"], "", [], [], cursor)
		if choice < 0 or choice == 2:
			break
		cursor = choice
		if choice == 0:
			await _move_menu(box, true)
		else:
			await _move_menu(box, false)
	box.close()
	player.can_act = true
	_busy = false


## A paged list of what's in your pack ([param putting]) or the chest; pick
## one to move all of it, or one at a time.
func _move_menu(box: DialogueBox, putting: bool) -> void:
	var page := 0
	var cursor := 0
	while true:
		var menu := chest_menu(putting, page)
		if menu.ids.is_empty():
			await box.say([{"speaker": "", "text": "Your pack is empty." if putting else "The chest is empty."}])
			return
		var choice := await box.choose("What will you put away?" if putting else "What will you take out?",
			menu.options, "", menu.icons, menu.details, cursor)
		if choice < 0:
			return
		cursor = choice
		var action: String = menu.actions[choice]
		if action == "back":
			return
		if action == "more":
			page += 1
			cursor = 0
			continue
		var id := action
		var have := Inventory.count(id) if putting else Camp.chest_count(id)
		var amount := have
		if have > 1:
			var how := await box.choose("How many?", ["All %d" % have, "Just one", "Back"])
			if how < 0 or how == 2:
				continue
			amount = have if how == 0 else 1
		if putting:
			if Camp.put_away(id, amount) == 0:
				await box.say([{"speaker": "", "text": "The chest is full. Take something out to make room, or keep it in your pack."}])
		else:
			Camp.take_out(id, amount)
		Sound.play("item_get", -10.0, 0.05)


## The menu for the pack ([param putting]) or the chest: {"options",
## "icons", "details", "actions", "ids"}, a page at a time.
static func chest_menu(putting: bool, page := 0) -> Dictionary:
	var ids: Array[String] = []
	var source: Dictionary = Inventory.items if putting else Camp.chest
	for id: String in source:
		if int(source[id]) > 0 and ItemDB.get_item(id):
			ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		return ItemDB.get_item(a).display_name < ItemDB.get_item(b).display_name)
	var options := []
	var icons := []
	var details := []
	var actions := []
	var pages := maxi(1, ceili(ids.size() / float(PAGE)))
	page = posmod(page, pages)
	for id: String in ids.slice(page * PAGE, (page + 1) * PAGE):
		var item := ItemDB.get_item(id)
		var n := int(source[id])
		options.append("%s (%d)" % [item.display_name, n])
		icons.append(item.icon)
		var note := item.description
		var facts := ""
		var days := Larder.days_left(id) if putting else int(Camp.chest_batches.get(id, [0])[0])
		if FoodDB.shelf_life(id) > 0 and days > 0:
			facts = "Keeps %d more day%s" % [days, "" if days == 1 else "s"]
		if putting and not Camp.has_room_for(id):
			note = "The chest is full: there's no room for another kind of thing."
		elif putting:
			note += " Quests only count what's in your pack."
		details.append({"title": item.display_name, "rows": [], "facts": facts, "note": note})
		actions.append(id)
	if pages > 1:
		options.append("More (%d/%d)" % [page + 1, pages])
		icons.append(null)
		details.append(null)
		actions.append("more")
	options.append("Back")
	icons.append(null)
	details.append(null)
	actions.append("back")
	return {"options": options, "icons": icons, "details": details, "actions": actions, "ids": ids}


# ---------------------------------------------------------------- drawing

const INK := Color("2a1b14")
const WOOD := Color("8a5a32")
const WOOD_HI := Color("b07a46")
const WOOD_DARK := Color("5a3820")
const CANVAS := Color("ece4cc")
const CANVAS_SHADE := Color("c8bc9c")
const CANVAS_DARK := Color("9c8f70")
const IRON := Color("3a3836")
const IRON_HI := Color("6a6662")
const STEEL := Color("4d5544")
const STEEL_HI := Color("6e785f")
const STEEL_DARK := Color("2f352a")
const GRANITE := Color("c9c4b8")
const GRANITE_HI := Color("e4e0d6")
const GRANITE_SHADE := Color("8c877c")
const GRANITE_DARK := Color("5f5a52")
const ROPE_RED := Color("b8402e")
const ROPE_HI := Color("e0745a")
const WEBBING := Color("3f6fa8")
const WEBBING_HI := Color("6c98cc")
const PAPER := Color("f5eee0")
const GLASS := Color("cfe4ea")
const FLAME := Color("f5a33a")
const FLAME_HI := Color("fbe08a")
const SHADOW := Color(0, 0, 0, 0.25)


func _draw() -> void:
	if not is_shown():
		return
	match piece.id:
		"chest": _draw_chest()
		"camp_chair": _draw_stool()
		"gear_rack": _draw_gear_rack()
		"lantern": _draw_lantern()
		"wall_tent": _draw_wall_tent()
		"print": _draw_print()
		"hammock": _draw_hammock()
		"bird_bath": _draw_bird_bath()
		"woodpile": _draw_woodpile()
		"pot_crane": _draw_pot_crane()
		"dutch_oven": _draw_dutch_oven()
		"bear_box": _draw_bear_box()
		"fish_board": _draw_fish_board()
		"press_frames": _draw_press_frames()
		"keepsake_shelf": _draw_keepsake_shelf()
		"summit_cairn": _draw_cairn()
		"guardian_sign": _draw_sign()


func _shadow(width: float, height := 6.0) -> void:
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, height / width))
	draw_circle(Vector2.ZERO, width / 2.0, SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A box of planks: [param rect] with a rim, a lit top edge and a shaded foot.
func _plank_box(rect: Rect2, fill := WOOD) -> void:
	draw_rect(rect.grow(1), INK)
	draw_rect(rect, fill)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), fill.lightened(0.25))
	draw_rect(Rect2(rect.position.x, rect.end.y - 2, rect.size.x, 2), fill.darkened(0.3))


func _post(x: float, top: float, width := 3.0) -> void:
	draw_rect(Rect2(x - width / 2.0 - 1, top - 1, width + 2, -top + 1), INK)
	draw_rect(Rect2(x - width / 2.0, top, width, -top), WOOD)
	draw_rect(Rect2(x - width / 2.0, top, 1, -top), WOOD_HI)


func _draw_chest() -> void:
	_shadow(30)
	_plank_box(Rect2(-13, -16, 26, 16))
	for y in [-11, -6]:
		draw_rect(Rect2(-13, y, 26, 1), WOOD_DARK)
	# the lid
	draw_rect(Rect2(-14, -20, 28, 5).grow(1), INK)
	draw_rect(Rect2(-14, -20, 28, 5), WOOD_HI)
	draw_rect(Rect2(-14, -16, 28, 1), WOOD_DARK)
	# hasp and a stencilled apple
	draw_rect(Rect2(-2, -17, 4, 5), IRON)
	draw_rect(Rect2(-1, -16, 2, 1), IRON_HI)
	draw_rect(Rect2(5, -10, 4, 3), Color("b8322a"))
	draw_rect(Rect2(6, -11, 1, 1), Color("4f7a34"))


func _draw_stool() -> void:
	_shadow(18, 5)
	draw_line(Vector2(-7, 0), Vector2(6, -11), INK, 2.0)
	draw_line(Vector2(7, 0), Vector2(-6, -11), INK, 2.0)
	draw_line(Vector2(-7, 0), Vector2(6, -11), WOOD_HI, 1.0)
	draw_line(Vector2(7, 0), Vector2(-6, -11), WOOD, 1.0)
	draw_rect(Rect2(-8, -14, 16, 4).grow(1), INK)
	draw_rect(Rect2(-8, -14, 16, 4), Color("4f6a3a"))
	draw_rect(Rect2(-8, -14, 16, 1), Color("6f8a52"))
	# the taped leg
	draw_rect(Rect2(3, -6, 3, 2), Color("d8d0b8"))


func _draw_gear_rack() -> void:
	_shadow(40)
	_post(-16, -30)
	_post(16, -30)
	draw_rect(Rect2(-19, -31, 38, 3).grow(1), INK)
	draw_rect(Rect2(-19, -31, 38, 3), WOOD_HI)
	if Gear.count("rope") > 0:
		# a coiled rope hanging from the bar
		for i in 4:
			var y := -26.0 + i * 3.0
			draw_arc(Vector2(-6, y), 6.0 - i * 0.5, 0.2, PI - 0.2, 8, INK, 2.0)
			draw_arc(Vector2(-6, y), 6.0 - i * 0.5, 0.2, PI - 0.2, 8, ROPE_RED if i % 2 == 0 else ROPE_HI, 1.0)
		draw_rect(Rect2(-7, -28, 2, 4), ROPE_RED)
	var cams := mini(Gear.count("cam"), 6)
	for i in cams:
		var x := 2.0 + i * 2.5
		draw_line(Vector2(x, -28), Vector2(x, -20), Color("8c877c"), 1.0)
		draw_rect(Rect2(x - 1, -20, 2, 3), [Color("c83a2a"), Color("e8b83a"), Color("3a86a8"), Color("6aa84a"), Color("a84a8a"), Color("8c877c")][i % 6])
	var draws := mini(Gear.count("quickdraw"), 5)
	for i in draws:
		var x := -16.0 + i * 3.0
		draw_rect(Rect2(x, -27, 1, 5), Color("b8b8a8"))
		draw_rect(Rect2(x, -22, 1, 3), Color("3a86a8"))
	if Gear.count("ice_axe") > 0:
		draw_line(Vector2(13, -8), Vector2(18, -29), INK, 2.0)
		draw_line(Vector2(13, -8), Vector2(18, -29), Color("c8a46a"), 1.0)
		draw_rect(Rect2(14, -31, 8, 2), IRON_HI)


func _draw_lantern() -> void:
	_shadow(10, 4)
	_post(0, -30, 3.0)
	draw_rect(Rect2(0, -31, 7, 2), WOOD_DARK)
	# hanging from the arm
	draw_line(Vector2(6, -29), Vector2(6, -27), IRON, 1.0)
	draw_rect(Rect2(3, -27, 7, 2), IRON)
	draw_rect(Rect2(3, -25, 7, 7).grow(1), INK)
	draw_rect(Rect2(3, -25, 7, 7), GLASS)
	var lit := _night()
	draw_rect(Rect2(5, -23, 3, 4), FLAME if lit else Color("c8b48a"))
	if lit:
		draw_rect(Rect2(6, -22, 1, 2), FLAME_HI)
	draw_rect(Rect2(3, -18, 7, 2), IRON)


func _night() -> bool:
	return GameClock.hour >= 19 or GameClock.hour < 6


func _draw_wall_tent() -> void:
	# a white canvas wall tent on a plank floor, the door flaps tied back
	_shadow(84, 10)
	draw_rect(Rect2(-42, -6, 84, 6).grow(1), INK)
	draw_rect(Rect2(-42, -6, 84, 6), WOOD)
	draw_rect(Rect2(-42, -6, 84, 1), WOOD_HI)
	for x in [-30, -14, 2, 18, 34]:
		draw_rect(Rect2(x, -6, 1, 6), WOOD_DARK)
	# walls
	draw_rect(Rect2(-36, -40, 72, 34).grow(1), INK)
	draw_rect(Rect2(-36, -40, 72, 34), CANVAS)
	draw_rect(Rect2(-36, -40, 72, 3), CANVAS_SHADE)
	# the roof
	var roof := PackedVector2Array([Vector2(-40, -38), Vector2(0, -62), Vector2(40, -38)])
	draw_colored_polygon(PackedVector2Array([Vector2(-42, -37), Vector2(0, -64), Vector2(42, -37)]), INK)
	draw_colored_polygon(roof, CANVAS)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -62), Vector2(40, -38), Vector2(0, -38)]), CANVAS_SHADE)
	draw_line(Vector2(-40, -38), Vector2(40, -38), CANVAS_DARK, 1.0)
	# the door, flaps tied back on a dark inside, with a cot's end showing
	draw_rect(Rect2(-9, -34, 18, 28), Color("3a2c22"))
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -35), Vector2(-3, -35), Vector2(-12, -6)]), CANVAS_SHADE)
	draw_colored_polygon(PackedVector2Array([Vector2(10, -35), Vector2(3, -35), Vector2(12, -6)]), CANVAS_DARK)
	draw_rect(Rect2(-6, -14, 12, 3), Color("8a6a4a"))
	draw_rect(Rect2(-6, -14, 12, 1), Color("a8402e"))
	# guy lines and pegs
	for side in [-1, 1]:
		draw_line(Vector2(side * 36, -36), Vector2(side * 48, -2), CANVAS_DARK, 1.0)
		draw_rect(Rect2(side * 48 - 1, -3, 2, 3), WOOD_DARK)
	# a stovepipe out of the roof
	draw_rect(Rect2(20, -58, 4, 12), IRON)
	draw_rect(Rect2(19, -59, 6, 2), IRON_HI)


func _draw_print() -> void:
	_shadow(16, 4)
	# easel legs
	draw_line(Vector2(-6, 0), Vector2(0, -26), INK, 2.0)
	draw_line(Vector2(6, 0), Vector2(0, -26), INK, 2.0)
	draw_line(Vector2(-6, 0), Vector2(0, -26), WOOD, 1.0)
	draw_line(Vector2(6, 0), Vector2(0, -26), WOOD, 1.0)
	# the frame, the mat, and Half Dome's face in black and white
	draw_rect(Rect2(-9, -26, 18, 16).grow(1), INK)
	draw_rect(Rect2(-9, -26, 18, 16), Color("2a2622"))
	draw_rect(Rect2(-7, -24, 14, 12), PAPER)
	draw_rect(Rect2(-6, -23, 12, 10), Color("1e1e1e"))
	draw_rect(Rect2(-6, -23, 12, 4), Color("5a5a5a"))
	draw_colored_polygon(PackedVector2Array([Vector2(-4, -13), Vector2(-3, -21), Vector2(1, -22), Vector2(4, -18), Vector2(3, -13)]), Color("a8a8a8"))
	draw_line(Vector2(1, -22), Vector2(1, -14), Color("d8d8d8"), 1.0)


func _draw_hammock() -> void:
	_shadow(72, 8)
	# an A-frame at each end
	for side in [-1, 1]:
		var x: float = side * 32
		draw_line(Vector2(x - 5, 0), Vector2(x, -30), INK, 3.0)
		draw_line(Vector2(x + 5, 0), Vector2(x, -30), INK, 3.0)
		draw_line(Vector2(x - 5, 0), Vector2(x, -30), WOOD_HI, 1.0)
		draw_line(Vector2(x + 5, 0), Vector2(x, -30), WOOD, 1.0)
	draw_line(Vector2(-32, -29), Vector2(32, -29), INK, 3.0)
	draw_line(Vector2(-32, -29), Vector2(32, -29), WOOD, 1.0)
	# the webbing sags between them, woven in strips
	var points := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		points.append(Vector2(lerpf(-30, 30, t), -26.0 + sin(t * PI) * 12.0))
	draw_polyline(points, INK, 6.0)
	draw_polyline(points, WEBBING, 4.0)
	for i in range(1, 16, 3):
		draw_rect(Rect2(points[i] - Vector2(1, 2), Vector2(2, 4)), WEBBING_HI)


func _draw_bird_bath() -> void:
	_shadow(26)
	draw_rect(Rect2(-4, -10, 8, 10).grow(1), GRANITE_DARK)
	draw_rect(Rect2(-4, -10, 8, 10), GRANITE_SHADE)
	draw_rect(Rect2(-13, -16, 26, 7).grow(1), GRANITE_DARK)
	draw_rect(Rect2(-13, -16, 26, 7), GRANITE)
	draw_rect(Rect2(-13, -16, 26, 2), GRANITE_HI)
	draw_rect(Rect2(-9, -15, 18, 3), Color("6aa8c8"))
	draw_rect(Rect2(-7, -15, 6, 1), Color("b8e0f0"))
	# a junco on the rim, mornings
	if GameClock.hour >= 6 and GameClock.hour < 11:
		draw_rect(Rect2(8, -21, 5, 4), Color("4a4a52"))
		draw_rect(Rect2(8, -19, 5, 2), Color("d8d0c0"))
		draw_rect(Rect2(12, -21, 2, 1), Color("e8c8a0"))


func _draw_woodpile() -> void:
	_shadow(44, 8)
	for row in 3:
		var count := 5 - row
		for i in count:
			var center := Vector2(-16 + i * 8 + row * 4, -5 - row * 7)
			draw_circle(center, 4.5, INK)
			draw_circle(center, 3.5, Color("c8a070"))
			draw_circle(center, 1.5, Color("a87a4a"))
	# a round with the axe in it
	draw_rect(Rect2(18, -8, 10, 8).grow(1), INK)
	draw_rect(Rect2(18, -8, 10, 8), WOOD)
	draw_rect(Rect2(18, -8, 10, 2), Color("c8a070"))
	draw_line(Vector2(23, -8), Vector2(28, -20), Color("c8a46a"), 2.0)
	draw_rect(Rect2(20, -10, 5, 3), IRON_HI)


func _draw_pot_crane() -> void:
	# three iron legs over the fire and a pot on the hook
	draw_line(Vector2(-16, 4), Vector2(0, -34), INK, 3.0)
	draw_line(Vector2(16, 4), Vector2(0, -34), INK, 3.0)
	draw_line(Vector2(-16, 4), Vector2(0, -34), IRON_HI, 1.0)
	draw_line(Vector2(16, 4), Vector2(0, -34), IRON, 1.0)
	draw_line(Vector2(0, -34), Vector2(0, -26), IRON, 1.0)
	draw_rect(Rect2(-6, -26, 12, 9).grow(1), INK)
	draw_rect(Rect2(-6, -26, 12, 9), IRON)
	draw_rect(Rect2(-6, -26, 12, 2), IRON_HI)
	draw_arc(Vector2(0, -26), 6.0, PI, TAU, 8, IRON, 1.0)


func _draw_dutch_oven() -> void:
	_shadow(16, 4)
	draw_rect(Rect2(-7, -9, 14, 9).grow(1), INK)
	draw_rect(Rect2(-7, -9, 14, 9), IRON)
	draw_rect(Rect2(-8, -11, 16, 3), IRON_HI)
	draw_rect(Rect2(-2, -13, 4, 2), IRON)
	# coals on the lid
	for x in [-5, -1, 3]:
		draw_rect(Rect2(x, -12, 2, 1), Color("e86a2a"))


func _draw_bear_box() -> void:
	_shadow(36, 8)
	draw_rect(Rect2(-15, -18, 30, 18).grow(1), STEEL_DARK)
	draw_rect(Rect2(-15, -18, 30, 18), STEEL)
	draw_rect(Rect2(-15, -18, 30, 4), STEEL_HI)
	draw_rect(Rect2(-15, -14, 30, 1), STEEL_DARK)
	draw_rect(Rect2(-6, -12, 4, 4), Color("a8a89a"))
	draw_rect(Rect2(2, -12, 4, 4), Color("a8a89a"))
	draw_rect(Rect2(6, -17, 7, 3), Color("e8c64a"))


func _draw_fish_board() -> void:
	_shadow(10, 4)
	_post(0, -16, 3.0)
	draw_rect(Rect2(-14, -30, 28, 14).grow(1), INK)
	draw_rect(Rect2(-14, -30, 28, 14), WOOD_HI)
	draw_rect(Rect2(-14, -18, 28, 2), WOOD)
	var best := Camp.biggest_fish()
	if best.is_empty():
		return
	# a chalk outline: longer for a longer fish
	var length := clampf(float(best.inches) / 24.0, 0.4, 1.0) * 22.0
	var mid := Vector2(-1, -23)
	draw_arc(mid, length / 2.0, PI * 0.15, PI * 0.85, 10, PAPER, 1.0)
	draw_arc(mid + Vector2(0, -4), length / 2.0, PI * 1.15, PI * 1.85, 10, PAPER, 1.0)
	draw_line(mid + Vector2(length / 2.0, -2), mid + Vector2(length / 2.0 + 4, -5), PAPER, 1.0)
	draw_line(mid + Vector2(length / 2.0, -2), mid + Vector2(length / 2.0 + 4, 1), PAPER, 1.0)
	draw_rect(Rect2(mid + Vector2(-length / 2.0 + 3, -3), Vector2(1, 1)), PAPER)


func _draw_press_frames() -> void:
	_shadow(84, 6)
	_post(-40, -30)
	_post(40, -30)
	draw_line(Vector2(-40, -28), Vector2(40, -28), Color("d8d0b8"), 1.0)
	var frames := clampi(Herbarium.count() / 5, 1, 6)
	var greens := [Color("4f7a34"), Color("6aa04a"), Color("8a6a3a"), Color("a84a8a"), Color("3a6a4a"), Color("c8a83a")]
	for i in frames:
		var x := -32.0 + i * 11.0
		draw_rect(Rect2(x, -27, 9, 12).grow(1), INK)
		draw_rect(Rect2(x, -27, 9, 12), PAPER)
		draw_line(Vector2(x + 4, -17), Vector2(x + 4, -24), greens[i], 1.0)
		draw_rect(Rect2(x + 2, -24, 2, 2), greens[i])
		draw_rect(Rect2(x + 5, -22, 2, 2), greens[(i + 3) % greens.size()])
		draw_rect(Rect2(x + 3, -28, 2, 1), WOOD_DARK)


func _draw_keepsake_shelf() -> void:
	_shadow(48, 8)
	for x in [-18, 18]:
		draw_rect(Rect2(x - 4, -10, 8, 10).grow(1), INK)
		draw_rect(Rect2(x - 4, -10, 8, 10), WOOD)
		draw_rect(Rect2(x - 4, -10, 8, 2), Color("c8a070"))
	draw_rect(Rect2(-23, -13, 46, 4).grow(1), INK)
	draw_rect(Rect2(-23, -13, 46, 4), WOOD_HI)
	draw_rect(Rect2(-23, -10, 46, 1), WOOD_DARK)
	var items := Camp.keepsakes()
	for i in items.size():
		# two rows: the first seven on the plank, the rest on the ground
		var at := Vector2(-20 + (i % 7) * 6.5, -13.0) if i < 7 else Vector2(-14 + (i - 7) * 6.0, 0.0)
		_keepsake(items[i].look, at)


## One keepsake, standing on a line at [param at] (its foot).
func _keepsake(look: String, at: Vector2) -> void:
	match look:
		"card":
			draw_rect(Rect2(at + Vector2(0, -6), Vector2(4, 6)), PAPER)
			draw_rect(Rect2(at + Vector2(1, -4), Vector2(2, 1)), Color("3a86a8"))
		"coil":
			draw_circle(at + Vector2(2, -3), 3.0, Color("c8b080"))
			draw_circle(at + Vector2(2, -3), 1.5, Color("8a6a3a"))
		"postcard":
			draw_rect(Rect2(at + Vector2(0, -5), Vector2(5, 5)), Color("6aa8c8"))
			draw_rect(Rect2(at + Vector2(0, -2), Vector2(5, 2)), Color("8a8a7a"))
		"nut":
			draw_rect(Rect2(at + Vector2(1, -4), Vector2(3, 4)), Color("c8c8c8"))
			draw_line(at + Vector2(2, -4), at + Vector2(2, -8), Color("e8b83a"), 1.0)
		"page":
			draw_rect(Rect2(at + Vector2(0, -6), Vector2(4, 6)), Color("e8dcb8"))
			draw_rect(Rect2(at + Vector2(1, -5), Vector2(2, 1)), INK)
			draw_rect(Rect2(at + Vector2(1, -3), Vector2(2, 1)), INK)
		"piton":
			draw_rect(Rect2(at + Vector2(1, -7), Vector2(1, 7)), Color("4a5a7a"))
			draw_rect(Rect2(at + Vector2(1, -7), Vector2(3, 2)), Color("4a5a7a"))
		"tape":
			draw_circle(at + Vector2(2, -2), 2.5, PAPER)
			draw_circle(at + Vector2(2, -2), 1.0, WOOD_DARK)
		"hand":
			draw_rect(Rect2(at + Vector2(0, -6), Vector2(5, 6)), Color("8a6a4a"))
			draw_rect(Rect2(at + Vector2(1, -5), Vector2(3, 3)), PAPER)
		"hanger":
			draw_rect(Rect2(at + Vector2(0, -5), Vector2(4, 5)), Color("a8a8a0"))
			draw_rect(Rect2(at + Vector2(1, -4), Vector2(2, 2)), INK)
		"cone":
			draw_rect(Rect2(at + Vector2(0, -5), Vector2(4, 5)), Color("7a5634"))
			draw_rect(Rect2(at + Vector2(1, -5), Vector2(2, 1)), Color("a87a4a"))
		"pebble":
			draw_rect(Rect2(at + Vector2(0, -3), Vector2(5, 3)), Color("a8b0b8"))
			draw_rect(Rect2(at + Vector2(1, -3), Vector2(2, 1)), Color("e0e8f0"))
		"pencil":
			draw_line(at + Vector2(0, -1), at + Vector2(5, -3), Color("e8b83a"), 1.0)
		"tin":
			draw_rect(Rect2(at + Vector2(0, -4), Vector2(6, 4)), Color("9aa0a0"))
			draw_rect(Rect2(at + Vector2(0, -4), Vector2(6, 1)), Color("d0d8d8"))


func _draw_cairn() -> void:
	var stones := maxi(Achievements.summit_count(), 1)
	_shadow(24, 6)
	var y := 0.0
	for i in stones:
		var width := 18.0 - i * 3.0
		var height := 6.0 - i * 0.5
		var rect := Rect2(-width / 2.0 + (i % 2) * 1.0, y - height, width, height)
		draw_rect(rect.grow(1), GRANITE_DARK)
		draw_rect(rect, GRANITE if i % 2 == 0 else GRANITE_SHADE.lightened(0.15))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1)), GRANITE_HI)
		y -= height


func _draw_sign() -> void:
	_shadow(14, 4)
	_post(0, -20, 4.0)
	draw_rect(Rect2(-22, -36, 44, 14).grow(1), INK)
	draw_rect(Rect2(-22, -36, 44, 14), WOOD_HI)
	draw_rect(Rect2(-22, -24, 44, 2), WOOD)
	# carved letters, roughly
	for x in range(-18, 18, 4):
		draw_rect(Rect2(x, -32, 3, 1 + int(x * 7 % 3 == 0)), WOOD_DARK)
	for x in range(-14, 14, 4):
		draw_rect(Rect2(x, -28, 3, 1), WOOD_DARK)
	# a little flag on top
	draw_line(Vector2(18, -36), Vector2(18, -48), INK, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(19, -48), Vector2(27, -45), Vector2(19, -42)]), Color("3a7a4a"))
