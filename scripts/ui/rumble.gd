class_name Rumble
extends RefCounted
## Controller rumble for the moments you'd feel: a fall, a crux stuck, a fish
## on the line, a gust on the slackline, a quest done. It only plays on the
## gamepad you're holding (the last device you pressed something on), and the
## Vibration setting turns it off.
##
##   Rumble.play("fall")
##   Rumble.stop()            # the menu opened, or you looked away
##
## The HUD tells it which device is in use with [method note].

## cue -> [weak motor, strong motor, seconds]. The weak motor is the light
## buzz, the strong one the heavy thump. Kept short and soft: a nudge, not a
## jolt.
const CUES := {
	"fall": [0.5, 0.9, 0.35],
	"crux": [0.5, 0.2, 0.12],
	"miss": [0.0, 0.4, 0.1],
	"clip": [0.3, 0.0, 0.06],
	"top": [0.6, 0.5, 0.4],
	"bite": [0.7, 0.3, 0.15],
	"landed": [0.4, 0.5, 0.3],
	"gust": [0.35, 0.0, 0.25],
	"buck": [0.2, 0.35, 0.1],
	"quest": [0.4, 0.3, 0.25],
	"heart": [0.3, 0.0, 0.15],
}

## The gamepad in use, or -1 while the keyboard or mouse is.
static var pad := -1
## The last cue that played, and how many have (for tests).
static var last := ""
static var count := 0


## Call with every input event, so rumble goes to the pad in the player's
## hands and stays quiet while they're on the keyboard.
static func note(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		pad = event.device
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = -1


## True when [method play] would shake a controller.
static func active() -> bool:
	Settings.ensure_loaded()
	return Settings.vibration and pad >= 0


## Plays [param cue] (a key of CUES), [param scale] times as strong.
static func play(cue: String, scale := 1.0) -> void:
	if not active() or not CUES.has(cue):
		return
	var c: Array = CUES[cue]
	last = cue
	count += 1
	Input.start_joy_vibration(pad, clampf(c[0] * scale, 0.0, 1.0), clampf(c[1] * scale, 0.0, 1.0), c[2])


static func stop() -> void:
	if pad >= 0:
		Input.stop_joy_vibration(pad)
