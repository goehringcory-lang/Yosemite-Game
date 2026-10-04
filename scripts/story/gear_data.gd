class_name GearData
extends Resource
## One piece of climbing gear. Gear only comes from quest rewards, and
## climbing routes list the gear they need (see RouteData).

@export var id: String
@export var display_name: String
@export_multiline var description: String
## Painted icon used in the journal. Files live in res://assets/sprites/gear/.
@export var icon: Texture2D
## Rough progression tier (0-4), used to sort the gear list.
@export var tier := 0
