class_name TripEffect
extends CanvasLayer
## Crow's little piece of paper: for a while the whole screen (the world and
## the HUD over it) swirls, breathes, ripples and runs through every color,
## then settles back. Also a softer version, the haze after the joint, that
## only warms and wobbles things a little.
##
##   await TripEffect.play(self)              # the full trip, TRIP_SECONDS long
##   TripEffect.haze(self)                    # a gentle haze that fades on its own

const TRIP_SECONDS := 10.0
const HAZE_SECONDS := 25.0

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float intensity = 0.0;
uniform float t = 0.0;

vec3 hue_shift(vec3 c, float a) {
	const vec3 k = vec3(0.57735);
	float ca = cos(a);
	return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

void fragment() {
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 c = (SCREEN_UV - 0.5) * aspect;
	float r = length(c);
	float ang = atan(c.y, c.x);
	// a slow swirl that twists more toward the edges, and the world breathing
	ang += intensity * 0.9 * sin(t * 0.6 + r * 5.0) * r;
	r *= 1.0 + intensity * 0.07 * sin(t * 1.4);
	vec2 uv = vec2(cos(ang), sin(ang)) * r / aspect + 0.5;
	// melting ripples
	uv += intensity * 0.012 * vec2(sin(uv.y * 34.0 + t * 3.1), cos(uv.x * 27.0 + t * 2.4));
	// a mirrored kaleidoscope folding in at the peak
	vec2 fold = abs(fract(uv * (1.0 + intensity * 0.5) + 0.5) - 0.5) * 2.0;
	uv = mix(uv, fold, smoothstep(0.75, 1.0, intensity) * 0.35);
	uv = clamp(uv, vec2(0.0), vec2(1.0));
	// the colors come apart
	float ab = intensity * 0.01 * (1.0 + sin(t * 2.0));
	vec3 col;
	col.r = texture(screen, uv + vec2(ab, 0.0)).r;
	col.g = texture(screen, uv + vec2(0.0, ab * 0.5)).g;
	col.b = texture(screen, uv - vec2(ab, 0.0)).b;
	// every hue, cycling, in rings rolling out from the middle
	col = hue_shift(col, intensity * (sin(t * 0.9) * 3.2 + r * 7.0));
	float bands = sin(r * 22.0 - t * 4.0 + ang * 3.0) * 0.5 + 0.5;
	vec3 glow = 0.5 + 0.5 * cos(6.2832 * (vec3(0.0, 0.33, 0.67) + bands + t * 0.25));
	col = mix(col, col * 0.6 + glow * 0.55, intensity * 0.45);
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, 1.0 + intensity * 0.9);
	COLOR = vec4(col, 1.0);
}
"""

var _rect: ColorRect
var _material: ShaderMaterial
var _time := 0.0
var intensity := 0.0:
	set(value):
		intensity = value
		if _material:
			_material.set_shader_parameter("intensity", value)


func _init() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func _process(delta: float) -> void:
	_time += delta
	_material.set_shader_parameter("t", _time)


## The full trip over everything, TRIP_SECONDS long: it comes on, peaks, and
## lets go. Returns when it's over and the screen is back to normal.
static func play(from: Node) -> void:
	var fx := TripEffect.new()
	from.get_tree().root.add_child(fx)
	var tween := fx.create_tween()
	tween.tween_property(fx, "intensity", 1.0, 2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(fx, "intensity", 0.85, 2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(fx, "intensity", 1.0, 2.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(fx, "intensity", 0.0, TRIP_SECONDS - 6.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	fx.queue_free()


## A gentle haze, for after the joint: a little warmth and wobble that fades
## over HAZE_SECONDS. Doesn't wait.
static func haze(from: Node) -> void:
	var fx := TripEffect.new()
	fx.layer = 49
	from.get_tree().root.add_child(fx)
	var tween := fx.create_tween()
	tween.tween_property(fx, "intensity", 0.07, 3.0)
	tween.tween_property(fx, "intensity", 0.0, HAZE_SECONDS - 3.0).set_ease(Tween.EASE_IN)
	tween.tween_callback(fx.queue_free)
