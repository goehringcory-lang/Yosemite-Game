class_name Forageable
extends Node2D
## A wild item lying on the ground. Interact to pick it up.

## Set by ForageSpawner before the node enters the tree.
var item: ItemData
var cell: Vector2i

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	sprite.texture = item.icon


func interact(player: Player) -> void:
	# Two presses in one frame (E and Space) must not pick it up twice.
	if not is_inside_tree() or is_queued_for_deletion():
		return
	PickupPop.spawn(sprite, player)
	Inventory.add(item.id)
	Perks.note("forage")
	get_tree().call_group("hud", "show_message", "Found %s! %s" % [item.display_name, item.description])
	get_parent().remove_child(self)
	queue_free()
