shader_type canvas_item;
// Far scenery hung above a map (Tuolumne's High Sierra skyline): the day's
// sun and lamps light the scene in front of it, not mountains miles away,
// so no Light2D adds to it. The DayNight tint still darkens it at night
// (CanvasModulate is not a light; `render_mode unshaded` would drop it too).

// SunLight stands in for the sun's add by lifting the canvas modulate by
// 1 + the sun (see lit.gdshaderinc); the mountains never took that add, so
// the lift comes back out here.
global uniform vec3 sun_light;

void fragment() {
	COLOR.rgb /= 1.0 + sun_light;
}

void light() {
	LIGHT = vec4(0.0);
}
