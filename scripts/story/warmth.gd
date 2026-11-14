class_name Warmth
extends RefCounted
## Winter cold, and the down puffy that keeps it off.
##
## Marty at the Mountain Shop sets a down jacket aside for you in summer and
## fall (quest "shop_puffy", "Down Before the Snow"). Without it, winter is
## harder but never dangerous:
##   - Outdoors in winter you walk a little slower, hunched against the cold,
##     and now and then a snowflake bubble pops up over your head
##     (Player, [method speed_factor], [method is_cold]).
##   - On the wall, a night without a portaledge leaves you stiff and the
##     afternoon snow goes to slush (ClimbState.has_puffy cancels both).
## With the jacket, both go away for good. The quest stays on offer all
## winter, so missing the deadline never locks you out.
##
## The mornings of late fall carry a nudge until you have it
## ([method morning_note]).
##
## The jacket's name lives in data/gear/puffy_jacket.tres, the quest's lines in
## data/quests/shop_puffy.tres and the pickup's in data/story_items/torn_puffy.tres.

const JACKET := "puffy_jacket"
const QUEST := "shop_puffy"
## Walking speed outdoors in winter without the jacket.
const COLD_SPEED := 0.85
## Seconds between shivers (the snowflake bubble) while you're out in the cold.
const SHIVER_EVERY := 14.0
## Late-fall mornings that remind you, while the quest is open or not started.
const NUDGES := {
	15: "Frost on the meadow this morning. Marty at the Mountain Shop still has a down jacket set aside for you.",
	24: "Your breath smokes in the morning air. The snow's coming soon: get that puffy from Marty.",
}
const FIRST_SNOW_NOTE := "Winter's here, and you've no down jacket. You'll walk slower out in the cold. Marty at the Mountain Shop can still fit you."

## Set by World as the player arrives in a region: false indoors.
static var outdoors := true


static func has_jacket() -> bool:
	return Gear.count(JACKET) > 0


## True while the winter cold gets to you: outdoors, in winter, no jacket.
static func is_cold() -> bool:
	return outdoors and GameClock.season == GameClock.Season.WINTER and not has_jacket()


## What the cold does to your walking speed (1 when it doesn't).
static func speed_factor() -> float:
	return COLD_SPEED if is_cold() else 1.0


## Whether Marty would remind you: you have your first kit from him, and not
## yet the jacket.
static func needs_reminding() -> bool:
	return QuestLog.is_completed("shop_outfit") and not has_jacket() and not QuestLog.is_completed(QUEST)


## A line for the good-morning message, or "" for none: on two late-fall
## mornings, and on the first morning of winter, while you have no jacket.
static func morning_note(season := -1, day := -1) -> String:
	if season < 0:
		season = GameClock.season
	if day < 0:
		day = GameClock.day
	if not needs_reminding():
		return ""
	if season == GameClock.Season.FALL and NUDGES.has(day):
		return NUDGES[day]
	if season == GameClock.Season.WINTER and day == 1:
		return FIRST_SNOW_NOTE
	return ""
