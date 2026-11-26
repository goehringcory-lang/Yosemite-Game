class_name ClimbLook
extends Node2D
## Interface (thread 10, look, camera and sound): draws the wall and sky
## behind the climber, moves the camera (by setting the screen's world node
## transform), and plays sound, all derived from the session and bus events.
## It never changes the session; nothing waits on it.

var session: ClimbSession
## The node holding the wall, the climber and the rope; the camera moves it.
var world: Node2D
var screen_size := Vector2(960, 540)


func bind(p_session: ClimbSession, p_world: Node2D, p_screen_size: Vector2) -> void:
	session = p_session
	world = p_world
	screen_size = p_screen_size


## A new pitch's wall is ready to draw.
func show_wall(_wall: V2Wall) -> void:
	queue_redraw()


## Each frame: ease the camera, animate. Presentation only.
func frame(_delta: float) -> void:
	pass
