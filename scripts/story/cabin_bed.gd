extends "res://scripts/objects/tent.gd"
## The rope bed in your cabin: it sleeps like your tent does (and offers to
## sleep through to the thaw), except on the night of the supper after the
## cave, which ends at the fire outside, so it sends you out to your tent.


func interact(player: Player) -> void:
	if GuardianFeast.is_pending():
		get_tree().call_group("hud", "show_message", "Everyone's waiting for you round the fire. Turn in at your tent tonight.")
		return
	await super.interact(player)
