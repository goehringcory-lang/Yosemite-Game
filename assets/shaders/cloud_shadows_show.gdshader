shader_type canvas_item;
// Lays the cloud shadows over the world (scripts/world/cloud_shadows.gd): each
// texel of the picture cloud_shadows.gdshader worked out is one 2x2 cell of
// world pixels, and its red is the shade's step (0, 1/3, 2/3 or 1).

uniform float strength : hint_range(0.0, 1.0) = 0.14;
uniform vec3 shade : source_color = vec3(0.1, 0.13, 0.24);

void fragment() {
	float level = floor(texture(TEXTURE, UV).r * 3.0 + 0.5) / 3.0;
	COLOR = vec4(shade, level * strength);
}
