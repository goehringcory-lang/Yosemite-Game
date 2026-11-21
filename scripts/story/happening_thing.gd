class_name HappeningThing
extends Node2D
## Something lost for a "find" Happening (a fly box, a sandal, a letter),
## lying where it ended up once you've heard about it, with a glint now and
## then so a sharp eye can spot it. Pick it up and take it back.

const GLINT_EVERY := 2.2
const GLINT_TIME := 0.35

var happening: Dictionary = {}
var _clock := 0.0
var _icon: Texture2D


func setup(for_happening: Dictionary) -> void:
	happening = for_happening
	name = "Lost_" + str(happening.id)
	var item := ItemDB.get_item(str(happening.thing.get("icon", "")))
	_icon = item.icon if item else null
	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 4
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(24, 20)
	shape.shape = box
	shape.position = Vector2(0, -6)
	hitbox.add_child(shape)
	add_child(hitbox)


func get_prompt() -> String:
	return "Pick up %s" % happening.thing.name


func interact(player: Player) -> void:
	Happenings.pick_up(happening.id)
	var lines: Array[Dictionary] = []
	for text: String in happening.get("found_lines", []):
		lines.append({"speaker": "", "text": text})
	lines.append({"speaker": "", "text": "Take it back to %s." % happening.who})
	Sound.play("pickup", 0.0, 0.08)
	queue_free()
	DialogueBox.say_to(player, lines)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	if _icon:
		# drawn at half size: a small thing lying in the grass
		draw_texture_rect(_icon, Rect2(Vector2(-8, -14), Vector2(16, 16)), false)
	else:
		draw_rect(Rect2(-5, -6, 10, 6), Color(0.55, 0.38, 0.22))
	var t := fmod(_clock, GLINT_EVERY)
	if t < GLINT_TIME:
		var s := 1.0 + 3.0 * sin(t / GLINT_TIME * PI)
		var c := Vector2(5, -12)
		var glint := Color(1, 1, 0.9, 0.9)
		draw_rect(Rect2(c - Vector2(0.5, s), Vector2(1, s * 2)), glint)
		draw_rect(Rect2(c - Vector2(s, 0.5), Vector2(s * 2, 1)), glint)
