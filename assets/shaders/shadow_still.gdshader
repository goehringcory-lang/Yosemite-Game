shader_type canvas_item;
// The still shadows' baked picture (scripts/world/sun_shadows.gd), laid on the
// ground: white where a shadow lies, drawn in the shadow's colour, as strong
// as the sprite's alpha (the hour's shadow strength).

uniform vec3 shade : source_color = vec3(0.1, 0.11, 0.22);

void fragment() {
	COLOR = vec4(shade, COLOR.a);
}
