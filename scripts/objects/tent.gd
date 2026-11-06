extends StaticBody2D
## Your campsite tent. Interact with it to sleep and start the next day.
##
## While the snow has shut the Tioga Road and the story is waiting on the
## high country (QuestLog.snowed_in), it also offers to sleep straight
## through to the thaw.

signal sleep_requested
## Sleep for [param nights] nights in one go (World.rest).
signal rest_requested(nights: int)


func interact(player: Player) -> void:
	# the supper after the finale ends when you turn in
	var feast := GuardianFeast.at(get_tree())
	if feast:
		await feast.finish()
		sleep_requested.emit()
		return
	var nights := Park.nights_until_open("tioga_road") if QuestLog.snowed_in() else 0
	if nights <= 1:
		sleep_requested.emit()
		return
	player.can_act = false
	var box := DialogueBox.open(player)
	var details := [
		{"title": "Sleep", "rows": [], "facts": "Wake up tomorrow", "note": "End the day here, as usual."},
		{"title": "Sleep through to the thaw", "rows": [], "facts": "%d nights, to Summer 1" % nights,
			"note": "The Tioga Road opens and Muir is waiting in Tuolumne. Fresh food in your pack and your chest will spoil, and whatever the winter and spring bring, you'll sleep through."},
		null,
	]
	var choice := await box.choose("Sleep?", ["Sleep", "Sleep until the Tioga Road opens", "Not yet"], "", [], details)
	box.close()
	player.can_act = true
	if choice == 0:
		sleep_requested.emit()
	elif choice == 1:
		rest_requested.emit(nights)
