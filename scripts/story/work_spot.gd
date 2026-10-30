class_name WorkSpot
extends Node2D
## One piece of the Guardian's Year work, standing where it's done: a
## washed-out step, a weed, a shortcut across a meadow, fuel round a
## sequoia, the burn, a cooler left out at a campsite (Stewardship.SPOTS).
##
## While a quest step asks for its task, it shows the problem and the
## interact button does the work (resetting a step is RockWork; the rest just
## take time). Once done, it shows the fix for good: a set step, a roped-off
## path, ash and then seedlings, a new bear box. Before its arc it isn't there.
## It draws itself, so the generated maps never need a rebuild.

## A Stewardship.SPOTS entry.
var spot: Dictionary = {}

var _busy := false
var _hitbox: Area2D


## A WorkSpot for [param for_spot], placed and named.
static func make(for_spot: Dictionary) -> WorkSpot:
	var node := WorkSpot.new()
	node.spot = for_spot
	node.name = node_name(for_spot.id)
	node.position = for_spot.pos
	return node


static func node_name(spot_id: String) -> String:
	return "Work_" + spot_id


func _ready() -> void:
	_hitbox = Area2D.new()
	_hitbox.name = "Hitbox"
	_hitbox.collision_layer = 4
	_hitbox.collision_mask = 0
	_hitbox.monitoring = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(36, 26)
	shape.shape = rect
	shape.position = Vector2(0, -8)
	_hitbox.add_child(shape)
	add_child(_hitbox)
	Stewardship.changed.connect(_refresh)
	QuestLog.changed.connect(_refresh)
	GameClock.day_started.connect(_refresh.unbind(3))
	# only the drip torch's flame moves
	set_process(spot.get("kind") == "burn")
	_refresh()


func _process(_delta: float) -> void:
	if visible and not Stewardship.is_done(spot.id):
		queue_redraw()


## "todo" while a quest step wants this spot's task, "done" once it's done,
## and "" before then (nothing to see).
func state() -> String:
	if Stewardship.is_done(spot.id):
		return "done"
	return "todo" if Stewardship.is_wanted(spot.task) else ""


## True while the interact button does something here: the work, or reading
## a new bear box.
func is_usable() -> bool:
	var now := state()
	return now == "todo" or (now == "done" and spot.kind == "bear_box")


func _refresh() -> void:
	visible = state() != ""
	if _hitbox:
		_hitbox.set_deferred("monitorable", is_usable())
	queue_redraw()


func get_prompt() -> String:
	if state() == "done":
		return "Read: Bear Box"
	var verb: String = Stewardship.TASKS[spot.task].verb
	if spot.kind == "weed":
		return "%s the %s" % [verb, Stewardship.WEEDS[spot.plant].name]
	return verb


func interact(player: Player) -> void:
	if _busy or not is_usable():
		return
	if state() == "done":
		get_tree().call_group("hud", "show_info", "Bear Box", EasterEggs.BEAR_BOX_TEXT)
		return
	if spot.kind == "step":
		await _rock_work(player)
		return
	GameClock.advance_minutes(int(Stewardship.TASKS[spot.task].minutes))
	finish_work()


## Resets a step: the rock bar on a timing meter (RockWork). A slip costs
## time, and the step stays as it was.
func _rock_work(player: Player) -> void:
	_busy = true
	player.can_act = false
	var game := RockWork.new()
	get_tree().root.add_child(game)
	game.start()
	var set_it: bool = await game.finished
	var outcome := game.outcome
	game.queue_free()
	if set_it:
		GameClock.advance_minutes(int(Stewardship.TASKS[spot.task].minutes))
		finish_work(RockWork.SET_TEXT.get(outcome, ""))
	else:
		GameClock.advance_minutes(RockWork.SLIP_MINUTES)
		get_tree().call_group("hud", "show_message", RockWork.SLIP_TEXT.get(outcome, RockWork.SLIP_TEXT.slipped))
		Sound.play("ui_back", -4.0, 0.05)
	player.can_act = true
	_busy = false


## Does the work: marks the spot done and says so. Returns the message.
func finish_work(extra := "") -> String:
	if not Stewardship.finish(spot.id):
		return ""
	var text := Stewardship.done_text(spot)
	if extra != "":
		text = extra + " " + text
	var left := 0
	for step_spot: Dictionary in Stewardship.spots_for(spot.task):
		if not Stewardship.is_done(step_spot.id):
			left += 1
	if left > 0:
		text += " (%d to go.)" % left
	if is_inside_tree():
		get_tree().call_group("hud", "show_message", text)
	Sound.play("item_get", -4.0, 0.1)
	return text


# ---------------------------------------------------------------- drawing

const GRANITE := Color("c9c4b8")
const GRANITE_HI := Color("e4e0d6")
const GRANITE_SHADE := Color("8c877c")
const GRANITE_DARK := Color("5f5a52")
const MUD := Color("5a4632")
const MUD_DARK := Color("3f3022")
const TRAMPLED := Color("a8946a")
const LEAF := Color("4f7a34")
const LEAF_DARK := Color("33522a")
const STAKE := Color("7a5634")
const ROPE := Color("efe3c4")
const ASH := Color("3a3632")
const ASH_DARK := Color("221f1d")
const ASH_GREY := Color("6b655e")
const SEEDLING := Color("6fa04a")
const STEEL := Color("4d5544")
const STEEL_HI := Color("6e785f")
const STEEL_DARK := Color("2f352a")
const CARD := Color("e8c64a")


func _draw() -> void:
	var now := state()
	if now == "":
		return
	var done := now == "done"
	var healed := done and Stewardship.grown_back(spot.id)
	match spot.kind:
		"step":
			_draw_step(done)
		"weed":
			if done:
				_draw_healed_ground(healed)
			else:
				_draw_weed(spot.plant)
		"path":
			_draw_path(done, healed)
		"fuel":
			if done:
				_draw_ash(Vector2(40, 16), healed)
			else:
				_draw_fuel()
		"burn":
			if done:
				_draw_ash(Vector2(52, 20), healed)
			else:
				_draw_drip_torch()
		"bear_box":
			if done:
				_draw_bear_box()
			else:
				_draw_cooler()


func _oval(center: Vector2, size: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, size.y / size.x))
	draw_circle(Vector2.ZERO, size.x / 2.0, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _block(rect: Rect2) -> void:
	draw_rect(rect.grow(1), GRANITE_DARK)
	draw_rect(rect, GRANITE)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), GRANITE_HI)
	draw_rect(Rect2(rect.position.x, rect.end.y - 2, rect.size.x, 2), GRANITE_SHADE)


## A washed-out step: a muddy rut, the old block tumbled out of it. Reset,
## a squared granite step bedded in gravel.
func _draw_step(done: bool) -> void:
	if not done:
		_oval(Vector2(0, -2), Vector2(36, 12), MUD_DARK)
		_oval(Vector2(0, -3), Vector2(30, 9), MUD)
		draw_set_transform(Vector2(-8, -10), -0.35, Vector2.ONE)
		_block(Rect2(-7, -5, 14, 9))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_block(Rect2(6, -9, 8, 6))
		return
	_oval(Vector2(0, 0), Vector2(40, 10), Color(MUD_DARK, 0.6))
	draw_rect(Rect2(-18, -10, 36, 10).grow(1), GRANITE_DARK)
	draw_rect(Rect2(-18, -10, 36, 4), GRANITE_HI)
	draw_rect(Rect2(-18, -6, 36, 6), GRANITE_SHADE)
	draw_rect(Rect2(-18, -10, 36, 1), Color.WHITE.lerp(GRANITE_HI, 0.5))
	for x in [-15, -6, 4, 13]:
		draw_rect(Rect2(x, 1, 2, 1), GRANITE_SHADE)


## A weed of the meadow, by Stewardship.WEEDS id.
func _draw_weed(plant: String) -> void:
	match plant:
		"himalayan_blackberry":
			for cane: Array in [[Vector2(-2, 0), Vector2(-10, -20), Vector2(-16, -6)], [Vector2(0, 0), Vector2(4, -24), Vector2(14, -8)], [Vector2(2, 0), Vector2(10, -16), Vector2(18, -2)]]:
				draw_polyline(PackedVector2Array([cane[0], cane[1], cane[2]]), Color("6a3a3e"), 1.5)
				for t in [0.35, 0.7]:
					var at: Vector2 = cane[0].lerp(cane[1], t * 2.0) if t < 0.5 else cane[1].lerp(cane[2], (t - 0.5) * 2.0)
					draw_rect(Rect2(at - Vector2(3, 2), Vector2(5, 3)), LEAF)
					draw_rect(Rect2(at - Vector2(3, 2), Vector2(5, 1)), LEAF.lightened(0.2))
			for berry in [Vector2(-9, -15), Vector2(6, -18), Vector2(12, -9)]:
				draw_rect(Rect2(berry, Vector2(2, 2)), Color("2a1a2e"))
		"bull_thistle":
			draw_line(Vector2(0, 0), Vector2(0, -20), LEAF_DARK, 2.0)
			for y in [-4, -10, -15]:
				draw_colored_polygon(PackedVector2Array([Vector2(0, y), Vector2(-9, y - 3), Vector2(-4, y + 1)]), LEAF)
				draw_colored_polygon(PackedVector2Array([Vector2(0, y - 2), Vector2(9, y - 5), Vector2(4, y - 1)]), LEAF)
			draw_rect(Rect2(-3, -24, 6, 4), Color("5f7a3a"))
			draw_rect(Rect2(-3, -27, 6, 3), Color("9a4fa8"))
			draw_rect(Rect2(-2, -28, 4, 1), Color("c486cf"))
		_:
			for i in 7:
				var x := -9.0 + i * 3.0
				var top := Vector2(x + (i % 3 - 1) * 2.0, -12.0 - (i % 2) * 4.0)
				draw_line(Vector2(x, 0), top, Color("9aa88a"), 1.0)
				draw_rect(Rect2(top - Vector2(1, 2), Vector2(2, 3)), Color("bba9ad"))


## Where a weed came out: turned earth, then the season after, meadow
## flowers in its place.
func _draw_healed_ground(healed: bool) -> void:
	if not healed:
		_oval(Vector2(0, -1), Vector2(14, 6), Color(MUD, 0.7))
		return
	for i in 5:
		var at := Vector2(-8 + i * 4, -2 - (i % 2) * 3)
		draw_line(at + Vector2(0, 3), at, LEAF, 1.0)
		draw_rect(Rect2(at - Vector2(1, 1), Vector2(2, 2)), [Color("f2d04a"), Color("7a8fd8"), Color("f5f0e0")][i % 3])


## A shortcut worn across the meadow; roped off, and green again a season
## later.
func _draw_path(done: bool, healed: bool) -> void:
	if not healed:
		_oval(Vector2(0, -2), Vector2(44, 10), Color(TRAMPLED, 0.85))
		for x in [-14, -4, 7, 15]:
			draw_rect(Rect2(x, -4 + (x % 3), 2, 1), Color(MUD, 0.6))
	else:
		_oval(Vector2(0, -2), Vector2(40, 9), Color(LEAF, 0.5))
	if not done:
		return
	for x in [-20, 20]:
		draw_rect(Rect2(x - 1, -14, 3, 14), STAKE)
		draw_rect(Rect2(x - 1, -14, 3, 1), STAKE.lightened(0.3))
	draw_polyline(PackedVector2Array([Vector2(-19, -12), Vector2(0, -9), Vector2(19, -12)]), ROPE, 1.0)
	draw_rect(Rect2(-4, -10, 8, 6), Color("f5f0e0"))
	draw_rect(Rect2(-3, -8, 6, 1), STAKE)


## Dead branches and deep needle litter piled round a giant's foot.
func _draw_fuel() -> void:
	_oval(Vector2(0, -2), Vector2(38, 12), Color("8a5a2e"))
	for branch: Array in [[Vector2(-16, -2), Vector2(10, -10)], [Vector2(-10, -12), Vector2(14, -1)], [Vector2(-4, -1), Vector2(6, -14)], [Vector2(-18, -6), Vector2(-2, -6)]]:
		draw_line(branch[0], branch[1], Color("4a3020"), 2.0)
		draw_line(branch[0] + Vector2(0, -1), branch[1] + Vector2(0, -1), Color("7a5634"), 1.0)


## The drip torch, set ready on a stump, a little flame at the wick.
func _draw_drip_torch() -> void:
	draw_rect(Rect2(-8, -6, 16, 6), Color("6b4829"))
	draw_rect(Rect2(-4, -18, 8, 12), Color("b8322a"))
	draw_rect(Rect2(-4, -18, 8, 2), Color("d65a44"))
	draw_line(Vector2(3, -16), Vector2(11, -24), Color("8c877c"), 1.5)
	var flicker := roundf(1.0 + sin(Time.get_ticks_msec() / 90.0))
	draw_rect(Rect2(10, -27 - flicker, 3, 3 + flicker), Color("f5a33a"))
	draw_rect(Rect2(11, -26, 1, 2), Color("fbe08a"))


## Burned ground: black ash, white at the edges; the spring after, sequoia
## seedlings, bright green, coming up through it.
func _draw_ash(size: Vector2, healed: bool) -> void:
	_oval(Vector2(0, -2), size + Vector2(4, 2), Color(ASH_GREY, 0.7))
	_oval(Vector2(0, -2), size, ASH)
	_oval(Vector2(-3, -3), size * 0.5, ASH_DARK)
	if not healed:
		return
	for at in [Vector2(-10, -3), Vector2(2, -6), Vector2(11, -2), Vector2(-3, 1)]:
		draw_line(at, at + Vector2(0, -6), Color("5a3a24"), 1.0)
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -9), at + Vector2(-3, -3), at + Vector2(3, -3)]), SEEDLING)
		draw_rect(Rect2(at + Vector2(-1, -9), Vector2(1, 2)), SEEDLING.lightened(0.3))


## A cooler and a bag of groceries left out at a campsite.
func _draw_cooler() -> void:
	_oval(Vector2(0, 0), Vector2(30, 8), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(-13, -10, 14, 10), Color("2f6aa8"))
	draw_rect(Rect2(-14, -12, 16, 3), Color("f5f0e0"))
	draw_rect(Rect2(-9, -14, 6, 2), Color("8c877c"))
	draw_rect(Rect2(4, -12, 8, 12), Color("c8a46a"))
	draw_rect(Rect2(4, -12, 8, 2), Color("a8844a"))
	draw_rect(Rect2(6, -15, 3, 3), Color("d8502e"))


## A new steel food locker, latched, with its yellow card on the lid.
func _draw_bear_box() -> void:
	_oval(Vector2(0, 0), Vector2(36, 8), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(-16, -18, 32, 18).grow(1), STEEL_DARK)
	draw_rect(Rect2(-16, -18, 32, 18), STEEL)
	draw_rect(Rect2(-16, -18, 32, 4), STEEL_HI)
	draw_rect(Rect2(-16, -14, 32, 1), STEEL_DARK)
	draw_rect(Rect2(-2, -12, 4, 4), Color("a8a89a"))
	draw_rect(Rect2(6, -17, 7, 3), CARD)
