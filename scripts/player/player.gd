class_name Player
extends CharacterBody2D
## The player: movement, facing, and talking to or using whatever is in front of them.

const SPEED := 160.0
## Holding the run button multiplies the walking speed by this.
const RUN_BOOST := 1.75

var facing := Vector2i.DOWN
## Set to false during cutscenes, menus, and sleeping.
var can_act := true

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var interaction_area: Area2D = $InteractionArea


func _ready() -> void:
	add_to_group("persist")
	add_child(Footfall.new())


## The interactable in front of the player, or null.
func get_target() -> Node:
	for area in interaction_area.get_overlapping_areas():
		var target := area.get_parent()
		if target.has_method("interact"):
			return target
	return null


## A short verb for [param target], shown in the HUD prompt ("Talk", "Read").
static func prompt_for(target: Node) -> String:
	if target.has_method("get_prompt"):
		return target.call("get_prompt")
	if target is NPC:
		return "Talk to %s" % target.character.display_name if target.character else "Talk"
	if target is ClimbStart:
		return "Climb %s" % target.route.display_name if target.route else "Climb"
	if target is Station:
		return "Use %s" % target.display_name
	if target.has_signal("sleep_requested"):
		return "Sleep"
	return "Use"


func _physics_process(_delta: float) -> void:
	var input := Vector2.ZERO
	if can_act:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var running := input != Vector2.ZERO and Input.is_action_pressed("run")
	velocity = input * SPEED * (1.0 + Perks.bonus("muirs_stride")) * (RUN_BOOST if running else 1.0)
	move_and_slide()

	if input != Vector2.ZERO:
		if absf(input.x) > absf(input.y):
			facing = Vector2i(signi(roundi(input.x)), 0)
		else:
			facing = Vector2i(0, signi(roundi(input.y)))
		interaction_area.position = Vector2(facing) * 24.0
	sprite.speed_scale = RUN_BOOST if running else 1.0
	sprite.play(("walk_" if input != Vector2.ZERO else "idle_") + _direction_name())


func _unhandled_input(event: InputEvent) -> void:
	# There are no tools any more, so the tool button interacts too.
	if can_act and (event.is_action_pressed("interact") or event.is_action_pressed("use_tool")):
		get_viewport().set_input_as_handled()
		_interact()
	elif can_act and event.is_action_pressed("gift"):
		var target := get_target()
		if target and target.has_method("receive_gift"):
			get_viewport().set_input_as_handled()
			target.receive_gift(self)


func _interact() -> void:
	var target := get_target()
	if target:
		target.interact(self)


func _direction_name() -> String:
	match facing:
		Vector2i.UP:
			return "up"
		Vector2i.LEFT:
			return "left"
		Vector2i.RIGHT:
			return "right"
	return "down"


func save_data() -> Dictionary:
	return {"x": position.x, "y": position.y, "facing_x": facing.x, "facing_y": facing.y}


func load_data(data: Dictionary) -> void:
	position = Vector2(data.get("x", position.x), data.get("y", position.y))
	facing = Vector2i(int(data.get("facing_x", 0)), int(data.get("facing_y", 1)))
	interaction_area.position = Vector2(facing) * 24.0


func _draw() -> void:
	GroundShadow.draw_under(self)
