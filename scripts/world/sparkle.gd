class_name Sparkle
extends Node2D
## A burst of pixel motes, for the moments that should feel like something:
## a find landing in your pack, a trout leaving the water, a quest done.
## Purely for show: it draws a few 2x2 squares for under half a second and
## frees itself. In the Low graphics setting a burst has half the motes.
##
##   Sparkle.burst(parent, global_point, Sparkle.STAR)
##   Sparkle.burst(parent, global_point, Sparkle.SPLASH)

enum { STAR, SPLASH, GLOW }

const LIFE := {STAR: 0.42, SPLASH: 0.6, GLOW: 0.8}
const COUNT := {STAR: 6, SPLASH: 8, GLOW: 10}
## Gold for a find, white water for a splash, warm light for a quest.
const COLORS := {
	STAR: [Color("ffd48a"), Color("fff4d6")],
	SPLASH: [Color("e8f4ff"), Color("9cc8e8")],
	GLOW: [Color("ffd48a"), Color("f6a85a"), Color("fff4d6")],
}

var kind := STAR
var _age := 0.0
## Each mote: [direction, speed, color].
var _motes: Array = []


## Bursts at [param at] (global) under [param parent]. Returns the burst, or
## null if there was nowhere to put it.
static func burst(parent: Node, at: Vector2, what := STAR) -> Sparkle:
	if parent == null or not parent.is_inside_tree():
		return null
	var s := Sparkle.new()
	s.kind = what
	var count: int = COUNT[what]
	if Settings.low():
		count = maxi(3, count / 2)
	var colors: Array = COLORS[what]
	for i in count:
		# spread evenly round the circle, with a little give
		var angle := TAU * (float(i) + randf() * 0.5) / float(count)
		if what == SPLASH:
			angle = lerpf(-PI * 0.9, -PI * 0.1, (float(i) + randf() * 0.6) / float(count))
		s._motes.append([Vector2.from_angle(angle), 0.75 + randf() * 0.5, colors[i % colors.size()]])
	parent.add_child(s)
	s.global_position = at
	return s


func _ready() -> void:
	z_index = 6
	z_as_relative = false


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE[kind]:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / float(LIFE[kind])
	for mote: Array in _motes:
		var dir: Vector2 = mote[0]
		var speed: float = mote[1]
		var c: Color = mote[2]
		var p := Vector2.ZERO
		match kind:
			STAR:
				# out fast, easing off, and twinkling to nothing
				p = dir * 16.0 * speed * (1.0 - (1.0 - t) * (1.0 - t))
				c.a = 1.0 - t * t
			SPLASH:
				# thrown up and out, falling back under gravity
				p = Vector2(dir.x * 14.0 * speed * t, dir.y * 26.0 * speed * t + 40.0 * t * t)
				c.a = 1.0 - t
			GLOW:
				# rising slowly round you, like embers
				p = dir * 14.0 * speed * sqrt(t) + Vector2(0, -18.0 * t)
				c.a = 1.0 - t
		p = p.round()
		draw_rect(Rect2(p - Vector2.ONE, Vector2(2, 2)), c)
		# the brightest motes get a cross of light while they're fresh
		if kind != SPLASH and speed > 1.0 and t < 0.4:
			var arm := Color(c, c.a * 0.6)
			draw_rect(Rect2(p + Vector2(-3, -1), Vector2(1, 2)), arm)
			draw_rect(Rect2(p + Vector2(2, -1), Vector2(1, 2)), arm)
			draw_rect(Rect2(p + Vector2(-1, -3), Vector2(2, 1)), arm)
			draw_rect(Rect2(p + Vector2(-1, 2), Vector2(2, 1)), arm)
