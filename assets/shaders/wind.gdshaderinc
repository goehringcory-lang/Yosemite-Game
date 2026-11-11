// The wind in the valley (see scripts/world/wind.gd), shared by everything
// that moves in it: trees and plants sway (sway_offset), and gusts cross the
// grass as bands of blades catching the light (seasonal_ground.gdshader).
// Both read the same gust at the same spot, so a tree bends as the band on
// the grass reaches its foot.

// How hard it blows: 0 still air, 1 an ordinary breezy day, more in a storm.
global uniform float wind_strength;

// How far the gusts travel in a second, in world pixels, and the way they go
// (up the valley, a little down the screen).
const float GUST_SPEED = 120.0;
const vec2 GUST_WAY = vec2(0.93, 0.37);

// The gust passing over a spot of the world right now, 0 (the lull between
// two) to 1 (its crest). A gust is a band a few hundred pixels deep; one
// crosses the view every ten seconds or so.
float wind_gust(vec2 world, float t) {
	float along = dot(world, GUST_WAY) - t * GUST_SPEED;
	float a = sin(along * 0.0046) * 0.5 + 0.5;
	float b = sin(along * 0.0113 + world.y * 0.006 + 1.7) * 0.5 + 0.5;
	return smoothstep(0.5, 0.95, a * 0.7 + b * 0.3);
}

// How far, in texture pixels, the row at height 0 (the foot) to 1 (the top)
// of a plant standing at foot leans downwind. amount is the lean of its top
// in a full gust on an ordinary day; row is the texture row, for the slow
// whip that runs up a tall tree. The lean moves in whole texture pixels and
// grows steadily up the plant, so a trunk's edge steps over a pixel every
// thirty rows or so and stays clean, and the pixels stay crisp.
float sway_offset(float amount, float height, float row, vec2 foot, float t) {
	if (amount <= 0.0 || wind_strength <= 0.0) {
		return 0.0;
	}
	float phase = foot.x * 0.021 + foot.y * 0.013;
	float gust = wind_gust(foot, t);
	// a slow rocking in the breeze, a hard lean in the gust (with a shiver)
	float lean = sin(t * 1.3 + phase) * 0.22 + gust * (0.85 + 0.15 * sin(t * 4.1 + phase * 3.0));
	float whip = sin(t * 2.3 + phase * 2.0 - row * 0.012) * (0.08 + 0.14 * gust);
	float bend = pow(height, 1.7);
	return clamp(floor(amount * wind_strength * (lean + whip) * bend + 0.5), -15.0, 15.0);
}
