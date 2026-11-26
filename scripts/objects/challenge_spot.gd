class_name ChallengeSpot
extends Node2D
## A register to sign or a spot to sketch from (Challenges).
##
## A register is a battered steel ammo can on a rock (a summit register), or
## a bronze survey disk with its little cairn; once signed, the lid's shut
## and a pencil lies on top. A sketch spot is a flat rock to sit on, with a
## few charcoal smudges where others have sat and drawn. Interact to sign,
## or to sit and sketch (only at the right time: otherwise the Logbook says
## when to come back).

const INK := Color("2a1b14")
const STEEL := Color("5d6b58")
const STEEL_LIT := Color("8a9a80")
const GRANITE := Color("a9a39a")
const GRANITE_LIT := Color("cfc9bd")
const GRANITE_DK := Color("7b766e")
const BRONZE := Color("b0823e")
const BRONZE_LIT := Color("e0b468")
const PAPER := Color("efe4c8")
const PENCIL := Color("d9a441")

## Its id in data/park/challenges.json.
var challenge_id := ""

var _hitbox: Area2D
var _busy := false


func _ready() -> void:
	add_to_group("challenge_spot")
	_hitbox = Area2D.new()
	_hitbox.name = "Hitbox"
	_hitbox.collision_layer = 4
	_hitbox.collision_mask = 0
	_hitbox.monitoring = false
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48, 36)
	shape.shape = rect
	shape.position = Vector2(0, -12)
	_hitbox.add_child(shape)
	add_child(_hitbox)
	Challenges.changed.connect(queue_redraw)


func entry() -> Dictionary:
	return Challenges.get_challenge(challenge_id)


func is_register() -> bool:
	return Challenges.kind_of(challenge_id) == "register"


func get_prompt() -> String:
	var e := entry()
	if is_register():
		return ("Read: %s" if Challenges.is_signed(challenge_id) else "Sign: %s") % e.get("title", "Register")
	return ("Look: %s" if Challenges.is_sketched(challenge_id) else "Sketch: %s") % e.get("title", "the view")


func interact(player: Player) -> void:
	if _busy or not is_inside_tree():
		return
	_busy = true
	var e := entry()
	var lines: Array = []
	if is_register():
		if Challenges.is_signed(challenge_id):
			lines.append({"text": "%s Your own name is there now too." % e.text})
		else:
			var earned = Challenges.sign_register(challenge_id)
			Sound.play("climb_clip", -6.0, 0.02)
			var text := "%s You add your name and the date." % e.text
			if earned is Dictionary and not (earned as Dictionary).is_empty():
				text += " That's %d registers signed: someone's left %s in the box for whoever signs this many. Finders keepers." % [Challenges.signed_count(), Finds.reward_text({"reward": earned})]
			lines.append({"text": text})
	else:
		player.pose("crouch", Player.PICK_TIME)
		if Challenges.sketch(challenge_id):
			Sound.play("story_sting", -8.0, 0.0)
			lines.append({"text": "%s It goes in your sketchbook." % e.text})
		else:
			lines.append({"text": "You sit a while with your pencil, but it isn't right yet. %s" % e.get("early", "")})
	await DialogueBox.say_to(player, lines)
	queue_redraw()
	_busy = false


func _draw() -> void:
	# in whole 2x2 art pixels, like the rest of the world's art
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2, 2))
	if not is_register():
		_draw_sketch_rock()
	elif str(entry().get("title", "")).to_lower().contains("benchmark") or str(entry().get("title", "")).to_lower().contains("disk"):
		_draw_disk()
	else:
		_draw_box()


func _rock(r: Rect2) -> void:
	draw_rect(Rect2(r.position.x - 1, r.position.y + 1, r.size.x + 2, r.size.y), INK)
	draw_rect(r, GRANITE)
	draw_rect(Rect2(r.position + Vector2(2, 0), Vector2(r.size.x - 4, 1)), GRANITE_LIT)
	draw_rect(Rect2(r.position.x, r.end.y - 2, r.size.x, 2), GRANITE_DK)


## A summit register: an old steel ammo can wedged on a rock.
func _draw_box() -> void:
	draw_rect(Rect2(-12, -2, 24, 4), Color(0, 0, 0, 0.18))
	_rock(Rect2(-11, -8, 22, 8))
	draw_rect(Rect2(-6, -16, 12, 9), INK)
	draw_rect(Rect2(-5, -15, 10, 7), STEEL)
	draw_rect(Rect2(-5, -15, 10, 1), STEEL_LIT)
	draw_rect(Rect2(-2, -17, 4, 2), INK)
	if Challenges.is_signed(challenge_id):
		draw_rect(Rect2(-4, -17, 8, 1), PENCIL)


## A bronze survey disk in a granite knob, with a little cairn.
func _draw_disk() -> void:
	draw_rect(Rect2(-12, -2, 24, 4), Color(0, 0, 0, 0.18))
	_rock(Rect2(-11, -7, 22, 7))
	draw_rect(Rect2(-3, -6, 6, 4), INK)
	draw_rect(Rect2(-2, -5, 4, 2), BRONZE)
	draw_rect(Rect2(-2, -5, 2, 1), BRONZE_LIT)
	_rock(Rect2(6, -12, 6, 4))
	_rock(Rect2(7, -15, 4, 3))
	if Challenges.is_signed(challenge_id):
		draw_rect(Rect2(-8, -9, 6, 1), PENCIL)


## A flat rock to sit on, smudged with charcoal (and your page, once drawn).
func _draw_sketch_rock() -> void:
	draw_rect(Rect2(-13, -2, 26, 4), Color(0, 0, 0, 0.18))
	_rock(Rect2(-12, -6, 24, 6))
	draw_rect(Rect2(-7, -5, 2, 1), Color(INK, 0.5))
	draw_rect(Rect2(3, -4, 3, 1), Color(INK, 0.4))
	if Challenges.is_sketched(challenge_id):
		draw_rect(Rect2(-4, -9, 8, 5), INK)
		draw_rect(Rect2(-3, -8, 6, 3), PAPER)
		draw_rect(Rect2(-2, -7, 3, 1), Color(INK, 0.6))
