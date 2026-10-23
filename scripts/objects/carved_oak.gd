class_name CarvedOak
extends InfoSign
## The old black oak at the edge of the Ahwahnee's Tea Lawn. Wild grape hangs
## over its trunk until the head chef pulls it aside at the end of his side
## story (data/quests/ahwahnee_chef_larder.tres), and then you can see the
## face carved into the bark. Art: tools/hubs/ahwahnee32/carved_tree.py.
##
## The carving is invented, and what it shows is pending tribal review (see
## docs/CAST.md, "Ahwahnee staff").

## The quest that pulls the vines aside.
@export var revealed_after_quest := "ahwahnee_chef_larder"
@export var hidden_texture: Texture2D
@export var revealed_texture: Texture2D
## What the oak says once the carving can be seen, in place of [member text].
@export_multiline var revealed_text := ""


func _ready() -> void:
	QuestLog.changed.connect(_refresh)
	_refresh()


func is_revealed() -> bool:
	return QuestLog.is_completed(revealed_after_quest)


func _refresh() -> void:
	var sprite := get_node_or_null("Sprite") as Sprite2D
	var texture := revealed_texture if is_revealed() else hidden_texture
	if sprite and texture:
		sprite.texture = texture


func get_prompt() -> String:
	return "Look: %s" % title


func current_text() -> String:
	return revealed_text if is_revealed() and revealed_text != "" else text
