class_name Emote
extends Node2D
## A little bubble that pops up over someone's head for a moment, as
## Stardew's villagers show what they feel: "!" when they're surprised, a
## note when they're glad, a sweat drop when it's hard to say, a heart, a
## sparkle, "..." while they think, and "Zzz" when they're asleep on their
## feet. People show them as they talk (NPC.on_line), when a friend walks up,
## and through the night.
##
##   Emote.pop(npc, "surprised")
##
## Drawn in the quest marker's style: an outlined white bubble with a tail,
## each glyph cell 2x2 px. It sits just above the quest marker's height so
## the two never overlap (the marker hides while you talk).

const INK := Color("2a1b14")
const HEIGHT := -64.0
## How long the bubble stays up, after popping in.
const HOLD := 1.3
## Glyphs, 7 wide x 7 tall, "#" ink and the letter a colour from COLORS.
const GLYPHS := {
	"surprised": ["...r...", "...r...", "...r...", "...r...", "...r...", ".......", "...r..."],
	"question": ["..bbb..", ".b...b.", ".....b.", "....b..", "...b...", ".......", "...b..."],
	"heart": [".rr.rr.", "rrrrrrr", "rrrrrrr", ".rrrrr.", "..rrr..", "...r...", "......."],
	"glad": ["...gggg", "...g..g", "...g..g", "...g..g", ".ggg.gg", "gggggg.", ".gg...."],
	"sad": ["...b...", "..bbb..", ".bbbbb.", ".bbbbb.", ".bbwbb.", "..bbb..", "......."],
	"thinking": [".......", ".......", ".......", ".......", ".......", ".......", "k.k.k.."],
	"sparkle": ["...y...", "...y...", ".yyyyy.", "..yyy..", ".y...y.", ".......", "......."],
	"sleep": ["kkkk...", "...k...", "..k....", ".k.....", "kkkk...", "....kkk", ".....k."],
}
const COLORS := {
	"r": Color("c8402e"), "b": Color("3a86a8"), "g": Color("4a8a4a"),
	"y": Color("e8b040"), "k": Color("5a4a3e"), "w": Color.WHITE,
}

var kind := ""


## Shows [param emote_kind] (a key of GLYPHS) over [param anchor] and returns
## the bubble, or null if there's no such emote. A newer bubble replaces the
## one already showing.
static func pop(anchor: Node2D, emote_kind: String) -> Emote:
	if anchor == null or not anchor.is_inside_tree() or not GLYPHS.has(emote_kind):
		return null
	for child in anchor.get_children():
		if child is Emote:
			# out of the way now, so the new bubble can take the name
			anchor.remove_child(child)
			child.queue_free()
	var bubble := Emote.new()
	bubble.kind = emote_kind
	bubble.name = "Emote"
	anchor.add_child(bubble)
	return bubble


## The emote a line of dialogue reads as, from its mood (Portraits.mood_for)
## and its words: "" when it reads as nothing much.
static func for_line(text: String, mood: String) -> String:
	match mood:
		"surprised":
			return "surprised"
		"sad":
			return "sad"
		"happy":
			var lower := text.to_lower()
			if "love" in lower or "thank" in lower:
				return "heart"
			return "glad"
	var trimmed := text.strip_edges()
	if trimmed.ends_with("?"):
		return "question"
	if trimmed.begins_with("...") or trimmed.begins_with("Hm") or trimmed.begins_with("Well,"):
		return "thinking"
	return ""


func _ready() -> void:
	z_index = 31
	# the node sits at the bubble's middle, so it pops out of itself
	position = Vector2(0, HEIGHT)
	scale = Vector2(0.3, 0.3)
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.08)
	tween.parallel().tween_property(self, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.08)
	tween.tween_interval(HOLD)
	tween.tween_property(self, "position:y", HEIGHT - 6.0, 0.3)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


func _draw() -> void:
	var glyph: Array = GLYPHS.get(kind, [])
	if glyph.is_empty():
		return
	var top := -10.0
	# the bubble: an outlined rounded box, 20 x 18 inside, and a tail
	draw_rect(Rect2(-10, top - 2, 20, 22), INK)
	draw_rect(Rect2(-12, top, 24, 18), INK)
	draw_rect(Rect2(-10, top, 20, 18), Color.WHITE)
	draw_rect(Rect2(-2, top + 20, 6, 2), INK)
	draw_rect(Rect2(0, top + 18, 2, 4), Color.WHITE)
	draw_rect(Rect2(0, top + 22, 2, 2), INK)
	for y in glyph.size():
		var row: String = glyph[y]
		for x in row.length():
			var cell := row[x]
			if cell != "." and COLORS.has(cell):
				draw_rect(Rect2(-7 + x * 2, top + 2 + y * 2, 2, 2), COLORS[cell])
