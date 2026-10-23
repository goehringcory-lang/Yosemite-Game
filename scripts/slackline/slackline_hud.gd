class_name SlacklineHud
extends RefCounted
## The slackline screen's overlays, drawn on the climbing screen's wood and
## parchment panels (ClimbUi): the balance meter, the line plate with your
## progress, the score and flow, the trick prompt, the pop-up callouts, the
## card where you pick a line, and the results card with its medal.

const UI := preload("res://scripts/climb/art/climb_ui.gd")
const SCREEN := Vector2(480, 270)
const RED := Color("b3362b")
const OUTLINE := Color("15141c")
## Bronze, silver and gold: face, rim (shade) and shine.
const MEDALS := [
	[Color("b0703a"), Color("7e4a22"), Color("e0a070")],
	[Color("c8ccd4"), Color("8a8e9a"), Color("f5f5f8")],
	[Color("f1cf6a"), Color("ad7a22"), Color("fff4c0")],
]
const MEDAL_NAMES := ["", "Bronze", "Silver", "Gold"]


# ---------------------------------------------------------------- walking

## The balance meter, top center: green in the middle, orange where you stop
## to steady yourself, red at the edges. [param ghost] is where the needle
## was a moment ago (it trails behind). Chevrons flash on the side a buck or
## gust is coming from.
static func meter(ci: CanvasItem, state: SlacklineState, ghost: float, time: float, shake: float) -> void:
	var r := Rect2(140, 6, 200, 30)
	r.position += Vector2(sin(time * 61.0), cos(time * 47.0)) * shake
	UI.panel(ci, r)
	var bar := Rect2(r.position.x + 12, r.position.y + 10, r.size.x - 24, 9)
	ci.draw_rect(bar.grow(1), OUTLINE)
	ci.draw_rect(bar, RED)
	var warn_w := bar.size.x * (1.0 - 0.1)
	ci.draw_rect(Rect2(bar.get_center().x - warn_w / 2.0, bar.position.y, warn_w, bar.size.y), UI.WARN)
	var safe := bar.size.x * SlacklineState.STEADY_LEAN
	ci.draw_rect(Rect2(bar.get_center().x - safe / 2.0, bar.position.y, safe, bar.size.y), UI.GOOD)
	var calm := bar.size.x * SlacklineState.CENTER
	ci.draw_rect(Rect2(bar.get_center().x - calm / 2.0, bar.position.y, calm, bar.size.y), UI.GOOD.lightened(0.22))
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x, 2)), Color(1, 1, 1, 0.18))
	ci.draw_rect(Rect2(bar.get_center().x, bar.position.y - 1, 1, bar.size.y + 2), Color(0.082, 0.078, 0.11, 0.35))
	# the needle and its ghost
	var gx := bar.position.x + bar.size.x * (ghost + 1.0) / 2.0
	ci.draw_rect(Rect2(gx - 1, bar.position.y, 2, bar.size.y), Color(0.961, 0.933, 0.878, 0.35))
	var nx := bar.position.x + bar.size.x * (state.lean + 1.0) / 2.0
	ci.draw_rect(Rect2(nx - 2, bar.position.y - 4, 5, bar.size.y + 8), OUTLINE)
	ci.draw_rect(Rect2(nx - 1, bar.position.y - 3, 3, bar.size.y + 6), UI.CREAM)
	ci.draw_rect(Rect2(nx - 1, bar.position.y - 3, 3, 1), Color.WHITE)
	# the trick clock fills a strip under the bar
	if not state.trick.is_empty():
		var f := clampf(state.trick_age / float(state.trick.time), 0.0, 1.0)
		ci.draw_rect(Rect2(bar.position.x, bar.end.y + 3, bar.size.x, 2), UI.PAPER_DARK)
		ci.draw_rect(Rect2(bar.position.x, bar.end.y + 3, bar.size.x * f, 2), UI.GOLD)
	var w := state.warning()
	if not w.is_empty():
		var side: int = w.side
		var gust: bool = w.kind == "gust"
		var blink: bool = fmod(time, 0.16) < 0.1 or float(w.t) >= 1.0
		var col := Color("9fd8d9") if gust else UI.WARN
		if blink:
			# arrows under the meter's end, pointing the way you're about to
			# be shoved (lean the other way to meet it)
			var x := r.end.x - 26.0 if side > 0 else r.position.x + 26.0
			for k in 3:
				_chevron(ci, Vector2(x + side * (k * 6.0 + float(w.t) * 4.0) - side * 6.0, r.end.y + 9), side, col)
		if gust:
			UI.outlined(ci, Vector2(r.get_center().x, r.end.y + 14), "Gust!", Color("d6f1ee"), 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	elif absf(state.lean) >= SlacklineState.STEADY_LEAN and fmod(time, 0.5) < 0.3:
		UI.outlined(ci, Vector2(r.get_center().x, r.end.y + 14), "Steady...", UI.WARN, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)


## A pixel chevron pointing [param dir] (1 right, -1 left), centered on [param at].
static func _chevron(ci: CanvasItem, at: Vector2, dir: int, col: Color) -> void:
	for i in 5:
		var dx := (2 - absi(i - 2)) * dir
		ci.draw_rect(Rect2(at.x + dx - 1, at.y - 5 + i * 2, 3, 2), OUTLINE)
	for i in 5:
		var dx := (2 - absi(i - 2)) * dir
		ci.draw_rect(Rect2(at.x + dx, at.y - 5 + i * 2, 2, 2), col)


## The line's plate, top left: its name and a strip showing how far along
## you are, with a tick at each quarter.
static func plate(ci: CanvasItem, line: Dictionary, state: SlacklineState) -> void:
	var r := Rect2(6, 6, 124, 30)
	UI.panel(ci, r)
	UI.ink(ci, r.position + Vector2(8, 14), line.name, UI.INK, 10)
	var track := Rect2(r.position.x + 8, r.position.y + 19, r.size.x - 16, 4)
	ci.draw_rect(track.grow(1), OUTLINE)
	ci.draw_rect(track, UI.PAPER_DARK)
	ci.draw_rect(Rect2(track.position, Vector2(track.size.x * state.progress, track.size.y)), UI.GOLD)
	for q in range(1, 4):
		ci.draw_rect(Rect2(track.position.x + track.size.x * q / 4.0, track.position.y - 1, 1, track.size.y + 2), UI.CREAM if state.progress * 4.0 >= q else UI.INK_SOFT)
	var mx := track.position.x + track.size.x * state.progress
	ci.draw_rect(Rect2(mx - 2, track.position.y - 2, 4, track.size.y + 4), OUTLINE)
	ci.draw_rect(Rect2(mx - 1, track.position.y - 1, 2, track.size.y + 2), UI.CREAM)
	UI.ink(ci, Vector2(r.end.x - 8, r.position.y + 14), "%d%%" % state.percent(), UI.INK_SOFT, 10, -1.0, HORIZONTAL_ALIGNMENT_RIGHT)


## The score, top right, counting up to the real one, and the flow
## multiplier with a strip filling toward the next step.
static func score_box(ci: CanvasItem, state: SlacklineState, shown: int, pulse: float) -> void:
	var r := Rect2(SCREEN.x - 130, 6, 124, 30)
	UI.panel(ci, r)
	UI.ink(ci, r.position + Vector2(8, 13), "Score", UI.INK_SOFT, 10)
	UI.ink(ci, r.position + Vector2(8, 25), "%d" % shown, UI.CREAM.lerp(UI.GOLD, pulse), 12)
	var f := state.flow()
	var badge := Rect2(r.end.x - 40, r.position.y + 5, 32, 20)
	var col: Color = [UI.INK_SOFT, UI.GOOD, UI.GOLD][f - 1]
	var grow := pulse * 2.0
	ci.draw_rect(badge.grow(1 + grow), OUTLINE)
	ci.draw_rect(badge.grow(grow), UI.PAPER_DARK)
	UI.ink(ci, Vector2(badge.get_center().x, badge.position.y + 12), "x%d" % f, col, 12, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	# toward the next step of flow
	var steps: Array = SlacklineState.FLOW_STEPS
	var frac := 1.0
	if f <= steps.size():
		var lo: float = 0.0 if f == 1 else steps[f - 2]
		frac = clampf((state.steady_time - lo) / (float(steps[f - 1]) - lo), 0.0, 1.0)
	ci.draw_rect(Rect2(badge.position.x + 2, badge.end.y - 3, (badge.size.x - 4) * frac, 1), col)


## The trick you can do next, bottom center: lit when you're steady enough
## to start it, dim when you're not.
static func trick_prompt(ci: CanvasItem, state: SlacklineState, key: String, time: float) -> void:
	var t := state.next_trick_info()
	var ready := state.can_trick()
	var doing := not state.trick.is_empty()
	var label := "%s  Trick: %s" % [key, t.name]
	if doing:
		label = state.trick.name + "..."
	var w := UI.text_width(label, 10) + 18
	var r := Rect2((SCREEN.x - w) / 2.0, SCREEN.y - 26, w, 18)
	ci.modulate.a = 1.0 if ready or doing else 0.55
	UI.panel(ci, r)
	var col := UI.GOLD if doing else (UI.INK if ready else UI.INK_SOFT)
	if ready and fmod(time, 1.0) < 0.12:
		col = UI.CREAM
	UI.ink(ci, Vector2(r.position.x + 9, r.position.y + 13), label, col, 10)
	ci.modulate.a = 1.0


## A key hint along the bottom (the first walk shows how to lean).
static func hint(ci: CanvasItem, text: String, y: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var w := UI.text_width(text, 10) + 16
	var r := Rect2((SCREEN.x - w) / 2.0, y, w, 18)
	ci.modulate.a = alpha
	UI.panel(ci, r)
	UI.ink(ci, Vector2(r.position.x + 8, r.position.y + 13), text, UI.INK, 10)
	ci.modulate.a = 1.0


## Callouts that pop up and float away: {"text", "color", "age", "at", "big"}.
static func popups(ci: CanvasItem, list: Array[Dictionary]) -> void:
	for p: Dictionary in list:
		var age: float = p.age
		var life := 1.4 if p.big else 1.1
		if age > life:
			continue
		var a := clampf((life - age) * 4.0, 0.0, 1.0)
		var rise := age * 14.0
		var pop := 1.0 + maxf(0.0, 0.25 - age) * 2.0
		var size := 16 if p.big else 10
		var at: Vector2 = p.at - Vector2(0, rise)
		ci.modulate.a = a
		if pop > 1.01:
			ci.draw_set_transform(at, 0.0, Vector2(pop, pop))
			UI.outlined(ci, Vector2.ZERO, p.text, p.color, size, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			UI.outlined(ci, at.round(), p.text, p.color, size, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
		ci.modulate.a = 1.0


## "Ready..." then "Walk!" as you step off the tree.
static func countdown(ci: CanvasItem, age: float, total: float) -> void:
	var walk := age >= total - 0.45
	var text := "Walk!" if walk else "Ready..."
	var local := age - (total - 0.45) if walk else age
	var pop := 1.0 + maxf(0.0, 0.2 - local) * 2.5
	ci.draw_set_transform(Vector2(SCREEN.x / 2.0, 96), 0.0, Vector2(pop, pop))
	UI.outlined(ci, Vector2.ZERO, text, UI.GOLD if walk else UI.CREAM, 16, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- medals

## A medal on its ribbon, centered at [param at]. [param tier] 1 bronze, 2
## silver, 3 gold; 0 draws an empty socket for one not won yet.
static func medal(ci: CanvasItem, at: Vector2, tier: int, big := false, shine := 0.0) -> void:
	var r := 7.0 if big else 4.0
	at = at.round()
	if tier <= 0:
		ci.draw_circle(at, r + 1, OUTLINE)
		ci.draw_circle(at, r, UI.PAPER_DARK)
		ci.draw_circle(at, r - 1.5, UI.PAPER_DARK.lightened(0.08))
		return
	var cols: Array = MEDALS[tier - 1]
	# the ribbon, a V of red and cream
	if big:
		ci.draw_rect(Rect2(at.x - 6, at.y - 18, 5, 12), OUTLINE)
		ci.draw_rect(Rect2(at.x + 1, at.y - 18, 5, 12), OUTLINE)
		ci.draw_rect(Rect2(at.x - 5, at.y - 17, 3, 11), RED)
		ci.draw_rect(Rect2(at.x + 2, at.y - 17, 3, 11), UI.CREAM)
	ci.draw_circle(at, r + 1, OUTLINE)
	ci.draw_circle(at, r, cols[1])
	ci.draw_circle(at - Vector2(0.5, 0.5), r - 1, cols[0])
	ci.draw_rect(Rect2(at.x - r * 0.5, at.y - r * 0.6, maxf(r * 0.4, 1), maxf(r * 0.3, 1)), cols[2])
	if big:
		# a star stamped in the middle
		ci.draw_rect(Rect2(at.x - 1, at.y - 3, 2, 6), cols[1])
		ci.draw_rect(Rect2(at.x - 3, at.y - 1, 6, 2), cols[1])
	if shine > 0.0:
		var sx := at.x - r + fmod(shine, 1.0) * r * 2.0
		ci.draw_rect(Rect2(sx, at.y - r + 1, 1, r * 2.0 - 2), Color(1, 1, 1, 0.7))


# ---------------------------------------------------------------- cards

## The card where you pick a line. [param rows] has, for each line in
## SlacklineState.LINES: {"line", "open", "medal", "best"}.
static func select_card(ci: CanvasItem, rows: Array[Dictionary], chosen: int, age: float, keys: String, legend: bool) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.03, 0.03, 0.06, 0.35 * minf(age * 4.0, 1.0)))
	var w := 330.0
	var line: Dictionary = rows[chosen].line
	var blurb := UI.wrap_lines(line.blurb if rows[chosen].open else _locked_text(line), w - 32, 10)
	var h := 76.0 + rows.size() * 24.0 + blurb.size() * 12.0 + 26.0
	var slide := 1.0 - pow(1.0 - minf(age * 3.5, 1.0), 3.0)
	var r := Rect2((SCREEN.x - w) / 2.0, lerpf(SCREEN.y + 10, (SCREEN.y - h) / 2.0 + 6, slide), w, h)
	UI.panel(ci, r)
	var x := r.position.x + 16
	UI.ink(ci, Vector2(r.get_center().x, r.position.y + 22), "The Camp 4 Slacklines", UI.GOLD, 16, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	if legend:
		UI.ink(ci, Vector2(r.get_center().x, r.position.y + 36), "Camp 4 Legend: gold on every line", UI.GOOD_DARK, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		UI.ink(ci, Vector2(r.get_center().x, r.position.y + 36), "Walk them end to end. Style earns silver and gold.", UI.INK_SOFT, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	ci.draw_rect(Rect2(x, r.position.y + 42, w - 32, 1), UI.PAPER_DARK)
	var y := r.position.y + 50
	for i in rows.size():
		var row: Dictionary = rows[i]
		var l: Dictionary = row.line
		var rr := Rect2(x - 4, y, w - 24, 22)
		if i == chosen:
			ci.draw_rect(rr, UI.PAPER_DARK)
			ci.draw_rect(Rect2(rr.position, Vector2(2, rr.size.y)), UI.GOLD)
			# the cursor nudges toward the row
			var nudge := sin(age * 8.0) * 1.0
			_chevron(ci, Vector2(rr.position.x - 6 + nudge, rr.get_center().y + 1), 1, UI.GOLD)
		var open: bool = row.open
		var col := UI.INK if open else UI.INK_SOFT
		medal(ci, Vector2(x + 8, y + 11), int(row.medal) if open else 0)
		UI.ink(ci, Vector2(x + 20, y + 10), l.name if open else "%s (locked)" % l.name, col, 10)
		UI.ink(ci, Vector2(x + 20, y + 20), "%d m · %s" % [l.meters, l.height], UI.INK_SOFT, 10)
		if open and int(row.best) > 0:
			UI.ink(ci, Vector2(rr.end.x - 8, y + 10), "Best %d" % row.best, UI.CREAM, 10, -1.0, HORIZONTAL_ALIGNMENT_RIGHT)
		if open:
			UI.ink(ci, Vector2(rr.end.x - 8, y + 20), "Silver %d · Gold %d" % [l.silver, l.gold], UI.INK_SOFT, 10, -1.0, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 24.0
	ci.draw_rect(Rect2(x, y + 2, w - 32, 1), UI.PAPER_DARK)
	for i in blurb.size():
		UI.ink(ci, Vector2(x, y + 16 + i * 12), blurb[i], UI.INK, 10)
	UI.ink(ci, Vector2(r.get_center().x, r.end.y - 10), keys, UI.INK_SOFT, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)


static func _locked_text(line: Dictionary) -> String:
	if line.needs == "slackline_walked":
		return "Walk the Camp 4 Line end to end first. Then somebody'll string the long one."
	return "Not strung yet."


## The results card. [param info]: {"title", "rows": [[label, value]], "total",
## "medal", "new_best", "prize": Texture2D or null, "prize_text", "line",
## "note"}. The rows count up one by one ([param age] seconds in), then the
## medal stamps down.
static func result_card(ci: CanvasItem, info: Dictionary, age: float, keys: String) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.03, 0.03, 0.06, 0.5 * minf(age * 3.0, 1.0)))
	var w := 300.0
	var rows: Array = info.rows
	var note := UI.wrap_lines(info.note, w - 32, 10)
	var h := 64.0 + rows.size() * 13.0 + 22.0 + note.size() * 12.0 + (34.0 if info.prize else 0.0) + 14.0
	var slide := 1.0 - pow(1.0 - minf(age * 3.5, 1.0), 3.0)
	var r := Rect2((SCREEN.x - w) / 2.0, lerpf(SCREEN.y + 10, (SCREEN.y - h) / 2.0, slide), w, h)
	UI.panel(ci, r)
	var x := r.position.x + 16
	var walked: bool = info.medal > 0
	UI.ink(ci, Vector2(r.get_center().x, r.position.y + 24), info.title, UI.GOOD_DARK if walked else UI.WARN_DARK, 16, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	UI.ink(ci, Vector2(r.get_center().x, r.position.y + 38), info.line, UI.INK_SOFT, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	ci.draw_rect(Rect2(x, r.position.y + 44, w - 32, 1), UI.PAPER_DARK)
	var y := r.position.y + 58
	var t := tally_time(rows.size())
	for i in rows.size():
		var shown_at := 0.35 + i * 0.28
		if age < shown_at:
			break
		var row: Array = rows[i]
		var f := clampf((age - shown_at) / 0.22, 0.0, 1.0)
		UI.ink(ci, Vector2(x, y + i * 13), str(row[0]), UI.INK, 10)
		var value := str(row[1])
		if value.is_valid_int():
			value = str(int(roundf(int(value) * f)))
		UI.ink(ci, Vector2(r.end.x - 120, y + i * 13), value, UI.CREAM, 10, 104.0, HORIZONTAL_ALIGNMENT_RIGHT)
	y += rows.size() * 13.0
	ci.draw_rect(Rect2(x, y - 6, w - 32, 1), UI.PAPER_DARK)
	if age >= t:
		UI.ink(ci, Vector2(x, y + 8), "Score", UI.GOLD, 12)
		UI.ink(ci, Vector2(r.end.x - 120, y + 8), "%d" % info.total, UI.GOLD, 12, 104.0, HORIZONTAL_ALIGNMENT_RIGHT)
		if info.new_best and fmod(age, 0.8) < 0.6:
			UI.ink(ci, Vector2(x + 46, y + 8), "New best!", UI.GOOD_DARK, 10)
	y += 22.0
	for i in note.size():
		UI.ink(ci, Vector2(x, y + i * 12), note[i], UI.INK_SOFT, 10)
	y += note.size() * 12.0
	if info.prize and age >= t:
		ci.draw_texture_rect(info.prize, Rect2(Vector2(x, y - 4), Vector2(32, 32)), false)
		UI.text(ci, Vector2(x + 38, y + 16), info.prize_text, UI.CREAM, 10)
	# the medal stamps down after the tally
	if info.medal > 0 and age >= t:
		var land := clampf((age - t) / 0.18, 0.0, 1.0)
		var scale := lerpf(2.6, 1.0, land * land)
		var at := Vector2(r.end.x - 34, r.position.y + 26)
		ci.draw_set_transform(at, 0.0, Vector2(scale, scale))
		medal(ci, Vector2.ZERO, info.medal, true, (age - t) * 0.7 if land >= 1.0 else 0.0)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if land >= 1.0:
			UI.ink(ci, at + Vector2(0, 18), MEDAL_NAMES[info.medal], MEDALS[info.medal - 1][2], 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	if age >= t:
		UI.ink(ci, Vector2(r.get_center().x, r.end.y - 10), keys, UI.INK_SOFT, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER)


## Seconds until a results card with [param rows] rows has counted up.
static func tally_time(rows: int) -> float:
	return 0.35 + rows * 0.28 + 0.2
