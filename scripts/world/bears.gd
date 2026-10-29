class_name Bears
extends Wanderers
## Black bears that wander by now and then as you go about outdoors (see
## Wanderers): one ambles in, noses about and goes off the other side, and
## if you come too close it lifts its head to look at you, then moves off,
## at a lope if you run at it.
##
## They are Yosemite's own: American black bears, which here are mostly
## brown or cinnamon, some blond, and only some black. (The grizzly on the
## state flag is gone from California.) They're about from spring to fall,
## most of all in fall when they eat all day to fatten up for winter, hardly
## ever in winter, and more at dawn and dusk than midday. Near a campground
## with bear boxes they come round more at dusk. In spring and summer a
## mother may have a cub or two at her heels.

const SEASON_CHANCE := [0.7, 1.0, 1.6, 0.06]
## The chance a spring or summer bear is a mother with cubs.
const CUBS_CHANCE := 0.35
## Coats and how common each is (the rows of Bear.SHEET).
const COATS := ["brown", "cinnamon", "blond", "black"]
const COAT_WEIGHTS := [0.45, 0.3, 0.1, 0.15]
const NOTICE_DISTANCE := 150.0
## Bears are big: this close and on screen is a good enough look.
const SPOT_DISTANCE := 260.0
const NOTICE_MESSAGE := "The bear lifts its head and looks at you. Give it room: at least 50 yards, half a football field."


func _init() -> void:
	animal_id = "black_bear"
	check_every = 12.0
	base_chance = 0.22
	season_chance = SEASON_CHANCE
	first_hour = 5
	last_hour = 22
	cooldown_time = 70.0
	walk_speed = 32.0
	leave_speed = 58.0
	bolt_speed = 110.0
	notice_distance = NOTICE_DISTANCE
	bolt_distance = 110.0
	watch_time = 1.6
	spot_distance = SPOT_DISTANCE
	notice_message = NOTICE_MESSAGE


func _new_animal() -> Wanderer:
	return Bear.new()


func _place_odds(odds: float, at_dusk: bool) -> float:
	return odds * 1.5 if at_dusk and _has_bear_boxes(_region()) else odds


static func _has_bear_boxes(region: Region) -> bool:
	if region == null or region.entities == null:
		return false
	for node in region.entities.get_children():
		if "BearBox" in String(node.name):
			return true
	return false


func _spawn_group(at: Vector2, to: Vector2) -> void:
	var season := GameClock.season
	var cubs := 0
	if (season == GameClock.Season.SPRING or season == GameClock.Season.SUMMER) and _rng.randf() < CUBS_CHANCE:
		cubs = 1 + int(_rng.randf() < 0.5)
	add_group(at, to, _pick(COAT_WEIGHTS), cubs)
