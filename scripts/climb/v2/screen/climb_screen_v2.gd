class_name ClimbScreenV2
extends CanvasLayer
## The v2 climbing screen (thread 1 owns it): a thin layer over ClimbDirector.
## It builds the views (the look behind, the climber in front), mounts each
## system's overlay in a slot named after it, turns input into verbs and
## forwards bus events to the views. All rules live in the director and the
## systems; nothing here changes the session.
##
## Same signal as the old ClimbMinigame, so ClimbStart can use either.

signal finished(success: bool, minutes: int)

const SCREEN := Vector2(960, 540)

var route: RouteData
var director := ClimbDirector.new()
var session: ClimbSession
var result: V2Result

## The camera moves this (ClimbLook); it holds the look and the climber.
var world := Node2D.new()
var look: ClimbLook
var climber: ClimberView
var hud := Control.new()
var overlays := Control.new()
var _hint := Label.new()
var _seed := 0
var _mods: V2Modifiers
var _rack: V2Rack


## [param seed] makes the walls the same every time; [param mods] and
## [param rack] default to the game's.
func setup(p_route: RouteData, seed := -1, mods: V2Modifiers = null, rack: V2Rack = null) -> void:
	route = p_route
	_seed = seed if seed >= 0 else randi()
	_mods = mods
	_rack = rack


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = director.setup(route, _seed, _mods, _rack)
	var size := get_viewport().get_visible_rect().size if get_viewport() else SCREEN
	var back := ColorRect.new()
	back.color = Color("1a2230")
	back.size = size
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	world.name = "World"
	add_child(world)
	look = ClimbSystems.make(&"look")
	look.name = "Look"
	look.bind(session, world, size)
	world.add_child(look)
	climber = ClimbSystems.make(&"climber")
	climber.name = "Climber"
	climber.bind(session)
	world.add_child(climber)
	hud.name = "Hud"
	hud.size = size
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	overlays.name = "Overlays"
	overlays.size = size
	overlays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(overlays)
	for system in session.sys.all():
		var node := system.make_overlay()
		if node:
			node.name = String(system.id())
			overlays.add_child(node)
	_hint.position = Vector2(12, size.y - 28)
	_hint.add_theme_color_override("font_color", Color("f2e6c8"))
	hud.add_child(_hint)
	var bus := session.bus
	bus.pitch_started.connect(_on_pitch_started)
	bus.move_previewed.connect(climber.show_ghost)
	bus.aim_changed.connect(_on_aim_changed)
	bus.move_committed.connect(_on_move_committed)
	bus.fall_caught.connect(_on_fall_caught)
	bus.phase_changed.connect(_on_phase_changed)
	director.finished.connect(_on_finished)
	director.start()


func _process(delta: float) -> void:
	if director.current:
		director.current.step(delta)
		_hint.text = director.current.hint()
	if look:
		look.frame(delta)


func _unhandled_input(event: InputEvent) -> void:
	var used := false
	for pair: Array in ClimbInput.verbs_for(event):
		used = director.handle_verb(pair[0], pair[1]) or used
	if used:
		get_viewport().set_input_as_handled()


func _on_pitch_started(_pitch: int) -> void:
	look.show_wall(session.wall)
	climber.show_pose(session.pose)


func _on_aim_changed(hold_id: String) -> void:
	if hold_id == "":
		climber.show_ghost(null)


func _on_move_committed(_move: V2Move) -> void:
	climber.show_pose(session.pose)


func _on_fall_caught(fall: V2Fall) -> void:
	climber.show_ghost(null)
	climber.show_fall(fall)


func _on_phase_changed(_from: StringName, _to: StringName) -> void:
	climber.show_pose(session.pose)


func _on_finished(r: V2Result) -> void:
	result = r
	finished.emit(r.success, r.minutes)
	queue_free()
