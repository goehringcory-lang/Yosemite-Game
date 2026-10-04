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
##   "talk"       target (character id): go and talk to someone
##   "chuckah"    count: have built this many chuckahs
##   "stored"     count: have this many acorns stored in your chuckahs
##   "made"       recipe, count: have made a recipe this many times
##   "climbed"    route (route id): have finished this climb
##   "return"     nothing: just come back and talk to the quest giver
## Every step except "talk" is turned in by talking to the quest giver.

@export var id: String
@export var title: String
## Character id of the person who gives the quest.
@export var giver: String
## Quest ids that must be finished before this one is offered.
@export var requires: PackedStringArray
@export var intro: PackedStringArray
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
