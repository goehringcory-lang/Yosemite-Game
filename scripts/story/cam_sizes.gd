class_name CamSizes
extends RefCounted
## The sizes of cam on your rack. Gear counts cams as one number; the rack
## fills in size order, like a Camalot set: the first cam is a #0.75, then a
## #1, a #2 and a #3, then a second of each. Each size has the color Black
## Diamond prints on its sling and thumb loop, so the climbing screen, the
## Backpack and the gear icons all tell them apart the way climbers do.

const SIZES := [
	{"size": "#0.75", "color": Color("4f9a3a"), "icon": "res://assets/sprites/gear/cam_075.png", "fits": "Fits thin hands."},
	{"size": "#1", "color": Color("c8382e"), "icon": "res://assets/sprites/gear/cam.png", "fits": "Fits hand cracks."},
	{"size": "#2", "color": Color("dcaa2c"), "icon": "res://assets/sprites/gear/cam_2.png", "fits": "Fits wide hands."},
	{"size": "#3", "color": Color("2f6cc0"), "icon": "res://assets/sprites/gear/cam_3.png", "fits": "Fits fists."},
]


## Which size (an index into SIZES) the [param n]th cam on the rack is,
## counting from 0.
static func size_of(n: int) -> int:
	return posmod(n, SIZES.size())


static func color(n: int) -> Color:
	return SIZES[size_of(n)].color


## How many of each size a rack of [param cams] holds, in SIZES order.
static func counts(cams: int) -> Array[int]:
	var out: Array[int] = []
	for i in SIZES.size():
		out.append(maxi(0, ceili(float(cams - i) / SIZES.size())))
	return out


## The 64x64 icon for size [param size_index].
static func icon(size_index: int) -> Texture2D:
	return load(SIZES[size_of(size_index)].icon)
