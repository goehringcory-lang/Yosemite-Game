class_name QuestData
extends Resource
## One quest: a person asks for help, you complete the steps, and they
## reward you with gear, recipes, or new abilities.
##
## Each step is a Dictionary with a "type" and these text keys:
##   "objective": short line for the quest list ("Gather 12 black oak acorns")
##   "reminder":  what the giver says while the step isn't done yet
##   "done":      what they say when you complete it (Array of lines)
##
## Step types and their other keys:
##   "have"       item, count, consume (bool): carry this many of an item
##   "have_food"  energy: carry edible food worth at least this much energy
##   "pay"        energy: trade food worth this much energy (it's taken, the
##                soonest to spoil first, when you turn the step in)
##   "talk"       target (character id): go and talk to someone
##   "chuckah"    count: have built this many chuckahs
##   "stored"     count: have this many acorns stored in your chuckahs
##   "made"       recipe, count: have made a recipe this many times
##   "climbed"    route (route id): have finished this climb
##   "return"     nothing: just come back and talk to the quest giver
##   "time"       from, to (hours, 0-23): talk to the giver between these
##                hours. The range wraps past midnight, so 20 to 2 means
##                8 PM until 2 AM (see GameClock.hour_in_range).
##   "pressed"    plants (plant ids), count, hub: have these plants in the
##                press book, and at least this many in all (of those that
##                grow in that hub, if one is named; see Herbarium)
##   "unlocked"   ability: have this ability (set by something in the world,
##                like the mirror in the Guardian's cave)
##   "work"       task, count: have done this many of the task's work spots
##                around the park (Stewardship.SPOTS), like resetting steps
##                on the Mist Trail
## Every step except "talk" is turned in by talking to the quest giver.
##
## Any step can also hand the player something the moment it's done:
##   "unlock": ability id (for example "guidebook")
##   "gear":   gear id -> count
##   "items":  item id -> count
## Main-line quests (see [member main_line]) end on a "climbed" step, so they
## finish only after the route is ticked in the guidebook.

@export var id: String
@export var title: String
## Part of the main storyline: the quests that follow the guidebook's tick
## list. Everything else is a side story.
@export var main_line := false
## Part of the press book's storyline, which runs beside the tick list: the
## naturalists and rangers who ask for plants. The finale needs both.
@export var press_line := false
## Part of the Guardian's Year, the year of stewardship after the finale:
## one arc a season, each ending in a change you can see on the map (see
## Stewardship).
@export var guardian_line := false
## Character id of the person who gives the quest.
@export var giver: String
## Quest ids that must be finished before this one is offered.
@export var requires: PackedStringArray
## Seasons the giver offers this quest in (none ticked = any season). Once
## it's started it can be finished in any season.
@export_flags("Spring", "Summer", "Fall", "Winter") var offered_in := 0
## What the giver says while the quest is ready except for the season, so
## the player knows to come back ("Come and see me when the snow flies").
@export var out_of_season: PackedStringArray
## What the giver says while every main-line quest in [member requires] is
## done but a side story the quest still waits on isn't, so the player knows
## who to go and see. Quest id -> line, checked in order; the first one not
## yet finished is said. Galen Clark uses it to name who hasn't been heard
## before the last page.
@export var waiting_on: Dictionary = {}
@export var intro: PackedStringArray
## Abilities handed over the moment the quest starts, such as the plant
## press that Enid Michael's first quest is about.
@export var start_unlocks: PackedStringArray
@export var steps: Array = []
@export var outro: PackedStringArray

@export_group("Rewards")
## Gear id -> count.
@export var reward_gear: Dictionary = {}
## Item id -> count.
@export var reward_items: Dictionary = {}
@export var reward_recipes: PackedStringArray
## Named abilities other systems check, such as "chuckah" (can build one).
## "hub:<id>" also unlocks that hub, for example "hub:tuolumne_meadows".
@export var reward_unlocks: PackedStringArray


## Whether the giver offers this quest in [param season] (a GameClock.Season).
func is_offered_in(season: int) -> bool:
	return offered_in == 0 or offered_in & (1 << season) != 0
