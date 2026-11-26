class_name VistaSpot
extends Node2D
## A vista (Vistas): where you stop and take in the view. It looks like what
## really stands at the spot: a stretch of railing ("railing"), a survey
## benchmark set in a granite knob with a little cairn ("benchmark"), or the
## foot of a fire lookout's stairs with its sign ("lookout"). Until you've
## taken in the view it catches the light now and then (Glint).
##
## Interact: the panorama (VistaView) sweeps across what you can see and
## names it; the areas below go on the area map and the landmarks in the
## log; then the peak-finder asks which one the arrow is on.

const INK := Color("2a1b14")
const WOOD := Color("7a5636")
const WOOD_LIT := Color("a87a4e")
const WOOD_DK := Color("4f3622")
const IRON := Color("3d3f44")
const IRON_LIT := Color("6b6f78")
const GRANITE := Color("a9a39a")
const GRANITE_LIT := Color("cfc9bd")
const GRANITE_DK := Color("7b766e")
const BRONZE := Color("b0823e")
const BRONZE_LIT := Color("e0b468")

## Its id in data/park/vistas.json.
var vista_id := ""

var _hitbox: Area2D
var _glint: Glint
var _busy := false


func _ready() -> void:
	add_to_group("vista_spot")
	_hitbox = Area2D.new()
	_hitbox.name = "Hitbox"
	_hitbox.collision_layer = 4
	_hitbox.collision_mask = 0
	_hitbox.monitoring = false
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(88, 48)
	shape.shape = rect
	shape.position = Vector2(0, -18)
	_hitbox.add_child(shape)
	add_child(_hitbox)
	_refresh_glint()
	Vistas.changed.connect(_refresh_glint)


func _refresh_glint() -> void:
	var want := not Vistas.is_surveyed(vista_id) and not Settings.low()
	if want and _glint == null:
		_glint = Glint.new()
		_glint.position = Vector2(20, -40)
		add_child(_glint)
	elif not want and _glint:
		_glint.queue_free()
		_glint = null


func stand() -> String:
	return str(Vistas.get_vista(vista_id).get("stand", "railing"))


func get_prompt() -> String:
	return "Take in the view: %s" % Vistas.get_vista(vista_id).get("title", "View")


func interact(player: Player) -> void:
	if _busy or not is_inside_tree():
		return
	_busy = true
	player.can_act = false
	var was_paused := GameClock.paused
	GameClock.paused = true
	var vista := Vistas.get_vista(vista_id)
	var view := VistaView.new()
	view.setup_vista(vista)
	get_tree().root.add_child(view)
	Sound.play("story_sting", -8.0, 0.0)
	await view.swept
	var result := Vistas.survey(vista_id)
	if is_instance_valid(view) and not view._closing and not Vistas.is_named(vista_id):
		await _peak_finder(player, view)
	if is_instance_valid(view) and view.is_inside_tree():
		await view.finished
	GameClock.paused = was_paused
	if is_instance_valid(player):
		player.can_act = true
	_tell(result)
	_busy = false


## Which one is that? The arrow swings to a landmark and three names are
## offered. Right earns the vista's stamp; wrong says which it was (and
## you can try again another time).
func _peak_finder(player: Player, view: VistaView) -> void:
	var quiz := Vistas.quiz(vista_id)
	if quiz.is_empty():
		return
	var vista := Vistas.get_vista(vista_id)
	view.holding = true
	view.point_at(str(vista.get("quiz_target", "")))
	var names: Array[String] = []
	for id: String in quiz.options:
		names.append(str(Landmarks.get_landmark(id).get("name", id.capitalize())))
	var box := DialogueBox.open(player)
	var picked := await box.choose("Peak-finder: which one is under the arrow?", names)
	var answer_name := str(Landmarks.get_landmark(quiz.answer).get("name", quiz.answer))
	if picked >= 0 and Vistas.answer(vista_id, quiz.options[picked]):
		Sound.play("item_get", -2.0, 0.0)
		await box.say([{"text": "That's %s. You mark it on your sketch of the skyline." % answer_name}])
	elif picked >= 0:
		await box.say([{"text": "Not quite: that's %s. Next time you're up here, you'll know it." % answer_name}])
	box.close()
	if is_instance_valid(view):
		view.point_at("")
		view.holding = false


## What the view gave, on the HUD: areas on the map, landmarks in the log,
## and the glint below (the cache's line, in the Logbook too).
func _tell(result: Dictionary) -> void:
	if not result.get("first", false):
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	var parts := PackedStringArray()
	var landmarks: Array = result.get("landmarks", [])
	if not landmarks.is_empty():
		parts.append("%d landmark%s in your log" % [landmarks.size(), "" if landmarks.size() == 1 else "s"])
	if int(result.get("places", 0)) > 0:
		parts.append("the places below on your area map")
	var cache := ""
	for find: Dictionary in Finds.all():
		if Finds.is_cache(find) and str(find.vista) == vista_id and not Finds.is_found(find.id):
			cache = str(find.rumor)
	var text := ("Seen from here: %s." % " and ".join(parts)) if not parts.is_empty() else ""
	if cache != "":
		text += ("\n\n" if text != "" else "") + cache
	if text != "" and hud.has_method("show_info"):
		hud.show_info(str(Vistas.get_vista(vista_id).get("title", "")), text)


func _draw() -> void:
	# in whole 2x2 art pixels, like the rest of the world's art
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2, 2))
	match stand():
		"benchmark":
			_draw_benchmark()
		"lookout":
			_draw_lookout()
		_:
			_draw_railing()


## A stretch of wooden railing on iron posts, with a brass plaque.
func _draw_railing() -> void:
	draw_rect(Rect2(-24, -2, 48, 4), Color(0, 0, 0, 0.18))
	for x in [-22, 0, 20]:
		draw_rect(Rect2(x - 1, -18, 4, 18), INK)
		draw_rect(Rect2(x, -17, 2, 17), IRON)
		draw_rect(Rect2(x, -17, 1, 17), IRON_LIT)
	draw_rect(Rect2(-24, -20, 48, 4), INK)
	draw_rect(Rect2(-23, -19, 46, 2), WOOD)
	draw_rect(Rect2(-23, -19, 46, 1), WOOD_LIT)
	draw_rect(Rect2(-23, -11, 46, 2), WOOD_DK)
	# the plaque, on the middle post
	draw_rect(Rect2(-5, -15, 10, 7), INK)
	draw_rect(Rect2(-4, -14, 8, 5), BRONZE)
	draw_rect(Rect2(-4, -14, 8, 1), BRONZE_LIT)


## A bronze survey disk set in a knob of granite, and a little cairn.
func _draw_benchmark() -> void:
	draw_rect(Rect2(-16, -2, 32, 4), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(-14, -8, 28, 8), INK)
	draw_rect(Rect2(-13, -9, 26, 8), GRANITE)
	draw_rect(Rect2(-11, -10, 20, 2), GRANITE_LIT)
	draw_rect(Rect2(-13, -3, 26, 2), GRANITE_DK)
	draw_rect(Rect2(-4, -8, 6, 4), INK)
	draw_rect(Rect2(-3, -7, 4, 2), BRONZE)
	draw_rect(Rect2(-3, -7, 2, 1), BRONZE_LIT)
	# the cairn
	var stones := [Rect2(7, -12, 8, 4), Rect2(8, -16, 6, 4), Rect2(9, -19, 4, 3)]
	for r: Rect2 in stones:
		draw_rect(r.grow(1), INK)
		draw_rect(r, GRANITE)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), GRANITE_LIT)


## The foot of a fire lookout's stairs: a signpost with the lookout's name
## board and a pair of field glasses burned into it.
func _draw_lookout() -> void:
	draw_rect(Rect2(-14, -2, 28, 4), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(-2, -26, 4, 26), INK)
	draw_rect(Rect2(-1, -25, 2, 25), WOOD)
	draw_rect(Rect2(-14, -30, 28, 12), INK)
	draw_rect(Rect2(-13, -29, 26, 10), WOOD_LIT)
	draw_rect(Rect2(-13, -21, 26, 2), WOOD)
	# field glasses
	for x in [-6, 1]:
		draw_rect(Rect2(x, -27, 5, 5), WOOD_DK)
		draw_rect(Rect2(x + 1, -26, 3, 3), INK)
	draw_rect(Rect2(-1, -26, 2, 2), WOOD_DK)
