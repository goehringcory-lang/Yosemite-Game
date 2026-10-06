class_name ClimbHud
extends RefCounted
## The climbing screen's interface, in warm wood and parchment like a farming
## game's menus: the route plate, altimeter, rack toolbar, stamina bar, route
## topo, toasts, pitch banners, the crux meter, and the route and result cards.
## Every function draws onto the CanvasItem it's given.

const UI := preload("res://scripts/climb/art/climb_ui.gd")
const SCREEN := Vector2(480, 270)


# ---------------------------------------------------------------- always on

static func route_plate(ci: CanvasItem, state: ClimbState, feet: int) -> void:
	var r := Rect2(6, 6, 156, 34)
	UI.panel(ci, r)
	UI.ink(ci, Vector2(14, 20), state.route.display_name, UI.INK, 10, 142)
	var sub := "%s  ·  %s" % [state.pitch_name(), Guidebook.yds_label(state.route.grade) if Guidebook.yds(state.route.grade) > 0.0 else state.route.grade.split(",")[0]]
	UI.ink(ci, Vector2(14, 32), sub, UI.INK_SOFT, 10, 142)
	# Altimeter under it.
	var a := Rect2(6, 44, 60, 14)
	UI.glass(ci, a)
	UI.text(ci, Vector2(11, 55), "%d ft" % feet, UI.CREAM, 10)


static func topo_bar(ci: CanvasItem, state: ClimbState, progress: float) -> void:
	var bar := Rect2(SCREEN.x - 10, 28, 4, 138)
	UI.glass(ci, Rect2(bar.position + Vector2(-3, -6), bar.size + Vector2(6, 12)), 0.5)
	ci.draw_rect(bar, Color(0.12, 0.1, 0.14, 0.9))
	var n := state.route.pitches.size()
	for i in n + 1:
		var y := bar.end.y - bar.size.y * float(i) / n
		ci.draw_rect(Rect2(bar.position.x - 3, y, 10, 1), Color(UI.CREAM, 0.7 if i <= state.pitch else 0.3))
	var fill := bar.size.y * progress
	ci.draw_rect(Rect2(bar.position.x, bar.end.y - fill, bar.size.x, fill), UI.GOLD)
	ci.draw_rect(Rect2(bar.position.x - 3, bar.end.y - fill - 2, 10, 4), UI.WARN)
	ci.draw_rect(Rect2(bar.position.x - 2, bar.end.y - fill - 1, 8, 2), Color("ffb090"))


static func stamina(ci: CanvasItem, state: ClimbState, flash: float, shake: float) -> void:
	var frac := clampf(state.stamina / float(ClimbState.MAX_STAMINA), 0.0, 1.0)
	var r := Rect2(SCREEN.x - 26 + roundf(shake), SCREEN.y - 96, 12, 80)
	UI.energy_bar(ci, r, frac, state.stamina <= 25, flash)
	UI.text(ci, Vector2(r.position.x - 3, r.end.y + 12), "%d" % maxi(state.stamina, 0), UI.WARN if state.stamina <= 25 else UI.CREAM, 10)


## The rack as a Stardew-style toolbar. Slots light up when what they do is
## possible right now.
static func toolbar(ci: CanvasItem, state: ClimbState, time: float, usable: Dictionary) -> void:
	var slots: Array[Dictionary] = []
	if not state.route.top_rope:
		if state.cams_per_pitch > 0:
			slots.append({"id": "cam", "n": state.cams_left, "on": usable.get("cam", false)})
		if state.quickdraws_per_pitch > 0:
			slots.append({"id": "quickdraw", "n": state.quickdraws_left, "on": usable.get("clip", false)})
	if state.has_chalk:
		slots.append({"id": "chalk_bag", "n": -1, "dim": state.chalked_this_pitch, "on": usable.get("chalk", false)})
	slots.append({"id": "food", "n": FoodDB.carried_energy(), "on": usable.get("eat", false)})
	if state.has_device:
		slots.append({"id": "belay_device", "n": -1})
	if state.has_aiders:
		slots.append({"id": "aiders", "n": -1, "on": usable.get("aid", false)})
	if state.has_ascenders:
		slots.append({"id": "ascenders", "n": -1, "on": usable.get("jug", false)})
	if state.has_axe:
		slots.append({"id": "ice_axe", "n": -1})
	if state.has_crampons:
		slots.append({"id": "crampons", "n": -1})
	var w := slots.size() * 22 + 6
	var origin := Vector2(8, SCREEN.y - 30)
	UI.panel(ci, Rect2(origin - Vector2(3, 3), Vector2(w + 2, 27)))
	for i in slots.size():
		var s := slots[i]
		var pos := origin + Vector2(i * 22 + 1, 0)
		UI.slot(ci, pos, s.id, s.n, s.get("dim", false), s.get("on", false) and fmod(time, 0.8) < 0.5)


## Key hints for what you can do right now, along the bottom.
static func hints(ci: CanvasItem, text: String, x: float) -> void:
	if text == "":
		return
	var w := UI.text_width(text, 10) + 10
	var r := Rect2(x, SCREEN.y - 24, w, 14)
	UI.glass(ci, r, 0.62)
	UI.text(ci, Vector2(r.position.x + 5, r.position.y + 10), text, UI.CREAM, 10)


## What just happened, as a parchment note under the route plate.
static func toast(ci: CanvasItem, text: String, age: float) -> void:
	if text == "":
		return
	var alpha := 1.0 if age < 5.0 else clampf(1.0 - (age - 5.0) / 1.0, 0.0, 1.0)
	if alpha <= 0.0:
		return
	var lines := UI.wrap_lines(text, 170.0, 10)
	var r := Rect2(SCREEN.x - 190, 8, 174, 12 + lines.size() * 11)
	ci.modulate.a = alpha
	UI.panel(ci, r)
	for i in lines.size():
		UI.ink(ci, r.position + Vector2(8, 17 + i * 11), lines[i], UI.INK, 10)
	ci.modulate.a = 1.0


## A line of banter from the belayer, in a speech bubble above them.
static func speech(ci: CanvasItem, at: Vector2, text: String, name: String, age: float) -> void:
	if text == "" or age > 4.0 or age < 0.0:
		return
	var alpha := clampf(minf(age * 4.0, (4.0 - age) * 2.0), 0.0, 1.0)
	var lines := UI.wrap_lines(text, 118.0, 10)
	var h := 14 + lines.size() * 11
	var w := 0.0
	for line in lines:
		w = maxf(w, UI.text_width(line, 10))
	w += 14
	var r := Rect2(clampf(at.x - 10, 4, SCREEN.x - w - 4), clampf(at.y - h - 24, 4, SCREEN.y - h - 40), w, h)
	ci.modulate.a = alpha
	UI.panel(ci, r, UI.PAPER, true)
	if name != "":
		UI.ink(ci, r.position + Vector2(6, 11), name, UI.WARN_DARK, 10)
	for i in lines.size():
		UI.ink(ci, r.position + Vector2(6, 11 + (i + (1 if name != "" else 0)) * 11), lines[i], UI.INK, 10)
	# The tail of the bubble.
	var tail := PackedVector2Array([Vector2(r.position.x + 12, r.end.y), Vector2(r.position.x + 22, r.end.y), Vector2(at.x, at.y - 8)])
	ci.draw_colored_polygon(tail, UI.PAPER)
	ci.draw_polyline(PackedVector2Array([tail[0], tail[2], tail[1]]), UI.WOOD_DARK, 1.0)
	ci.modulate.a = 1.0


## Pitch title banner, sliding down from the top.
static func pitch_banner(ci: CanvasItem, state: ClimbState, age: float) -> void:
	if age > 3.6:
		return
	var slide := minf(age * 5.0, 1.0)
	var out := clampf((3.6 - age) * 4.0, 0.0, 1.0)
	var beta: String = state.spec.get("beta", "")
	var lines := UI.wrap_lines(beta, 226.0, 10)
	var h := 30 + lines.size() * 11
	var x := lerpf(-260.0, 6.0, 1.0 - pow(1.0 - slide, 3.0)) - (1.0 - out) * 260.0
	var r := Rect2(x, 64, 250, h)
	UI.panel(ci, r)
	var title := "Pitch %d of %d · %s" % [state.pitch + 1, state.route.pitches.size(), state.pitch_name()]
	UI.ink(ci, Vector2(r.position.x + 125, r.position.y + 17), title, UI.INK, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	ci.draw_rect(Rect2(r.position.x + 14, r.position.y + 21, 222, 1), UI.PAPER_DARK)
	for i in lines.size():
		UI.ink(ci, Vector2(r.position.x + 125, r.position.y + 33 + i * 11), lines[i], UI.INK_SOFT, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)


# ---------------------------------------------------------------- crux meter

## The skill check at a crux. [param kind] is "timing", "rhythm" or "mash".
static func crux(ci: CanvasItem, kind: String, name: String, data: Dictionary, time: float) -> void:
	var r := Rect2(SCREEN.x * 0.5 - 110, 60, 220, 66)
	UI.panel(ci, r)
	UI.ink(ci, Vector2(r.position.x + 110, r.position.y + 17), "CRUX: " + name.to_upper(), UI.WARN_DARK, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	var bar := Rect2(r.position.x + 16, r.position.y + 28, 188, 12)
	match kind:
		"timing":
			ci.draw_rect(bar.grow(1), UI.WOOD_DARK)
			ci.draw_rect(bar, Color("5a4a3a"))
			var win: float = data.window
			var center: float = data.center
			var good := Rect2(bar.position.x + bar.size.x * (center - win / 2.0), bar.position.y, bar.size.x * win, bar.size.y)
			ci.draw_rect(good, Color("c8a040"))
			var perfect_w := win * 0.38
			var perf := Rect2(bar.position.x + bar.size.x * (center - perfect_w / 2.0), bar.position.y, bar.size.x * perfect_w, bar.size.y)
			ci.draw_rect(perf, UI.GOOD)
			ci.draw_rect(Rect2(perf.position.x, perf.position.y, perf.size.x, 2), UI.GOOD.lightened(0.4))
			var mx: float = bar.position.x + bar.size.x * float(data.pos)
			ci.draw_rect(Rect2(mx - 1, bar.position.y - 4, 3, bar.size.y + 8), UI.WOOD_DARK)
			ci.draw_rect(Rect2(mx, bar.position.y - 3, 1, bar.size.y + 6), UI.CREAM)
			UI.ink(ci, Vector2(r.position.x + 110, r.position.y + 58), "Space: stop in the green", UI.INK_SOFT, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
		"rhythm", "mash":
			var need: int = data.need
			var done: int = data.done
			var left_next: bool = data.get("left_next", true)
			for i in need:
				var x := bar.position.x + 2 + i * (bar.size.x - 4) / need
				var filled := i < done
				var cell := Rect2(x, bar.position.y, (bar.size.x - 4) / need - 2, bar.size.y)
				ci.draw_rect(cell.grow(1), UI.WOOD_DARK)
				ci.draw_rect(cell, UI.GOOD if filled else Color("5a4a3a"))
			var tleft: float = data.time_left
			ci.draw_rect(Rect2(bar.position.x, bar.end.y + 4, bar.size.x * clampf(tleft / float(data.time_total), 0.0, 1.0), 2), UI.GOLD)
			var prompt := "Tap Up quickly!" if kind == "mash" else ("Left!" if left_next else "Right!")
			if kind == "rhythm":
				var arrow := "<" if left_next else ">"
				UI.ink(ci, Vector2(r.position.x + 110, r.position.y + 58), "%s %s %s  (alternate Left and Right)" % [arrow, prompt, arrow], UI.INK_SOFT, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
			else:
				UI.ink(ci, Vector2(r.position.x + 110, r.position.y + 58), prompt, UI.INK_SOFT, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)


static func crux_result(ci: CanvasItem, result: String, age: float) -> void:
	if age > 1.4:
		return
	var text: String = {"perfect": "PERFECT!", "good": "Good", "slip": "Slip!"}.get(result, "")
	var col: Color = {"perfect": UI.GOLD, "good": UI.CREAM, "slip": UI.WARN}.get(result, UI.CREAM)
	var y := 100.0 - age * 30.0
	ci.modulate.a = clampf(1.4 - age, 0.0, 1.0)
	UI.text(ci, Vector2(SCREEN.x * 0.5, y), text, col, 16, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	ci.modulate.a = 1.0


# ---------------------------------------------------------------- cards

## The card shown before the climb: a postcard of the view, where and who's on
## belay, the pitches, the gear you'll need and carry, and what to eat.
static func route_card(ci: CanvasItem, state: ClimbState, profile: Dictionary, belayer: Dictionary, recommended_food: int, age: float, view := {}) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.03, 0.03, 0.06, 0.55 * minf(age * 4.0, 1.0)))
	var slide := minf(age * 4.0, 1.0)
	var r := Rect2(30, lerpf(280.0, 14.0, 1.0 - pow(1.0 - slide, 3.0)), 420, 242)
	UI.panel(ci, r)
	var route := state.route
	var x := r.position.x + 16
	var y := r.position.y + 22
	UI.ink(ci, Vector2(x, y), route.display_name, UI.INK, 16)
	UI.ink(ci, Vector2(r.end.x - 16, y), route.grade, UI.WARN_DARK, 10, 220.0, HORIZONTAL_ALIGNMENT_RIGHT)
	UI.ink(ci, Vector2(x, y + 14), profile.get("place", ""), UI.INK_SOFT, 10)
	ci.draw_rect(Rect2(x, y + 19, r.size.x - 32, 1), UI.PAPER_DARK)
	# The postcard: the view from the wall, in a wooden frame.
	var card := Rect2(x, y + 27, 108, 61)
	ci.draw_rect(card.grow(2), UI.WOOD_DARK)
	ci.draw_rect(card.grow(1), UI.WOOD_LIGHT)
	if view.has("sky"):
		ci.draw_texture_rect_region(view.sky, card, Rect2(0, 0, 480, 270))
		for layer: Dictionary in view.get("layers", []):
			ci.draw_texture_rect_region(layer.tex, card, Rect2(0, layer.pad, 480, 270))
	else:
		ci.draw_rect(card, Color("5aa8e0"))
	ci.draw_rect(Rect2(card.position, Vector2(card.size.x, 1)), Color(1, 1, 1, 0.3))
	# Facts beside it.
	var sx := x + 122
	var rows: Array[String] = ["%d pitch%s" % [route.pitches.size(), "" if route.pitches.size() == 1 else "es"], "%s ft" % str(route.total_height_ft())]
	if route.nights > 0:
		rows.append("%d nights out" % route.nights)
	if route.top_rope:
		rows.append("top rope")
	elif state.is_bolted() or route.protection == "bolts":
		rows.append("bolted")
	else:
		rows.append("cams in cracks")
	if belayer.get("name", "") != "":
		rows.append("belay: " + belayer.name.split(" ")[0])
	for i in rows.size():
		UI.ink(ci, Vector2(sx, y + 38 + i * 12), rows[i], UI.INK, 10, 100.0)
	# The blurb.
	var lines := UI.wrap_lines(route.description, 236.0, 10)
	for i in mini(lines.size(), 3):
		UI.ink(ci, Vector2(x, y + 102 + i * 11), lines[i] + ("..." if i == 2 and lines.size() > 3 else ""), UI.INK, 10)
	if route.guide_tip != "":
		var tip := UI.wrap_lines("Tip: " + route.guide_tip, 236.0, 10)
		for i in mini(tip.size(), 2):
			UI.ink(ci, Vector2(x, y + 102 + mini(lines.size(), 3) * 11 + 4 + i * 11), tip[i] + ("..." if i == 1 and tip.size() > 2 else ""), UI.WARN_DARK, 10)
	# The topo: the pitches, bottom to top.
	var tx := r.position.x + 280
	var ty := r.position.y + 44
	UI.ink(ci, Vector2(tx, ty - 4), "THE LINE", UI.WARN_DARK, 10)
	var specs: Array = profile.get("pitches", [])
	var n := route.pitches.size()
	var row_h := minf(12.0, 100.0 / n)
	for i in n:
		var yy := ty + 8 + (n - 1 - i) * row_h
		var diff := route.pitches[i]
		ci.draw_rect(Rect2(tx, yy - 6, 6, 6), [Color("7ac24a"), Color("a8c24a"), Color("e8c040"), Color("e8863a"), Color("d8452e")][clampi(diff - 1, 0, 4)])
		var nm: String = specs[i].get("name", "Pitch %d" % (i + 1)) if i < specs.size() else "Pitch %d" % (i + 1)
		var mark := ""
		if i < specs.size() and specs[i].get("crux", 0) > 0:
			mark = " *"
		UI.ink(ci, Vector2(tx + 10, yy), nm + mark, UI.INK, 10, 130.0)
	UI.ink(ci, Vector2(tx, ty + 14 + n * row_h), "* a crux: a skill check", UI.INK_SOFT, 10)
	if route.nights > 0:
		UI.ink(ci, Vector2(tx, ty + 26 + n * row_h), "%d nights on the wall" % route.nights, UI.WARN_DARK, 10)
	if profile.get("weather", "") == "alpine":
		UI.ink(ci, Vector2(tx, ty + 26 + n * row_h + (12 if route.nights > 0 else 0)), "Storms build after 2 pm.", UI.WARN_DARK, 10)
	# Gear you need, with what you have.
	var gy := r.position.y + 196
	UI.ink(ci, Vector2(x, gy), "GEAR", UI.WARN_DARK, 10)
	var gx := x + 34
	for id: String in route.required_gear:
		var need := int(route.required_gear[id])
		var have := Gear.count(id)
		UI.slot(ci, Vector2(gx, gy - 11), id, need, have < need)
		gx += 22
	if route.top_rope:
		UI.ink(ci, Vector2(gx, gy), "A top rope: nothing to carry.", UI.INK_SOFT, 10)
	var carrying := FoodDB.carried_energy()
	var fy := gy + 23
	UI.icon(ci, "food", Vector2(x, fy - 9))
	var ok := carrying >= recommended_food
	UI.ink(ci, Vector2(x + 16, fy), "Food: %d energy" % carrying + ("" if recommended_food <= 0 else "  (bring about %d)" % recommended_food), UI.GOOD_DARK if ok else UI.WARN_DARK, 10)
	UI.ink(ci, Vector2(r.end.x - 16, r.end.y - 10), "E: start climbing     Esc: not yet", UI.INK_SOFT, 10, 240.0, HORIZONTAL_ALIGNMENT_RIGHT)


static func result_card(ci: CanvasItem, state: ClimbState, profile: Dictionary, belayer_line: String, age: float, won: bool) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.03, 0.03, 0.06, 0.45 * minf(age * 3.0, 1.0)))
	var slide := minf(age * 3.0, 1.0)
	var r := Rect2(70, lerpf(280.0, 36.0, 1.0 - pow(1.0 - slide, 3.0)), 340, 198)
	UI.panel(ci, r)
	var x := r.position.x + 18
	var y := r.position.y + 26
	var title := "Topped out!" if won else "Back on the ground"
	UI.ink(ci, Vector2(r.position.x + r.size.x * 0.5, y), title, UI.GOOD_DARK if won else UI.WARN_DARK, 16, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	UI.ink(ci, Vector2(r.position.x + r.size.x * 0.5, y + 14), "%s  ·  %s" % [state.route.display_name, state.route.grade.split(",")[0]], UI.INK_SOFT, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	ci.draw_rect(Rect2(x, y + 20, r.size.x - 36, 1), UI.PAPER_DARK)
	var hours := state.minutes / 60
	var rows: Array[String] = ["Time: %dh %02dm" % [hours, state.minutes % 60], "Falls: %d" % state.falls]
	if won:
		rows.append("Style: %s" % state.style_rating())
		if state.perfect_cruxes + state.slipped_cruxes > 0:
			rows.append("Cruxes: %d perfect, %d slipped" % [state.perfect_cruxes, state.slipped_cruxes])
		if state.aid_moves > 0:
			rows.append("Aid moves: %d" % state.aid_moves)
		elif state.route.nights > 0 or state.route.id == "the_nose":
			rows.append("A free ascent! No pulling on gear.")
		if state.jug_moves > 0:
			rows.append("Jugged %d fixed-rope moves" % state.jug_moves)
	for i in rows.size():
		UI.ink(ci, Vector2(x, y + 36 + i * 12), rows[i], UI.INK, 10)
	# Stars: a rating for the style.
	if won:
		var stars := 3
		if state.aid_moves > 0:
			stars = 1
		elif state.falls > 1:
			stars = 2
		for i in 3:
			UI.icon(ci, "star", Vector2(r.end.x - 70 + i * 16, y + 28), Color.WHITE if i < stars else Color(1, 1, 1, 0.22))
	var facts: Array = profile.get("facts", [])
	if not facts.is_empty() and won:
		var fact: String = facts[(state.route.id.hash() + state.minutes) % facts.size()]
		var fl := UI.wrap_lines(fact, r.size.x - 40.0, 10)
		for i in mini(fl.size(), 3):
			UI.ink(ci, Vector2(x, r.end.y - 54 + i * 11), fl[i], UI.INK_SOFT, 10)
	if belayer_line != "":
		UI.ink(ci, Vector2(x, r.end.y - 78), "\"%s\"" % belayer_line, UI.WARN_DARK, 10, r.size.x - 36.0)
	UI.ink(ci, Vector2(r.end.x - 16, r.end.y - 10), "E: continue", UI.INK_SOFT, 10, 120.0, HORIZONTAL_ALIGNMENT_RIGHT)


static func pause_card(ci: CanvasItem, state: ClimbState) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.03, 0.03, 0.06, 0.5))
	var r := Rect2(SCREEN.x * 0.5 - 100, 90, 200, 74)
	UI.panel(ci, r)
	var verb := "Rappel down?" if state.has_device and state.pitch > 0 else "Lower off?"
	UI.ink(ci, Vector2(r.position.x + 100, r.position.y + 22), verb, UI.INK, 16, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	UI.ink(ci, Vector2(r.position.x + 100, r.position.y + 38), "Your gear comes with you. The tick doesn't.", UI.INK_SOFT, 10, 190.0, HORIZONTAL_ALIGNMENT_CENTER)
	UI.ink(ci, Vector2(r.position.x + 100, r.position.y + 62), "Esc: yes, retreat     E: keep climbing", UI.WARN_DARK, 10, 190.0, HORIZONTAL_ALIGNMENT_CENTER)
