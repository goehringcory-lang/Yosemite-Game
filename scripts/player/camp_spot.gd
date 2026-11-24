class_name CampSpot
extends Node
## Open ground in front of you, in the evening, with the backpacking pack on:
## the player's fallback target after the fly rod (Player.get_target). Its
## action is "Make camp": a box says what's wrong with the spot by Leave No
## Trace (Backpacking.preview), and you sleep here or not (World.camp_out).

## The choices in the box, in order.
enum Choice { SLEEP, FIRE, NOT_YET }


func get_prompt() -> String:
	return "Make camp"


func interact(player: Player) -> void:
	var world := player.get_tree().get_first_node_in_group("world")
	if world == null or world.region == null:
		return
	var at := player.global_position
	var no := Backpacking.refusal(world.region, at)
	if no != "":
		DialogueBox.say_to(player, [{"speaker": "", "text": no}])
		return
	player.can_act = false
	var box := DialogueBox.open(player)
	var choice := await box.choose(Backpacking.preview(world.region, at), ["Sleep here", "Light a small fire, then sleep", "Not yet"])
	box.close()
	player.can_act = true
	if choice == Choice.SLEEP or choice == Choice.FIRE:
		world.camp_out(at, Backpacking.problems(world.region, at, choice == Choice.FIRE))
