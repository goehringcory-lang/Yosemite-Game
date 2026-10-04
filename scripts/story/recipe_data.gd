class_name RecipeData
extends Resource
## One way to prepare food at a station (campfire, bedrock mortar, or
## leaching basin). The player has to learn a recipe before using it.

@export var id: String
@export var display_name: String
## Which station makes it: "campfire", "mortar", or "leaching".
@export var station := "campfire"
## Item id -> how many are used.
@export var inputs: Dictionary = {}
@export var output_id: String
@export var output_count := 1
## In-game minutes it takes.
@export var minutes := 60
## Shown in the recipe list.
@export_multiline var description: String
