class_name ClimbTopo
extends RefCounted
## The line up a pitch, as the climbing screen shows it.
##
## Two things, both from the pitch's guaranteed line ([member ClimbState.line]):
## - The topo sketch: a guidebook topo drawn on the wall in chalky ink, a
##   wobbly dashed line from where you are to the anchor, an X and a name at
##   each crux point, and the anchor's ring. It draws itself up the wall as a
##   pitch starts, then fades; hold Down to read the pitch again.
## - Chalk: the white smudges climbers leave on the holds of a popular line,
##   on the next few holds ahead of you and fading with distance, so you can
##   pick out the line without it being spelled out. Classic routes are well
##   chalked, high-country ones hardly at all, and no one chalks snow.
##
## [param at] turns (row, column) into a screen point, so the same code
## draws a face, a chimney and a roof.

const UI := preload("res://scripts/climb/art/climb_ui.gd")

const INK := Color(0.961, 0.933, 0.878)
const INK_SHADOW := Color(0.082, 0.078, 0.11, 0.75)
const CRUX_INK := Color("f0b44a")
## How many holds ahead the chalk shows.
const CHALK_AHEAD := 4
## Dash and gap along the line, in menu pixels.
const DASH := 4.0
const GAP := 3.0


## How well chalked this route's holds are, 0..1: a profile can say
## ("chalk"); otherwise boulders are caked, Valley routes well used, the high
## country and long alpine routes hardly touched, and snow never.
static func chalkiness(state: ClimbState, profile: Dictionary) -> float:
	if profile.has("chalk"):
		return float(profile.chalk)
	if state.is_snow():
		return 0.0
	if state.route.boulder:
		return 1.0
	if profile.get("weather", "") == "alpine":
		return 0.35
	return 0.8


## The line's points from row [param from_row] to the anchor, one for each
## row, as screen positions. The first is where you are now.
static func points(state: ClimbState, at: Callable, from_row: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if state.line.is_empty():
		return pts
	var first := clampi(from_row, 0, state.top_row)
	for r in range(first, state.top_row + 1):
		var c: int
		if state.line.has(r):
			c = int(state.line[r])
		elif r >= state.top_row:
			c = int(state.line.get(state.top_row - 1, ClimbState.COLUMNS / 2))
		else:
			c = int(state.line.get(1, ClimbState.COLUMNS / 2))
		if r == from_row and r > 0:
			c = state.col
		pts.append(at.call(float(r), float(c)))
	return pts


## The topo sketch. [param reveal] 0..1 is how much of it has been drawn
## (it draws upwards); [param alpha] fades all of it.
static func draw_line(ci: CanvasItem, state: ClimbState, at: Callable, alpha: float, reveal := 1.0) -> void:
	if alpha <= 0.01 or state.line.is_empty():
		return
	var pts := points(state, at, state.row)
	if pts.size() < 2:
		return
	# Total length, to draw only the revealed part.
	var lengths: Array[float] = [0.0]
	for i in range(1, pts.size()):
		lengths.append(lengths[i - 1] + pts[i - 1].distance_to(pts[i]))
	var total: float = lengths[-1]
	var shown := total * clampf(reveal, 0.0, 1.0)
	var ink := Color(INK, 0.9 * alpha)
	var shadow := Color(INK_SHADOW, INK_SHADOW.a * alpha)
	var walked := 0.0
	var on := true
	var left := DASH
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var seg := a.distance_to(b)
		if seg <= 0.0:
			continue
		var side := Vector2(-(b - a).y, (b - a).x) / seg
		var t := 0.0
		while t < seg and walked < shown:
			var step := minf(minf(left, seg - t), shown - walked)
			if on:
				var p0 := a.lerp(b, t / seg)
				var p1 := a.lerp(b, (t + step) / seg)
				# A hand-drawn wobble, the same every frame.
				p0 += side * sin(p0.y * 0.31 + p0.x * 0.07) * 1.2
				p1 += side * sin(p1.y * 0.31 + p1.x * 0.07) * 1.2
				ci.draw_line((p0 + Vector2(0.5, 0.5)).round(), (p1 + Vector2(0.5, 0.5)).round(), shadow, 1.5)
				ci.draw_line(p0.round(), p1.round(), ink, 1.0)
			t += step
			walked += step
			left -= step
			if left <= 0.001:
				on = not on
				left = DASH if on else GAP
	# Crux points: an X and the name the topo gives it.
	for r: int in state.crux_rows():
		if r <= state.row or r >= state.top_row:
			continue
		var i := r - state.row
		if i >= lengths.size() or lengths[i] > shown:
			continue
		var c := _crux_column(state, r)
		var p: Vector2 = at.call(float(r), float(c))
		_cross(ci, p + Vector2(-11, 0), Color(CRUX_INK, alpha), shadow)
		var name: String = ClimbProfiles.crux_at(state.spec, r).get("name", "crux")
		UI.outlined(ci, p + Vector2(-17, 3), name, CRUX_INK, 10, -1.0, HORIZONTAL_ALIGNMENT_RIGHT, alpha)
	# The anchor: a ring and its two bolts, as a topo marks a belay.
	if shown >= total - 0.5:
		var top := pts[-1] + Vector2(0, 2)
		ci.draw_arc(top + Vector2(0.5, 0.5), 4.0, 0.0, TAU, 14, shadow, 1.5)
		ci.draw_arc(top, 4.0, 0.0, TAU, 14, ink, 1.0)
		ci.draw_rect(Rect2(top + Vector2(-2, -1), Vector2(1, 1)), ink)
		ci.draw_rect(Rect2(top + Vector2(1, -1), Vector2(1, 1)), ink)
		var label := "summit" if state.pitch == state.route.pitches.size() - 1 else "belay"
		UI.outlined(ci, top + Vector2(7, 3), label, INK, 10, -1.0, HORIZONTAL_ALIGNMENT_LEFT, alpha)


## The chalk on the holds ahead: a few smudges on each, fainter the further
## up they are. A crux hold is left bare (everyone's hand slips off it).
static func draw_chalk(ci: CanvasItem, state: ClimbState, at: Callable, amount: float) -> void:
	if amount <= 0.0:
		return
	var rows: Array = []
	if state.route.boulder:
		# A boulder problem is caked on every hold that's used.
		for r in range(state.row + 1, mini(state.row + CHALK_AHEAD + 2, state.top_row)):
			for c: int in state.holds.get(r, {}):
				rows.append(Vector2i(c, r))
	else:
		for r in range(state.row + 1, mini(state.row + CHALK_AHEAD + 1, state.top_row)):
			if state.line.has(r):
				rows.append(Vector2i(int(state.line[r]), r))
	for cell: Vector2i in rows:
		var hold := state.hold_at(cell.y, cell.x)
		if hold.is_empty() or hold.get("crux", false):
			continue
		var fade := 1.0 - float(cell.y - state.row - 1) / float(CHALK_AHEAD)
		var a := clampf(amount * (0.35 + 0.5 * fade), 0.0, 0.85)
		var p: Vector2 = at.call(float(cell.y), float(cell.x))
		# A soft smear where palms have been, and specks of chalk round it.
		var top := (p + Vector2(-4, -3)).round()
		ci.draw_rect(Rect2(top, Vector2(8, 2)), Color(1, 1, 1, a * 0.45))
		ci.draw_rect(Rect2(top + Vector2(1, 2), Vector2(6, 1)), Color(1, 1, 1, a * 0.3))
		var n := 2 + int(round(amount * 4.0))
		for i in n:
			var h := hash(Vector3i(cell.x, cell.y, i + state.pitch * 31))
			var off := Vector2(float(h % 11) - 5.0, float((h >> 4) % 5) - 4.0)
			ci.draw_rect(Rect2(p + off, Vector2(1, 1)), Color(1, 1, 1, a * (0.7 + 0.3 * float((h >> 10) % 2))))


static func _crux_column(state: ClimbState, r: int) -> int:
	var row: Dictionary = state.holds.get(r, {})
	for c: int in row:
		if row[c].get("crux", false):
			return c
	return int(state.line.get(r, state.col))


static func _cross(ci: CanvasItem, p: Vector2, ink: Color, shadow: Color) -> void:
	p = p.round()
	for k in [Vector2(1, 1), Vector2(1, -1)]:
		ci.draw_line(p - k * 3.0 + Vector2(0.5, 0.5), p + k * 3.0 + Vector2(0.5, 0.5), shadow, 2.0)
		ci.draw_line(p - k * 3.0, p + k * 3.0, ink, 1.0)
