class_name ClimbGripView
extends RefCounted
## The grip close-up: when you take a hold you haven't taken that way yet on
## this pitch (or a crux hold), a small panel pops up beside your hand with
## the hand big on the rock (ClimbGripCloseup) and a word for it: "Crimp",
## "Hand jam", "Smear". It shows the first time each shape comes up on a
## pitch, not on every move, and the next move clears it at once, so it never
## holds you up.
##
## ClimbMinigame calls [method took] after each move, [method update] each
## frame, [method clear] on a new pitch or a fall, and [method draw] with the
## screen position of the hand that took the hold.

## Seconds the panel pops in, stays and fades.
const POP := 0.08
const HOLD := 0.75
const FADE := 0.2
## The panel's size on the 480 x 270 grid (its picture is twice that, one
## texel to a screen pixel).
const SIZE := 32.0
## How far from the hand the panel sits.
const GAP := 18.0

## Shapes and foot techniques already shown on this pitch.
var _seen := {}
var _age := 99.0
var _shape := ""
var _foot := false
var _right := true
var _tex: Texture2D
var _textures := {}


## Forgets what's been shown (a new pitch).
func reset() -> void:
	_seen.clear()
	clear()


## Hides the panel now.
func clear() -> void:
	_age = 99.0


## You took [param hold] with your right hand ([param right]) or left. Shows
## its shape if it's new on this pitch or a crux; else a notable foot
## technique (a smear or a toe jam) if that's new. [param rock] is the
## wall's base color.
func took(hold: Dictionary, right: bool, rock: Color, chalk := false) -> void:
	clear()
	var shape := str(hold.get("shape", ""))
	var foot := str(hold.get("foot", ""))
	if shape != "" and (not _seen.has(shape) or hold.get("crux", false)):
		_seen[shape] = true
		_show(shape, false, right, rock, chalk)
	elif foot in ["smear", "toe_jam"] and not _seen.has("foot_" + foot):
		_seen["foot_" + foot] = true
		_show(foot, true, right, rock, false)


func _show(shape: String, foot: bool, right: bool, rock: Color, chalk: bool) -> void:
	_shape = shape
	_foot = foot
	_right = right
	_age = 0.0
	var key := "%s|%s|%s|%s|%s|%s" % [shape, foot, right, rock.to_html(false), chalk, ClimbSprites.SKIN.to_html(false) + ClimbSprites.SHIRT.to_html(false)]
	if not _textures.has(key):
		var tex := ImageTexture.create_from_image(ClimbGripCloseup.image(shape, right, rock, chalk, foot))
		tex.set_size_override(Vector2i(int(SIZE), int(SIZE)))
		_textures[key] = tex
	_tex = _textures[key]


func update(delta: float) -> void:
	_age += delta


func showing() -> bool:
	return _age < POP + HOLD + FADE


## The shape on show ("" when none).
func shape() -> String:
	return _shape if showing() else ""


## Draws the panel beside [param hand] (screen position on the 480 grid),
## on the outside of the hand that took the hold, kept on [param bounds].
func draw(ci: CanvasItem, hand: Vector2, bounds: Rect2) -> void:
	if not showing() or _tex == null:
		return
	var alpha := 1.0
	var scale := 1.0
	if _age < POP:
		scale = lerpf(0.6, 1.0, _age / POP)
	elif _age > POP + HOLD:
		alpha = 1.0 - (_age - POP - HOLD) / FADE
	var side := 1.0 if _right else -1.0
	var center := hand + Vector2(side * (GAP + SIZE * 0.5), -6.0)
	# Keep it on the wall: flip to the other side rather than run off it.
	if center.x + SIZE * 0.5 > bounds.end.x or center.x - SIZE * 0.5 < bounds.position.x:
		center.x = hand.x - side * (GAP + SIZE * 0.5)
	center.y = clampf(center.y, bounds.position.y + SIZE * 0.5, bounds.end.y - SIZE * 0.5 - 10.0)
	var half := Vector2(SIZE, SIZE) * 0.5 * scale
	var rect := Rect2(center - half, half * 2.0)
	# A leader line from the panel's edge to the hand.
	var edge := Vector2(rect.position.x if hand.x < center.x else rect.end.x, center.y)
	ci.draw_line(edge, hand, Color(0.082, 0.078, 0.11, 0.55 * alpha), 2.0)
	ci.draw_line(edge, hand, Color(0.961, 0.933, 0.878, 0.8 * alpha), 1.0)
	ci.draw_rect(rect.grow(1.0), Color(0.082, 0.078, 0.11, 0.6 * alpha))
	ci.draw_texture_rect(_tex, rect, false, Color(1, 1, 1, alpha))
	var word := HoldShape.foot_label(_shape) if _foot else HoldShape.label(_shape)
	ClimbUI.outlined(ci, Vector2(center.x, rect.end.y + 9), word, ClimbUI.CREAM, 10, -1.0, HORIZONTAL_ALIGNMENT_CENTER, alpha)
