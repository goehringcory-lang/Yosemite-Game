class_name ClimbMinigame
extends CanvasLayer
## The climbing screen. The rules live in ClimbState; this draws them and turns
## input into moves.
##
## The view is a granite wall seen face-on, its ragged right edge against the
## sky, with the valley and its ridgelines behind. The climber works up the
## face on a rope that runs down through their quickdraws or cams to the
## belayer on the ledge. The wall scrolls as you climb, the far ridges sink as
## you gain height, and the light follows the time of day. Bottom left: the
## altimeter, stamina, and the rack.
##
## Controls: up = climb straight up, left/right = climb up-left/up-right,
## use tool = clip a bolt or place a cam, interact = eat (at a belay ledge) or
## chalk up (on the wall), cancel = retreat.

## Emitted when the player leaves the screen after topping out or retreating.
signal finished(success: bool, minutes: int)

const SCREEN := Vector2(480, 270)
## Size of one hold cell on screen.
const COL_W := 30.0
const ROW_H := 22.0
## Left edge of the hold grid. The grid sits near the wall's sunlit edge,
## the way the climbers in the reference pictures hang out over the drop.
const GRID_X := 120.0
## Width of the wall picture. Its right edge is ragged against the sky.
const WALL_W := 300
## The climber is kept about this far down the screen as the wall scrolls.
const ANCHOR_Y := 186.0
## Rows of wall painted under the belay ledge and over the top ledge.
const ROWS_BELOW := 5
const ROWS_ABOVE := 10
const MOVE_TIME := 0.16

const TEXT := Color(0.97, 0.94, 0.86)
const SHADOW := Color(0.05, 0.05, 0.1, 0.85)
const WARN := Color(1.0, 0.5, 0.38)
const EASY := Color(0.55, 0.88, 0.45)
const MEDIUM := Color(0.98, 0.82, 0.35)
const HARD := Color(1.0, 0.5, 0.3)
const ROPE := Color("d8452e")
const ROPE_DARK := Color("8a2a1c")
const STEEL := Color("c8ccd4")
const STEEL_DARK := Color("6a6e78")
const DRAW_SLING := Color("3a78c8")
const CAM_SLING := Color("e0a030")
const OUTLINE := Color("1e1620")
## The player's colors (assets/sprites/player.png): hat, shirt, pants.
const CLIMBER := {"skin": Color("f0c088"), "hat": Color("8a5a2a"), "top": Color("6a8a4a"), "pants": Color("3a4466")}

var state: ClimbState

var _canvas: Control
var _font: Font
var _pal: Dictionary
var _sky_tex: Texture2D
var _ridges: Array[Texture2D] = []
var _clouds: Array[Texture2D] = []
var _wall_tex: Texture2D
var _wall_pitch := -1
## The row the view is centered on; eases toward the climber.
var _view_row := 0.0
## The climber's drawn position in (column, row), easing between holds.
var _shown := Vector2.ZERO
var _from := Vector2.ZERO
var _move_t := 1.0
var _reach := 0
var _time := 0.0
var _fade := 0.0
var _start_minutes := 0
var _belayer := {}


## Call before adding the node to the tree.
func setup(route: RouteData, seed := -1) -> void:
	state = ClimbState.new(route, Gear.count("cam"), seed, Gear.owned)


func _ready() -> void:
	layer = 20
	_font = ThemeDB.fallback_font
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_draw_screen)
	add_child(_canvas)
	_start_minutes = GameClock.minutes
	_belayer = _find_belayer()
	_paint_scenery()
	_shown = Vector2(state.col, state.row)
	_from = _shown
	_view_row = state.row
	var intro := "%s (%s). Pitch 1 of %d." % [state.route.display_name, state.route.grade, state.route.pitches.size()]
	if state.is_bolted():
		intro += " Bolted: clip each one with a quickdraw as you pass it."
	if _belayer.get("name", "") != "":
		intro += " %s has you on belay." % _belayer.name
	state.message = intro


func _process(delta: float) -> void:
	_time += delta
	if _move_t < 1.0:
		_move_t = minf(_move_t + delta / MOVE_TIME, 1.0)
		var t := _move_t * _move_t * (3.0 - 2.0 * _move_t)
		_shown = _from.lerp(Vector2(state.col, state.row), t)
	else:
		_shown = Vector2(state.col, state.row)
	_view_row = lerpf(_view_row, _shown.y, minf(delta * 6.0, 1.0))
	_fade = maxf(_fade - delta * 2.5, 0.0)
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if not (event.is_action_pressed("move_up") or event.is_action_pressed("move_left") \
			or event.is_action_pressed("move_right") or event.is_action_pressed("use_tool") \
			or event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel")):
		return
	if event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if state.status != ClimbState.Status.CLIMBING:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
			finished.emit(state.status == ClimbState.Status.TOPPED_OUT, state.minutes)
			queue_free()
		return
	var before := Vector3i(state.col, state.row, state.pitch)
	if event.is_action_pressed("move_up"):
		state.move(0)
	elif event.is_action_pressed("move_left"):
		state.move(-1)
	elif event.is_action_pressed("move_right"):
		state.move(1)
	elif event.is_action_pressed("use_tool"):
		state.protect()
	elif event.is_action_pressed("interact"):
		if state.is_at_belay():
			eat_next()
		else:
			state.chalk_up()
	elif event.is_action_pressed("ui_cancel"):
		state.retreat()
	_after_action(before)


## Eats whatever will spoil soonest, so fresh food doesn't go to waste.
func eat_next() -> void:
	var foods := FoodDB.edible_in_inventory()
	if foods.is_empty():
		state.message = "You have nothing to eat."
		return
	foods.sort_custom(func(a, b): return _freshness(a) < _freshness(b))
	state.eat(foods[0])


func _freshness(id: String) -> int:
	var days := Larder.days_left(id)
	return days if days > 0 else 9999


## Starts the move animation, and repaints the wall on a new pitch.
func _after_action(before: Vector3i) -> void:
	if before.z != state.pitch and state.status == ClimbState.Status.CLIMBING:
		_paint_scenery()
		_fade = 1.0
		_from = Vector2(state.col, state.row)
		_shown = _from
		_view_row = 0.0
		_move_t = 1.0
	elif before.x != state.col or before.y != state.row:
		_from = _shown
		_move_t = 0.0
		_reach = state.col - before.x if before.y < state.row else 0


# ---------------------------------------------------------------- scenery

func _hour() -> float:
	return (_start_minutes + state.minutes) / 60.0


## Paints the sky, ridges, clouds and this pitch's wall for the current light.
func _paint_scenery() -> void:
	_pal = ClimbScenery.palette(_hour())
	_sky_tex = ImageTexture.create_from_image(ClimbScenery.sky(_pal))
	_ridges.clear()
	for im in ClimbScenery.mountains(_pal, hash(state.route.id)):
		_ridges.append(ImageTexture.create_from_image(im))
	_clouds.clear()
	for i in 4:
		_clouds.append(ImageTexture.create_from_image(ClimbScenery.cloud(_pal, hash(state.route.id) + i)))
	var rows := state.top_row + ROWS_BELOW + ROWS_ABOVE
	var wall := ClimbScenery.wall(WALL_W, int(rows * ROW_H), hash(state.route.id) + state.pitch * 97, _pal)
	var im: Image = wall.image
	ClimbScenery.paint_holds(im, state, _wall_px, _pal, wall.edge)
	_wall_tex = ImageTexture.create_from_image(im)
	_wall_pitch = state.pitch


## Pixel position of hold (r, c) inside the wall picture.
func _wall_px(r: int, c: int) -> Vector2:
	return Vector2(GRID_X + (c + 0.5) * COL_W, (state.top_row + ROWS_ABOVE - r - 0.5) * ROW_H)


## Screen position of a (possibly fractional) row and column.
func _screen(r: float, c: float) -> Vector2:
	return Vector2(GRID_X + (c + 0.5) * COL_W, ANCHOR_Y - (r - _view_row) * ROW_H)


## How far up the whole route the climber is, 0 at the start, 1 at the top.
func _progress() -> float:
	var total := state.route.pitches.size() * state.top_row
	var done := mini(state.pitch, state.route.pitches.size()) * state.top_row + (_shown.y if state.pitch < state.route.pitches.size() else 0.0)
	return clampf(done / float(total), 0.0, 1.0)


## The person holding your rope: your quest partner, the instructor up top
## on a top rope, or an unnamed partner.
func _find_belayer() -> Dictionary:
	var quest := QuestLog.get_quest(state.route.partner_quest) if state.route.partner_quest != "" else null
	var who := QuestLog.get_character(quest.giver) if quest else null
	if who:
		return {"name": who.display_name, "top": who.color}
	return {"name": "", "top": Color("8a4a6a")}


# ---------------------------------------------------------------- drawing

func _draw_screen() -> void:
	var height := _progress()
	_canvas.draw_texture(_sky_tex, Vector2.ZERO)
	_draw_clouds(height)
	# Ridges sink as you climb: the nearer, the faster.
	var sink := [10.0, 20.0, 34.0, 60.0]
	for i in _ridges.size():
		_canvas.draw_texture(_ridges[i], Vector2(0, height * sink[i]))
	_draw_wall()
	_draw_protection()
	_draw_rope()
	_draw_belayer()
	_draw_climber()
	_draw_reachable()
	_draw_hud(height)
	_draw_message()
	if _fade > 0.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0, 0, 0, _fade))
	if state.status != ClimbState.Status.CLIMBING:
		_draw_result()


func _draw_clouds(height: float) -> void:
	var tint := Color(1, 1, 1, 0.35 if _pal.night else 0.95)
	for i in _clouds.size():
		var speed := 3.0 + i * 1.7
		var x := fposmod(140.0 + i * 131.0 + _time * speed, SCREEN.x + 140.0) - 70.0
		var y := 22.0 + i * 27.0 + height * (8.0 + i * 3.0)
		_canvas.draw_texture(_clouds[i], Vector2(x, y).round(), tint)


func _draw_wall() -> void:
	var top := _screen(state.top_row + ROWS_ABOVE - 0.5, -0.5).y
	_canvas.draw_texture(_wall_tex, Vector2(0, roundf(top)))
	# Below the picture: more wall, or the forest floor at the foot of pitch one.
	var bottom := top + _wall_tex.get_height()
	if bottom < SCREEN.y:
		var ground := Color("2e3a2a") if state.pitch == 0 else (_pal.rock as Color).darkened(0.2)
		_canvas.draw_rect(Rect2(0, bottom, SCREEN.x, SCREEN.y - bottom), ground)
	# Bolts glint until they're clipped.
	for r: int in state.bolts:
		var cell := Vector2i(state.bolts[r], r)
		if cell in state.clipped_bolts:
			continue
		var p := _bolt_pos(cell)
		# A hanger: a steel ring bolted to the rock, with a dark rim.
		_canvas.draw_rect(Rect2(p + Vector2(-2, -2), Vector2(5, 6)), OUTLINE)
		_canvas.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(3, 4)), STEEL)
		_canvas.draw_rect(Rect2(p + Vector2(0, 0), Vector2(1, 2)), STEEL_DARK)
		if fmod(_time * 1.3 + r * 0.37, 2.0) < 0.25:
			_canvas.draw_rect(Rect2(p + Vector2(-2, -1), Vector2(5, 1)), Color(1, 1, 1, 0.9))
			_canvas.draw_rect(Rect2(p + Vector2(0, -3), Vector2(1, 5)), Color(1, 1, 1, 0.9))


func _bolt_pos(cell: Vector2i) -> Vector2:
	return (_screen(cell.y, cell.x) + Vector2(9, -5)).round()


## Quickdraws hanging from clipped bolts, and cams in their cracks.
func _draw_protection() -> void:
	for piece: Dictionary in state.protection:
		var cell: Vector2i = piece.cell
		if piece.kind == "draw":
			var p := _bolt_pos(cell)
			_canvas.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(3, 3)), STEEL_DARK)
			_canvas.draw_rect(Rect2(p + Vector2(-1, 2), Vector2(2, 3)), STEEL)
			_canvas.draw_rect(Rect2(p + Vector2(-1, 5), Vector2(2, 4)), DRAW_SLING)
			_canvas.draw_rect(Rect2(p + Vector2(-1, 9), Vector2(3, 3)), STEEL)
		else:
			var p := (_screen(cell.y, cell.x) + Vector2(3, -2)).round()
			_canvas.draw_rect(Rect2(p + Vector2(-2, -2), Vector2(5, 4)), STEEL_DARK)
			_canvas.draw_rect(Rect2(p + Vector2(-1, -2), Vector2(3, 2)), STEEL)
			_canvas.draw_rect(Rect2(p + Vector2(0, 2), Vector2(1, 4)), CAM_SLING)
			_canvas.draw_rect(Rect2(p + Vector2(-1, 6), Vector2(3, 2)), STEEL)


## Where the rope leaves each piece of protection.
func _rope_point(piece: Dictionary) -> Vector2:
	var cell: Vector2i = piece.cell
	if piece.kind == "draw":
		return _bolt_pos(cell) + Vector2(0, 10)
	return (_screen(cell.y, cell.x) + Vector2(3, 6)).round()


func _harness() -> Vector2:
	return (_screen(_shown.y, _shown.x) + Vector2(0, 5)).round()


func _belay_spot() -> Vector2:
	if state.route.top_rope:
		return (_screen(state.top_row, ClimbState.COLUMNS / 2) + Vector2(0, -2)).round()
	return (_screen(0, ClimbState.COLUMNS / 2) + Vector2(-14, 4)).round()


## The rope: from the belayer up through every piece to the climber's harness
## (a top rope runs straight up to the anchor), with a little sag between.
func _draw_rope() -> void:
	var points: Array[Vector2] = [_belay_spot()]
	if not state.route.top_rope:
		for piece in state.protection:
			points.append(_rope_point(piece))
	points.append(_harness())
	for i in points.size() - 1:
		_sag(points[i], points[i + 1], 0.06 if i == 0 else 0.03)
	if not state.route.top_rope:
		# The tail hanging below the belayer, like the pictures' trailing rope.
		var b := points[0]
		_sag(b, b + Vector2(10, 16), 0.2)


func _sag(a: Vector2, b: Vector2, amount: float) -> void:
	var mid := (a + b) / 2.0 + Vector2(a.distance_to(b) * amount, a.distance_to(b) * amount * 0.6)
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		pts.append((a.lerp(mid, t)).lerp(mid.lerp(b, t), t).round())
	_canvas.draw_polyline(pts, ROPE_DARK, 2.0)
	_canvas.draw_polyline(pts, ROPE, 1.0)


func _draw_belayer() -> void:
	var p := _belay_spot()
	if p.y < -20 or p.y > SCREEN.y + 30:
		return
	var top: Color = _belayer.top
	# A small figure facing the wall, braced, paying out rope.
	var o := p + Vector2(0, 0)
	_canvas.draw_rect(Rect2(o + Vector2(-3, -12), Vector2(6, 15)), OUTLINE)
	_canvas.draw_rect(Rect2(o + Vector2(-2, -11), Vector2(4, 3)), Color("5a3a24"))
	_canvas.draw_rect(Rect2(o + Vector2(-2, -8), Vector2(4, 6)), top)
	_canvas.draw_rect(Rect2(o + Vector2(-2, -2), Vector2(4, 1)), Color("2a2a30"))
	_canvas.draw_rect(Rect2(o + Vector2(-2, -1), Vector2(1, 3)), Color("6a5a48"))
	_canvas.draw_rect(Rect2(o + Vector2(1, -1), Vector2(1, 3)), Color("6a5a48"))
	_canvas.draw_rect(Rect2(o + Vector2(2, -6), Vector2(3, 1)), CLIMBER.skin)


## The climber, seen from behind: hat, shirt, harness and chalk bag, legs
## bridged on the slab, one arm reaching for the next hold.
func _draw_climber() -> void:
	var c := _screen(_shown.y, _shown.x).round()
	var moving := _move_t < 1.0
	# Lean toward the side you're moving to; alternate the reaching arm.
	var lean := 0 if not moving else _reach
	var right_up := (state.row % 2 == 0) if lean == 0 else lean > 0
	var body := c + Vector2(lean, 7)
	var hand_hi := c + Vector2(4 if right_up else -4, -2)
	var hand_lo := body + Vector2(-5 if right_up else 5, -3)
	var foot_l := body + Vector2(-4, 9 if right_up else 6)
	var foot_r := body + Vector2(4, 6 if right_up else 9)
	# Outline pass, then color.
	for pass_i in 2:
		var w := 3.0 if pass_i == 0 else 1.0
		var arm: Color = OUTLINE if pass_i == 0 else CLIMBER.skin
		var leg: Color = OUTLINE if pass_i == 0 else CLIMBER.pants
		_canvas.draw_line(body + Vector2(1 if right_up else -1, -5), hand_hi, arm, w)
		_canvas.draw_line(body + Vector2(-1 if right_up else 1, -4), hand_lo, arm, w)
		_canvas.draw_line(body + Vector2(-1, 2), foot_l, leg, w + (1.0 if pass_i == 1 else 0.0))
		_canvas.draw_line(body + Vector2(1, 2), foot_r, leg, w + (1.0 if pass_i == 1 else 0.0))
	_canvas.draw_rect(Rect2(body + Vector2(-4, -12), Vector2(8, 15)), OUTLINE)
	_canvas.draw_rect(Rect2(body + Vector2(-3, -11), Vector2(6, 4)), CLIMBER.hat)
	_canvas.draw_rect(Rect2(body + Vector2(-4, -8), Vector2(8, 1)), CLIMBER.hat.darkened(0.2))
	_canvas.draw_rect(Rect2(body + Vector2(-3, -7), Vector2(6, 6)), CLIMBER.top)
	_canvas.draw_rect(Rect2(body + Vector2(-3, -7), Vector2(2, 6)), CLIMBER.top.lightened(0.15))
	_canvas.draw_rect(Rect2(body + Vector2(-3, -1), Vector2(6, 2)), Color("30303a"))
	_canvas.draw_rect(Rect2(body + Vector2(-3, 1), Vector2(6, 2)), CLIMBER.pants)
	if state.has_chalk:
		_canvas.draw_rect(Rect2(body + Vector2(-1, 0), Vector2(3, 3)), Color("e8e0d0"))
		if state.chalk_moves > 0:
			_canvas.draw_rect(Rect2(hand_hi + Vector2(-1, -1), Vector2(2, 2)), Color(1, 1, 1, 0.9))
	# Shoes: red climbing shoes, or the brown approach shoes.
	var shoe := Color("c8502e") if state.has_shoes else Color("6a4a2a")
	_canvas.draw_rect(Rect2(foot_l + Vector2(-2, -1), Vector2(3, 2)), shoe)
	_canvas.draw_rect(Rect2(foot_r + Vector2(-1, -1), Vector2(3, 2)), shoe)


## Rings round the holds you can reach, with what each move costs.
func _draw_reachable() -> void:
	if state.status != ClimbState.Status.CLIMBING or _move_t < 1.0:
		return
	var pulse := 0.6 + 0.4 * sin(_time * 5.0)
	for dx in [-1, 0, 1]:
		var r := state.row + 1
		var c: int = state.col + dx
		if state.hold_at(r, c).is_empty():
			continue
		var p := _screen(r, c).round()
		var cost := state.move_cost(r, c)
		if r == state.top_row:
			_text(p + Vector2(-14, -5), "ledge", EASY)
			continue
		var color := _cost_color(cost)
		_canvas.draw_arc(p, 6.0, 0, TAU, 14, Color(color, pulse), 1.0)
		var key: String = ["<", "^", ">"][dx + 1]
		_text(p + Vector2(7, -3), "%s %d" % [key, cost], color)
		if state.stamina - cost <= 0:
			_text(p + Vector2(7, 6), "fall!", WARN)


func _cost_color(cost: int) -> Color:
	var base := 2 + state.route.pitches[mini(state.pitch, state.route.pitches.size() - 1)] * 2
	return EASY if cost <= base else (MEDIUM if cost <= base + 2 else HARD)


## Bottom left, like the pictures' altimeter: height, stamina, and the rack.
func _draw_hud(height: float) -> void:
	var box := Rect2(6, SCREEN.y - 58, 122, 52)
	_canvas.draw_rect(box, Color(0.06, 0.06, 0.1, 0.72))
	_canvas.draw_rect(box, Color(1, 1, 1, 0.18), false, 1.0)
	var x := box.position.x + 6
	var y := box.position.y + 11
	var feet := int(round(height * state.route.total_height_ft()))
	_text(Vector2(x, y), "%d ft" % feet, TEXT)
	_text(Vector2(x + 44, y), "Pitch %d/%d" % [mini(state.pitch + 1, state.route.pitches.size()), state.route.pitches.size()], Color(TEXT, 0.75))
	y += 6
	# Stamina bar
	var frac := clampf(state.stamina / float(ClimbState.MAX_STAMINA), 0, 1)
	var low := state.stamina <= 25
	_canvas.draw_rect(Rect2(x, y, 110, 5), Color(0.15, 0.15, 0.18))
	_canvas.draw_rect(Rect2(x, y, 110 * frac, 5), WARN if low else EASY)
	y += 15
	_text(Vector2(x, y), "Stamina %d" % maxi(state.stamina, 0), WARN if low else TEXT)
	_text(Vector2(x + 62, y), "Food %d" % FoodDB.carried_energy(), Color(TEXT, 0.75))
	y += 5
	# The rack: one icon per piece left on this pitch.
	if state.route.top_rope:
		_text(Vector2(x, y + 9), "Top rope: falls are safe", Color(TEXT, 0.8))
	elif state.is_bolted():
		for i in mini(state.quickdraws_left, 10):
			_draw_draw_icon(Vector2(x + i * 7, y + 1))
		var runout := state.runout()
		if runout >= ClimbState.DANGEROUS_RUNOUT - 1:
			_text(Vector2(x + 72, y + 9), "Runout %d!" % runout, WARN)
	else:
		for i in mini(state.cams_left, 10):
			_draw_cam_icon(Vector2(x + i * 7, y + 1))
		var runout := state.runout()
		if runout >= ClimbState.DANGEROUS_RUNOUT - 1:
			_text(Vector2(x + 72, y + 9), "Runout %d!" % runout, WARN)
	# Route progress up the right edge, a notch at every belay.
	var bar := Rect2(SCREEN.x - 9, 30, 3, 200)
	_canvas.draw_rect(bar, Color(0.06, 0.06, 0.1, 0.6))
	for i in state.route.pitches.size() + 1:
		var ny := bar.end.y - bar.size.y * i / state.route.pitches.size()
		_canvas.draw_rect(Rect2(bar.position.x - 2, ny, 7, 1), Color(TEXT, 0.6))
	_canvas.draw_rect(Rect2(bar.position.x - 2, bar.end.y - bar.size.y * height - 2, 7, 4), ROPE)
	# Controls
	var tool := "" if state.route.top_rope else ("   Space clip" if state.is_bolted() else "   Space cam")
	var help := "Arrows climb%s   E %s   Esc retreat" % [tool, "eat" if state.is_at_belay() else "chalk"]
	if state.status != ClimbState.Status.CLIMBING:
		help = "E: continue"
	_text(Vector2(box.end.x + 8, SCREEN.y - 8), help, Color(TEXT, 0.7))
	_draw_prompt()


func _draw_draw_icon(p: Vector2) -> void:
	_canvas.draw_rect(Rect2(p + Vector2(1, 0), Vector2(3, 3)), STEEL)
	_canvas.draw_rect(Rect2(p + Vector2(1, 3), Vector2(3, 4)), DRAW_SLING)
	_canvas.draw_rect(Rect2(p + Vector2(1, 7), Vector2(3, 3)), STEEL)


func _draw_cam_icon(p: Vector2) -> void:
	_canvas.draw_rect(Rect2(p + Vector2(0, 0), Vector2(5, 3)), STEEL)
	_canvas.draw_rect(Rect2(p + Vector2(2, 3), Vector2(1, 4)), CAM_SLING)
	_canvas.draw_rect(Rect2(p + Vector2(1, 7), Vector2(3, 3)), STEEL)


## A hint by the climber for what the buttons do right here.
func _draw_prompt() -> void:
	if state.status != ClimbState.Status.CLIMBING or _move_t < 1.0:
		return
	var hint := ""
	if state.can_clip():
		hint = "Space: clip the bolt"
	elif state.can_place_cam():
		hint = "Space: place a cam"
	elif state.is_at_belay() and state.stamina < ClimbState.MAX_STAMINA and FoodDB.carried_energy() > 0:
		hint = "E: eat"
	elif not state.is_at_belay() and state.has_chalk and not state.chalked_this_pitch:
		hint = "E: chalk up"
	if hint != "":
		var p := _screen(_shown.y, _shown.x) + Vector2(-60, 26)
		_text(p.round(), hint, MEDIUM)


## What just happened, written across the sky.
func _draw_message() -> void:
	var rect := Rect2(306, 8, 160, 70)
	_canvas.draw_string(_font, Vector2(rect.position.x + 1, rect.position.y + 9), state.route.display_name + "  " + state.route.grade,
		HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 8, SHADOW)
	_canvas.draw_string(_font, Vector2(rect.position.x, rect.position.y + 8), state.route.display_name + "  " + state.route.grade,
		HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 8, MEDIUM)
	if state.message == "":
		return
	var pos := Vector2(rect.position.x, rect.position.y + 22)
	_canvas.draw_multiline_string(_font, pos + Vector2(1, 1), state.message, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 8, -1, SHADOW)
	_canvas.draw_multiline_string(_font, pos, state.message, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 8, -1, TEXT)


## The end card: topped out, or lowered off.
func _draw_result() -> void:
	var won := state.status == ClimbState.Status.TOPPED_OUT
	var box := Rect2(150, 96, 180, 64)
	_canvas.draw_rect(box, Color(0.06, 0.06, 0.1, 0.85))
	_canvas.draw_rect(box, Color(MEDIUM if won else WARN, 0.8), false, 1.0)
	var title := "Topped out!" if won else "Back on the ground"
	_canvas.draw_string(_font, box.position + Vector2(10, 16), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, MEDIUM if won else WARN)
	var hours := state.minutes / 60
	var detail := "%s in %dh %02dm, %d fall%s" % [state.route.display_name, hours, state.minutes % 60, state.falls, "" if state.falls == 1 else "s"]
	_canvas.draw_string(_font, box.position + Vector2(10, 32), detail, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 20, 8, TEXT)
	_canvas.draw_string(_font, box.position + Vector2(10, 52), "E: continue", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(TEXT, 0.7))


func _text(p: Vector2, text: String, color: Color) -> void:
	_canvas.draw_string(_font, p + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, SHADOW)
	_canvas.draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)
