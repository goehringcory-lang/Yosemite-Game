class_name Deer
extends Wanderers
## Mule deer that wander by as you go about outdoors (see Wanderers), more
## often than the bears: a doe or a few grazing their way across, a buck on
## his own in fall, and in summer a doe with a spotted fawn or two. Come too
## close and they lift their heads and stare with those big ears up, then go
## off in the bounds mule deer are known for, all four feet at once.
##
## They're in the Valley all year (many come down from the high country for
## the winter), most of all at dawn and dusk. Their coats are reddish in
## spring and summer and gray from fall; bucks carry antlers from summer
## (in velvet) through the fall rut into winter, and shed them in spring.

const SEASON_CHANCE := [1.0, 1.1, 1.2, 0.8]
## The rows of MuleDeer.SHEET.
const LOOKS := ["doe_summer", "doe_winter", "buck_summer", "buck_winter"]
## The chance a summer doe has fawns, and that a summer or fall deer, or an
## early winter one, is a buck on his own.
const FAWNS_CHANCE := 0.4
const BUCK_CHANCE := 0.3
const NOTICE_DISTANCE := 120.0
const SPOT_DISTANCE := 200.0


func _init() -> void:
	animal_id = "mule_deer"
	check_every = 10.0
	base_chance = 0.3
	season_chance = SEASON_CHANCE
	first_hour = 5
	last_hour = 21
	dawn = [5, 9]
	dusk = [16, 21]
	cooldown_time = 50.0
	walk_speed = 26.0
	leave_speed = 115.0
	bolt_speed = 140.0
	notice_distance = NOTICE_DISTANCE
	bolt_distance = 150.0
	watch_time = 1.2
	spot_distance = SPOT_DISTANCE


func _new_animal() -> Wanderer:
	return MuleDeer.new()


## The row for a doe or buck in this season's coat.
static func look_for(buck: bool, season: int) -> int:
	var gray := season == GameClock.Season.FALL or season == GameClock.Season.WINTER
	return (2 if buck else 0) + (1 if gray else 0)


func _spawn_group(at: Vector2, to: Vector2) -> void:
	var season := GameClock.season
	if season != GameClock.Season.SPRING and _rng.randf() < BUCK_CHANCE:
		add_group(at, to, look_for(true, season))
	elif season == GameClock.Season.SUMMER and _rng.randf() < FAWNS_CHANCE:
		add_group(at, to, look_for(false, season), 1 + int(_rng.randf() < 0.5))
	else:
		add_group(at, to, look_for(false, season), _rng.randi_range(0, 2), false)
