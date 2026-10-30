extends CanvasModulate
## Tints the world based on the time of day. Edit the gradient in the
## Inspector: its left edge is midnight, the middle is noon. The clock is
## stretched onto it by the season (see Sun.gradient_progress), so the sun
## sets after 8 PM in summer and around 5 PM in winter, and the colours follow.
##
## Moonlit nights are a touch brighter and more silver than moonless ones.
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
## The full moon's light, mixed into the night tint by the moon's phase.
const MOONLIGHT := Color(0.42, 0.5, 0.74)

@export var gradient: Gradient


func _process(_delta: float) -> void:
	if gradient:
		var c := gradient.sample(Sun.gradient_progress())
		c *= SEASON_TINTS[clampi(GameClock.season, 0, 3)]
		var weather := Weather.today()
		var moonlit: float = Sun.night() * Sun.moon() * (1.0 - weather.clouds * 0.8)
		if moonlit > 0.0:
			c = c.lerp(MOONLIGHT, moonlit * 0.6)
		var grey := maxf(weather.rain * 0.7, weather.snow * 0.5)
		if grey > 0.0:
			c = c.lerp(c * OVERCAST, grey)
		c.a = 1.0
		color = c
