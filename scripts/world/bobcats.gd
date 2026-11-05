class_name Bobcats
extends Wanderers
## Now and then, and not often, a bobcat (see Wanderers): one comes slinking
## through the grass on its own, crouches and stalks a vole, pounces, and
## goes on. Come close and it freezes and stares at you, ear tufts up, then
## slips away; run at it and it's gone.
##
## Bobcats live all over the park but keep out of sight, so seeing one is
## luck. They hunt the meadows most at dawn and dusk, and in winter, when the
## voles run under the snow, Valley visitors see them more than in any other
## season.

const SEASON_CHANCE := [0.8, 0.7, 1.0, 1.5]
## Meadows they hunt, where one is twice as likely.
const MEADOWS := ["el_capitan_meadow", "leidig_meadow", "ahwahnee_meadow", "yosemite_village", "wawona", "crane_flat",
	"tuolumne_meadows", "mirror_lake", "big_oak_flat_junction"]
## In the middle of the day the odds are this much of the rest.
const MIDDAY := 0.4
const NOTICE_MESSAGE := "A bobcat! It freezes mid-stalk and stares at you, ear tufts up. Then it slips off into the grass."


func _init() -> void:
	animal_id = "bobcat"
	check_every = 15.0
	base_chance = 0.05
	season_chance = SEASON_CHANCE
	first_hour = 5
	last_hour = 21
	dawn = [5, 9]
	dusk = [16, 21]
	cooldown_time = 240.0
	walk_speed = 24.0
	leave_speed = 80.0
	bolt_speed = 150.0
	notice_distance = 130.0
	bolt_distance = 140.0
	watch_time = 2.2
	spot_distance = 210.0
	notice_message = NOTICE_MESSAGE
	max_wander = 40.0


func _new_animal() -> Wanderer:
	return Bobcat.new()


func _place_odds(odds: float, at_dusk: bool) -> float:
	var hour := GameClock.hour
	if not at_dusk and not (hour >= dawn[0] and hour < dawn[1]):
		odds *= MIDDAY
	var region := _region()
	if region and region.region_id in MEADOWS:
		odds *= 2.0
	return odds
