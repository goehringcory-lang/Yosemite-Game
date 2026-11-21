class_name FindSpot
extends Node2D
## One hidden find (Finds) lying off the path: the thing itself, half sunk in
## the grass and a little darker than the ground around it, and every so
## often a faint blue-white twinkle (slower and cooler than a forage find's
## gold Glint, so the two don't read alike). Out of season, or outside its
## hours, it isn't there at all. Interact to take it, once.

## Its id in data/park/finds.json.
var find_id := ""

var _sprite: Sprite2D
var _hitbox: Area2D
var _twinkle: FindTwinkle
var _check := 0.0


func _ready() -> void:
	add_to_group("find_spot")
	var find := Finds.get_find(find_id)
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture = Finds.icon_of(find)
	# Icons are 32 px; on the ground a find is half that, like forage.
	if _sprite.texture and _sprite.texture.get_width() > 16:
		_sprite.scale = Vector2.ONE * 16.0 / _sprite.texture.get_width()
	_sprite.offset = Vector2(0, -12) if _sprite.texture and _sprite.texture.get_width() > 16 else Vector2(0, -6)
	# Half hidden: darker, and leaning, as if dropped.
	_sprite.modulate = Color(0.78, 0.78, 0.8)
	_sprite.rotation = deg_to_rad(-14.0 if hash(find_id) % 2 == 0 else 12.0)
	add_child(_sprite)
	_hitbox = Area2D.new()
	_hitbox.name = "Hitbox"
	_hitbox.collision_layer = 4
	_hitbox.collision_mask = 0
	_hitbox.monitoring = false
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 24)
	shape.shape = rect
	shape.position = Vector2(0, -4)
	_hitbox.add_child(shape)
	add_child(_hitbox)
	if not Settings.low():
		_twinkle = FindTwinkle.new()
		_twinkle.position = Vector2(4, -9)
		add_child(_twinkle)
	_refresh()


func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 1.0
		_refresh()


## Shows it while it's out (Finds.is_out), and goes once it's found.
func _refresh() -> void:
	if Finds.is_found(find_id):
		queue_free()
		return
	var out := Finds.is_out(Finds.get_find(find_id))
	visible = out
	_hitbox.monitorable = out


func get_prompt() -> String:
	return "Look: %s" % Finds.get_find(find_id).get("title", "Something")


func interact(player: Player) -> void:
	if not visible or not is_inside_tree() or is_queued_for_deletion():
		return
	var find := Finds.get_find(find_id)
	if not Finds.take(find_id):
		return
	PickupPop.spawn(_sprite, player)
	player.pose("crouch", Player.PICK_TIME)
	get_tree().call_group("hud", "show_find", find)
	get_parent().remove_child(self)
	queue_free()
