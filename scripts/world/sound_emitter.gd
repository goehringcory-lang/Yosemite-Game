class_name SoundEmitter
extends AudioStreamPlayer2D
## A looping sound placed in the world, louder the closer you are: the crackle
## of a campfire or the roar of a waterfall. AmbientFx adds one to every fire's
## sparks and every waterfall's mist; World adds one at each waterfall Place on
## the hub maps (attach_waterfalls). Plays on the Ambience bus.

## The loop to play (a sound in assets/audio/: "campfire", "waterfall").
@export var sound := "campfire"
## Level at the source, before distance and the waterfall season.
@export var level := 1.0

var _check := 0.0


## An emitter of [param sound] heard out to [param reach] world pixels.
static func make(sound_id: String, reach: float, level_at_source := 1.0) -> SoundEmitter:
	var emitter := SoundEmitter.new()
	emitter.name = "Sound_" + sound_id
	emitter.sound = sound_id
	emitter.level = level_at_source
	emitter.max_distance = reach
	return emitter


## Adds a waterfall's roar at each Place in [param region] that is a fall or
## a cascade ("Bridalveil Fall", "Royal Arch Cascade"; not "...Trailhead" or
## the Firefall). Hand-built areas whose waterfall mist already carries the
## sound are left as they are.
static func attach_waterfalls(region: Region) -> void:
	if not region.find_children("Sound_waterfall", "", true, false).is_empty():
		return
	for place in region.get_places():
		var label := place.display_name
		if not (label.ends_with(" Fall") or label.ends_with(" Falls") or label.ends_with(" Cascade")) or label.contains("Firefall"):
			continue
		place.add_child(make("waterfall", 720.0, 1.0))


func _ready() -> void:
	bus = Sound.BUS_AMBIENCE
	stream = Sound.loop_stream(sound)
	attenuation = 1.6
	panning_strength = 0.6
	_refresh_level()


func _notification(what: int) -> void:
	# A region the player left keeps its nodes but leaves the tree, which
	# stops the sound; start it again on the way back in.
	if what == NOTIFICATION_ENTER_TREE and stream:
		_resume.call_deferred()


func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 2.0
		_refresh_level()


func _refresh_level() -> void:
	volume_linear = level * (Sound.waterfall_level() if sound == "waterfall" else 1.0)
	_resume()


## Starts the loop at a random point (so two fires don't crackle in step).
func _resume() -> void:
	if stream and not playing and is_inside_tree():
		play(randf() * stream.get_length())
