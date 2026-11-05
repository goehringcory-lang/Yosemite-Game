class_name ScreenWipe
extends CanvasLayer
## The pixel-diamond wipe for the screens that take over the whole view (the
## climbing wall, the slackline, the Half Dome cables, rock work, a rescue
## lower). A screen used to pop up in one frame and vanish in another. Now,
## as it opens, it is first hidden under the palette's night color, which
## then breaks into diamonds and shrinks away in a sweep from the top left
## (the same pixel_wipe.gdshader the HUD wipes between places with). When
## the screen closes, the valley opens up out of the diamonds the same way.
##
## It is a cover over everything, drawn after the fact: it never holds the
## game up, so nothing waits on it and every input reaches the screen at once.
##
##   tree.root.add_child(minigame)
##   ScreenWipe.attach(minigame)

## How long the diamonds take to clear, in seconds.
const TIME := 0.36
## Above every screen and menu (the pause menu is 28).
const LAYER := 40

var _time := TIME
var _rect: ColorRect


## Wipes [param screen] open now, and wipes the world open again when it
## leaves the tree.
static func attach(screen: Node) -> void:
	if screen == null or not screen.is_inside_tree():
		return
	var tree := screen.get_tree()
	reveal(tree)
	screen.tree_exiting.connect(func() -> void: reveal(tree), CONNECT_ONE_SHOT)


## Lays the cover over the whole view and wipes it away over [param time]
## seconds.
static func reveal(tree: SceneTree, time := TIME) -> ScreenWipe:
	if tree == null or tree.root == null:
		return null
	var wipe := ScreenWipe.new()
	wipe._time = time
	# Deferred: a screen often opens or closes while the tree is busy.
	tree.root.add_child.call_deferred(wipe)
	return wipe


func _ready() -> void:
	name = "ScreenWipe"
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiScale.layer(self)
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiScale.fit(_rect)
	var wipe := ShaderMaterial.new()
	wipe.shader = preload("res://assets/shaders/pixel_wipe.gdshader")
	wipe.set_shader_parameter("rect_size", UiScale.SCREEN)
	_rect.material = wipe
	_rect.color = Color(HUD.WIPE_COLOR, 1.0)
	add_child(_rect)
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", 0.0, _time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)


## How covered the view still is (1 all, 0 clear), for tests.
func cover() -> float:
	return _rect.color.a if _rect else 1.0
