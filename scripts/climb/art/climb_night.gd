class_name ClimbNight
extends RefCounted
## The night on the wall: stars over the Valley, a few campfires far below, and
## you and your partner on a ledge or a portaledge, eating by headlamp.

const P := preload("res://scripts/climb/art/climb_paint.gd")
const UI := preload("res://scripts/climb/art/climb_ui.gd")
const SCREEN := Vector2(480, 270)

const PLAYER_LOOK := {"id": "player", "skin": "f0c088", "hair": "6a4428", "hat": "8a5a2a", "hat_kind": "fedora", "top": "6a8a4a", "bottom": "3a4466"}


static func draw(ci: CanvasItem, info: Dictionary, state: ClimbState, route: RouteData, profile: Dictionary, age: float, time: float, kit: Dictionary) -> void:
	# Sky: deep blue to purple at the horizon.
	for i in 27:
		var t := i / 26.0
		ci.draw_rect(Rect2(0, i * 10, SCREEN.x, 10), Color("0a0e28").lerp(Color("2a2a58"), t * t))
	# Stars, twinkling.
	for i in 90:
		var x := fposmod(P.noise(i, 1, 4) * SCREEN.x, SCREEN.x)
		var y := P.noise(i, 2, 4) * 170.0
		var tw := 0.5 + 0.5 * sin(time * (1.0 + P.noise(i, 3, 4) * 3.0) + i)
		ci.draw_rect(Rect2(x, y, 1 + int(i % 11 == 0), 1), Color(1, 1, 0.95, 0.35 + 0.65 * tw))
	# The moon.
	ci.draw_circle(Vector2(398, 44), 16, Color(0.9, 0.9, 1.0, 0.07))
	ci.draw_circle(Vector2(398, 44), 9, Color("e8e8f0"))
	ci.draw_circle(Vector2(401, 42), 8, Color("0e1230"))
	ci.draw_circle(Vector2(398, 44), 9, Color(0.9, 0.9, 1.0, 0.0))
	# Far ridgelines and the valley floor, with campfires and lights.
	for l in 3:
		var base := 150 + l * 18
		var col := Color("1a2040").lerp(Color("0a0e22"), l / 2.0)
		for x in int(SCREEN.x):
			var top := base - 22 + int(sin(x * (0.013 + l * 0.01) + l) * 12.0 + sin(x * 0.04 + l * 2.0) * 4.0)
			ci.draw_rect(Rect2(x, top, 1, SCREEN.y - top), col)
	for i in 16:
		var fx := 200.0 + P.noise(i, 5, 9) * 270.0
		var fy := 204.0 + P.noise(i, 6, 9) * 50.0
		var flick := 0.6 + 0.4 * sin(time * 5.0 + i * 3.0)
		ci.draw_rect(Rect2(fx, fy, 2, 2), Color(1.0, 0.7, 0.3, 0.6 + 0.4 * flick))
	# The wall, dark, lit a little by the lamp.
	var wall := Rect2(0, 0, 330, SCREEN.y)
	ci.draw_rect(wall, Color("1a1c2c"))
	for x in range(0, 330, 6):
		var shade := 0.5 + 0.5 * P.noise(x, 7, 2)
		ci.draw_rect(Rect2(x, 0, 6, SCREEN.y), Color("1a1c2c").lerp(Color("2a2c40"), shade))
	for i in 24:
		var sx := P.noise(i, 8, 3) * 320.0
		ci.draw_rect(Rect2(sx, 0, 1, SCREEN.y), Color(0.05, 0.05, 0.1, 0.6))
	ci.draw_rect(Rect2(326, 0, 4, SCREEN.y), Color("40425a"))
	ci.draw_rect(Rect2(329, 0, 1, SCREEN.y), Color("6a6c88"))
	var hanging: bool = info.get("place", "ledge") == "hanging"
	var cx := 170.0
	var cy := 168.0
	# A lamp glow over the whole scene.
	for i in 8:
		ci.draw_circle(Vector2(cx, cy - 20), 120.0 - i * 13.0, Color(1.0, 0.82, 0.5, 0.03 + 0.004 * sin(time * 3.0)))
	if hanging:
		# Straps up to the anchors, and the orange portaledge.
		var anchor_y := 60.0
		for k in [-70.0, 70.0]:
			ci.draw_rect(Rect2(cx + k, anchor_y, 3, 6), Color("c8ccd4"))
			ci.draw_line(Vector2(cx + k, anchor_y + 6), Vector2(cx + k * 0.55, cy + 8), Color("7a2218"), 2.0)
			ci.draw_line(Vector2(cx + k, anchor_y + 6), Vector2(cx + k * 0.55, cy + 8), Color("d8452e"), 1.0)
		ci.draw_rect(Rect2(cx - 78, cy + 8, 156, 6), Color("2a2a30"))
		ci.draw_rect(Rect2(cx - 76, cy + 6, 152, 6), Color("e88a30"))
		ci.draw_rect(Rect2(cx - 76, cy + 6, 152, 1), Color("f8b060"))
		ci.draw_rect(Rect2(cx - 76, cy + 11, 152, 1), Color("a85a1c"))
		for k in range(-70, 76, 14):
			ci.draw_rect(Rect2(cx + k, cy + 14, 2, 5), Color("6a6e78"))
	else:
		ci.draw_rect(Rect2(cx - 100, cy + 8, 220, 10), Color("5a5e78"))
		ci.draw_rect(Rect2(cx - 100, cy + 8, 220, 2), Color("8a8ea8"))
		ci.draw_rect(Rect2(cx - 100, cy + 18, 214, 4), Color("0e1020"))
	# Two people, eating by headlamp: you and your partner.
	var partner := ClimbProfiles.belayer_look(route)
	var me := ClimbSprites.belayer(PLAYER_LOOK, "sit", 0)
	var they := ClimbSprites.belayer(partner, "sit", int(time * 1.2) % 2)
	ci.draw_texture(me, Vector2(cx - 50, cy - 36))
	ci.draw_texture(they, Vector2(cx + 14, cy - 36))
	# The stove: a little blue flame under a pot.
	var flick := int(time * 12.0) % 3
	ci.draw_rect(Rect2(cx - 8, cy + 2, 14, 4), Color("505868"))
	ci.draw_rect(Rect2(cx - 6, cy - 6, 10, 8), Color("8a8e98"))
	ci.draw_rect(Rect2(cx - 6, cy - 6, 10, 1), Color("c8ccd4"))
	ci.draw_rect(Rect2(cx - 4, cy + 2, 6, 2), Color("5aa8e0"))
	ci.draw_rect(Rect2(cx - 3, cy + 0 - flick, 4, 2 + flick), Color("f0a040"))
	# Steam.
	for i in 4:
		var sy := cy - 10 - fposmod(time * 14.0 + i * 8.0, 26.0)
		ci.draw_rect(Rect2(cx - 3 + sin(time * 2.0 + i) * 2.0, sy, 2, 2), Color(1, 1, 1, 0.5 * (1.0 - (cy - 10 - sy) / 26.0)))
	# The haul bag hangs below.
	if state.has_haul_bag:
		ci.draw_line(Vector2(cx - 60, cy + 20), Vector2(cx - 60, cy + 60), Color("d8452e"), 2.0)
		ci.draw_texture(UI.icon_texture("haul_bag"), Vector2(cx - 66, cy + 60))
	# The card.
	var r := Rect2(300, 24, 170, 100)
	UI.panel(ci, r)
	UI.ink(ci, Vector2(r.position.x + 85, r.position.y + 20), "Night %d on the wall" % info.get("night", 1), UI.INK, 16, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	UI.ink(ci, Vector2(r.position.x + 85, r.position.y + 34), "%s" % ("A portaledge on the wall." if hanging else "A ledge to sleep on."), UI.INK_SOFT, 10, 156.0, HORIZONTAL_ALIGNMENT_CENTER)
	var meal: String = info.get("meal", "a meal")
	var lines := UI.wrap_lines("You and your partner share %s by headlamp. The Valley's campfires glow far below." % meal, 150.0, 10)
	for i in lines.size():
		UI.ink(ci, Vector2(r.position.x + 10, r.position.y + 50 + i * 11), lines[i], UI.INK, 10)
	if age > 0.8:
		UI.ink(ci, Vector2(r.position.x + 85, r.end.y - 8), "E: sleep until dawn", UI.WARN_DARK, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	var fade := clampf(1.0 - age * 2.0, 0.0, 1.0)
	if fade > 0.0:
		ci.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0, 0, 0, fade))
