class_name QuestMarker
extends Node2D
## The little speech bubble over someone's head when they have something for
## you: an orange "!" for a new quest (or a quest that sent you to them), a
## blue "?" when talking to them finishes one (see QuestLog.marker_for), and
## a pink heart when a friend has a heart scene to share (HeartScenes). It
## bobs gently, and hides while you're talking. NPC and Vendor each add one.

## Seconds between checks of whether they have something for you.
const CHECK := 0.5
## The bubble's height over their feet, and its bob.
const HEIGHT := -68.0
const BOB := 3.0
const INK := Color("2a1b14")
const NEW := Color("f7a64a")
const DONE := Color("3a86a8")
const HEART := Color("e0607e")
## Glyphs five cells high (each cell drawn 2x2 px) for the bubble.
const GLYPHS := {
	"!": ["010", "010", "010", "000", "010"],
	"?": ["111", "001", "011", "000", "010"],
	"heart": ["01010", "11111", "11111", "01110", "00100"],
}

## Whose quests to check (a character id, or a shop's talk target).
var character_id := ""
## "!", "?" or "heart" while showing, or "".
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
	if kind == "" and not hidden_while_talking and character_id != "" and HeartScenes.ready_for(character_id) > 0:
		kind = "heart"
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
	var ink: Color = {"!": NEW, "?": DONE, "heart": HEART}[marker]
	# centered in the bubble, which is centered on x = 1
	var left := 1 - String(glyph[0]).length()
	for y in glyph.size():
		for x in String(glyph[y]).length():
			if glyph[y][x] == "1":
				draw_rect(Rect2(left + x * 2, top + 2 + y * 2, 2, 2), ink)
