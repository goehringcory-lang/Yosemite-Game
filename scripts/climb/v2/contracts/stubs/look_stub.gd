class_name ClimbLookStub
extends ClimbLook
## Stand-in look until thread 10's lands: a flat granite panel, holds as dots
## coloured by kind, cracks as lines as wide as they are, bolts and pins,
## rest and crux zones outlined, and a camera that eases after the hips.
## Debug drawing only; no sound.

const KIND_COLORS := {
	&"jug": Color("6fbf5a"), &"edge": Color("d8c27a"), &"crimp": Color("d9772a"),
	&"sloper": Color("8fa3c8"), &"pinch": Color("c88fc0"), &"pocket": Color("a06a4a"),
	&"jam": Color("4a8ac0"), &"stance": Color("e8e0c8"), &"horn": Color("9ad0a0"),
}

var _focus := Vector2.ZERO
var _zoom := 1.0


func show_wall(wall: V2Wall) -> void:
	_focus = wall.start + Vector2(0, 1.5)
	queue_redraw()


func frame(delta: float) -> void:
	if session == null or world == null:
		return
	var want := session.pose.hip + Vector2(0, 0.8)
	_focus = _focus.lerp(want, 1.0 - exp(-4.0 * delta))
	world.scale = Vector2(_zoom, _zoom)
	world.position = screen_size * 0.5 - ClimberView.px(_focus) * _zoom
	queue_redraw()


func _draw() -> void:
	if session == null or session.wall == null:
		return
	var w := session.wall
	var px := ClimberView.px
	var r := Rect2(px.call(Vector2(0, w.size.y)), w.size * ClimbV2.PX_PER_M)
	draw_rect(r.grow(400), Color("2a3442"))
	draw_rect(r, Color("8a8478"))
	for z in w.zones:
		var zr := Rect2(px.call(Vector2(z.rect.position.x, z.rect.end.y)), z.rect.size * ClimbV2.PX_PER_M)
		draw_rect(zr, Color("e8c050") if z.kind == &"crux" else Color("6fbf5a"), false, 2.0)
	for c in w.cracks:
		for i in c.points.size() - 1:
			draw_line(px.call(c.points[i]), px.call(c.points[i + 1]), Color("2a2622"), 2.0 + c.widths[i] * 1.5)
	for h in w.holds:
		var col: Color = KIND_COLORS.get(h.kind, Color.WHITE)
		if not h.hand:
			col = Color("5c5750")
		draw_circle(px.call(h.pos), 3.0 + h.size * 4.0 if h.hand else 3.0, col)
	for p: V2Piece in session.pieces.values():
		draw_rect(Rect2(px.call(p.pos) - Vector2(2, 4), Vector2(4, 8)), Color("c8382e") if not p.popped else Color("5c5750"))
	for p in w.fixed:
		draw_rect(Rect2(px.call(p.pos) - Vector2(3, 3), Vector2(6, 6)), Color("bdb8ae") if not p.clipped else Color("e8c050"))
