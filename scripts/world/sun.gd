class_name Sun
extends RefCounted
## Where the sun and moon are, worked out from the clock and the date, for
## everything that lights the outdoors: the day and night tint (DayNight), the
## shadows things cast (SunShadows), the picture grade (Atmosphere) and the
## mist and light shafts in the air (ValleyAir). Nothing is saved.
##
## The days follow the valley's year: long summer evenings (sunset after 8 PM),
## short winter days (sunset around 5 PM), sunrise and sunset sliding smoothly
## between the seasons. The sun rises in the east (right of the map), swings
## through the south (down) and sets in the west (left), higher in summer than
## in winter, so shadows fall long to the west in the morning, short and to the
## north at midday, and long to the east in the evening.

## Sunrise and sunset (clock hours) in the middle of each season: April, July,
## October and January in Yosemite Valley, with daylight saving time. Late
## winter evenings land on Horsetail Fall's firefall (about 5:30 PM).
const SUN_TIMES := [Vector2(6.5, 19.6), Vector2(5.9, 20.3), Vector2(7.2, 18.5), Vector2(7.2, 17.2)]
## Highest the sun gets each season, in degrees above the horizon (latitude 37.7).
const NOON_HEIGHT := [58.0, 72.0, 46.0, 32.0]
## Sunrise and sunset on DayNight's gradient (as day progress), so its colours
## line up with the sun whatever the season.
const GRADIENT_SUNRISE := 6.2 / 24.0
const GRADIENT_SUNSET := 19.2 / 24.0


## Today's sunrise (x) and sunset (y), in clock hours.
static func times(season := -1, day := -1) -> Vector2:
	if season < 0:
		season = GameClock.season
	if day < 0:
		day = GameClock.day
	var half := GameClock.DAYS_PER_SEASON / 2.0
	var f := (float(day) - half) / GameClock.DAYS_PER_SEASON
	var other := season + (1 if f >= 0.0 else -1)
	var a: Vector2 = SUN_TIMES[posmod(season, 4)]
	var b: Vector2 = SUN_TIMES[posmod(other, 4)]
	return a.lerp(b, absf(f))


## The clock time now, in hours (past 24 after midnight).
static func hour_now() -> float:
	return GameClock.get_day_progress() * 24.0


## Where today sits on DayNight's gradient: the clock, stretched so sunrise and
## sunset land on the gradient's own sunrise and sunset.
static func gradient_progress(hour := -1.0) -> float:
	if hour < 0.0:
		hour = hour_now()
	var t := times()
	hour = fposmod(hour, 24.0)
	if hour >= t.x and hour <= t.y:
		return lerpf(GRADIENT_SUNRISE, GRADIENT_SUNSET, (hour - t.x) / (t.y - t.x))
	var night := 24.0 - (t.y - t.x)
	var since_sunset := fposmod(hour - t.y, 24.0)
	var span := 1.0 - (GRADIENT_SUNSET - GRADIENT_SUNRISE)
	return fposmod(GRADIENT_SUNSET + span * since_sunset / night, 1.0)


## How far the sun is across the sky: 0 at sunrise, 0.5 at midday, 1 at sunset
## (below 0 or above 1 when it's down).
static func arc(hour := -1.0) -> float:
	if hour < 0.0:
		hour = hour_now()
	var t := times()
	return (fposmod(hour, 24.0) - t.x) / (t.y - t.x)


## The sun's height above the horizon in degrees (negative below it).
static func height(hour := -1.0) -> float:
	if hour < 0.0:
		hour = hour_now()
	var s := arc(hour)
	if s >= 0.0 and s <= 1.0:
		return NOON_HEIGHT[clampi(GameClock.season, 0, 3)] * sin(PI * s)
	# Below the horizon it sinks about 11 degrees an hour.
	var t := times()
	var h := fposmod(hour, 24.0)
	var away := minf(fposmod(h - t.y, 24.0), fposmod(t.x - h, 24.0))
	return -minf(away * 11.0, 60.0)


## On the ground, the way toward the sun: (1, 0) east at sunrise, (0, 1) south
## at midday, (-1, 0) west at sunset.
static func direction(hour := -1.0) -> Vector2:
	var s := clampf(arc(hour), 0.0, 1.0)
	return Vector2(cos(PI * s), sin(PI * s))


## How bright the moon is tonight: 1 at full moon (day 14), 0 at new moon.
static func moon(day := -1) -> float:
	if day < 0:
		day = GameClock.day
	return 0.5 - 0.5 * cos(TAU * float(day - GameClock.FULL_MOON_DAY + 14) / 28.0)


## 1 while the sun is up and clear of the ridges, fading to 0 in the half hour
## either side of sunrise and sunset.
static func daylight(hour := -1.0) -> float:
	return smoothstep(-1.0, 6.0, height(hour))


## The golden hours: the first and last hour or so of sun.
static func golden(hour := -1.0) -> float:
	var h := height(hour)
	return smoothstep(-2.0, 2.0, h) * (1.0 - smoothstep(8.0, 22.0, h))


## Alpenglow: the pink light on the granite and snow, strongest in the minutes
## after sunset (and faintly before sunrise), after the valley floor is
## already in shadow.
static func alpenglow(hour := -1.0) -> float:
	if hour < 0.0:
		hour = hour_now()
	var t := times()
	var h := fposmod(hour, 24.0)
	var evening := smoothstep(t.y - 0.7, t.y - 0.1, h) * (1.0 - smoothstep(t.y + 0.25, t.y + 0.6, h))
	var morning := smoothstep(t.x - 0.5, t.x - 0.15, h) * (1.0 - smoothstep(t.x + 0.1, t.x + 0.45, h))
	return maxf(evening, morning * 0.6)


## 0 by day, 1 in the dark of night, between at twilight.
static func night(hour := -1.0) -> float:
	return 1.0 - smoothstep(-12.0, 0.0, height(hour))


## The moon's way across the night sky, like the sun's by day: (1, 0) after
## sunset, (0, 1) at midnight, (-1, 0) before dawn.
static func moon_direction(hour := -1.0) -> Vector2:
	if hour < 0.0:
		hour = hour_now()
	var t := times()
	var dark := 24.0 - (t.y - t.x)
	var s := clampf(fposmod(fposmod(hour, 24.0) - t.y, 24.0) / dark, 0.0, 1.0)
	return Vector2(cos(PI * s), sin(PI * s))
