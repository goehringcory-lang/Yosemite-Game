class_name TrailheadSign
extends StaticBody2D
## A trailhead signpost Trailheads puts down beside a spot in its region
## (data/park/trailheads.json). Walking up to it finds it; interact to plan a
## trip to any other trailhead, campground or parking area you've found.

const TEXTURE := preload("res://assets/sprites/trailhead_sign.png")

@export var point_id := ""
@export var label := ""


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = TEXTURE
	sprite.offset = Vector2(0, -24)
	add_child(sprite)
	var post := CollisionShape2D.new()
	post.name = "Collision"
	var post_shape := RectangleShape2D.new()
	post_shape.size = Vector2(6, 4)
	post.shape = post_shape
	post.position = Vector2(0, -2)
	add_child(post)
	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 4
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	var reach := CollisionShape2D.new()
	reach.name = "Shape"
	var reach_shape := RectangleShape2D.new()
	reach_shape.size = Vector2(32, 44)
	reach.shape = reach_shape
	reach.position = Vector2(0, -20)
	hitbox.add_child(reach)
	add_child(hitbox)


func get_prompt() -> String:
	return "Plan a trip from %s" % label if label != "" else "Plan a trip"


func interact(player: Player) -> void:
	Trailheads.plan_trip(player, point_id)
