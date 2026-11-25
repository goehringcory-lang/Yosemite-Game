class_name GearTent
extends Node2D
## Your gear tent, pitched in the grass east of the cabin at the homestead:
## a canvas wall tent with its door flaps tied back, a rope coil and a rack
## of cams hanging inside. It's pitched once you own any climbing gear.
## Walk up and press E to go in: GearTentView lays everything you've
## collected out on a tarp to look at, and to choose what goes in your gear
## bag for the next climb.
##
## Like Cabin it draws itself, so the homestead map needs no rebuild.

## Where the middle of the tent's front stands at the homestead.
const POS := Vector2(1000, 292)
## Map decoration under the tent that gives way to it, relative to POS.
const CLEAR := Rect2(-64, -76, 128, 92)
## Its solid footprint, and how far in front of it you can reach the door.
const FOOT := Vector2(92, 26)
## Kinds of gear that mean you climb, and so need a tent for it.
const CLIMBING := ["cam", "nut", "rope", "draw", "wall", "ice"]

const INK := CampPiece.INK
const CANVAS := CampPiece.CANVAS
const CANVAS_SHADE := CampPiece.CANVAS_SHADE
const CANVAS_DARK := CampPiece.CANVAS_DARK
const WOOD := CampPiece.WOOD
const WOOD_HI := CampPiece.WOOD_HI
const WOOD_DARK := CampPiece.WOOD_DARK
const ROPE := CampPiece.ROPE_RED
const ROPE_HI := CampPiece.ROPE_HI
const INSIDE := Color("3a2a1e")
const SHADOW := Color(0, 0, 0, 0.22)

var _body: StaticBody2D
var _hitbox: Area2D
var _busy := false


## Pitches the tent at the homestead (Camp.dress), clearing the plants and
## rocks the map put under it.
static func build(region: Node) -> void:
	if region.entities.has_node("GearTent"):
		return
	var area := Rect2(POS + CLEAR.position, CLEAR.size)
	var dressing: Node = region.entities.get_node_or_null("WildDressing")
	for parent: Node in [region.entities, dressing]:
		if parent == null:
			continue
		for child in parent.get_children():
			if not child is Node2D or (parent == region.entities and not str(child.name).begins_with("Dec_")):
				continue
			if area.has_point((child as Node2D).global_position if child.is_inside_tree() else (child as Node2D).position):
				child.free()
	var tent := GearTent.new()
	tent.name = "GearTent"
	tent.position = POS
	region.entities.add_child(tent)


## True once you own climbing gear (or anything already hangs at camp).
static func is_pitched() -> bool:
	if Gear.any_cached():
		return true
	for gear: GearData in Gear.GEAR:
		if gear.kind in CLIMBING and not gear.generic and Gear.count(gear.id) > 0:
			return true
	return false


func _ready() -> void:
	_body = StaticBody2D.new()
	_body.name = "Body"
	_body.collision_mask = 0
	var solid := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = FOOT
	solid.shape = rect
	solid.position = Vector2(0, -FOOT.y / 2.0)
	_body.add_child(solid)
	add_child(_body)
	_hitbox = Area2D.new()
	_hitbox.name = "Hitbox"
	_hitbox.collision_layer = 4
	_hitbox.collision_mask = 0
	_hitbox.monitoring = false
	var shape := CollisionShape2D.new()
	var reach := RectangleShape2D.new()
	reach.size = Vector2(FOOT.x + 8.0, 40)
	shape.shape = reach
	shape.position = Vector2(0, -10)
	_hitbox.add_child(shape)
	add_child(_hitbox)
	Gear.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var shown := is_pitched()
	visible = shown
	if _hitbox:
		_hitbox.set_deferred("monitorable", shown)
	if _body:
		for child in _body.get_children():
			(child as CollisionShape2D).set_deferred("disabled", not shown)
	queue_redraw()


func get_prompt() -> String:
	return "Go into your gear tent"


func interact(player: Player) -> void:
	if not is_pitched() or _busy:
		return
	_busy = true
	var view := GearTentView.open(player)
	await view.closed
	_busy = false


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if not is_pitched():
		return
	var w := 88.0
	var wall := 22.0
	var ridge := 58.0
	# shadow on the grass
	draw_rect(Rect2(-w / 2 - 4, -6, w + 12, 9), SHADOW)
	# the far roof, seen past the ridge on the right
	_poly([Vector2(-w / 2, -wall), Vector2(0, -ridge), Vector2(w / 2 + 6, -ridge + 4), Vector2(w / 2 + 6, -wall + 3)], CANVAS_SHADE)
	# the front: walls, then the gable up to the ridge
	_poly([Vector2(-w / 2, 0), Vector2(-w / 2, -wall), Vector2(0, -ridge), Vector2(w / 2, -wall), Vector2(w / 2, 0)], CANVAS)
	# light from the upper left: the right half of the gable in shade
	_poly([Vector2(0, -ridge), Vector2(w / 2, -wall), Vector2(w / 2, 0), Vector2(18, 0), Vector2(14, -ridge + 12)], CANVAS_SHADE.lerp(CANVAS, 0.5))
	# seams
	for x: float in [-w / 2 + 14, w / 2 - 14]:
		draw_line(Vector2(x, -1), Vector2(x, -wall - (ridge - wall) * (1.0 - absf(x) / (w / 2)) + 1), CANVAS_DARK, 1.0)
	# the doorway, dark inside, with the gear hanging there
	var door := PackedVector2Array([Vector2(-14, 0), Vector2(-10, -40), Vector2(10, -40), Vector2(14, 0)])
	draw_colored_polygon(door, INSIDE)
	_inside_gear()
	# flaps tied back either side
	_poly([Vector2(-14, 0), Vector2(-10, -40), Vector2(-17, -30), Vector2(-22, 0)], CANVAS_SHADE)
	_poly([Vector2(14, 0), Vector2(10, -40), Vector2(17, -30), Vector2(22, 0)], CANVAS_DARK)
	draw_line(Vector2(-19, -18), Vector2(-14, -18), ROPE, 1.0)
	draw_line(Vector2(19, -18), Vector2(14, -18), ROPE, 1.0)
	# outline
	draw_polyline(PackedVector2Array([Vector2(-w / 2, 0), Vector2(-w / 2, -wall), Vector2(0, -ridge), Vector2(w / 2, -wall), Vector2(w / 2, 0)]), INK, 1.0)
	draw_line(Vector2(0, -ridge), Vector2(w / 2 + 6, -ridge + 4), INK, 1.0)
	draw_line(Vector2(w / 2 + 6, -ridge + 4), Vector2(w / 2 + 6, -wall + 3), INK, 1.0)
	# the ridge pole poking out, and guy lines to stakes
	draw_rect(Rect2(-2, -ridge - 3, 4, 4), WOOD_DARK)
	draw_line(Vector2(-w / 2, -wall), Vector2(-w / 2 - 8, 0), CANVAS_DARK, 1.0)
	draw_line(Vector2(w / 2, -wall), Vector2(w / 2 + 10, 0), CANVAS_DARK, 1.0)
	draw_rect(Rect2(-w / 2 - 9, -2, 2, 3), WOOD_DARK)
	draw_rect(Rect2(w / 2 + 9, -2, 2, 3), WOOD_DARK)
	# a little plank sign by the door
	draw_rect(Rect2(-36, -12, 2, 12), WOOD_DARK)
	draw_rect(Rect2(-42, -18, 16, 7), WOOD)
	draw_rect(Rect2(-42, -18, 16, 1), WOOD_HI)
	draw_rect(Rect2(-40, -15, 12, 1), INK)


## What you see through the door: a coiled rope on a peg and a run of cams
## in their colors, from what's in the tent right now.
func _inside_gear() -> void:
	draw_line(Vector2(-9, -34), Vector2(9, -34), WOOD, 1.0)
	if Gear.have("rope") > 0:
		draw_arc(Vector2(-4, -27), 5.0, 0.0, TAU, 12, ROPE, 2.0)
		draw_arc(Vector2(-4, -27), 2.0, 0.0, TAU, 8, ROPE_HI, 1.0)
	var x := 3.0
	for id: String in Gear.of_kind("cam"):
		if Gear.count(id) <= 0 or x > 9.0:
			continue
		var gear := Gear.get_gear(id)
		draw_rect(Rect2(x, -33, 1, 6), Color("93918f"))
		draw_rect(Rect2(x, -27, 1, 2), gear.color)
		x += 2.0


func _poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)
