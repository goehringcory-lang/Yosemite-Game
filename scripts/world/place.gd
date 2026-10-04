class_name Place
extends Marker2D
## A named spot. Inside [member radius], its name shows in the location
## banner. It can also be labeled on the area map.

@export var display_name := ""
## Pixels. 0 means it's only a map label (for example a peak you can't reach).
@export var radius := 64.0
@export var show_banner := true
@export var show_on_map := false
