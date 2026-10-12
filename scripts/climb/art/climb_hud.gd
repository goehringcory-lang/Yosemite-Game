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
	var a := Rect2(6, 43, 60, 18)
	UI.panel(ci, a)
	UI.ink(ci, Vector2(12, 56), "%d ft" % feet, UI.INK, 10)


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
	# an "E" over the bar, as on Stardew's energy bar, and the number under it
	UI.outlined(ci, Vector2(r.position.x + r.size.x / 2.0, r.position.y - 3), "E", UI.GOLD, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	UI.text(ci, Vector2(r.position.x - 3, r.end.y + 12), "%d" % maxi(state.stamina, 0), UI.WARN if state.stamina <= 25 else UI.CREAM, 10)


## The rack as a Stardew-style toolbar. Slots light up when what they do is
## possible right now. Returns the x where the toolbar ends.
static func toolbar(ci: CanvasItem, state: ClimbState, time: float, usable: Dictionary) -> float:
	var slots: Array[Dictionary] = []
	if not state.route.top_rope:
		if state.cams_per_pitch > 0:
			slots.append({"id": "cam", "n": state.cams_left, "on": usable.get("cam", false)})
		if state.quickdraws_per_pitch > 0 and state.route_has_fixed_pieces():
			slots.append({"id": "quickdraw", "n": state.quickdraws_left, "on": usable.get("clip", false)})
	if state.has_chalk:
		slots.append({"id": "chalk_bag", "n": -1, "dim": state.chalked_this_pitch or state.is_snow(), "on": usable.get("chalk", false)})
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
	return origin.x + w - 3.0


## Key hints for what you can do right now, along the bottom.
static func hints(ci: CanvasItem, text: String, x: float) -> void:
	if text == "":
		return
	var w := UI.text_width(text, 10) + 16
	var r := Rect2(x, SCREEN.y - 28, w, 18)
	UI.panel(ci, r)
	UI.ink(ci, Vector2(r.position.x + 8, r.position.y + 13), text, UI.INK, 10)


## What just happened, as a parchment note under the route plate.
static func toast(ci: CanvasItem, text: String, age: float) -> void:
	if text == "":
		return
	var alpha := 1.0 if age < 5.0 else clampf(1.0 - (age - 5.0) / 1.0, 0.0, 1.0)
	if alpha <= 0.0:
		return
	# wrapped to the board inside the frame (174 wide, text 8 in from each side)
	var lines := UI.wrap_lines(text, 158.0, 10)
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

## The skill check at a crux. [param kind] is "timing", "rhythm" or "mash",
## or "pumped" after a miss, when you have to eat before the next try.
static func crux(ci: CanvasItem, kind: String, name: String, data: Dictionary, time: float) -> void:
	var r := Rect2(SCREEN.x * 0.5 - 110, 60, 220, 66)
	UI.panel(ci, r)
	UI.ink(ci, Vector2(r.position.x + 110, r.position.y + 17), ("PUMPED: " if kind == "pumped" else "CRUX: ") + name.to_upper(), UI.WARN_DARK, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	var bar := Rect2(r.position.x + 16, r.position.y + 28, 188, 12)
	match kind:
		"pumped":
			UI.ink(ci, Vector2(r.position.x + 110, r.position.y + 37), "You missed the green. Your arms are done.", UI.INK, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
			UI.ink(ci, Vector2(r.position.x + 110, r.position.y + 54), "E: eat %s (+%d), then try again" % [data.food, data.energy], UI.GOOD_DARK, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
		"timing":
			ci.draw_rect(bar.grow(1), UI.WOOD_DARK)
			ci.draw_rect(bar, Color("5a4a3a"))
			var win: float = data.window
			var center: float = data.center
			# The green is the move; its bright middle is a perfect one.
			var good := Rect2(bar.position.x + bar.size.x * (center - win / 2.0), bar.position.y, bar.size.x * win, bar.size.y)
			ci.draw_rect(good, UI.GOOD_DARK)
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
	var text: String = {"perfect": "PERFECT!", "good": "Good", "slip": "Missed!"}.get(result, "")
	var col: Color = {"perfect": UI.GOLD, "good": UI.CREAM, "slip": UI.WARN}.get(result, UI.CREAM)
	var y := 100.0 - age * 30.0
	ci.modulate.a = clampf(1.4 - age, 0.0, 1.0)
	UI.text(ci, Vector2(SCREEN.x * 0.5, y), text, col, 16, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	ci.modulate.a = 1.0


# ---------------------------------------------------------------- cards

## The card shown before the climb: a postcard of the view, where and who's on
## belay, the pitches, the gear you'll need and carry, and what to eat. The
## text runs the full width under the postcard, the facts and the topo, so
## nothing is cut off however long a route's blurb is.
static func route_card(ci: CanvasItem, state: ClimbState, profile: Dictionary, belayer: Dictionary, recommended_food: int, age: float, view := {}) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.03, 0.03, 0.06, 0.55 * minf(age * 4.0, 1.0)))
	var route := state.route
	var too_late := ClimbState.starts_too_late(route, state.start_minutes)
	# Work out what goes where first, so the card is only as tall as it needs
	# to be. Facts beside the postcard: [text, color].
	var fact_w := 168.0
	var facts: Array = []
	var pitch_text := route.pitch_text()
	if UI.text_width(pitch_text, 10) > fact_w:
		var parts := pitch_text.split(", ", true, 1)
		facts.append([parts[0] + ",", UI.INK])
		facts.append([parts[1], UI.INK])
	else:
		facts.append([pitch_text, UI.INK])
	facts.append(["%s ft" % str(route.total_height_ft()), UI.INK])
	if route.nights > 0:
		facts.append(["%d nights out" % route.nights, UI.INK])
		var meals := state.meals_in_pack()
		facts.append(["Night meals: %d of %d" % [meals, route.nights], UI.GOOD_DARK if meals >= route.nights else UI.WARN_DARK])
	if route.top_rope:
		facts.append(["top rope", UI.INK])
	elif state.is_bolted() or route.protection == "bolts":
		facts.append(["bolted", UI.INK])
	else:
		facts.append(["cams in cracks", UI.INK])
	if belayer.get("name", "") != "":
		facts.append(["belay: " + belayer.name.split(" ")[0], UI.INK])
	if profile.get("weather", "") == "alpine":
		facts.append(["Start before %d AM" % ClimbState.ALPINE_START_BEFORE, UI.WARN_DARK])
		facts.append(["Storms after %s" % ClimbState.storm_time_text(), UI.WARN_DARK])
	if too_late:
		facts.append(["You'd still be on the wall at 2 AM.", UI.WARN_DARK])
		facts.append(["Start in the morning.", UI.WARN_DARK])
	var specs: Array = profile.get("pitches", [])
	var n := route.pitches.size()
	var row_h := minf(11.0, 84.0 / n)
	var text_w := 452.0 - 32.0
	var lines := UI.wrap_lines(route.description, text_w, 10)
	var tip := UI.wrap_lines("Tip: " + route.guide_tip, text_w, 10) if route.guide_tip != "" else PackedStringArray()
	var band_at := 49.0 # from the top of the card
	var bottom := maxf(band_at + 61.0, maxf(band_at + 3 + facts.size() * 11, band_at + 19 + (n - 1) * row_h + 3.0))
	var text_at := bottom + 12.0
	var last_line := text_at + (lines.size() - 1) * 11 + (4 + tip.size() * 11 if not tip.is_empty() else 0)
	var gear_at := last_line + 17.0
	var height := gear_at + 25.0
	var slide := minf(age * 4.0, 1.0)
	var r := Rect2(14, lerpf(280.0, (SCREEN.y - height) * 0.5, 1.0 - pow(1.0 - slide, 3.0)), 452, height)
	UI.panel(ci, r)
	var x := r.position.x + 16
	var y := r.position.y + 22
	UI.ink(ci, Vector2(x, y), route.display_name, UI.INK, 16)
	UI.ink(ci, Vector2(r.end.x - 16, y), route.grade, UI.WARN_DARK, 10, 220.0, HORIZONTAL_ALIGNMENT_RIGHT)
	UI.ink(ci, Vector2(x, y + 14), profile.get("place", ""), UI.INK_SOFT, 10)
	ci.draw_rect(Rect2(x, y + 19, r.size.x - 32, 1), UI.PAPER_DARK)
	# The postcard: the view from the wall, in a wooden frame.
	var band := y + 27.0
	var card := Rect2(x, band, 108, 61)
	ci.draw_rect(card.grow(2), UI.WOOD_DARK)
	ci.draw_rect(card.grow(1), UI.WOOD_LIGHT)
	if view.has("sky"):
		ci.draw_texture_rect_region(view.sky, card, Rect2(0, 0, 480, 270))
		for layer: Dictionary in view.get("layers", []):
			ci.draw_texture_rect_region(layer.tex, card, Rect2(0, layer.pad, 480, 270))
	else:
		ci.draw_rect(card, Color("5aa8e0"))
	ci.draw_rect(Rect2(card.position, Vector2(card.size.x, 1)), Color(1, 1, 1, 0.3))
	var sx := x + 124
	for i in facts.size():
		UI.ink(ci, Vector2(sx, band + 11 + i * 11), facts[i][0], facts[i][1], 10, fact_w + 8)
	# The topo: the pitches, bottom to top.
	var tx := r.position.x + 306
	UI.ink(ci, Vector2(tx, band + 7), "THE LINE", UI.WARN_DARK, 10)
	UI.ink(ci, Vector2(r.end.x - 16, band + 7), "* crux", UI.INK_SOFT, 10, 60.0, HORIZONTAL_ALIGNMENT_RIGHT)
	for i in n:
		var yy := band + 19 + (n - 1 - i) * row_h
		var diff := route.pitches[i]
		ci.draw_rect(Rect2(tx, yy - 6, 6, 6), [Color("7ac24a"), Color("a8c24a"), Color("e8c040"), Color("e8863a"), Color("d8452e")][clampi(diff - 1, 0, 4)])
		var nm: String = specs[i].get("name", "Pitch %d" % (i + 1)) if i < specs.size() else "Pitch %d" % (i + 1)
		# One star for each crux point on the pitch.
		var mark := ""
		var cruxes: int = ClimbProfiles.pitch_spec(route, i).cruxes.size()
		if cruxes > 0:
			mark = " " + "*".repeat(cruxes)
		UI.ink(ci, Vector2(tx + 10, yy), nm + mark, UI.INK, 10, 130.0)
	# The blurb and the tip, across the card.
	var ty := r.position.y + text_at
	for i in lines.size():
		UI.ink(ci, Vector2(x, ty + i * 11), lines[i], UI.INK, 10)
	for i in tip.size():
		UI.ink(ci, Vector2(x, ty + lines.size() * 11 + 4 + i * 11), tip[i], UI.WARN_DARK, 10)
	# Gear you need, with what you have.
	var gy := r.position.y + gear_at
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
	var fy := gy + 17
	UI.icon(ci, "food", Vector2(x, fy - 9))
	var ok := state.food_ready(recommended_food)
	UI.ink(ci, Vector2(x + 16, fy), "Food: %d energy" % carrying + ("" if recommended_food <= 0 else "  (bring about %d)" % recommended_food), UI.GOOD_DARK if ok else UI.WARN_DARK, 10)
	UI.ink(ci, Vector2(r.end.x - 16, fy), "Esc: not yet" if too_late else "E: start climbing     Esc: not yet", UI.INK_SOFT, 10, 240.0, HORIZONTAL_ALIGNMENT_RIGHT)


static func result_card(ci: CanvasItem, state: ClimbState, profile: Dictionary, belayer_line: String, age: float, won: bool) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.03, 0.03, 0.06, 0.6 * minf(age * 3.0, 1.0)))
	var width := 340.0
	var inner := width - 36.0
	# What goes on the card, so the card is only as tall as it needs to be.
	var minutes := state.minutes
	var time_text := "Time: %dh %02dm" % [minutes / 60, minutes % 60]
	if minutes >= 24 * 60:
		time_text = "Time: %dd %dh %02dm" % [minutes / (24 * 60), minutes / 60 % 24, minutes % 60]
	var rows: Array[String] = [time_text, "Falls: %d" % state.falls]
	if won:
		rows.append("Style: %s" % state.style_rating())
		if state.perfect_cruxes + state.slipped_cruxes > 0:
			rows.append("Cruxes: %d perfect, %d missed" % [state.perfect_cruxes, state.slipped_cruxes])
		if state.aid_moves > 0:
			rows.append("Aid moves: %d" % state.aid_moves)
		elif state.route.nights > 0 or state.route.id == "the_nose":
			rows.append("A free ascent! No pulling on gear.")
		if state.jug_moves > 0:
			rows.append("Jugged %d fixed-rope moves" % state.jug_moves)
	var quote := PackedStringArray()
	if belayer_line != "":
		quote = UI.wrap_lines("\"%s\"" % belayer_line, inner, 10)
	var fact_lines := PackedStringArray()
	var facts: Array = profile.get("facts", [])
	if not facts.is_empty() and won:
		fact_lines = UI.wrap_lines(facts[(state.route.id.hash() + state.minutes) % facts.size()], inner, 10)
	var height := 46.0 + rows.size() * 12.0 + 6.0
	if not quote.is_empty():
		height += 6.0 + quote.size() * 11.0
	if not fact_lines.is_empty():
		height += 6.0 + fact_lines.size() * 11.0
	height += 24.0
	var slide := minf(age * 3.0, 1.0)
	var r := Rect2(70, lerpf(280.0, (SCREEN.y - height) * 0.5, 1.0 - pow(1.0 - slide, 3.0)), width, height)
	UI.panel(ci, r)
	var x := r.position.x + 18
	var y := r.position.y + 26
	var title := "Topped out!" if won else "Back on the ground"
	UI.ink(ci, Vector2(r.position.x + r.size.x * 0.5, y), title, UI.GOOD_DARK if won else UI.WARN_DARK, 16, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	UI.ink(ci, Vector2(r.position.x + r.size.x * 0.5, y + 14), "%s  ·  %s" % [state.route.display_name, state.route.grade.split(",")[0]], UI.INK_SOFT, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	ci.draw_rect(Rect2(x, y + 20, r.size.x - 36, 1), UI.PAPER_DARK)
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
	var ly := y + 36 + rows.size() * 12 + 2.0
	for i in quote.size():
		UI.ink(ci, Vector2(x, ly + 6 + i * 11), quote[i], UI.WARN_DARK, 10)
	if not quote.is_empty():
		ly += 6.0 + quote.size() * 11.0
	for i in fact_lines.size():
		UI.ink(ci, Vector2(x, ly + 6 + i * 11), fact_lines[i], UI.INK_SOFT, 10)
	UI.ink(ci, Vector2(r.end.x - 16, r.end.y - 10), "E: continue", UI.INK_SOFT, 10, 120.0, HORIZONTAL_ALIGNMENT_RIGHT)


static func pause_card(ci: CanvasItem, state: ClimbState) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.03, 0.03, 0.06, 0.5))
	var r := Rect2(SCREEN.x * 0.5 - 100, 90, 200, 74)
	UI.panel(ci, r)
	var verb := "Rappel down?" if state.has_device and state.pitch > 0 else "Lower off?"
	UI.ink(ci, Vector2(r.position.x + 100, r.position.y + 22), verb, UI.INK, 16, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	UI.ink(ci, Vector2(r.position.x + 100, r.position.y + 38), "Your gear comes with you. The tick doesn't.", UI.INK_SOFT, 10, 190.0, HORIZONTAL_ALIGNMENT_CENTER)
	UI.ink(ci, Vector2(r.position.x + 100, r.position.y + 62), "E: yes, retreat     Esc: keep climbing", UI.WARN_DARK, 10, 190.0, HORIZONTAL_ALIGNMENT_CENTER)
