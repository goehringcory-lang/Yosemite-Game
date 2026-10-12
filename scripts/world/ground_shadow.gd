class_name GroundShadow
extends RefCounted
## The soft oval under a person's feet, as under everyone in Stardew Valley,
## so people stand on the ground instead of floating over it. Drawn in whole
## pixels, from the node's own _draw (which draws under its sprite).

const COLOR := Color(0.05, 0.04, 0.03, 0.28)


static func draw_under(ci: CanvasItem, at := Vector2.ZERO) -> void:
	ci.draw_rect(Rect2(at + Vector2(-3, -2), Vector2(6, 1)), COLOR)
	ci.draw_rect(Rect2(at + Vector2(-5, -1), Vector2(10, 2)), COLOR)
	ci.draw_rect(Rect2(at + Vector2(-3, 1), Vector2(6, 1)), COLOR)
