class_name EffortOverlay
extends Control
## Shows strain on the climber's body instead of a meter (thread 4): the
## forearms flush and tremble as the pump builds, elbows lift when boxed, a
## shake-out throws chalk off the resting hand and stops once it has nothing
## left to give, breath puffs when working hard or low on gas, sweat in the
## sun, a glance at the pack when food would help, crumbs and the food's
## name when you eat. The ghost of a move that will fail shakes red at the
## reaching arm.
##
## It reads session.notes.effort.signs (EffortSigns) and the bus and never
## changes the session. It stands down if the climber art (thread 9) says it
## draws the signs itself (a draws_effort_signs() method returning true).

var session: ClimbSession

var _climber: Node2D
var _time := 0.0
var _puffs: Array = []   # [pos (wall m), velocity (px/s), age, life, kind]
var _ghost: V2Move
var _ghost_signs := {}
var _food_label := ""
var _food_age := 99.0
var _breath_clock := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 4
	var screen := _screen()
	if screen:
		_climber = screen.get("climber")
	if session:
		session.bus.rested.connect(_on_rested)
		session.bus.food_eaten.connect(_on_food_eaten)
		session.bus.move_previewed.connect(_on_previewed)
		session.bus.move_committed.connect(func(_m: V2Move) -> void: _ghost = null)
		session.bus.aim_changed.connect(func(id: String) -> void:
			if id == "":
				_ghost = null)


func _process(delta: float) -> void:
	_time += delta
	_food_age += delta
	for p: Array in _puffs:
		p[2] += delta
	_puffs = _puffs.filter(func(p: Array) -> bool: return p[2] < p[3])
	var s := _signs()
	var breath := float(s.get("breath", 0.0))
	if breath > 0.3:
		_breath_clock += delta * (0.6 + 2.2 * breath)
		if _breath_clock >= 1.0:
			_breath_clock = 0.0
			_puff(_head(), Vector2(10 * _facing(), -6), 1.1, &"breath")
	if float(s.get("sweat", 0.0)) > 0.45 and _rng.randf() < delta * 0.8 * float(s.sweat):
		_puff(_head() + Vector2(0.08 * _facing(), 0), Vector2(0, 26), 0.7, &"sweat")
	queue_redraw()


func _draw() -> void:
	if session == null or session.pose == null or _stood_down():
		return
	var s := _signs()
	var tremble := float(s.get("tremble", 0.0))
	var wing := float(s.get("chicken_wing", 0.0))
	for hand: StringName in [&"lh", &"rh"]:
		var l: V2Limb = session.pose.limb(hand)
		if not l.on_rock():
			continue
		var elbow := _elbow(hand, l.pos, wing)
		_draw_forearm(elbow, l.pos, tremble, hand)
	_draw_ghost()
	for p: Array in _puffs:
		var t: float = p[2] / p[3]
		var at: Vector2 = _to_screen(p[0]) + (p[1] as Vector2) * float(p[2])
		match p[4]:
			&"breath":
				draw_circle(at, 2.0 + 5.0 * t, Color(1, 1, 1, 0.35 * (1.0 - t)))
			&"chalk":
				draw_circle(at, 1.5 + 4.0 * t, Color(0.97, 0.96, 0.92, 0.7 * (1.0 - t)))
			&"sweat":
				draw_circle(at, 1.4, Color(0.7, 0.86, 1.0, 0.8 * (1.0 - t)))
			&"crumb":
				draw_rect(Rect2(at, Vector2(2, 2)), Color(0.86, 0.66, 0.38, 1.0 - t))
	if float(s.get("hunger", 0.0)) > 0.3:
		# A glance at the pack: a little wavy growl by the belly.
		var belly := _to_screen(session.pose.hip + Vector2(0.12 * _facing(), 0.18))
		var a := 0.35 + 0.35 * sin(_time * 3.0)
		for i in 3:
			var x := belly.x + 6 + i * 4
			draw_line(Vector2(x, belly.y - 2 + 2 * sin(_time * 8 + i)), Vector2(x + 3, belly.y + 2 * cos(_time * 8 + i)), Color(1, 0.9, 0.6, a), 1.0)
	if _food_age < 1.8 and _food_label != "":
		var at := _to_screen(_head()) + Vector2(-30, -26 - 14 * _food_age)
		draw_string(get_theme_default_font(), at, _food_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.93, 0.75, clampf(2.0 - _food_age * 1.1, 0, 1)))


## Pumped forearms flush and shake: a warm stroke over the forearm, jittering
## with the tremble.
func _draw_forearm(elbow: Vector2, hand_pos: Vector2, tremble: float, hand: StringName) -> void:
	if tremble <= 0.02:
		return
	var a := _to_screen(elbow)
	var b := _to_screen(hand_pos)
	var phase := 0.0 if hand == &"lh" else 1.7
	var jitter := Vector2(sin(_time * 47.0 + phase), cos(_time * 53.0 + phase)) * 2.2 * tremble
	var flush := Color(0.92, 0.32, 0.22, 0.25 + 0.4 * tremble)
	draw_line(a + jitter, b + jitter * 0.5, flush, 3.0 + 2.0 * tremble)
	if tremble > 0.4:
		var mid := (a + b) * 0.5 + jitter
		var n := (b - a).orthogonal().normalized() * 5.0
		draw_line(mid + n, mid + n * 1.8, Color(1, 0.85, 0.7, tremble * 0.6), 1.0)
		draw_line(mid - n, mid - n * 1.8, Color(1, 0.85, 0.7, tremble * 0.6), 1.0)


## A move the ghost shows will fail (or will leave you shaking): the reaching
## arm trembles red toward the hold.
func _draw_ghost() -> void:
	if _ghost == null or _ghost.to == null or _ghost_signs.is_empty():
		return
	var h := session.wall.hold(_ghost.hold_id) if session.wall else null
	if h == null:
		return
	var fail := float(_ghost_signs.get("fail", 0.0)) > 0.5
	var tremble := float(_ghost_signs.get("tremble", 0.0))
	if not fail and tremble < 0.35:
		return
	var shoulder := _ghost.to.hip + Vector2(0.18 * (-1.0 if _ghost.hand == &"lh" else 1.0), ClimbV2.TORSO_M)
	var a := _to_screen(shoulder)
	var b := _to_screen(h.pos)
	var j := Vector2(sin(_time * 40.0), cos(_time * 37.0)) * (3.0 if fail else 1.5 * tremble)
	var col := Color(0.95, 0.25, 0.2, 0.75) if fail else Color(0.95, 0.55, 0.3, 0.35 + 0.3 * tremble)
	if fail:
		# Broken, shaking: the arm won't stay on.
		var seg := 6
		for i in seg:
			if i % 2 == 0:
				draw_line(a.lerp(b, float(i) / seg) + j, a.lerp(b, float(i + 1) / seg) - j, col, 2.0)
		draw_circle(b + j, 5.0, Color(col, 0.35))
	else:
		draw_line(a + j, b - j, col, 2.0)


func _on_rested(kind: StringName) -> void:
	if kind == &"belay" or session.pose == null:
		return
	var arm := StringName(str(session.note(&"effort").get("arm", "lh")))
	var l: V2Limb = session.pose.limb(arm)
	var at := l.pos if l.on_rock() else session.pose.hip
	# The resting arm drops and shakes: chalk shakes off below the hip.
	var shake_at := session.pose.hip + Vector2(0.3 * (-1.0 if arm == &"lh" else 1.0), -0.15)
	var gain := float(_signs().get("rest_left", 0.0))
	for i in 4 + int(gain * 6):
		_puff(shake_at.lerp(at, 0.2), Vector2(_rng.randf_range(-22, 22), _rng.randf_range(10, 34)), 0.9, &"chalk")


func _on_food_eaten(food_id: String, _gas: float) -> void:
	_food_label = _food_name(food_id)
	_food_age = 0.0
	for i in 5:
		_puff(_head(), Vector2(_rng.randf_range(-12, 12), _rng.randf_range(14, 30)), 0.8, &"crumb")


func _on_previewed(move: V2Move) -> void:
	_ghost = move
	var effort := session.sys.effort
	_ghost_signs = effort.ghost_signs(move) if effort and effort.has_method("ghost_signs") else {}


func _puff(at: Vector2, vel: Vector2, life: float, kind: StringName) -> void:
	if _puffs.size() < 80:
		_puffs.append([at, vel, 0.0, life, kind])


func _signs() -> Dictionary:
	return session.note(&"effort").get("signs", {}) if session else {}


func _head() -> Vector2:
	return session.pose.hip + Vector2(0.05 * _facing(), ClimbV2.TORSO_M + 0.22)


func _facing() -> float:
	return -1.0 if session.pose.facing < 0 else 1.0


func _elbow(hand: StringName, hand_pos: Vector2, wing: float) -> Vector2:
	var side := -1.0 if hand == &"lh" else 1.0
	var shoulder := session.pose.hip + Vector2(0.18 * side, ClimbV2.TORSO_M)
	# The forearm: from the hand to a bit under half way to the shoulder.
	# Chicken wings: the elbow lifts out sideways as the arm gives out.
	return hand_pos.lerp(shoulder, 0.45) + Vector2(side * 0.14 * wing, 0.06 * wing)


func _to_screen(wall_pos: Vector2) -> Vector2:
	var px := ClimberView.px(wall_pos)
	if _climber and is_instance_valid(_climber):
		return _climber.get_global_transform() * px
	return px


func _stood_down() -> bool:
	return _climber != null and is_instance_valid(_climber) and _climber.has_method("draws_effort_signs") and _climber.call("draws_effort_signs")


func _screen() -> Node:
	var n := get_parent()
	while n and not n.get("climber") is ClimberView:
		n = n.get_parent()
	return n


func _food_name(food_id: String) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var db := tree.root.get_node_or_null("/root/ItemDB") if tree else null
	if db and db.has_method("get_item"):
		var item: ItemData = db.get_item(food_id)
		if item and str(item.get("display_name")) != "":
			return str(item.get("display_name"))
	return food_id.replace("_", " ")
