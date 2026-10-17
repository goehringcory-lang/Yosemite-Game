class_name SlacklineSpot
extends InfoSign
## The Camp 4 slackline's sign, which also lets you walk the line (see
## SlacklineMinigame). EasterEggs puts this script on the generated map's
## SlacklineInfo node, so a map rebuild keeps it.

const MINIGAME := preload("res://scripts/slackline/slackline_minigame.gd")


func get_prompt() -> String:
	return "Walk: %s" % title


func interact(player: Player) -> void:
	player.can_act = false
	var box := DialogueBox.open(player)
	var choice := await box.choose(current_text(), ["Walk the line", "Leave"])
	box.close()
	if choice != 0:
		player.can_act = true
		return
	await walk(player)


## Opens the slackline screen and waits for the player to leave it.
func walk(player: Player) -> void:
	var was_paused := GameClock.paused
	GameClock.paused = true
	var minigame: SlacklineMinigame = MINIGAME.new()
	player.get_tree().root.add_child(minigame)
	await minigame.finished
	var spent := minigame.minutes()
	GameClock.paused = was_paused
	player.can_act = true
	# Time passes last: running past 2 AM sends the player home.
	if spent > 0:
		GameClock.advance_minutes(spent)
