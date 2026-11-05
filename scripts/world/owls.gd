class_name Owls
extends Wanderers
## Great gray owls hunting the high meadows (see Wanderers): one comes
## gliding low and silent over the grass, drops onto a vole with its talons
## out, sits a while turning that huge round face to listen, and glides on.
## Great grays pay people little mind: walk up slowly and it only turns its
## face your way before it drifts off.
##
## There are only a couple of hundred great gray owls in all of California,
## nearly all of them in and around Yosemite's mid-elevation meadows: Crane
## Flat, the meadows off the Big Oak Flat Road, and Wawona. They hunt mostly
## at dawn and dusk, by ear, and can hear a vole under a foot of snow.

const SEASON_CHANCE := [1.0, 1.0, 1.0, 0.8]
## The meadows they hunt.
const MEADOWS := ["crane_flat", "wawona", "big_oak_flat_junction"]
## In the middle of the day the odds are this much of the rest.
const MIDDAY := 0.25
const NOTICE_MESSAGE := "The great gray owl turns its huge round face toward you. It listens a moment, then glides off without a sound."


func _init() -> void:
	animal_id = "great_gray_owl"
	check_every = 10.0
	base_chance = 0.3
	season_chance = SEASON_CHANCE
	first_hour = 5
	last_hour = 21
	dawn = [5, 9]
	dusk = [16, 21]
	cooldown_time = 90.0
	walk_speed = 40.0
	leave_speed = 55.0
	bolt_speed = 90.0
	notice_distance = 80.0
	bolt_distance = 70.0
	watch_time = 2.6
	spot_distance = 220.0
	notice_message = NOTICE_MESSAGE
	max_wander = 50.0


func _new_animal() -> Wanderer:
	return GreatGrayOwl.new()


func _place_odds(odds: float, at_dusk: bool) -> float:
	var region := _region()
	if region == null or not region.region_id in MEADOWS:
		return 0.0
	var hour := GameClock.hour
	if not at_dusk and not (hour >= dawn[0] and hour < dawn[1]):
		odds *= MIDDAY
	return odds


## An owl flies: nothing on the ground is in its way.
func _walk(animal: Wanderer, delta: float, want: Vector2) -> void:
	animal.global_position += want * animal.speed * delta
	if absf(want.x) > 0.2:
		animal.facing = 1 if want.x > 0.0 else -1
	animal.steps += delta * animal.speed / walk_speed
