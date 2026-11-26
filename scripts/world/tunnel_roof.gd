class_name TunnelRoof
extends Sprite2D
## Rock hung over a walk-through tunnel (Hetch Hetchy's Wapama tunnel): drawn
## above everyone, it thins to see-through while the player is under it, so
## you can see yourself walk the tunnel, and fills back in once you're out.

## The tunnel's walkable stretch, in this node's parent's space.
@export var inside := Rect2()
## How see-through the rock gets with you inside (1 is solid).
@export var faded := 0.35
## How fast it fades either way, in alpha per second.
@export var speed := 3.0


func _process(delta: float) -> void:
	var target := 1.0
	var world := get_tree().get_first_node_in_group("world")
	var player: Node2D = world.get("player") if world else null
	if player and is_instance_valid(player) and get_parent() is Node2D:
		var at := (get_parent() as Node2D).to_local(player.global_position)
		if inside.has_point(at):
			target = faded
	modulate.a = move_toward(modulate.a, target, speed * delta)
