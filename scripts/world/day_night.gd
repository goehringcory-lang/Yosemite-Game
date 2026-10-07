extends CanvasModulate
## Tints the world based on the time of day. Edit the gradient in the
## Inspector: its left edge is midnight, the middle is noon.
##
## On top of the gradient, each season grades the light a touch (fresh in
## spring, warm in summer, golden in fall, cool in winter), and rainy or
## snowy days (see Weather.today) are greyer. These stay subtle, so the
## lamps and glows that read the tint's brightness still come on at dusk.

const SEASON_TINTS := [
	Color(1.0, 1.0, 0.98),
	Color(1.0, 0.985, 0.95),
	Color(1.0, 0.965, 0.91),
	Color(0.94, 0.965, 1.0),
]
const OVERCAST := Color(0.86, 0.89, 0.95)

@export var gradient: Gradient


func _process(_delta: float) -> void:
	if gradient:
		var c := gradient.sample(GameClock.get_day_progress())
		c *= SEASON_TINTS[clampi(GameClock.season, 0, 3)]
		var weather := Weather.today()
		var grey := maxf(weather.rain * 0.7, weather.snow * 0.5)
		if grey > 0.0:
			c = c.lerp(c * OVERCAST, grey)
		c.a = 1.0
		color = c
