class_name ClimberView
extends Node2D
## Interface (thread 9, climber art and animation): draws the climber from
## session.pose exactly as given (IK from the contacts; it never guesses), the
## ghost of a previewed move, and falls. It lives in the screen's world node,
## where 1 unit = 1 pixel and wall metres map through [method px]. It reads
## the session and the bus and never changes them; nothing waits on it.

var session: ClimbSession


func bind(p_session: ClimbSession) -> void:
	session = p_session


## Wall metres to this node's pixels (y flipped).
static func px(wall_pos: Vector2) -> Vector2:
	return Vector2(wall_pos.x, -wall_pos.y) * ClimbV2.PX_PER_M


## The pose to show now (eases from the last one as the art likes).
func show_pose(_pose: V2Pose) -> void:
	queue_redraw()


## The ghost of a previewed move (null hides it). move.strain says how much
## it trembles; move.valid false draws it as "can't".
func show_ghost(_move: V2Move) -> void:
	queue_redraw()


## Plays a fall (the session already holds the settled pose).
func show_fall(_fall: V2Fall) -> void:
	queue_redraw()
