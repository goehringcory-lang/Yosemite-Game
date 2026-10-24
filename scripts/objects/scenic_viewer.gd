class_name ScenicViewer
extends StaticBody2D
## One of the coin-operated viewers on Glacier Point's railing. Step up and
## look through it (BinocularView): pan along the skyline and it names the
## peaks and falls you hold in its crosshairs. Each viewer starts pointed its
## own way ([member facing]), so the three on the point each frame a
## different part of the view.

## Which panorama it looks at (a key of BinocularView.VIEWS).
@export var view := "glacier_point"
## The bearing it's pointed at when you step up, in degrees.
@export var facing := 65.0


func get_prompt() -> String:
	return "Look: Binoculars"


func interact(player: Player) -> void:
	player.can_act = false
	var was_paused := GameClock.paused
	GameClock.paused = true
	var binoculars := BinocularView.new()
	binoculars.setup(view, facing)
	player.get_tree().root.add_child(binoculars)
	await binoculars.finished
	GameClock.paused = was_paused
	if is_instance_valid(player):
		player.can_act = true
