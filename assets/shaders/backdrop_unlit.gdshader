shader_type canvas_item;
// Far scenery hung above a map (Tuolumne's High Sierra skyline): the day's
// sun and lamps light the scene in front of it, not mountains miles away,
// so no Light2D adds to it. The DayNight tint still darkens it at night
// (CanvasModulate is not a light; `render_mode unshaded` would drop it too).

void light() {
	LIGHT = vec4(0.0);
}
