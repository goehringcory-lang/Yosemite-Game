class_name QuestMarker
extends Node2D
## The little speech bubble over someone's head when they have something for
## you: an orange "!" for a new quest (or a quest that sent you to them), a
## blue "?" when talking to them finishes one (see QuestLog.marker_for). It
## bobs gently, and hides while you're talking. NPC and Vendor each add one.

## Seconds between checks of whether they have something for you.
const CHECK := 0.5
## The bubble's height over their feet, and its bob.
const HEIGHT := -68.0
const BOB := 3.0
const INK := Color("2a1f1a")
const NEW := Color("e8a020")
const DONE := Color("4a8ad0")
## 3x5 glyphs (each cell drawn 2x2 px) for the bubble.
const GLYPHS := {
	"!": ["010", "010", "010", "000", "010"],
	"?": ["111", "001", "011", "000", "010"],
}

## Whose quests to check (a character id, or a shop's talk target).
var character_id := ""
## "!" or "?" while showing, or "".
var marker := ""
## Set while the person is talking with you.
var hidden_while_talking := false
var _check := 0.0
var _time := 0.0


func _init(id := "") -> void:
	character_id = id
	z_index = 20
	_check = randf() * CHECK


func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = CHECK
		refresh()
	if marker != "":
		_time += delta
		position.y = roundf(sin(_time * TAU * 0.8) * BOB)


func refresh() -> void:
	var kind := "" if hidden_while_talking or character_id == "" else QuestLog.marker_for(character_id)
	if kind != marker:
		marker = kind
		queue_redraw()


func _draw() -> void:
	if marker == "":
		return
	var top := HEIGHT
	# an outlined, rounded bubble with a tail pointing down
	draw_rect(Rect2(-8, top - 2, 18, 18), INK)
	draw_rect(Rect2(-10, top, 22, 14), INK)
	draw_rect(Rect2(-8, top, 18, 14), Color.WHITE)
	draw_rect(Rect2(-2, top + 16, 6, 2), INK)
	draw_rect(Rect2(0, top + 14, 2, 4), Color.WHITE)
	draw_rect(Rect2(0, top + 18, 2, 2), INK)
	var glyph: Array = GLYPHS[marker]
	var ink := NEW if marker == "!" else DONE
	for y in glyph.size():
		for x in 3:
			if glyph[y][x] == "1":
				draw_rect(Rect2(-2 + x * 2, top + 2 + y * 2, 2, 2), ink)
