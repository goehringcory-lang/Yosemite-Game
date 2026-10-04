extends StaticBody2D
## Your campsite tent. Interact with it to sleep and start the next day.

signal sleep_requested


func interact(_player: Player) -> void:
	sleep_requested.emit()
