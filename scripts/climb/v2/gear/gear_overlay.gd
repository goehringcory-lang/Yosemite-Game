class_name TradGearOverlay
extends Control
## The trad-gear view on the v2 climbing screen (thread 6): while the place
## phase is open, a close look into the crack (granite walls drawn at the
## crack's true width, the gear in it, never a hand) and your harness along
## the bottom. Nothing here grades a piece: no bar, number or colour code.
## You read the lobes and the nut the way you would on the rock.
## It only reads the session and the place phase; it never changes them.

const PANEL := Rect2(704, 64, 240, 300)
## Inside the panel: pixels per mm across, pixels per metre up the crack.
const PX_MM := 1.25
const PX_M := 300.0
const STRIP_H := 44.0

const ROCK := Color("8f897c")
const ROCK_DARK := Color("6b665c")
const ROCK_LIGHT := Color("b4ad9d")
const GAP := Color("17161b")
const METAL := Color("d9dbe0")
const METAL_DARK := Color("8d929c")
const INK := Color("f2e6c8")
const PANEL_BG := Color(0.07, 0.08, 0.1, 0.88)

var gear: TradGear
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = get_viewport_rect().size if get_viewport() else Vector2(960, 540)


func _process(delta: float) -> void:
	_t += delta
	var open := _phase() != null
	visible = open
	if open:
		queue_redraw()


func _phase() -> TradGear.PlacePhase:
	if gear == null or gear.session == null or gear.session.phase != &"place":
		return null
	return gear.place_phase


func _draw() -> void:
	var ph := _phase()
	if ph == null or ph.director == null:
		return
	var s := gear.session
	var font := ThemeDB.fallback_font
	var shake := Vector2.ZERO
	if gear.next_try_feel(ph.at) == "last":
		shake = Vector2(sin(_t * 41.0), cos(_t * 37.0)) * 1.6
	var panel := Rect2(PANEL.position + shake, PANEL.size)
	draw_rect(panel.grow(3), Color(0, 0, 0, 0.35))
	draw_rect(panel, PANEL_BG)
	var crack := s.wall.crack(ph.crack_id)
	var e := ph.current()
	var view := Rect2(panel.position + Vector2(8, 8), Vector2(panel.size.x - 16, 200))
	var centre := ph.at
	if crack:
		_draw_crack(view, crack, centre)
	match str(e.get("type", "")):
		"item":
			_draw_item(view, ph, crack, centre)
		"pin":
			_draw_pin(view, s.piece(str(e.id)))
		"booty":
			pass
	if not ph.reading.is_empty() and ph.reading.get("murky", false):
		draw_rect(view, Color(0.02, 0.02, 0.04, 0.42))
	# What you see, in words.
	var title := _entry_title(e)
	draw_string(font, panel.position + Vector2(10, 226), title, HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 20, 14, INK)
	var note := str(ph.reading.get("note", "")) if not ph.reading.is_empty() else _before_offer_line(e)
	draw_multiline_string(font, panel.position + Vector2(10, 246), note, HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 20, 12, 4, INK.darkened(0.12))
	_draw_strip(ph, font)


func _entry_title(e: Dictionary) -> String:
	match str(e.get("type", "")):
		"pin":
			return "An old fixed pin"
		"booty":
			for b in gear.booty_in_reach():
				if b.id == e.id:
					return "Stuck: " + str(b.name)
			return "A stuck piece"
		"item":
			var it := gear.session.rack.item(str(e.id))
			return str(it.get("name", e.id))
	return ""


func _before_offer_line(e: Dictionary) -> String:
	match str(e.get("type", "")):
		"pin":
			return "Somebody hammered it in years ago. A tug tells you more."
		"booty":
			return "Somebody left this behind. Worth a try to work it free."
		"item":
			return "Held up beside the crack. Offer it to see how it sits."
	return ""


# --------------------------------------------------------------- the crack

func _px_y(view: Rect2, y: float, centre: Vector2) -> float:
	return view.position.y + view.size.y * 0.5 - (y - centre.y) * PX_M


func _draw_crack(view: Rect2, crack: V2Crack, centre: Vector2) -> void:
	var cx := view.position.x + view.size.x * 0.5
	var top := view.position.y
	var bottom := view.end.y
	var left := PackedVector2Array([Vector2(view.position.x, top)])
	var right := PackedVector2Array([Vector2(view.end.x, top)])
	var steps := 24
	var edges := []
	for i in steps + 1:
		var py := lerpf(top, bottom, float(i) / steps)
		var wy := centre.y + (view.position.y + view.size.y * 0.5 - py) / PX_M
		var near := crack.nearest(Vector2(centre.x, wy))
		var half := TradGear.mm(float(near.width)) * PX_MM * 0.5
		# A crack only runs where it runs: past its ends the rock closes.
		var on := wy >= crack.points[0].y - 0.02 and wy <= crack.points[crack.points.size() - 1].y + 0.02
		if not on:
			half = 0.0
		left.append(Vector2(cx - half, py))
		right.append(Vector2(cx + half, py))
		edges.append([py, half])
	left.append(Vector2(view.position.x, bottom))
	right.append(Vector2(view.end.x, bottom))
	draw_rect(view, GAP)
	draw_colored_polygon(left, ROCK)
	var rr := right.duplicate()
	rr.reverse()
	draw_colored_polygon(rr, ROCK)
	# Speckled granite (fixed pattern, so it doesn't crawl).
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(crack.id)
	for i in 90:
		var p := Vector2(rng.randf_range(view.position.x, view.end.x), rng.randf_range(top, bottom))
		var half := _half_at(edges, p.y)
		if absf(p.x - cx) > half + 2.0:
			draw_rect(Rect2(p, Vector2(2, 2)), ROCK_DARK if i % 3 else ROCK_LIGHT)
	# Flare: the walls bevel away, lit on their lips.
	var bevel := 3.0 + 16.0 * crack.flare
	for k in edges.size() - 1:
		var a: Array = edges[k]
		var b: Array = edges[k + 1]
		if float(a[1]) <= 0.0 or float(b[1]) <= 0.0:
			continue
		var col := ROCK_LIGHT if crack.flare > 0.2 else ROCK_DARK
		draw_colored_polygon(PackedVector2Array([Vector2(cx - float(a[1]) - bevel, a[0]), Vector2(cx - float(a[1]), a[0]),
			Vector2(cx - float(b[1]), b[0]), Vector2(cx - float(b[1]) - bevel, b[0])]), col)
		draw_colored_polygon(PackedVector2Array([Vector2(cx + float(a[1]), a[0]), Vector2(cx + float(a[1]) + bevel, a[0]),
			Vector2(cx + float(b[1]) + bevel, b[0]), Vector2(cx + float(b[1]), b[0])]), col.darkened(0.2))
	# What a mentor taught you to spot: where the crack pinches.
	if gear.session.mods.knows("constrictions"):
		for i in crack.constrictions:
			if i < crack.points.size():
				var py := _px_y(view, crack.points[i].y, centre)
				if py > top and py < bottom:
					var half := TradGear.mm(float(crack.widths[i])) * PX_MM * 0.5
					var glint := 0.5 + 0.5 * sin(_t * 3.0 + i)
					draw_line(Vector2(cx - half - 4, py), Vector2(cx - half + 1, py), Color(1, 1, 0.9, 0.4 + 0.5 * glint), 2.0)
					draw_line(Vector2(cx + half - 1, py), Vector2(cx + half + 4, py), Color(1, 1, 0.9, 0.4 + 0.5 * glint), 2.0)
	for b in gear.booty_in_reach():
		if b.crack == crack.id:
			var bp := V2Data.vec(b.pos)
			var py := _px_y(view, bp.y, centre)
			if py > top + 10 and py < bottom - 10:
				var half := TradGear.mm(crack.width_near(bp)) * PX_MM * 0.5
				_draw_cam(Vector2(cx, py), half, 0.12, Color("6d6a5f"), 0.75)


func _half_at(edges: Array, y: float) -> float:
	for k in edges.size() - 1:
		if y >= float(edges[k][0]) and y <= float(edges[k + 1][0]):
			return lerpf(float(edges[k][1]), float(edges[k + 1][1]), (y - float(edges[k][0])) / maxf(0.01, float(edges[k + 1][0]) - float(edges[k][0])))
	return 0.0


# ----------------------------------------------------------------- the gear

func _draw_item(view: Rect2, ph: TradGear.PlacePhase, crack: V2Crack, centre: Vector2) -> void:
	var it := gear.session.rack.item(str(ph.current().id))
	if it.is_empty() or crack == null:
		return
	var cx := view.position.x + view.size.x * 0.5
	var cy := view.position.y + view.size.y * 0.5
	var sling: Color = it.get("color", Color(0.6, 0.6, 0.6)) if it.get("color") is Color else Color.html(str(it.get("color", "#999999")))
	var r := ph.reading
	var offered: bool = not r.is_empty() and r.get("item", "") == it.id
	var crack_half := TradGear.mm(crack.width_near(centre)) * PX_MM * 0.5
	if str(it.kind) == "cam":
		var size := float(it.width_min)
		if not offered:
			# Held up beside the crack at its middle size: eyeball it.
			var mid := TradGear.cam_range(size)
			var mid_half := (mid.x + mid.y) * 0.25 * PX_MM
			var hx := minf(cx + crack_half + mid_half + 14.0, view.end.x - mid_half - 4.0)
			_draw_cam(Vector2(hx, cy), mid_half, 0.5, sling, 0.8)
			return
		var e := float(r.get("e", 0.5))
		var wobble := 0.0
		if r.get("walks", false):
			wobble = sin(ph.since * 13.0) * 3.0 * maxf(0.0, 1.0 - ph.since / 1.6)
		match str(r.get("state", "")):
			"tight":
				var shut := TradGear.cam_range(size).x * PX_MM * 0.5
				_draw_cam(Vector2(cx, view.position.y + 26), shut, 0.0, sling, 0.9)
			"out":
				var tilt := minf(1.0, ph.since * 1.5)
				_draw_cam(Vector2(cx - crack_half * 0.4 * tilt, cy + 40.0 * tilt), TradGear.cam_range(size).y * PX_MM * 0.5, 1.0, sling, 0.9)
			_:
				_draw_cam(Vector2(cx + wobble, cy), crack_half, clampf(e, 0.0, 1.0), sling, 1.0)
	else:
		var lo := TradGear.mm(float(it.width_min))
		var hi := TradGear.mm(float(it.width_max))
		var nut_w := (lo + hi) * 0.5 * PX_MM
		if not offered:
			_draw_nut(Vector2(minf(cx + crack_half + nut_w * 0.5 + 14.0, view.end.x - nut_w * 0.5 - 4.0), cy), nut_w, sling, 0.8, str(it.kind) == "offset")
			return
		var from_y := cy
		var stop := V2Data.vec(r.get("stop", [centre.x, centre.y]))
		var to_y := _px_y(view, stop.y, centre)
		var state := str(r.get("state", ""))
		if state == "tight":
			to_y = view.position.y + 20
		elif state == "through" or state == "flare":
			to_y = view.end.y + 30
		var f := clampf(ph.since / 0.55, 0.0, 1.0)
		f = f * f
		var y := lerpf(from_y, to_y, f)
		var w := minf(nut_w, crack_half * 2.0 + (4.0 if state in ["seated", "shallow"] else 0.0))
		if state == "tight":
			w = nut_w
		if y < view.end.y + 20:
			_draw_nut(Vector2(cx, y), w, sling, 1.0, str(it.kind) == "offset")


## A cam head at [param at] with its lobes touching walls [param half] px
## out from the stem, opened [param e] (0 shut, 1 on its tips).
func _draw_cam(at: Vector2, half: float, e: float, sling: Color, alpha: float) -> void:
	var metal := Color(METAL, alpha)
	var dark := Color(METAL_DARK, alpha)
	# Shut lobes point up the crack; open ones splay out flat on their tips.
	# Each lobe is a log-spiral cam: the wall touches it where its radius
	# reaches the crack, so you read the angle the way you would on the rock.
	var rise := lerpf(30.0, 0.0, e)
	for side: float in [-1.0, 1.0]:
		var contact := at + Vector2(side * maxf(half, 4.0), -rise)
		for layer in 2:
			var shift := Vector2(-side * 2.0, 2.0) * (1 - layer)
			var col := dark.darkened(0.25) if layer == 0 else metal
			var to := contact - at
			var big := to.length()
			var aim := to.angle()
			var lobe := PackedVector2Array([at + shift])
			for k in 9:
				var f := k / 8.0
				var ang := aim + side * lerpf(1.25, 0.0, f)
				lobe.append(at + shift + Vector2.from_angle(ang) * lerpf(big * 0.42, big, f))
			lobe.append(at + shift + Vector2.from_angle(aim - side * 0.18) * big * 0.92)
			draw_colored_polygon(lobe, col)
			if layer == 1:
				draw_polyline(lobe + PackedVector2Array([lobe[0]]), dark, 1.0)
		# Teeth where it bites the rock.
		draw_circle(contact, 1.6, Color(1, 1, 1, alpha))
	draw_circle(at, 3.0, dark)
	# Stem and trigger: the trigger rides low when the lobes are pulled shut.
	var stem_end := at + Vector2(0, 62)
	draw_line(at, stem_end, metal, 3.0)
	var trig := at + Vector2(0, lerpf(34.0, 12.0, e))
	draw_line(trig + Vector2(-9, 0), trig + Vector2(9, 0), metal, 3.0)
	draw_arc(stem_end + Vector2(0, 9), 9.0, 0.0, TAU, 18, Color(sling, alpha), 3.0)


func _draw_nut(at: Vector2, w: float, sling: Color, alpha: float, offset := false) -> void:
	var top_w := w
	var bot_w := w * 0.7
	var h := clampf(w * 0.9, 10.0, 28.0)
	var skew := w * 0.12 if offset else 0.0
	var poly := PackedVector2Array([at + Vector2(-top_w * 0.5, -h * 0.5), at + Vector2(top_w * 0.5 + skew, -h * 0.5),
		at + Vector2(bot_w * 0.5, h * 0.5), at + Vector2(-bot_w * 0.5 + skew, h * 0.5)])
	draw_colored_polygon(poly, Color(sling.lerp(METAL, 0.35), alpha))
	draw_polyline(poly + PackedVector2Array([poly[0]]), Color(METAL_DARK, alpha), 1.0)
	draw_line(at + Vector2(-2, h * 0.5), at + Vector2(-2, h * 0.5 + 34), Color(METAL, alpha), 1.5)
	draw_line(at + Vector2(2, h * 0.5), at + Vector2(2, h * 0.5 + 34), Color(METAL, alpha), 1.5)


func _draw_pin(view: Rect2, p: V2Piece) -> void:
	var c := view.get_center()
	draw_rect(view, ROCK)
	draw_line(c + Vector2(-60, 0), c + Vector2(10, 0), Color("2a2622"), 4.0)
	var rust := Color("8a4a2a") if p and p.tags.has("rusty") else METAL_DARK
	draw_rect(Rect2(c + Vector2(10, -10), Vector2(16, 20)), rust)
	draw_arc(c + Vector2(30, 0), 7.0, 0.0, TAU, 14, rust, 3.0)
	if p and p.tags.has("rusty"):
		for i in 5:
			draw_line(c + Vector2(12 + i * 3, 10), c + Vector2(10 + i * 3, 40 + i * 7), Color(0.55, 0.3, 0.18, 0.35), 2.0)


# -------------------------------------------------------------- the harness

func _draw_strip(ph: TradGear.PlacePhase, font: Font) -> void:
	var box := Vector2(62, STRIP_H)
	var total := ph.entries.size() * (box.x + 4)
	var x0 := maxf(12.0, (size.x - total) * 0.5)
	var y := size.y - 40 - STRIP_H - 12
	draw_rect(Rect2(x0 - 8, y - 8, total + 12, STRIP_H + 16), PANEL_BG)
	for i in ph.entries.size():
		var e: Dictionary = ph.entries[i]
		var r := Rect2(Vector2(x0 + i * (box.x + 4), y), box)
		var chosen := i == ph.index
		draw_rect(r, Color(1, 1, 1, 0.14 if chosen else 0.05))
		var label := ""
		var swatch := Color(0.5, 0.5, 0.5)
		var count := 0
		match str(e.type):
			"item":
				var it := gear.session.rack.item(str(e.id))
				swatch = it.get("color", swatch) if it.get("color") is Color else Color.html(str(it.get("color", "#888888")))
				label = gear.size_label(str(e.id))
				count = int(it.get("count", 0))
			"pin":
				label = "old pin"
				swatch = Color("8a4a2a")
			"booty":
				label = "stuck"
				swatch = Color("6d6a5f")
		draw_rect(Rect2(r.position + Vector2(4, 4), Vector2(box.x - 8, 6)), swatch)
		draw_string(font, r.position + Vector2(4, 28), label, HORIZONTAL_ALIGNMENT_CENTER, box.x - 8, 13, INK)
		if count > 1:
			draw_string(font, r.position + Vector2(4, 41), "x%d" % count, HORIZONTAL_ALIGNMENT_RIGHT, box.x - 8, 10, INK.darkened(0.3))
		if chosen:
			draw_rect(r.grow(1), INK, false, 2.0)
