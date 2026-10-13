class_name Chuckah
extends StaticBody2D
## The spot for your acorn granary. Once Tabuce has shown you how, interact
## to build it; after that, interact to store or take out acorns.
## The acorns themselves are kept in the Granary autoload.

## Acorns taken out at a time: enough for one batch of acorn flour.
const WITHDRAW_AMOUNT := 4
## In-game minutes it takes to build.
const BUILD_MINUTES := 4 * 60


## Painted art: the bare spot before it's built, and the granary after. Without
## them the placeholder shapes below are drawn.
@export var texture_empty: Texture2D
@export var texture_built: Texture2D
## Footprint and reach in pixels (zero keeps the scene's default sizes).
@export var body_size := Vector2.ZERO
@export var reach_size := Vector2.ZERO

var _art: Sprite2D


func _ready() -> void:
	Granary.changed.connect(_refresh_art)
	if texture_empty and texture_built:
		_art = Sprite2D.new()
		_art.name = "Art"
		add_child(_art)
		move_child(_art, 0)
		for spec: Array in [["Collision", body_size, Vector2(0, -body_size.y / 2.0)], ["Hitbox/Shape", reach_size, Vector2(0, -reach_size.y / 2.0 - 4.0)]]:
			var size: Vector2 = spec[1]
			var shape_node := get_node_or_null(spec[0] as String) as CollisionShape2D
			if size.x > 0.0 and shape_node:
				var rect := RectangleShape2D.new()
				rect.size = size
				shape_node.shape = rect
				shape_node.position = spec[2]
	_refresh_art()


func _refresh_art() -> void:
	if _art:
		_art.texture = texture_built if Granary.chuckahs_built > 0 else texture_empty
		_art.offset = Vector2(0, -_art.texture.get_height() / 2.0 + 8.0)
	else:
		queue_redraw()


## Placeholder art: a pole frame, and a tall woven granary once it's built.
func _draw() -> void:
	if _art:
		return
	var pole := Color(0.42, 0.282, 0.161)
	if Granary.chuckahs_built == 0:
		draw_line(Vector2(-12, 0), Vector2(0, -36), pole, 2.0)
		draw_line(Vector2(12, 0), Vector2(0, -36), pole, 2.0)
		return
	draw_line(Vector2(-14, 0), Vector2(-10, -16), pole, 4.0)
	draw_line(Vector2(14, 0), Vector2(10, -16), pole, 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -16), Vector2(14, -16), Vector2(10, -48), Vector2(-10, -48)]), Color(0.69, 0.573, 0.373))
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -48), Vector2(14, -48), Vector2(0, -60)]), Color(0.361, 0.561, 0.235))


func interact(player: Player) -> void:
	if Granary.chuckahs_built == 0:
		await _offer_build(player)
		return
	var carrying := Inventory.count(Granary.ACORN)
	var options := [
		"Store acorns (carrying %d)" % carrying,
		"Take out %d acorns" % WITHDRAW_AMOUNT,
		"Leave",
	]
	player.can_act = false
	var box := DialogueBox.open(player)
	var prompt := "Your chuckah holds %d of %d acorns." % [Granary.acorns, Granary.capacity]
	match await box.choose(prompt, options):
		0:
			var stored := Granary.deposit_all()
			var text := "You stored %d acorns." % stored
			if stored == 0:
				text = "You aren't carrying any acorns." if carrying == 0 else "The chuckah is full."
			await box.say([{"speaker": "", "text": text}])
		1:
			var taken := Granary.withdraw(WITHDRAW_AMOUNT)
			await box.say([{"speaker": "", "text": "You took out %d acorns." % taken if taken > 0 else "The chuckah is empty."}])
	box.close()
	player.can_act = true


func _offer_build(player: Player) -> void:
	if not QuestLog.is_unlocked("chuckah"):
		DialogueBox.say_to(player, [{"speaker": "", "text": "A good dry spot, up off the ground. Someone who knows how could build an acorn granary here."}])
		return
	player.can_act = false
	var box := DialogueBox.open(player)
	if await box.choose("Build a chuckah here? It will take the afternoon.", ["Build it", "Not now"]) == 0:
		GameClock.advance_minutes(BUILD_MINUTES)
		Granary.build_chuckah()
		await box.say([{"speaker": "", "text": "You set the poles, weave the sides, and line it the way Tabuce showed you. The chuckah holds %d acorns." % Granary.capacity}])
	box.close()
	player.can_act = true
