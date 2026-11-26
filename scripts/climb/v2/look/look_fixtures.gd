class_name LookFixtures
extends Node2D
## Things on the rock that aren't rock (thread 10), drawn over the lit wall
## and under the climber: the ground at the foot of the first pitch, grass
## on ledges, the bolts, old pins and anchors (with a quickdraw hanging once
## you clip one), the cams, nuts and slings you place, and a faint chalk
## tick on the holds within reach. Lives in the world node (1 unit = 1 pixel,
## wall metres through ClimberView.px). Redrawn only when something changes.

const T := preload("res://scripts/climb/v2/look/look_tuning.gd")
## Camalot colours by size (0 = #0.3 .. 7 = #4), as the real ones are.
const CAM_COLORS := ["3a6fd0", "9a9aa4", "8a52c0", "4aa04a", "d03a32", "e8c832", "3a6fd0", "9a9aa4"]
const STEEL := Color("c4c2bc")
const STEEL_DARK := Color("6e6c68")
const RUST := Color("8a4a2a")
const DRAW_SLING := Color("e86a2a")
const CHALK := Color(0.97, 0.95, 0.9, 0.55)

var session: ClimbSession
## The aimed hold's id ("" none): no tick on it (the ghost shows it).
var aim_id := ""
## Night lamp centre and radius (wall metres); ticks show only in the lamp.
var lamp := Vector2.ZERO
var night := 0.0


func _px(p: Vector2) -> Vector2:
	return ClimberView.px(p).round()


func _draw() -> void:
	if session == null or session.wall == null:
		return
	var w := session.wall
	if w.pitch == 0:
		_ground(w)
	for z in w.zones:
		if z.kind in [&"ledge", &"bivy"]:
			_grass(z.rect.position.x, z.rect.end.x, z.rect.end.y, hash(z.id))
	_ticks(w)
	for p in w.fixed:
		_fixed(p)
	for p: V2Piece in session.pieces.values():
		if not p.popped:
			_placed(p)


## The forest floor under the first pitch: dirt, a few talus blocks, ferns.
func _ground(w: V2Wall) -> void:
	var rect := LookWallPaint.area(w)
	var top := _px(Vector2(rect.position.x, 0.05))
	var bottom := _px(Vector2(rect.end.x, rect.position.y - 1.0))
	draw_rect(Rect2(top, bottom - top), Color("4a3e30"))
	draw_rect(Rect2(top, Vector2(bottom.x - top.x, 3)), Color("6a5a40"))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([w.route_id, "ground"])
	for i in int(rect.size.x * 1.5):
		var x := rng.randf_range(rect.position.x, rect.end.x)
		var p := _px(Vector2(x, rng.randf_range(-1.8, -0.1)))
		var s := rng.randi_range(6, 16)
		draw_rect(Rect2(p - Vector2(s, s * 0.6), Vector2(s * 2, s * 0.6 + 2)), Color("7a7670"))
		draw_rect(Rect2(p - Vector2(s, s * 0.6), Vector2(s * 2, 2)), Color("a29e96"))
	_grass(rect.position.x, rect.end.x, 0.05, hash(w.route_id))


func _grass(x0: float, x1: float, y: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var x := x0
	while x < x1:
		var p := _px(Vector2(x, y))
		var tall := rng.randi_range(3, 8)
		var col := Color("5a7a3a") if rng.randf() < 0.6 else Color("7a9a4a")
		draw_line(p, p + Vector2(rng.randf_range(-2, 2), -tall), col, 1.0)
		x += rng.randf_range(0.05, 0.25)


## A faint chalk tick on each hand hold within reach, the way you'd spot
## the chalked line; none on the aimed one, and at night only in the lamp.
func _ticks(w: V2Wall) -> void:
	var hip := session.pose.hip
	var held := {}
	for l: StringName in V2Pose.LIMBS:
		held[session.pose.limb(l).id] = true
	for h in w.holds_within(hip + Vector2(0, 0.6), T.TICK_RANGE):
		if h.id == aim_id or held.has(h.id) or h.has_tag("hidden") or h.kind == &"jam":
			continue
		if night > 0.5 and h.pos.distance_to(lamp) > T.LAMP_RADIUS:
			continue
		var p := _px(h.pos)
		var len := 3.0 + h.size * 4.0
		draw_line(p + Vector2(-len, -4), p + Vector2(len, -4), CHALK, 1.0)


func _fixed(p: V2Piece) -> void:
	var at := _px(p.pos)
	match p.kind:
		&"anchor":
			for dx in [-9, 9]:
				_hanger(at + Vector2(dx, 0))
			# Chain down to a ring.
			for k in 3:
				draw_rect(Rect2(at + Vector2(-9 + k * 3, 3 + k * 3), Vector2(2, 3)), STEEL_DARK)
				draw_rect(Rect2(at + Vector2(7 - k * 3, 3 + k * 3), Vector2(2, 3)), STEEL_DARK)
			draw_arc(at + Vector2(0, 14), 3.0, 0, TAU, 10, STEEL, 1.5)
		&"pin":
			draw_line(at + Vector2(-5, 1), at + Vector2(1, 0), RUST, 2.0)
			draw_arc(at + Vector2(3, 1), 2.0, 0, TAU, 8, RUST.darkened(0.2), 1.0)
		_:
			_hanger(at)
	if p.clipped:
		_draw_hanging(at + Vector2(0, 3) if p.kind != &"anchor" else at + Vector2(0, 16), p.back_clipped)


func _hanger(at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(-2, -3), Vector2(5, 7)), STEEL_DARK)
	draw_rect(Rect2(at + Vector2(-1, -2), Vector2(3, 5)), STEEL)
	draw_rect(Rect2(at + Vector2(0, 0), Vector2(1, 2)), STEEL_DARK)


## A quickdraw hanging from [param at]: top biner, dogbone, rope biner. A
## back-clipped one hangs twisted (its gate shows the wrong way).
func _draw_hanging(at: Vector2, back: bool) -> void:
	draw_arc(at + Vector2(0, 2), 2.0, 0, TAU, 8, STEEL, 1.0)
	draw_rect(Rect2(at + Vector2(-1, 4), Vector2(3, 7)), DRAW_SLING)
	var bottom := at + Vector2(0, 13)
	draw_arc(bottom, 2.5, 0, TAU, 8, STEEL, 1.0)
	draw_line(bottom + Vector2(2 if not back else -2, -2), bottom + Vector2(2 if not back else -2, 2), STEEL_DARK, 1.0)


func _placed(p: V2Piece) -> void:
	var at := _px(p.pos)
	match p.kind:
		&"cam":
			var col := Color(CAM_COLORS[clampi(roundi(p.width), 0, 7)])
			# Lobes in the crack, the stem and trigger out of it, a sling.
			draw_rect(Rect2(at + Vector2(-3, -2), Vector2(7, 4)), col.darkened(0.15))
			draw_rect(Rect2(at + Vector2(-2, -1), Vector2(5, 2)), col)
			draw_line(at + Vector2(0, 2), at + Vector2(0, 7), STEEL_DARK, 1.0)
			draw_line(at + Vector2(-2, 5), at + Vector2(2, 5), STEEL, 1.0)
			draw_rect(Rect2(at + Vector2(-1, 7), Vector2(3, 4)), col.lightened(0.2))
		&"nut":
			draw_colored_polygon(PackedVector2Array([at + Vector2(-3, -3), at + Vector2(3, -3), at + Vector2(2, 2), at + Vector2(-2, 2)]), Color("c8a040"))
			draw_line(at + Vector2(-1, 2), at + Vector2(-1, 9), STEEL, 1.0)
			draw_line(at + Vector2(1, 2), at + Vector2(1, 9), STEEL, 1.0)
		&"sling":
			draw_arc(at + Vector2(0, 4), 5.0, 0, TAU, 12, Color("3a8ad0"), 2.0)
		_:
			_hanger(at)
	if p.clipped:
		_draw_hanging(at + Vector2(0, 10), p.back_clipped)
