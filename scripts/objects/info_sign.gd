class_name InfoSign
extends StaticBody2D
## An interpretive sign. Interact to read it.

@export var title := ""
@export_multiline var text := ""


func get_prompt() -> String:
	return "Read: %s" % title


func interact(_player: Player) -> void:
	get_tree().call_group("hud", "show_info", title, text)
