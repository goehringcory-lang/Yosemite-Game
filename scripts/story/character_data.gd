class_name CharacterData
extends Resource
## A real historical person the player can meet.
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
## 48×96 walking sheet (3 frames × 4 facings, like the player's). Drawn by
## tools/npcgen; the NPC falls back to a plain figure in [member color] without one.
@export var sprite_sheet: Texture2D
## Placeholder sprite color, used when there's no sprite sheet.
@export var color := Color(0.5, 0.4, 0.3)
## Where they spend their days, for the journal: "Degnan's Bakery", "Camp 4".
@export var home: String
## An everyday park visitor from one of the park's eras, not a historical figure. Visitors
## only chat: they never give quests or appear in the Register.
@export var visitor := false

@export_group("Review")
## True until the associated tribes have reviewed this character and their dialogue.
@export var needs_tribal_review := false
## Where the facts in the bio and dialogue come from.
@export_multiline var sources: String
