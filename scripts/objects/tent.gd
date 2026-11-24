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
	var spoiling := Larder.spoiling_summary()
	if nights <= 1 and spoiling == "":
		sleep_requested.emit()
		return
	player.can_act = false
	var box := DialogueBox.open(player)
	if nights <= 1:
		var details := [
			{"title": "Sleep anyway", "rows": [], "facts": "Wake up tomorrow",
				"note": "Cook or trade perishable food before turning in to keep it from spoiling."},
			null,
		]
		var choice := await box.choose("Sleep? %s will spoil tonight." % spoiling, ["Sleep anyway", "Not yet"], "", [], details)
		box.close()
		player.can_act = true
		if choice == 0:
			sleep_requested.emit()
		return
	var sleep_note := "End the day here, as usual."
	if spoiling != "":
		sleep_note += " %s will spoil tonight." % spoiling
	var details := [
		{"title": "Sleep", "rows": [], "facts": "Wake up tomorrow", "note": sleep_note},
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
