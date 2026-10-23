class_name CharacterData
extends Resource
## A real historical person the player can meet (or, with [member visitor] or
## [member staff], an invented one).
##
## Every character must be researched before their dialogue ships. Native
## characters also need review by the tribes traditionally associated with
## Yosemite; set [member needs_tribal_review] until that review is done.

@export var id: String
@export var display_name: String
## For example "1908–1993". Leave empty until the dates are confirmed.
@export var years: String
## Tribe, nation, or organization, in that group's own preferred spelling.
@export var affiliation: String
## Short, sourced biography for the in-game journal.
@export_multiline var bio: String
## Things they say when they have no quest for you.
@export var idle_lines: PackedStringArray
## Optional: a rarer thing they say instead of [member idle_lines], about one
## talk in [member rare_chance], once the quest [member rare_after_quest] is
## done (empty means from the start).
@export var rare_lines: PackedStringArray
@export var rare_after_quest := ""
@export_range(0.0, 1.0) var rare_chance := 0.2
## Story beats: what they say as the main line moves on, each heard once in
## place of [member idle_lines]. Each is a Dictionary
## {"after": quest id, "lines": [...]}, in story order. Only the latest beat
## whose quest is done is offered, so a player who rushes ahead never hears
## stale news. A beat after "clark_last_page" is their epilogue.
@export var story_beats: Array = []
## 48×96 walking sheet (3 frames × 4 facings, like the player's). Drawn by
## tools/npcgen; the NPC falls back to a plain figure in [member color] without one.
@export var sprite_sheet: Texture2D
## Placeholder sprite color, used when there's no sprite sheet.
@export var color := Color(0.5, 0.4, 0.3)
## Where they spend their days, for the journal: "Degnan's Bakery", "Camp 4".
@export var home: String
## Their part in making the park what it is, one plain sentence for the
## Journal's list of the valley's keepers (GuardianSearch.keepers). Facts
## only, like [member bio]: what they did, not what they'd say.
@export_multiline var legacy := ""
## The year that part began, to put the keepers in order.
@export var legacy_year := 0
## Optional: where they spend their days early in the story, until the quest
## [member early_until] is done. Enid Michael keeps the Museum's garden until
## the way to Glacier Point opens, then goes up to Sentinel Dome. An NPC node
## can stand at either home (see NPC.stays).
@export var early_home := ""
@export var early_until := ""
## An everyday park visitor from one of the park's eras, not a historical figure. Visitors
## only chat: they never give quests or appear in the Register.
@export var visitor := false
## Invented staff (the Mountain Shop's, the Ahwahnee's chef), not historical
## figures. Unlike visitors they can give quests and partner on climbs, but
## they never appear in the Register. They live in QuestLog.STAFF, not
## QuestLog.CHARACTERS.
@export var staff := false

@export_group("Review")
## True until the associated tribes have reviewed this character and their dialogue.
@export var needs_tribal_review := false
## Where the facts in the bio and dialogue come from.
@export_multiline var sources: String


## What they say when they have no quest for you. [param rare_unlocked] is
## whether [member rare_after_quest] is done; [param roll] is a random 0 to 1.
func idle_lines_for(rare_unlocked: bool, roll := randf()) -> PackedStringArray:
	if not rare_lines.is_empty() and rare_unlocked and roll < rare_chance:
		return rare_lines
	return idle_lines


## The latest story beat whose quest [param is_done] reports finished, as
## {"key", "lines"}, or {} before the first. "key" names the beat, so the
## QuestLog can remember it was heard.
func latest_beat(is_done: Callable) -> Dictionary:
	for i in range(story_beats.size() - 1, -1, -1):
		var beat: Dictionary = story_beats[i]
		if is_done.call(beat.after):
			return {"key": "%s:%s" % [id, beat.after], "lines": PackedStringArray(beat.lines)}
	return {}


## True while they're still at [member early_home]. [param is_done] reports
## whether a quest is finished (QuestLog.is_completed).
func at_early_home(is_done: Callable) -> bool:
	return early_until != "" and not is_done.call(early_until)


## Where to find them now: [member early_home] or [member home].
func home_now(is_done: Callable) -> String:
	return early_home if at_early_home(is_done) and early_home != "" else home
