class_name CabinPorch
extends Node2D
## The front of your cabin's porch (once George Anderson builds it): the
## posts up to the eave and the rail along the deck's edge, with a gap for
## the steps. It stands at the deck's front edge, apart from Cabin, so you're
## drawn behind it when you're up on the porch and can't walk through the
## rail.

## From the middle of the cabin's front wall (Cabin.POS).
const AT := Vector2(0, 15)
## The rail's two spans, either side of the steps (x from, x to).
const SPANS := [Vector2(-90, -20), Vector2(20, 90)]

var _body: StaticBody2D


static func make() -> CabinPorch:
	var node := CabinPorch.new()
	node.name = "CabinPorch"
	node.position = Cabin.POS + AT
	return node


func _ready() -> void:
	_body = StaticBody2D.new()
	_body.name = "Body"
	_body.collision_mask = 0
	for span: Vector2 in SPANS:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(span.y - span.x, 4)
		shape.shape = box
		shape.position = Vector2((span.x + span.y) / 2.0, -2)
		_body.add_child(shape)
	add_child(_body)
	Camp.changed.connect(_refresh)
	QuestLog.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var shown := Camp.has("porch")
	visible = shown
	for child in _body.get_children():
		(child as CollisionShape2D).set_deferred("disabled", not shown)


func _draw() -> void:
	var ink := Cabin.INK
	# posts holding up the eave
	for x in [-88.0, -20.0, 20.0, 88.0]:
		draw_rect(Rect2(x - 2.5, -75, 5, 75).grow(1), ink)
		draw_rect(Rect2(x - 2.5, -75, 5, 75), Cabin.LOG)
		draw_rect(Rect2(x - 2.5, -75, 1, 75), Cabin.LOG_HI)
	# the rail and its balusters
	for span: Vector2 in SPANS:
		var from := span.x + (2.0 if span.x < 0 else 2.5)
		var to := span.y - (2.5 if span.x < 0 else 2.0)
		draw_rect(Rect2(from, -14, to - from, 3).grow(1), ink)
		draw_rect(Rect2(from, -14, to - from, 3), Cabin.LOG_HI)
		for x in range(int(from) + 5, int(to), 8):
			draw_rect(Rect2(x, -11, 2, 10), Cabin.LOG)
