class_name ClimbFx
extends RefCounted
## Little effects for the climbing screen: chalk puffs, rock dust, sparks off
## steel, sweat drops, falling leaves and snow, rain, drips, blown grit.
## Particles are tiny squares or short streaks, spawned in screen space and
## drawn on top.

class Bit:
	var pos: Vector2
	var vel: Vector2
	var life: float
	var max_life: float
	var color: Color
	var size: int
	var gravity: float
	var streak: bool


var bits: Array[Bit] = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func spawn(pos: Vector2, vel: Vector2, life: float, color: Color, size := 1, gravity := 0.0, streak := false) -> void:
	var b := Bit.new()
	b.pos = pos
	b.vel = vel
	b.life = life
	b.max_life = life
	b.color = color
	b.size = size
	b.gravity = gravity
	b.streak = streak
	bits.append(b)
	if bits.size() > 400:
		bits.pop_front()


func chalk(pos: Vector2, n := 14) -> void:
	for i in n:
		spawn(pos + Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-3, 3)), Vector2(_rng.randf_range(-22, 22), _rng.randf_range(-30, -4)),
			_rng.randf_range(0.5, 1.1), Color(0.961, 0.933, 0.878, 0.9), 1 + int(i % 3 == 0), 14.0)


func dust(pos: Vector2, color: Color, n := 6) -> void:
	for i in n:
		spawn(pos + Vector2(_rng.randf_range(-5, 5), _rng.randf_range(-2, 2)), Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-4, 14)),
			_rng.randf_range(0.3, 0.7), color, 1, 40.0)


func sparks(pos: Vector2, n := 8) -> void:
	for i in n:
		var a := _rng.randf() * TAU
		spawn(pos, Vector2(cos(a), sin(a)) * _rng.randf_range(20, 55), _rng.randf_range(0.2, 0.45), Color(0.945, 0.812, 0.416, 1), 1, 90.0)


func sweat(pos: Vector2) -> void:
	spawn(pos, Vector2(_rng.randf_range(-6, 6), -10), 0.6, Color(0.624, 0.847, 0.851, 0.95), 1, 80.0)


func confetti(pos: Vector2, n := 40) -> void:
	var cols := [Color("d8a63b"), Color("d9772a"), Color("84b04a"), Color("3a86a8"), Color("f5eee0")]
	for i in n:
		spawn(pos, Vector2(_rng.randf_range(-70, 70), _rng.randf_range(-130, -40)), _rng.randf_range(0.9, 1.8), cols[i % cols.size()], 2, 120.0)


func update(delta: float) -> void:
	var i := bits.size() - 1
	while i >= 0:
		var b := bits[i]
		b.life -= delta
		if b.life <= 0.0:
			bits.remove_at(i)
		else:
			b.vel.y += b.gravity * delta
			b.pos += b.vel * delta
		i -= 1


## Bits sit on the screen's own pixels (half a menu pixel): rain is a one
## pixel streak, and size 0 is a single screen pixel (drips, grit, heat).
func draw(ci: CanvasItem) -> void:
	for b in bits:
		var a := clampf(b.life / b.max_life, 0.0, 1.0)
		var col := Color(b.color, b.color.a * minf(a * 2.0, 1.0))
		var p := (b.pos * 2.0).round() / 2.0
		if b.streak:
			ci.draw_rect(Rect2(p, Vector2(0.5, 3.5)), col)
		elif b.size <= 0:
			ci.draw_rect(Rect2(p, Vector2(0.5, 0.5)), col)
		else:
			ci.draw_rect(Rect2(p, Vector2(b.size, b.size)), col)
