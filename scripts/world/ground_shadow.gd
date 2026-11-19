class_name GroundShadow
extends RefCounted
## The soft two-tier oval under a person's feet, as under everyone in Stardew
## Valley, so people stand grounded instead of floating. Drawn in whole 2x2 art
## pixels in a cool deep shadow tone matching SunShadows.

const OUTER := Color(0.06, 0.06, 0.13, 0.2)
const CORE := Color(0.05, 0.05, 0.11, 0.22)


static func draw_under(ci: CanvasItem, at := Vector2.ZERO) -> void:
	# Soft outer penumbra
	ci.draw_rect(Rect2(at + Vector2(-8, -4), Vector2(16, 2)), OUTER)
	ci.draw_rect(Rect2(at + Vector2(-10, -2), Vector2(20, 4)), OUTER)
	ci.draw_rect(Rect2(at + Vector2(-8, 2), Vector2(16, 2)), OUTER)
	# Deeper contact shadow directly under the boots
	ci.draw_rect(Rect2(at + Vector2(-6, -2), Vector2(12, 4)), CORE)
