class_name Chuckah
extends StaticBody2D
## The spot for your acorn granary. Once Tabuce has shown you how, interact
## to build it; after that, interact to store or take out acorns.
## The acorns themselves are kept in the Granary autoload.

## Acorns taken out at a time: enough for one batch of acorn flour.
const WITHDRAW_AMOUNT := 4
## In-game minutes it takes to build.
const BUILD_MINUTES := 4 * 60


func _ready() -> void:
	Granary.changed.connect(queue_redraw)
	queue_redraw()


## Placeholder art: a pole frame, and a tall woven granary once it's built.
func _draw() -> void:
	var pole := Color(0.45, 0.32, 0.2)
	if Granary.chuckahs_built == 0:
		draw_line(Vector2(-6, 0), Vector2(0, -18), pole, 1.0)
		draw_line(Vector2(6, 0), Vector2(0, -18), pole, 1.0)
		return
	draw_line(Vector2(-7, 0), Vector2(-5, -8), pole, 2.0)
	draw_line(Vector2(7, 0), Vector2(5, -8), pole, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-7, -8), Vector2(7, -8), Vector2(5, -24), Vector2(-5, -24)]), Color(0.7, 0.58, 0.35))
	draw_colored_polygon(PackedVector2Array([Vector2(-7, -24), Vector2(7, -24), Vector2(0, -30)]), Color(0.45, 0.55, 0.3))


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
