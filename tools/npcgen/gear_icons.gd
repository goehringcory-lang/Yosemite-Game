extends SceneTree
## Draws the gear icons that aren't hand-painted: for now, the climbing shoes
## (assets/sprites/gear/climbing_shoes.png). Icons are 64×64, drawn on a 32×32
## grid and doubled, with a dark rim like the painted ones.
## Run: godot --headless --path . -s res://tools/npcgen/gear_icons.gd

const OUT := "res://assets/sprites/gear/"
const OUTLINE := Color("2a1f1a")

var im: Image


func _init() -> void:
	climbing_shoes().save_png(ProjectSettings.globalize_path(OUT + "climbing_shoes.png"))
	print("drew climbing_shoes")
	quit()


func rect(x: int, y: int, w: int, h: int, hex: String) -> void:
	im.fill_rect(Rect2i(x, y, w, h), Color(hex))


func px(x: int, y: int, hex: String) -> void:
	im.set_pixel(x, y, Color(hex))


## A pair of slim, downturned slab shoes: suede uppers, a black rubber rand
## round the toe, and laces up the top. The back shoe sits up and to the left.
func climbing_shoes() -> Image:
	im = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	_shoe(2, 5)
	_shoe(12, 15)
	_outline()
	var big := im.duplicate()
	big.resize(64, 64, Image.INTERPOLATE_NEAREST)
	return big


func _shoe(x: int, y: int) -> void:
	# Sole and rand: one smooth strip of black rubber, turned up at the toe.
	rect(x + 1, y + 8, 15, 2, "222226")
	rect(x + 15, y + 6, 2, 3, "222226")
	px(x + 16, y + 5, "222226")
	rect(x + 2, y + 8, 12, 1, "3a3a42")
	# Suede upper, low at the toe and high at the heel.
	rect(x + 1, y + 3, 5, 5, "c8502e")
	rect(x + 6, y + 4, 6, 4, "c8502e")
	rect(x + 12, y + 5, 3, 3, "c8502e")
	rect(x + 15, y + 6, 1, 1, "c8502e")
	# Light from the upper left, shade underneath.
	rect(x + 1, y + 3, 5, 1, "e8784a")
	rect(x + 6, y + 4, 6, 1, "e0704a")
	rect(x + 1, y + 7, 13, 1, "9a3a22")
	# Heel tab and the collar.
	rect(x, y + 2, 2, 4, "4a6a8a")
	rect(x + 2, y + 2, 4, 1, "8a3020")
	# Laces.
	for i in 3:
		px(x + 6 + i * 2, y + 5, "f0e8d8")
		px(x + 7 + i * 2, y + 6, "f0e8d8")


func _outline() -> void:
	var edge: Array[Vector2i] = []
	for y in 32:
		for x in 32:
			if im.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < 32 and p.y < 32 and im.get_pixel(p.x, p.y).a > 0.0 \
						and im.get_pixel(p.x, p.y) != OUTLINE:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		im.set_pixelv(p, OUTLINE)
