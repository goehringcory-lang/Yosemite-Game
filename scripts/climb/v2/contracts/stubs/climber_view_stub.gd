class_name ClimberViewStub
extends ClimberView
## Stand-in climber until thread 9's art lands: a stick figure from the pose's
## contacts, the ghost of the previewed move, and the rope from the belay
## through every clipped piece to the harness. Debug drawing only.

var _ghost: V2Move


func show_ghost(move: V2Move) -> void:
	_ghost = move
	queue_redraw()


func _draw() -> void:
	if session == null or session.wall == null:
		return
	_rope()
	if _ghost and _ghost.to:
		var tint := Color(1, 1, 1, 0.35) if _ghost.valid else Color(1, 0.3, 0.3, 0.35)
		_figure(_ghost.to, tint.lerp(Color(1, 0.6, 0.2, 0.45), _ghost.strain))
	_figure(session.pose, Color("f2e6c8"))


func _figure(pose: V2Pose, color: Color) -> void:
	var hip := px(pose.hip)
	var neck := px(pose.hip + Vector2(0, ClimbV2.TORSO_M))
	draw_line(hip, neck, color, 3.0)
	draw_circle(neck + Vector2(0, -8), 6.0, color)
	for l in V2Pose.LIMBS:
		var limb: V2Limb = pose.limb(l)
		var root := neck if l == &"lh" or l == &"rh" else hip
		draw_line(root, px(limb.pos), color, 2.0)
		draw_circle(px(limb.pos), 3.0, color if limb.on_rock() else color.darkened(0.4))


func _rope() -> void:
	var pts := PackedVector2Array([px(session.wall.start)])
	for id in session.rope.clipped:
		var p := session.piece(id)
		if p:
			pts.append(px(p.pos))
	pts.append(px(session.pose.tie_in()))
	draw_polyline(pts, Color("b3362b"), 2.0)
