class_name ItemData
extends Resource
## Anything the player can carry: wild forage and prepared food. What food
## is worth on a climb (energy, shelf life) lives in FoodDB.

## FOREST (conifer shade) and HIGH_COUNTRY (lodgepole and granite sand) only
## exist on the generated hubs, not the hand-painted homestead.
enum Habitat { NONE, MEADOW, OAK_WOODLAND, CHAPARRAL, RIVERSIDE, FOREST, HIGH_COUNTRY }

@export var id: String
@export var display_name: String
## One line of natural history, shown when the player finds the item.
@export_multiline var description: String
@export var icon: Texture2D

@export_group("Foraging")
## Seasons when this item appears on the map. Leave empty for items you can only make.
@export_flags("Spring", "Summer", "Fall", "Winter") var forage_seasons := 0
## Where it spawns: meadow grass, under black oaks, beside manzanita, along
## the river, in the conifer forest, or up in the high country.
@export var habitat := Habitat.NONE
## How many appear each morning while in season.
@export var forage_per_day := 0
## Seasons at either end of its season, when only a few are left to find (or
## the first few are coming up): half as many appear, but always at least one.
@export_flags("Spring", "Summer", "Fall", "Winter") var lean_seasons := 0


func is_forageable_in(season: int) -> bool:
	return forage_per_day > 0 and (forage_seasons | lean_seasons) & (1 << season) != 0


## How many appear each morning in [param season] on a map that grows
## [param amount_scale] times the usual (see ForageSpawner.amount_scale).
func forage_count(season: int, amount_scale := 1.0) -> int:
	if not is_forageable_in(season):
		return 0
	var lean := forage_seasons & (1 << season) == 0
	return maxi(1, roundi(forage_per_day * amount_scale * (0.5 if lean else 1.0)))
