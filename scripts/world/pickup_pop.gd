class_name PickupPop
extends Sprite2D
## The picture of something you just picked up: it hops up off the ground,
## then flies into the player and is gone. Purely for show; the item is
## already in the pack when this starts.
##
##   PickupPop.spawn(sprite, player)

const HOP := 20.0
const HOP_TIME := 0.16
const FLY_TIME := 0.18

var _player: Node2D


## Copies [param from]'s picture and position, and sends it to [param player].
static func spawn(from: Sprite2D, player: Node2D) -> void:
	if from == null or from.texture == null or player == null or not from.is_inside_tree():
		return
	var pop := PickupPop.new()
	pop.texture = from.texture
	pop.offset = from.offset
	pop._player = player
	# Beside the player, not under the spawner: code walks the spawner's children.
	player.get_parent().add_child(pop)
	pop.global_position = from.global_position
	pop.z_index = 5


func _ready() -> void:
	var start := position
	var tween := create_tween()
	tween.tween_property(self, "position:y", start.y - HOP, HOP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_fly.bind(start - Vector2(0, HOP)), 0.0, 1.0, FLY_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


## Moves from [param from] toward the player's chest, shrinking as it goes.
func _fly(t: float, from: Vector2) -> void:
	if not is_instance_valid(_player):
		return
	var to: Vector2 = (get_parent() as Node2D).to_local(_player.global_position + Vector2(0, -20))
	position = from.lerp(to, t)
	scale = Vector2.ONE * lerpf(1.0, 0.4, t)
	modulate.a = lerpf(1.0, 0.6, t)
