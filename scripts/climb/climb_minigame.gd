class_name ClimbMinigame
extends CanvasLayer
## The climbing screen: a side view of one pitch at a time. The rules live in
## ClimbState; this draws them and turns input into moves.
##
## Controls: up = climb straight up, left/right = climb up-left/up-right,
## use tool = place a cam, interact = eat (at a belay ledge), cancel = retreat.

## Emitted when the player leaves the screen after topping out or retreating.
signal finished(success: bool, minutes: int)

const CELL := Vector2(36, 24)
const WALL_ORIGIN := Vector2(150, 18)
const GRANITE := Color(0.62, 0.6, 0.56)
const GRANITE_DARK := Color(0.45, 0.43, 0.4)
const LEDGE := Color(0.5, 0.42, 0.3)
const TEXT := Color(0.97, 0.94, 0.86)
const WARN := Color(1.0, 0.45, 0.35)
const EASY := Color(0.45, 0.8, 0.4)
const MEDIUM := Color(0.95, 0.8, 0.3)
const HARD := Color(0.95, 0.45, 0.25)

var state: ClimbState

var _canvas: Control
var _font: Font


## Call before adding the node to the tree.
func setup(route: RouteData, seed := -1) -> void:
	state = ClimbState.new(route, Gear.count("cam"), seed)


func _ready() -> void:
	layer = 20
	_font = ThemeDB.fallback_font
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_screen)
	add_child(_canvas)
	state.message = "%s (%s). Pitch 1 of %d." % [state.route.display_name, state.route.grade, state.route.pitches.size()]


func _input(event: InputEvent) -> void:
	if not (event.is_action_pressed("move_up") or event.is_action_pressed("move_left") \
			or event.is_action_pressed("move_right") or event.is_action_pressed("use_tool") \
			or event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel")):
		return
	get_viewport().set_input_as_handled()
	if state.status != ClimbState.Status.CLIMBING:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
			finished.emit(state.status == ClimbState.Status.TOPPED_OUT, state.minutes)
			queue_free()
		return
	if event.is_action_pressed("move_up"):
		state.move(0)
	elif event.is_action_pressed("move_left"):
		state.move(-1)
	elif event.is_action_pressed("move_right"):
		state.move(1)
	elif event.is_action_pressed("use_tool"):
		state.place_cam()
	elif event.is_action_pressed("interact"):
		eat_next()
	elif event.is_action_pressed("ui_cancel"):
		state.retreat()
	_canvas.queue_redraw()


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


func _cell_center(r: int, c: int) -> Vector2:
	return WALL_ORIGIN + Vector2(c + 0.5, state.top_row - r + 0.5) * CELL


func _draw_screen() -> void:
	var size := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.18, 0.22, 0.3))
	_draw_wall()
	_draw_panel()


func _draw_wall() -> void:
	var wall_size := Vector2(ClimbState.COLUMNS, state.top_row + 1) * CELL
	_canvas.draw_rect(Rect2(WALL_ORIGIN, wall_size), GRANITE)
	for r in state.top_row + 1:
		if r == 0 or r == state.top_row:
			var y := _cell_center(r, 0).y
			_canvas.draw_rect(Rect2(WALL_ORIGIN.x, y + 4, wall_size.x, 5), LEDGE)
			continue
		var base := 2 + state.route.pitches[mini(state.pitch, state.route.pitches.size() - 1)] * 2
		for c: int in state.holds.get(r, {}):
			var hold: Dictionary = state.holds[r][c]
			var center := _cell_center(r, c)
			if hold.crack:
				_canvas.draw_line(center + Vector2(0, -11), center + Vector2(0, 11), GRANITE_DARK, 2.0)
			var color := EASY if hold.cost <= base + 1 else (MEDIUM if hold.cost <= base + 2 else HARD)
			_canvas.draw_circle(center, 4.0, color)
			_canvas.draw_string(_font, center + Vector2(6, 4), str(hold.cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, GRANITE_DARK)
	# Reachable holds
	if state.status == ClimbState.Status.CLIMBING:
		for dx in [-1, 0, 1]:
			if not state.hold_at(state.row + 1, state.col + dx).is_empty():
				_canvas.draw_arc(_cell_center(state.row + 1, state.col + dx), 7.0, 0, TAU, 12, TEXT, 1.0)
	# Rope from the belay through each cam to the climber
	var points := PackedVector2Array([_cell_center(0, ClimbState.COLUMNS / 2)])
	for cam in state.placed_cams:
		points.append(_cell_center(cam.y, cam.x))
	points.append(_cell_center(state.row, state.col))
	_canvas.draw_polyline(points, Color(0.9, 0.3, 0.3), 1.0)
	for cam in state.placed_cams:
		var p := _cell_center(cam.y, cam.x)
		_canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-4, -3), p + Vector2(4, -3), p + Vector2(0, 4)]), Color(0.3, 0.6, 0.95))
	# Climber
	var me := _cell_center(state.row, state.col)
	_canvas.draw_circle(me + Vector2(0, -8), 3.0, Color(0.95, 0.8, 0.65))
	_canvas.draw_rect(Rect2(me + Vector2(-3, -5), Vector2(6, 8)), Color(0.85, 0.35, 0.2))


func _draw_panel() -> void:
	var x := WALL_ORIGIN.x + ClimbState.COLUMNS * CELL.x + 12
	var y := 28.0
	var lines := [
		[state.route.display_name, TEXT],
		["Grade %s" % state.route.grade, TEXT],
		["Pitch %d of %d" % [mini(state.pitch + 1, state.route.pitches.size()), state.route.pitches.size()], TEXT],
		["", TEXT],
		["Stamina %d" % maxi(state.stamina, 0), TEXT if state.stamina > 25 else WARN],
	]
	for line in lines:
		_canvas.draw_string(_font, Vector2(x, y), line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, line[1])
		y += 11
	_canvas.draw_rect(Rect2(x, y - 6, 90, 5), Color(0.2, 0.2, 0.2))
	_canvas.draw_rect(Rect2(x, y - 6, 90 * clampf(state.stamina / float(ClimbState.MAX_STAMINA), 0, 1), 5), EASY if state.stamina > 25 else WARN)
	y += 10
	var more := []
	if state.route.top_rope:
		more.append(["Top rope: falls are safe", TEXT])
	else:
		more.append(["Cams left %d" % state.cams_left, TEXT])
		var danger := state.runout() >= ClimbState.DANGEROUS_RUNOUT - 1
		more.append(["Runout %d%s" % [state.runout(), "  Place a cam!" if danger else ""], WARN if danger else TEXT])
	more.append(["Food energy %d" % FoodDB.carried_energy(), TEXT])
	if state.route.nights > 0:
		more.append(["Nights %d of %d" % [state.nights_spent, state.route.nights], TEXT])
	for line in more:
		_canvas.draw_string(_font, Vector2(x, y), line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, line[1])
		y += 11
	y += 6
	var help := "Arrows: climb\nSpace: place cam\nE: eat (at a ledge)\nEsc: retreat"
	if state.status != ClimbState.Status.CLIMBING:
		help = "E: continue"
	_canvas.draw_multiline_string(_font, Vector2(x, y), help, HORIZONTAL_ALIGNMENT_LEFT, 120, 8, -1, Color(TEXT, 0.7))
	# Message box on the left
	_canvas.draw_multiline_string(_font, Vector2(8, 40), state.message, HORIZONTAL_ALIGNMENT_LEFT, WALL_ORIGIN.x - 16, 8, -1, TEXT)
