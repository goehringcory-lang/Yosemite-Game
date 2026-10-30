class_name Player
extends CharacterBody2D
## The player: movement, facing, and talking to or using whatever is in front of them.

const SPEED := 160.0
## Holding the run button multiplies the walking speed by this.
const RUN_BOOST := 1.75

var facing := Vector2i.DOWN
## Set to false during cutscenes, menus, and sleeping.
var can_act := true

## Walking frames a second, and running ones (a run's strides come quicker).
const WALK_FPS := 8.0
const RUN_FPS := 12.0
## Carrying someone, you plod.
const CARRY_FPS := 5.5
## Standing about this long, you look round now and then, and after a
## while longer stretch your arms up.
const GLANCE_AFTER := 6.0
const STRETCH_AFTER := 24.0
## Crouched this long to pick something up.
const PICK_TIME := 0.45

@onready var sprite: Sprite2D = $Sprite
@onready var interaction_area: Area2D = $InteractionArea
## Casting from the bank, the thing to use when you face water with a rod.
var fishing := Fishing.new()
## A pose held over whatever you'd otherwise be doing (see [method pose]),
## and the seconds left on it (negative: until [method clear_pose]).
var action := ""
var _action_left := 0.0
## Seconds into the walk cycle, seconds standing still, and the look round
## you're giving while you stand.
var _stride := 0.0
var _idle := 0.0
var _glance := Vector2i.ZERO
var _glance_left := 0.0
var _stretched := false
var _asleep := false


func _ready() -> void:
	add_to_group("persist")
	add_child(Footfall.new())
	add_child(fishing)
	add_child(SmoothMotion.new())


## The interactable in front of the player, or null. One with a higher
## interact_priority wins (a building's door over the building's sign); among
## equals (a person by a sign), the one nearest the middle of the reach wins,
## so the prompt names what you're facing rather than whichever came first.
## With nothing there, facing water with a fly rod, it's the water (Fishing).
func get_target() -> Node:
	var best: Node = null
	var best_priority := -1
	var best_distance := INF
	var reach := interaction_area.global_position
	for area in interaction_area.get_overlapping_areas():
		var target := area.get_parent()
		if not target.has_method("interact"):
			continue
		var priority: int = target.get("interact_priority") if "interact_priority" in target else 0
		var distance := reach.distance_squared_to(area.global_position)
		if priority > best_priority or (priority == best_priority and distance < best_distance):
			best = target
			best_priority = priority
			best_distance = distance
	if best == null and Fishing.can_fish(self):
		return fishing
	return best


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
	velocity = input * SPEED * (1.0 + Perks.bonus("muirs_stride")) * (RUN_BOOST if running else 1.0) * Rescues.speed_factor()
	move_and_slide()
	if input != Vector2.ZERO and _action_left != 0.0:
		# walking off ends a crouch or a wave
		clear_pose()

	if input != Vector2.ZERO:
		if absf(input.x) > absf(input.y):
			facing = Vector2i(signi(roundi(input.x)), 0)
		else:
			facing = Vector2i(0, signi(roundi(input.y)))
		interaction_area.position = Vector2(facing) * 24.0
	_animate(_delta, input != Vector2.ZERO, running)


## Holds [param name] ("crouch", "arms_up", "reach", "carry", "talk") for
## [param seconds], or until [method clear_pose] when negative: foraging,
## casting, a stretch.
func pose(name: String, seconds := -1.0) -> void:
	action = name
	_action_left = seconds
	_idle = 0.0


func clear_pose() -> void:
	action = ""
	_action_left = 0.0


## Lies down to sleep (on your back, eyes shut), or gets up again.
func lie_down(asleep := true) -> void:
	_asleep = asleep
	clear_pose()
	sprite.rotation = -PI / 2.0 if asleep else 0.0
	# lying down, your middle is where your feet were
	sprite.position = Vector2(-22, -8) if asleep else Vector2.ZERO
	sprite.frame = CharacterSheet.frame(sprite.texture, Vector2i.DOWN, CharacterSheet.Col.BLINK)


## Picks the frame: the walk or run cycle, a held pose, or standing about
## (blinking, a look round, a stretch after a long wait).
func _animate(delta: float, moving: bool, running: bool) -> void:
	if _asleep:
		return
	var sheet := sprite.texture
	var carrying := Rescues.current_stage() == "carry"
	if _action_left > 0.0:
		_action_left = maxf(_action_left - delta, 0.0)
		if _action_left == 0.0:
			action = ""
	var col: int = CharacterSheet.Col.STAND
	var look := facing
	if moving:
		_idle = 0.0
		_glance_left = 0.0
		_stretched = false
		var fps := CARRY_FPS if carrying else (RUN_FPS if running else WALK_FPS)
		_stride += delta * fps
		var cycle: Array = CharacterSheet.CARRY_WALK if carrying else (CharacterSheet.RUN if running else CharacterSheet.WALK)
		col = cycle[int(_stride) % cycle.size()]
	else:
		_stride = 0.0
		if can_act:
			_idle += delta
		if action != "":
			col = _pose_column(action)
		elif carrying:
			col = CharacterSheet.Col.CARRY
		else:
			col = _idle_column(delta)
			if _glance_left > 0.0:
				look = _glance
	sprite.frame = CharacterSheet.frame(sheet, look, col)


func _pose_column(name: String) -> int:
	match name:
		"crouch":
			return CharacterSheet.Col.CROUCH
		"arms_up":
			return CharacterSheet.Col.ARMS_UP
		"reach":
			return CharacterSheet.Col.REACH
		"carry":
			return CharacterSheet.Col.CARRY
		"talk":
			return CharacterSheet.Col.TALK
	return CharacterSheet.Col.STAND


## Standing about: a blink every few seconds, a look round once you've
## stood a while, and one long stretch.
func _idle_column(delta: float) -> int:
	if _glance_left > 0.0:
		_glance_left -= delta
	elif _idle > GLANCE_AFTER and fmod(_idle, GLANCE_AFTER) < delta:
		var turns: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]
		turns.erase(facing)
		_glance = turns[int(_idle / GLANCE_AFTER) % turns.size()]
		_glance_left = 1.1
	if _idle > STRETCH_AFTER and not _stretched:
		_stretched = true
		pose("arms_up", 1.0)
		if GameClock.hour >= 21 or GameClock.hour < 6:
			Emote.pop(self, "sleep") # a yawn, late at night
		return CharacterSheet.Col.ARMS_UP
	if CharacterSheet.blinking(Time.get_ticks_msec() / 1000.0, 7):
		return CharacterSheet.Col.BLINK
	return CharacterSheet.Col.STAND


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


func save_data() -> Dictionary:
	return {"x": position.x, "y": position.y, "facing_x": facing.x, "facing_y": facing.y}


func load_data(data: Dictionary) -> void:
	position = Vector2(data.get("x", position.x), data.get("y", position.y))
	facing = Vector2i(int(data.get("facing_x", 0)), int(data.get("facing_y", 1)))
	interaction_area.position = Vector2(facing) * 24.0


func _draw() -> void:
	GroundShadow.draw_under(self)
