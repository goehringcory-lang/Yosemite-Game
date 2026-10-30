class_name DivingBoard
extends StaticBody2D
## The Diving Board: a flat prow of granite on Half Dome's shoulder, looking
## straight at the Dome's northwest face. Ansel Adams made "Monolith, the
## Face of Half Dome" from here in April 1927. Look out from it and you see
## the face (Backcountry.DIVING_BOARD_VIEW); between three and five in the
## afternoon the light comes round onto it, and that's the picture (marked
## Backcountry.DIVING_BOARD, which Ansel's quest asks for).

const ROCK := Color("b8a890")
const ROCK_LIT := Color("dcc8a8")
const ROCK_DARK := Color("6e6458")
const OUTLINE := Color("2a1f1a")


func _ready() -> void:
	queue_redraw()


func get_prompt() -> String:
	return "Look out from the Diving Board"


## Is the Dome's face in the afternoon light now?
static func face_lit() -> bool:
	return GameClock.hour_in_range(Backcountry.FACE_LIT_FROM, Backcountry.FACE_LIT_TO)


func interact(player: Player) -> void:
	var lit := face_lit()
	var moment := Backcountry.DIVING_BOARD_VIEW.duplicate()
	moment["hour"] = fmod(GameClock.minutes / 60.0, 24.0)
	moment["photograph"] = lit
	var words := {"who": "The Diving Board"}
	if lit:
		Backcountry.mark(Backcountry.DIVING_BOARD)
		words["text"] = "The sun has come round onto the face, and for about an hour the whole 2,000 feet of it stands out bright against the sky. This is the picture."
	else:
		words["text"] = "The Dome's face, close enough to count the streaks on it. The light's flat now. It comes round onto the face in the afternoon, for about an hour, between three and five."
	await Backcountry.show_view(player, moment, words)


## A flat prow of granite jutting out over the drop, lit on top.
func _draw() -> void:
	var lip := PackedVector2Array([Vector2(-30, 0), Vector2(-24, -8), Vector2(22, -10), Vector2(34, -4), Vector2(28, 2), Vector2(-26, 4)])
	draw_colored_polygon(lip, OUTLINE)
	var top := PackedVector2Array([Vector2(-26, -1), Vector2(-21, -7), Vector2(21, -9), Vector2(31, -4), Vector2(26, 0)])
	draw_colored_polygon(top, ROCK)
	draw_line(Vector2(-20, -6), Vector2(20, -8), ROCK_LIT, 1.0)
	draw_line(Vector2(-24, 2), Vector2(26, 1), ROCK_DARK, 2.0)
