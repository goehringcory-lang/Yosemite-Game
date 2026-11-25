class_name ClimbCheckHud
extends RefCounted
## The panels for the climbing screen's longer skill checks (ClimbCheck): the
## King Swing's arc, the piton's hammer and depth, the haul line with the bag
## coming up it, and the layback's tension. They sit where the crux meter
## does and are drawn in the same wood and parchment (ClimbHud, ClimbUi).

const UI := preload("res://scripts/climb/art/climb_ui.gd")
const SCREEN := Vector2(480, 270)
const TRACK := Color("5e4a38")
## The steel of a piton, and the haul bag's canvas.
const STEEL := Color("bdb8ae")
const BAG := Color("b3362b")


## The title on a check's panel.
static func title(kind: String, name: String) -> String:
	match kind:
		"nail":
			return "AID: NAIL A PIN"
		"haul":
			return "HAUL THE BAG"
		"place":
			return "PLACE GEAR"
		"clip":
			return "CLIP THE BOLT"
		"booty":
			return "BOOTY: " + name.to_upper()
	return "CRUX: " + name.to_upper()


## Draws the panel for [param check], the rules of a [param kind] check.
static func draw(ci: CanvasItem, kind: String, name: String, check: ClimbCheck) -> void:
	var r := Rect2(SCREEN.x * 0.5 - 110, 54 if kind in ["swing", "place"] else 60, 220, 84 if kind == "swing" else (100 if kind == "place" else 72))
	UI.panel(ci, r)
	UI.ink(ci, Vector2(r.position.x + 110, r.position.y + 17), title(kind, name), UI.WARN_DARK, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	match kind:
		"swing":
			_swing(ci, r, check as SwingCheck)
		"nail":
			_nail(ci, r, check as NailCheck)
		"haul":
			_haul(ci, r, check as HaulCheck)
		"layback":
			_layback(ci, r, check as LaybackCheck)
		"place":
			_place(ci, r, check as PlaceCheck)
		"clip":
			_clip(ci, r, check as ClipCheck)
		"booty":
			_booty(ci, r, check as BootyCheck)
	_time_bar(ci, r, check)


## The time left: a thin gold line along the bottom of the panel.
static func _time_bar(ci: CanvasItem, r: Rect2, check: ClimbCheck) -> void:
	if check.time_total <= 0.0:
		return
	var frac := clampf(check.time_left / check.time_total, 0.0, 1.0)
	ci.draw_rect(Rect2(r.position.x + 16, r.end.y - 9, 188 * frac, 2), UI.GOLD)


## A framed horizontal track for a bar.
static func _track(ci: CanvasItem, bar: Rect2) -> void:
	ci.draw_rect(bar.grow(1), UI.WOOD_DARK)
	ci.draw_rect(bar, TRACK)


## The marker on a bar: a dark post with a light line down it.
static func _marker(ci: CanvasItem, bar: Rect2, at: float) -> void:
	var mx := bar.position.x + bar.size.x * clampf(at, 0.0, 1.0)
	ci.draw_rect(Rect2(mx - 1, bar.position.y - 3, 3, bar.size.y + 6), UI.WOOD_DARK)
	ci.draw_rect(Rect2(mx, bar.position.y - 2, 1, bar.size.y + 4), UI.CREAM)


## The green from [param from] to [param to] on a bar, with its bright middle
## (a perfect) when [param perfect].
static func _green(ci: CanvasItem, bar: Rect2, from: float, to: float, perfect := true) -> void:
	ci.draw_rect(Rect2(bar.position.x + bar.size.x * from, bar.position.y, bar.size.x * (to - from), bar.size.y), UI.GOOD_DARK)
	if perfect:
		var mid := (from + to) / 2.0
		var w := (to - from) * ClimbCheck.PERFECT_SHARE
		var p := Rect2(bar.position.x + bar.size.x * (mid - w / 2.0), bar.position.y, bar.size.x * w, bar.size.y)
		ci.draw_rect(p, UI.GOOD)
		ci.draw_rect(Rect2(p.position.x, p.position.y, p.size.x, 2), UI.GOOD.lightened(0.4))


## Points along a swing's arc, [param a0] to [param a1] radians out from
## hanging straight down (right is positive).
static func _arc(pivot: Vector2, radius: float, a0: float, a1: float, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, i / float(n))
		pts.append(pivot + radius * Vector2(sin(a), cos(a)))
	return pts


static func _swing(ci: CanvasItem, r: Rect2, s: SwingCheck) -> void:
	var pivot := Vector2(r.position.x + 62, r.position.y + 24)
	var radius := 36.0
	# The whole arc, faint, with the corner at each end.
	ci.draw_polyline(_arc(pivot, radius, -SwingCheck.SLAM, SwingCheck.SLAM, 28), TRACK, 3.0)
	for side in [-1.0, 1.0]:
		var c: Vector2 = pivot + radius * Vector2(sin(side * SwingCheck.SLAM), cos(side * SwingCheck.SLAM))
		ci.draw_rect(Rect2(c - Vector2(2, 4), Vector2(4, 8)), UI.WARN)
	# The crack's green, and its middle.
	ci.draw_polyline(_arc(pivot, radius, s.green_from(), s.green_to(), 6), UI.GOOD_DARK, 5.0)
	var half := s.window / 2.0 * ClimbCheck.PERFECT_SHARE
	ci.draw_polyline(_arc(pivot, radius, SwingCheck.TARGET - half, SwingCheck.TARGET + half, 3), UI.GOOD, 5.0)
	var crack := pivot + (radius + 6) * Vector2(sin(SwingCheck.TARGET), cos(SwingCheck.TARGET))
	ci.draw_line(crack + Vector2(0, -6), crack + Vector2(1, 6), UI.WOOD_DARK, 2.0)
	# How far this swing will carry you, if you stop running now.
	var reach := minf(s.amplitude(), SwingCheck.SLAM)
	var tick := pivot + (radius + 4) * Vector2(sin(reach), cos(reach))
	ci.draw_circle(tick, 1.5, UI.INK_SOFT)
	# You, on the rope.
	var you := pivot + radius * Vector2(sin(s.angle), cos(s.angle))
	ci.draw_line(pivot, you, UI.INK_SOFT, 1.0)
	ci.draw_circle(pivot, 2.0, STEEL)
	ci.draw_circle(you, 4.0, UI.WOOD_DARK)
	ci.draw_circle(you, 3.0, UI.CREAM)
	var x := r.position.x + 158
	UI.ink(ci, Vector2(x, r.position.y + 34), "Run with the swing", UI.INK_SOFT, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	UI.keys(ci, Vector2(x, r.position.y + 50), "[%s]" % UI.button(ci, "Arrows", "Stick"), UI.INK_SOFT, 10, HORIZONTAL_ALIGNMENT_CENTER)
	UI.keys(ci, Vector2(x, r.position.y + 68), "[%s] Grab" % UI.button(ci, "Space", "X"), UI.GOOD_DARK if s.angle >= s.green_from() and s.angle <= s.green_to() else UI.INK_SOFT, 10, HORIZONTAL_ALIGNMENT_CENTER)


static func _nail(ci: CanvasItem, r: Rect2, n: NailCheck) -> void:
	# The hammer's swing: higher is a harder blow.
	UI.ink(ci, Vector2(r.position.x + 14, r.position.y + 32), "Swing", UI.INK_SOFT, 10)
	UI.ink(ci, Vector2(r.position.x + 14, r.position.y + 46), "Pin", UI.INK_SOFT, 10)
	var hammer := Rect2(r.position.x + 50, r.position.y + 25, 154, 6)
	_track(ci, hammer)
	ci.draw_rect(Rect2(hammer.position.x, hammer.position.y, hammer.size.x * n.swing, hammer.size.y), Color(UI.GOLD, 0.6))
	_marker(ci, hammer, n.swing)
	# The pin's depth: the green is seated, past it over-driven.
	var pin := Rect2(r.position.x + 50, r.position.y + 37, 154, 10)
	_track(ci, pin)
	_green(ci, pin, n.seat_from(), n.seat_to())
	ci.draw_rect(Rect2(pin.position.x + pin.size.x * n.seat_to(), pin.position.y, pin.size.x * (1.0 - n.seat_to()), pin.size.y), Color(UI.WARN, 0.55))
	ci.draw_rect(Rect2(pin.position.x, pin.position.y + 3, pin.size.x * n.depth, pin.size.y - 6), STEEL)
	_marker(ci, pin, n.depth)
	var prompt := "[%s] Strike   [%s] Step on it" % [UI.button(ci, "Space", "X"), UI.button(ci, "Up", "Stick up")]
	if n.strikes == 0:
		prompt = "[%s] Strike: high on the swing hits harder" % UI.button(ci, "Space", "X")
	UI.keys(ci, Vector2(r.position.x + 110, r.position.y + 58), prompt, UI.INK_SOFT, 10, HORIZONTAL_ALIGNMENT_CENTER)


static func _haul(ci: CanvasItem, r: Rect2, h: HaulCheck) -> void:
	# The haul line: the anchor at the top, the bag coming up it.
	var x := r.position.x + 24
	var top := r.position.y + 24
	var bottom := r.position.y + 58
	ci.draw_line(Vector2(x, top), Vector2(x, bottom), UI.INK_SOFT, 1.0)
	ci.draw_rect(Rect2(x - 3, top - 2, 6, 3), STEEL)
	for i in h.snags.size():
		var y := lerpf(bottom, top, h.snags[i])
		var col := UI.WARN if i == h.snag else (UI.GOOD if h.freed.has(i) else UI.INK_SOFT)
		ci.draw_line(Vector2(x - 8, y - 2), Vector2(x - 2, y + 1), col, 2.0)
	var by := lerpf(bottom, top, h.height)
	var bag := Rect2(x - 4, by, 8, 10)
	ci.draw_rect(bag.grow(1), UI.WOOD_DARK)
	ci.draw_rect(bag, BAG)
	ci.draw_rect(Rect2(bag.position.x, bag.position.y + 3, bag.size.x, 1), UI.WOOD_DARK)
	# The stroke, and the strength wasted.
	var stroke := Rect2(r.position.x + 44, r.position.y + 27, 160, 10)
	_track(ci, stroke)
	ci.draw_rect(Rect2(stroke.position.x, stroke.position.y, stroke.size.x * h.stroke, stroke.size.y), UI.GOOD if h.snag < 0 else UI.WARN)
	var strain := Rect2(r.position.x + 44, r.position.y + 41, 160, 3)
	_track(ci, strain)
	ci.draw_rect(Rect2(strain.position.x, strain.position.y, strain.size.x * clampf(h.strain / HaulCheck.GOOD_STRAIN, 0.0, 1.0), strain.size.y), UI.WARN)
	var prompt := "Hold [%s] to haul, let go to reset" % UI.button(ci, "Space", "X")
	if h.snag >= 0:
		var arrow := "<" if h.next_side() == "left" else ">"
		prompt = "Snagged! %s Wiggle Left, Right %s" % [arrow, arrow]
		if Settings.hold_taps:
			prompt = "Snagged! Hold Left or Right"
	elif h.stroke >= 1.0:
		prompt = "Let go, then pull again"
	UI.keys(ci, Vector2(r.position.x + 124, r.position.y + 58), prompt, UI.INK_SOFT, 10, HORIZONTAL_ALIGNMENT_CENTER)


static func _layback(ci: CanvasItem, r: Rect2, l: LaybackCheck) -> void:
	# The tension in your arms, and the green where a step holds.
	var bar := Rect2(r.position.x + 16, r.position.y + 26, 188, 10)
	_track(ci, bar)
	_green(ci, bar, l.band_from(), l.band_to(), false)
	ci.draw_rect(Rect2(bar.position.x + bar.size.x * l.band_to(), bar.position.y, bar.size.x * (1.0 - l.band_to()), bar.size.y), Color(UI.WARN, 0.4))
	ci.draw_rect(Rect2(bar.position.x, bar.position.y + 3, bar.size.x * l.tension, bar.size.y - 6), Color(UI.GOLD, 0.85))
	_marker(ci, bar, l.tension)
	# The strain of over-gripping, and the steps up the flake.
	var strain := Rect2(r.position.x + 16, r.position.y + 40, 120, 3)
	_track(ci, strain)
	ci.draw_rect(Rect2(strain.position.x, strain.position.y, strain.size.x * clampf(l.strain, 0.0, 1.0), strain.size.y), UI.WARN)
	for i in LaybackCheck.NEED:
		var pip := Rect2(r.position.x + 146 + i * 10, r.position.y + 39, 8, 5)
		ci.draw_rect(pip.grow(1), UI.WOOD_DARK)
		ci.draw_rect(pip, UI.GOOD if i < l.steps else TRACK)
	var prompt := "Hold [%s] to pull   [%s] Step in the green" % [UI.button(ci, "Space", "X"), UI.button(ci, "Up", "Stick up")]
	if Settings.hold_taps:
		prompt = "Hold [%s] to pull, hold [%s] to step" % [UI.button(ci, "Space", "X"), UI.button(ci, "Up", "Stick up")]
	UI.keys(ci, Vector2(r.position.x + 110, r.position.y + 58), prompt, UI.INK_SOFT, 10, HORIZONTAL_ALIGNMENT_CENTER)


## Placing a piece (PlaceCheck): your rack along the top, the crack's width,
## and the trigger bar with its green for the piece you've picked.
static func _place(ci: CanvasItem, r: Rect2, c: PlaceCheck) -> void:
	var crack := "%s crack (%s fits)" % [ClimbRack.width_name(c.width).capitalize(), ClimbRack.width_size(c.width)]
	ClimbGearArt.crack_tick(ci, Vector2(r.position.x + 18, r.position.y + 27), c.width)
	UI.ink(ci, Vector2(r.position.x + 26, r.position.y + 31), crack, UI.INK_SOFT, 10)
	# The rack: every piece you can pick, the cursor on the one in hand.
	var n := c.pieces.size()
	var step := minf(18.0, 196.0 / maxf(n, 1))
	var x0 := r.position.x + 110 - step * (n - 1) / 2.0
	for i in n:
		var at := Vector2(roundf(x0 + i * step), r.position.y + 46)
		if i == c.cursor:
			ci.draw_rect(Rect2(at + Vector2(-7, -10), Vector2(15, 20)), UI.GOLD)
			ci.draw_rect(Rect2(at + Vector2(-6, -9), Vector2(13, 18)), UI.WOOD_DARK)
		ClimbGearArt.icon(ci, at, c.pieces[i], not c.can_use(i))
		var left := int(c.pieces[i].get("left", 0))
		if c.pieces[i].get("kind", "") != "sling" and left > 1:
			UI.outlined(ci, at + Vector2(9, 9), str(left), UI.CREAM, 8)
	# What you're holding, and how it fits.
	var piece := c.selected()
	var fit := "fits"
	var fit_color := UI.GOOD_DARK
	match ClimbRack.misfit_side(piece, c.width):
		1:
			fit = "a size big: don't over-cam it"
			fit_color = UI.WARN
		-1:
			fit = "a size small: it may tip out"
			fit_color = UI.WARN
	if piece.get("kind", "") == "sling":
		fit = "always holds a short fall, no more"
		fit_color = UI.WARN
	UI.ink(ci, Vector2(r.position.x + 110, r.position.y + 68), "%s: %s" % [piece.get("name", "Cam"), fit], fit_color, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	# The trigger bar.
	var bar := Rect2(r.position.x + 16, r.position.y + 72, 188, 5)
	if piece.get("kind", "") != "sling":
		_track(ci, bar)
		var g := c.green()
		_green(ci, bar, clampf(g.x - g.y / 2.0, 0.0, 1.0), clampf(g.x + g.y / 2.0, 0.0, 1.0), ClimbRack.misfit(piece, c.width) == 0)
		if not c.is_nut():
			var over := clampf(g.x + g.y / 2.0, 0.0, 1.0)
			ci.draw_rect(Rect2(bar.position.x + bar.size.x * over, bar.position.y, bar.size.x * (1.0 - over), bar.size.y), Color(UI.WARN, 0.45))
		ci.draw_rect(Rect2(bar.position.x, bar.position.y + 1, bar.size.x * c.pull, bar.size.y - 2), STEEL)
		_marker(ci, bar, c.pull)
	var prompt := "[%s] Pick   Hold [%s], let go in the green   [%s] Back" % [UI.button(ci, "Left/Right", "Stick"), UI.button(ci, "Space", "X"), UI.button(ci, "Esc", "B")]
	if c.phase == "seat":
		prompt = "Let go in the green" if not c.is_nut() else "Let go to seat it"
	elif piece.get("kind", "") == "sling":
		prompt = "[%s] Pick   [%s] Sling it" % [UI.button(ci, "Left/Right", "Stick"), UI.button(ci, "Space", "X")]
	UI.keys(ci, Vector2(r.position.x + 110, r.position.y + 88), prompt, UI.INK_SOFT, 10, HORIZONTAL_ALIGNMENT_CENTER)


## Clipping from a bad hold (ClipCheck): the bight of rope coming up to the
## draw's gate.
static func _clip(ci: CanvasItem, r: Rect2, c: ClipCheck) -> void:
	var bar := Rect2(r.position.x + 16, r.position.y + 32, 188, 10)
	_track(ci, bar)
	_green(ci, bar, ClipCheck.CENTER - c.window / 2.0, ClipCheck.CENTER + c.window / 2.0)
	# The rope's bight, and the draw at the gate.
	var mx := bar.position.x + bar.size.x * c.pos
	ci.draw_rect(Rect2(mx - 2, bar.position.y + 2, 4, bar.size.y - 4), Color("b3362b"))
	ci.draw_rect(Rect2(mx - 1, bar.position.y + 3, 2, 1), Color("d9772a"))
	var gate := bar.position.x + bar.size.x * ClipCheck.CENTER
	ci.draw_rect(Rect2(gate - 1, bar.position.y - 7, 3, 6), STEEL)
	UI.keys(ci, Vector2(r.position.x + 110, r.position.y + 58), "[%s] Clip as the rope reaches the gate" % UI.button(ci, "Space", "X"), UI.INK_SOFT, 10, HORIZONTAL_ALIGNMENT_CENTER)


## Working booty loose (BootyCheck): the nut tool rocking, the green where a
## knock tells, and the knocks so far.
static func _booty(ci: CanvasItem, r: Rect2, c: BootyCheck) -> void:
	var bar := Rect2(r.position.x + 16, r.position.y + 28, 150, 10)
	_track(ci, bar)
	_green(ci, bar, c.center - c.window / 2.0, c.center + c.window / 2.0, false)
	ci.draw_rect(Rect2(bar.position.x + bar.size.x * c.pos - 1, bar.position.y - 2, 3, bar.size.y + 4), STEEL)
	for i in BootyCheck.NEED:
		var pip := Rect2(r.position.x + 174 + i * 10, r.position.y + 30, 8, 6)
		ci.draw_rect(pip.grow(1), UI.WOOD_DARK)
		ci.draw_rect(pip, UI.GOOD if i < c.knocks else TRACK)
	UI.keys(ci, Vector2(r.position.x + 110, r.position.y + 58), "[%s] Knock it loose in the green" % UI.button(ci, "Space", "X"), UI.INK_SOFT, 10, HORIZONTAL_ALIGNMENT_CENTER)
