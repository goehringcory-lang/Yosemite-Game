class_name RescueSubject
extends Node2D
## The person you're looking for on a rescue call (Rescues), waiting where
## the prints end (RescueField places them), sitting tight with a little
## wave now and then. Walk up and talk to them to reach them.

const WAVE_EVERY := 2.4

var call: Dictionary = {}
var _sprite: Sprite2D
var _wave := 0.0


func setup(rescue_call: Dictionary, look: CharacterData) -> void:
	call = rescue_call
	if look and look.sprite_sheet:
		_sprite = Sprite2D.new()
		_sprite.texture = look.sprite_sheet
		_sprite.hframes = 3
		_sprite.vframes = 4
		_sprite.offset = Vector2(0, -22)
		var size := float(call.get("scale", 1.0))
		_sprite.scale = Vector2(size, size)
		add_child(_sprite)
	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 4
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(28, 32)
	shape.shape = box
	shape.position = Vector2(0, -14)
	hitbox.add_child(shape)
	add_child(hitbox)


func get_prompt() -> String:
	return "Help %s" % call.get("who", "them")


func interact(player: Player) -> void:
	# not awaited: reaching them can take this node away mid-conversation
	DialogueBox.say_to(player, Rescues.reach())


func _process(delta: float) -> void:
	if _sprite == null:
		return
	# a hand up now and then: a quick turn toward you and back
	_wave -= delta
	if _wave <= 0.0:
		_wave = WAVE_EVERY
	_sprite.frame = 1 if _wave < 0.3 else 0


func _draw() -> void:
	GroundShadow.draw_under(self)
