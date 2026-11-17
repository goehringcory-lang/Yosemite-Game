class_name HighCountry
extends RefCounted
## The light and air of the high country (Tuolumne Meadows, 8,600 feet, and
## Tenaya Lake down the Tioga Road),
## shared by the outdoor grade (Atmosphere), the mist (ValleyAir) and the
## cloud shadows (CloudShadows):
##  - the air is thin and clean, so there's little haze (except the smoke of
##    fall fires), colours are clear, and the shade is lit by a deep blue sky;
##  - the cold air pools on the meadow overnight, so the river and the grass
##    steam with mist on summer mornings as well as in spring and fall;
##  - on most summer afternoons cumulus build over the domes into the storm
##    the climbs warn of (WallWeather): their shadows crowd the meadow and the
##    light dims before it breaks, then the air clears;
##  - nights are darker and colder blue, with no valley haze.

const REGIONS := ["tuolumne_meadows", "tenaya_lake"]
## A climb in the high country, whose weather (WallWeather) names the hour the
## afternoon storm breaks, so the sky over the meadow agrees with the guidebook.
const STORM_ROUTE := "cathedral_peak"
## How much of the valley's haze the thin air keeps, by season (spring,
## summer, fall's smoke, winter).
const HAZE := [0.3, 0.25, 0.6, 0.2]
## How likely a misty morning is up here, by season: cold air pools on the
## meadow on clear summer nights too.
const MIST_CHANCE := [0.55, 0.6, 0.55, 0.4]


static func is_high(region_id: String) -> bool:
	return region_id in REGIONS


## How far the afternoon clouds have built over the high country now (0..1):
## a little fair-weather cumulus on any warm midday, towering up to the storm
## on a storm day and breaking up an hour or two after it. Snow and rain days
## are the weather's own (overcast).
static func cloud_build(hour := -1.0) -> float:
	if hour < 0.0:
		hour = Sun.hour_now()
	var h := fposmod(hour, 24.0)
	var season := clampi(GameClock.season, 0, 3)
	# Fair-weather cumulus over the domes, late morning to late afternoon.
	var fair := smoothstep(10.5, 13.0, h) * (1.0 - smoothstep(16.5, 19.0, h))
	fair *= 0.35 if season == 1 else (0.2 if season != 3 else 0.0)
	var storm := storm_hour()
	if storm < 0.0:
		return fair
	var build := smoothstep(storm - 3.5, storm - 0.25, h) * (1.0 - smoothstep(storm + 1.25, storm + 3.0, h))
	return maxf(fair, build)


static var _storm_date := Vector3i(-1, -1, -1)
static var _storm_hour := -1.0


## The hour today's afternoon storm breaks over the high country, or -1.
## Worked out once a day (it's read every frame).
static func storm_hour() -> float:
	var date := Vector3i(GameClock.year, GameClock.season, GameClock.day)
	if date != _storm_date:
		_storm_date = date
		_storm_hour = float(WallWeather.today(STORM_ROUTE).get("storm_hour", -1.0))
	return _storm_hour


## How dark the sky is with storm cloud now (0..1): only the last hour or so
## before the storm breaks and while it rains.
static func storm_gloom(hour := -1.0) -> float:
	var storm := storm_hour()
	if storm < 0.0:
		return 0.0
	if hour < 0.0:
		hour = Sun.hour_now()
	var h := fposmod(hour, 24.0)
	return smoothstep(storm - 1.25, storm, h) * (1.0 - smoothstep(storm + 1.0, storm + 2.25, h))
