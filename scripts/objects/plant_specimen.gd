class_name PlantSpecimen
extends Node2D
## A plant from the press book, growing where PlantSpawner put it. Interact
## to press a specimen (or to sketch it, if it's one that mustn't be picked).
## The plant stays where it is: you take a sprig, not the plant.

## Set by PlantSpawner before the node enters the tree.
var plant_id := ""
var cell: Vector2i

## The glint over a plant that's still wanted for the book: how often it
## twinkles (seconds), and its color.
const GLINT_EVERY := 2.4
const GLINT := Color(1.0, 0.97, 0.8)

var _time := 0.0
var _glint := 0.0

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	sprite.texture = Herbarium.icon(plant_id)
	# Each plant twinkles on its own beat.
	_time = float(absi(hash(cell)) % 100) / 100.0 * GLINT_EVERY
	Herbarium.changed.connect(_refresh_glint)
	QuestLog.changed.connect(_refresh_glint)
	_refresh_glint()


## True while this plant would be new to the press book: it glints, so it
## stands out from the flowers that are only scenery.
func is_wanted() -> bool:
	return Herbarium.has_press() and not Herbarium.has(plant_id)


func _refresh_glint() -> void:
	set_process(is_wanted())
	queue_redraw()


func _process(delta: float) -> void:
	_time = fmod(_time + delta, GLINT_EVERY)
	# A quick twinkle at the start of each beat, in four steps.
	var glint := snappedf(clampf(1.0 - _time / 0.5, 0.0, 1.0), 0.25)
	if glint != _glint:
		_glint = glint
		queue_redraw()


## A four-pointed glint over the plant, one pixel thick.
func _draw() -> void:
	if not is_wanted() or _glint <= 0.0:
		return
	var at := Vector2(8, -26)
	var color := Color(GLINT, _glint)
	var arm := 2 + 2 * int(_glint * 2.0)
	draw_rect(Rect2(at.x - arm, at.y, arm * 2 + 2, 2), color)
	draw_rect(Rect2(at.x, at.y - arm, 2, arm * 2 + 2), color)


func get_prompt() -> String:
	var plant := Herbarium.get_plant(plant_id)
	if not Herbarium.has_press() or Herbarium.has(plant_id):
		return "Look at the %s" % plant.name
	return "Sketch the %s" % plant.name if plant.get("protected", false) else "Press a sprig of %s" % plant.name


func interact(player: Player) -> void:
	var plant := Herbarium.get_plant(plant_id)
	if plant.is_empty():
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	if not Herbarium.has_press():
		hud.show_info(plant.name, "%s\n\nYou have nothing to press it in. Enid Michael keeps the wildflower garden at the Museum in Yosemite Village." % plant.note)
		return
	if Herbarium.has(plant_id):
		hud.show_message("%s is in your press book already. This one stays where it grows." % plant.name)
		return
	Herbarium.press(plant_id, _where())
	PickupPop.spawn(sprite, player)
	Sound.play("item_get")
	var title := "Sketched: %s" if plant.get("protected", false) else "Pressed: %s"
	var text := "%s\n\n%s" % [plant.latin, plant.note]
	if plant.get("protected", false):
		text += "\n\nToo rare to pick. You draw it in the press book and leave it standing."
	hud.show_info(title % plant.name, "%s\n\nPress book: %d of %d." % [text, Herbarium.count(), Herbarium.total()])


## The name of the place this plant grows, for the specimen's label.
func _where() -> String:
	var node := get_parent()
	while node and not node is Region:
		node = node.get_parent()
	if node == null:
		return ""
	var region := node as Region
	var place := region.place_at(global_position)
	return place.display_name if place else region.display_name
