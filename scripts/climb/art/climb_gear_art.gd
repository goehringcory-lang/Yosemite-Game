class_name ClimbGearArt
extends RefCounted
## The gear on the climbing screen, drawn at screen resolution: cams, nuts and
## slung horns in their cracks (each in its size's sling color, with a tag
## on a piece you shouldn't trust), the rack on your harness, and the width
## of the crack you're reaching for. The placing checks' panels use the same
## little pieces (ClimbCheckHud).

const UI := preload("res://scripts/climb/art/climb_ui.gd")
const STEEL := Color("bdb8ae")
const STEEL_LIT := Color("e6e2d8")
const STEEL_DARK := Color("6a6a70")
const OUTLINE := Color("15141c")
const BRASS := Color("c9a24a")
const TAG := Color("d9452a")


## A placed piece, its crack at [param p] (the piece's top). [param time]
## makes a marginal one's tag wobble.
static func placed(ci: CanvasItem, p: Vector2, piece: Dictionary, time: float) -> void:
	var color: Color = piece.get("color", Color("c8382e"))
	match piece.get("hw", "cam"):
		"nut":
			nut(ci, p, color)
		"sling":
			sling(ci, p, color)
		_:
			cam(ci, p, color)
	match piece.get("quality", "good"):
		"marginal":
			# A red tag that trembles: don't fall on this.
			var wob := roundf(sin(time * 9.0 + p.y) * 1.0)
			var t := p + Vector2(8 + wob, -3)
			ci.draw_rect(Rect2(t - Vector2(1, 1), Vector2(6, 9)), OUTLINE)
			ci.draw_rect(Rect2(t, Vector2(4, 7)), TAG)
			ci.draw_rect(Rect2(t + Vector2(1, 1), Vector2(2, 3)), UI.CREAM)
			ci.draw_rect(Rect2(t + Vector2(1, 5), Vector2(2, 1)), UI.CREAM)
		"over":
			ci.draw_rect(Rect2(p + Vector2(7, -1), Vector2(5, 5)), OUTLINE)
			ci.draw_rect(Rect2(p + Vector2(8, 0), Vector2(3, 3)), UI.WARN)
		"solid":
			ci.draw_rect(Rect2(p + Vector2(-1, -2), Vector2(1, 1)), Color(UI.CREAM, 0.8))


## A cam: anodized lobes in the crack (the size's color, as on a Camalot),
## the stem and trigger, and a sling.
static func cam(ci: CanvasItem, p: Vector2, color: Color, scale := 1.0) -> void:
	var s := scale
	ci.draw_rect(Rect2(p + Vector2(-5, -1) * s, Vector2(11, 7) * s), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(-4, 0) * s, Vector2(9, 5) * s), color)
	ci.draw_rect(Rect2(p + Vector2(-4, 0) * s, Vector2(9, 1) * s), color.lightened(0.45))
	ci.draw_rect(Rect2(p + Vector2(-4, 4) * s, Vector2(9, 1) * s), color.darkened(0.35))
	ci.draw_rect(Rect2(p + Vector2(-1, 1) * s, Vector2(3, 3) * s), STEEL)
	ci.draw_rect(Rect2(p + Vector2(0, 2) * s, Vector2(1, 1) * s), STEEL_DARK)
	ci.draw_rect(Rect2(p + Vector2(-1, 6) * s, Vector2(3, 3) * s), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(0, 5) * s, Vector2(1, 3) * s), STEEL)
	ci.draw_rect(Rect2(p + Vector2(-2, 6) * s, Vector2(5, 1) * s), STEEL_LIT)
	_sling(ci, p + Vector2(0, 8) * s, color, s)


## A nut: a brass wedge in the crack on a steel wire, and its sling.
static func nut(ci: CanvasItem, p: Vector2, color: Color, scale := 1.0) -> void:
	var s := scale
	ci.draw_rect(Rect2(p + Vector2(-4, -1) * s, Vector2(9, 7) * s), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(-3, 0) * s, Vector2(7, 5) * s), BRASS)
	ci.draw_rect(Rect2(p + Vector2(-3, 0) * s, Vector2(7, 1) * s), BRASS.lightened(0.4))
	ci.draw_rect(Rect2(p + Vector2(-2, 4) * s, Vector2(5, 1) * s), BRASS.darkened(0.3))
	ci.draw_rect(Rect2(p + Vector2(0, 5) * s, Vector2(1, 3) * s), STEEL)
	_sling(ci, p + Vector2(0, 7) * s, color, s)


## A sling looped round a horn of rock.
static func sling(ci: CanvasItem, p: Vector2, color: Color, scale := 1.0) -> void:
	var s := scale
	ci.draw_rect(Rect2(p + Vector2(-4, -1) * s, Vector2(9, 5) * s), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(-3, 0) * s, Vector2(7, 3) * s), Color("8f877c"))
	ci.draw_rect(Rect2(p + Vector2(-3, 0) * s, Vector2(7, 1) * s), Color("b5ad9f"))
	_sling(ci, p + Vector2(0, 2) * s, color, s)


## A sewn sling in [param color] down to the carabiner the rope runs through.
static func _sling(ci: CanvasItem, top: Vector2, color: Color, s: float) -> void:
	ci.draw_rect(Rect2(top + Vector2(-2, 0) * s, Vector2(5, 6) * s), OUTLINE)
	ci.draw_rect(Rect2(top + Vector2(-1, 0) * s, Vector2(3, 5) * s), color)
	ci.draw_rect(Rect2(top + Vector2(-1, 0) * s, Vector2(1, 5) * s), color.lightened(0.3))
	ci.draw_rect(Rect2(top + Vector2(-2, 5) * s, Vector2(5, 4) * s), OUTLINE)
	ci.draw_rect(Rect2(top + Vector2(-1, 5) * s, Vector2(3, 3) * s), STEEL_DARK)
	ci.draw_rect(Rect2(top + Vector2(-1, 5) * s, Vector2(1, 3) * s), STEEL_LIT)


## One piece of your rack as an icon, centered on [param at] ([param dim]
## greys out a piece that won't go in).
static func icon(ci: CanvasItem, at: Vector2, piece: Dictionary, dim := false) -> void:
	var color: Color = piece.get("color", Color("c8382e"))
	if dim:
		color = Color(color.lerp(Color("5e4a38"), 0.7), 0.6)
	var p := at + Vector2(0, -6)
	match piece.get("kind", "cam"):
		"nut":
			nut(ci, p, color)
		"sling":
			sling(ci, p + Vector2(0, 2), color)
		_:
			cam(ci, p, color)
	if dim:
		ci.draw_rect(Rect2(at + Vector2(-5, -8), Vector2(11, 17)), Color(0.18, 0.12, 0.08, 0.45))


## The rack on your harness: a pip in each piece's color for every piece
## still on it, smallest first, from [param at]. A piece that fits the crack
## you're on stands a little proud. Returns the width drawn.
static func rack_strip(ci: CanvasItem, state: ClimbState, at: Vector2, crack_width := -1) -> float:
	var span := 0.0
	for piece: Dictionary in state.rack_now():
		span += 4 * int(piece.count) + 2
	UI.glass(ci, Rect2(at.x - 3, at.y - 4, span + 4, 16), 0.5)
	var x := at.x
	for piece: Dictionary in state.rack_now():
		var left := int(piece.left)
		var total := int(piece.count)
		var fits := crack_width >= 0 and ClimbRack.misfit(piece, crack_width) == 0
		for i in total:
			var on := i < left
			var c: Color = piece.color if on else Color(piece.color, 0.22)
			var h := 7.0 if piece.get("kind", "") == "nut" else 9.0
			var y := at.y + (9.0 - h) - (2.0 if fits and on else 0.0)
			ci.draw_rect(Rect2(x - 1, y - 1, 5, h + 2), OUTLINE)
			ci.draw_rect(Rect2(x, y, 3, h), c)
			if on:
				ci.draw_rect(Rect2(x, y, 3, 1), c.lightened(0.4))
			x += 4
		x += 2
	return x - at.x


## The width of a crack, beside its hold: a short bar in the color of the
## cam that fits, and its name when [param label].
static func crack_tick(ci: CanvasItem, p: Vector2, width: int, label := false) -> void:
	var c := ClimbRack.width_color(width)
	var h := 4 + width
	ci.draw_rect(Rect2(p + Vector2(-1, -h / 2.0 - 1), Vector2(4, h + 2)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(0, -h / 2.0), Vector2(2, h)), c)
	if label:
		UI.outlined(ci, p + Vector2(-4, 4), "%s %s" % [ClimbRack.width_name(width), ClimbRack.width_size(width)], UI.CREAM, 10, -1.0, HORIZONTAL_ALIGNMENT_RIGHT)
