class_name StoryPickup
extends Node2D
## A one-of-a-kind item lying somewhere in the park, like the old axle
## John Salathé needs. It can be picked up once, and stays gone after saving.
## Give each one a node name that is unique across the project.

@export var item_id: String
## Shown when it's picked up, after the item's own description.
@export_multiline var found_text: String

var taken := false

@onready var sprite: Sprite2D = $Sprite
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	add_to_group("persist")
	var item := ItemDB.get_item(item_id)
	if item:
		sprite.texture = item.icon
	_refresh()


func interact(_player: Player) -> void:
	if taken:
		return
	var item := ItemDB.get_item(item_id)
	Inventory.add(item_id)
	taken = true
	_refresh()
	var text := "Found %s! %s" % [item.display_name, item.description] if item else "Found %s!" % item_id
	if found_text != "":
		text += " " + found_text
	get_tree().call_group("hud", "show_message", text)


func _refresh() -> void:
	visible = not taken
	hitbox.set_deferred("monitorable", not taken)


func save_data() -> Dictionary:
	return {"taken": taken}


func load_data(data: Dictionary) -> void:
	taken = data.get("taken", false)
	if is_node_ready():
		_refresh()
