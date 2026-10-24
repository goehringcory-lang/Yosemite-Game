extends SceneTree
## Synthesizes every sound in the game into assets/audio/ as 16-bit mono WAVs:
## the ambience beds, the campfire and waterfall loops, footsteps, climbing
## and menu sounds. Nothing is recorded or downloaded, so there is nothing to
## license. Each sound has a fixed seed, so a rebuild gives the same files.
##
##   godot --headless --path . -s res://tools/audio/build_sounds.gd
##   godot --headless --path . --import
##
## Loops are built a little long and their tail is crossfaded into their head,
## so they repeat without a click. Sound (scripts/autoload/sound.gd) plays them.

const OUT := "res://assets/audio/"
## Samples a second: ambience is soft and low, so it keeps to 22 kHz; short
## sounds with sharp clicks and chimes get 32 kHz.
const RATE_BED := 22050
const RATE_FX := 32000

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# Ambience beds and positional loops.
	_save("amb_day", _amb_day(), RATE_BED, -14.0)
	_save("amb_night", _amb_night(), RATE_BED, -15.0)
	_save("amb_wind", _amb_wind(), RATE_BED, -13.0)
	_save("amb_rain", _amb_rain(), RATE_BED, -14.0)
	_save("waterfall", _waterfall(), RATE_BED, -8.0)
	_save("campfire", _campfire(), RATE_BED, -9.0)
	# Footsteps, three of each so steps don't sound stamped.
	for i in 3:
		_save("step_dirt_%d" % (i + 1), _step_dirt(10 + i), RATE_FX, -6.0)
		_save("step_snow_%d" % (i + 1), _step_snow(20 + i), RATE_FX, -6.0)
		_save("step_wood_%d" % (i + 1), _step_wood(30 + i), RATE_FX, -6.0)
		_save("step_wet_%d" % (i + 1), _step_wet(40 + i), RATE_FX, -6.0)
		_save("climb_move_%d" % (i + 1), _climb_move(50 + i), RATE_FX, -8.0)
	# Climbing.
	_save("climb_clip", _clip(60), RATE_FX, -4.0)
	_save("climb_cam", _cam(61), RATE_FX, -4.0)
	_save("climb_chalk", _chalk(62), RATE_FX, -10.0)
	_save("climb_eat", _eat(63), RATE_FX, -6.0)
	_save("climb_fall", _fall(64), RATE_FX, -3.0)
	_save("climb_jug", _ratchet(65, 3), RATE_FX, -6.0)
	_save("climb_crux", _chime([76, 83], 0.09, 0.5), RATE_FX, -6.0)
	_save("climb_topout", _chime([67, 71, 74, 79, 83], 0.11, 1.4), RATE_FX, -4.0)
	# Menus.
	_save("ui_move", _tick(1250.0, 0.03), RATE_FX, -14.0)
	_save("ui_select", _knock(660.0, 0.11), RATE_FX, -10.0)
	_save("ui_back", _knock(440.0, 0.1), RATE_FX, -12.0)
	_save("ui_open", _swish(70, true), RATE_FX, -13.0)
	_save("ui_close", _swish(71, false), RATE_FX, -14.0)
	# Getting things, and talking.
	_save("pickup", _pickup(), RATE_FX, -9.0)
	_save("item_get", _chime([72, 76, 79, 84], 0.07, 0.9), RATE_FX, -7.0)
	_save("quest_done", _chime([67, 72, 76, 79, 76, 84], 0.1, 1.2), RATE_FX, -6.0)
	_save("talk", _talk(), RATE_FX, -15.0)
	_save("flutter", _flutter(72), RATE_FX, -12.0)
	_save("rustle", _rustle(73), RATE_FX, -14.0)
	_save("heart", _chime([76, 81, 88], 0.09, 1.0), RATE_FX, -8.0)
	# The Camp 4 slackline (last, so the sounds above keep their random takes).
	_save("slack_twang", _twang(80), RATE_FX, -7.0)
	_save("slack_gust", _gust(81), RATE_FX, -9.0)
	_save("slack_cheer", _cheer(82), RATE_FX, -8.0)
	_save("slack_medal", _chime([72, 76, 79, 84, 88], 0.08, 1.3), RATE_FX, -5.0)
	# Rivers, and the story's moments (after the rest, for the same reason).
	_save("river", _river(), RATE_BED, -11.0)
	_save("story_sting", _sting(), RATE_FX, -7.0)
	print("Sounds written to %s. Run godot --headless --path . --import next." % OUT)
	quit()


# ------------------------------------------------------------------ output

## Normalizes [param buf] to [param peak_db] and writes it as OUT/<name>.wav.
## A sound that isn't a loop gets a short fade at its end, so it never stops
## on a click.
func _save(sound_name: String, buf: PackedFloat32Array, rate: int, peak_db: float) -> void:
	if not (sound_name.begins_with("amb_") or sound_name in ["waterfall", "campfire", "river"]):
		var tail := mini(int(0.008 * rate), buf.size())
		for i in tail:
			buf[buf.size() - 1 - i] *= float(i) / tail
	var peak := 0.0
	for v in buf:
		peak = maxf(peak, absf(v))
	var gain := db_to_linear(peak_db) / maxf(peak, 0.000001)
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, clampi(int(roundf(buf[i] * gain * 32767.0)), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	var err := wav.save_to_wav(OUT + sound_name + ".wav")
	if err != OK:
		push_error("Could not write %s: %s" % [sound_name, error_string(err)])


# ------------------------------------------------------------------ building blocks

func _buf(seconds: float, rate: int) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * rate))
	return buf


## [param seconds] of loop, built [param fade] seconds long and folded so the
## tail fades into the head. [param fill] writes the raw sound into the array.
func _loop(seconds: float, fade: float, rate: int, fill: Callable) -> PackedFloat32Array:
	var n := int(seconds * rate)
	var f := int(fade * rate)
	var raw := _buf(seconds + fade, rate)
	fill.call(raw, rate)
	var out := raw.slice(0, n)
	for i in f:
		var t := float(i) / f
		# Equal-power crossfade: the extra tail fades out over the head.
		out[i] = raw[i] * sin(t * PI / 2.0) + raw[n + i] * cos(t * PI / 2.0)
	return out


## Adds white noise shaped by a two-pole low-pass (cutoff [param lp] Hz) and,
## if [param hp] > 0, a one-pole high-pass, scaled by [param amp].
func _add_noise(buf: PackedFloat32Array, rate: int, amp: float, lp: float, hp := 0.0, from := 0, to := -1) -> void:
	if to < 0:
		to = buf.size()
	var a := _one_pole(lp, rate)
	var b := _one_pole(hp, rate) if hp > 0.0 else 0.0
	var low := 0.0
	var low2 := 0.0
	var high_low := 0.0
	# Two poles fall off at 12 dB an octave, so the cutoff really is the top.
	# The gain keeps the level about the same whatever the cutoff.
	var level := 1.0 / sqrt(maxf(a, 0.0001))
	for i in range(from, to):
		low += a * (_rng.randf_range(-1.0, 1.0) - low)
		low2 += a * (low - low2)
		var v := low2 * level
		if hp > 0.0:
			high_low += b * (v - high_low)
			v -= high_low
		buf[i] += v * amp


func _one_pole(cutoff: float, rate: int) -> float:
	return 1.0 - exp(-TAU * cutoff / rate)


## A slow random swell between [param lo] and [param hi], one value a sample,
## that wanders about every [param period] seconds.
func _wander(n: int, rate: int, period: float, lo: float, hi: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var step := int(period * rate)
	var a := _rng.randf()
	var b := _rng.randf()
	for i in n:
		if i % step == 0:
			a = b
			b = _rng.randf()
		var t := float(i % step) / step
		t = t * t * (3.0 - 2.0 * t)
		out[i] = lerpf(lo, hi, lerpf(a, b, t))
	return out


## Band-passed noise through a state-variable filter whose center follows
## [param center] (Hz, per sample). [param q] is the resonance.
func _add_band_noise(buf: PackedFloat32Array, rate: int, center: PackedFloat32Array, q: float, gain: PackedFloat32Array) -> void:
	var low := 0.0
	var band := 0.0
	for i in buf.size():
		var f := 2.0 * sin(PI * minf(center[i], rate / 6.0) / rate)
		var high := _rng.randf_range(-1.0, 1.0) - low - band / q
		band += f * high
		low += f * band
		buf[i] += band * gain[i]


## A short tone at [param at] seconds: frequency sweeps from [param f0] to
## [param f1] Hz over [param dur] seconds under a soft envelope.
func _add_tone(buf: PackedFloat32Array, rate: int, at: float, dur: float, f0: float, f1: float, amp: float, harmonics := 0.0) -> void:
	var start := int(at * rate)
	var n := int(dur * rate)
	var phase := 0.0
	for i in n:
		if start + i >= buf.size():
			break
		var t := float(i) / n
		var freq := lerpf(f0, f1, t)
		phase += TAU * freq / rate
		var env := sin(PI * t) * sin(PI * t)
		buf[start + i] += (sin(phase) + harmonics * sin(phase * 2.0)) * env * amp


## A struck-metal or wood "tink": a few inharmonic partials that ring and die.
func _add_ping(buf: PackedFloat32Array, rate: int, at: float, partials: Array, decay: float, amp: float) -> void:
	var start := int(at * rate)
	var n := int(decay * 6.0 * rate)
	for i in n:
		if start + i >= buf.size():
			break
		var t := float(i) / rate
		var v := 0.0
		for k in partials.size():
			var p: Array = partials[k]
			v += sin(TAU * float(p[0]) * t) * float(p[1]) * exp(-t / (decay / (1.0 + k * 0.6)))
		buf[start + i] += v * amp


## A click: a few milliseconds of bright noise.
func _add_click(buf: PackedFloat32Array, rate: int, at: float, length: float, amp: float, lp := 6000.0) -> void:
	var start := int(at * rate)
	var n := maxi(int(length * rate), 2)
	var a := _one_pole(lp, rate)
	var low := 0.0
	for i in n:
		if start + i >= buf.size():
			break
		low += a * (_rng.randf_range(-1.0, 1.0) - low)
		buf[start + i] += low * amp * exp(-float(i) / n * 5.0)


func _envelope(buf: PackedFloat32Array, attack: float, rate: int) -> void:
	var a := int(attack * rate)
	for i in buf.size():
		var t := float(i) / buf.size()
		var env := minf(float(i) / maxf(a, 1), 1.0) * pow(1.0 - t, 2.0)
		buf[i] *= env


# ------------------------------------------------------------------ ambience

## Pines in a light breeze, with mountain chickadees ("fee-bee"), a far-off
## warbler's trill, and a Steller's jay now and then.
func _amb_day() -> PackedFloat32Array:
	_rng.seed = 1
	return _loop(16.0, 1.5, RATE_BED, func(buf: PackedFloat32Array, rate: int) -> void:
		var n := buf.size()
		_add_band_noise(buf, rate, _wander(n, rate, 3.0, 350.0, 700.0), 0.8, _wander(n, rate, 2.5, 0.05, 0.16))
		_add_noise(buf, rate, 0.05, 2500.0, 600.0)
		# Chickadees: a clear two-note whistle, the second note lower.
		for at in [1.2, 6.8, 11.9]:
			var f := _rng.randf_range(3600.0, 4100.0)
			var amp := _rng.randf_range(0.18, 0.3)
			_add_tone(buf, rate, at, 0.32, f, f * 0.98, amp)
			_add_tone(buf, rate, at + 0.42, 0.36, f * 0.86, f * 0.84, amp * 0.85)
		# A warbler's trill: quick falling notes.
		for at in [3.9, 13.6]:
			for k in 9:
				var f := 5200.0 - k * 120.0
				_add_tone(buf, rate, at + k * 0.075, 0.06, f, f - 900.0, 0.08)
		# A jay: two harsh calls, far off.
		var jay := 9.3
		for k in 2:
			_add_tone(buf, rate, jay + k * 0.32, 0.2, 1900.0, 1500.0, 0.06, 0.8)
		)


## Crickets in the meadow grass, a soft breeze, and a great horned owl.
func _amb_night() -> PackedFloat32Array:
	_rng.seed = 2
	return _loop(20.0, 1.5, RATE_BED, func(buf: PackedFloat32Array, rate: int) -> void:
		var n := buf.size()
		_add_band_noise(buf, rate, _wander(n, rate, 4.0, 250.0, 500.0), 0.7, _wander(n, rate, 3.0, 0.03, 0.08))
		# Each cricket chirps in bursts of pulses at its own pitch and pace.
		var crickets := [[4300.0, 0.62, 0.11], [4700.0, 0.55, 0.07], [3900.0, 0.8, 0.05], [5100.0, 0.47, 0.035]]
		for c: Array in crickets:
			var freq: float = c[0]
			var every: float = c[1]
			var amp: float = c[2]
			var t := _rng.randf() * every
			while t < float(n) / rate:
				for p in 3:
					_add_tone(buf, rate, t + p * 0.035, 0.025, freq, freq, amp)
				t += every * _rng.randf_range(0.95, 1.05)
		# "Hoo, h-hoo, hoo, hoo."
		var owl := 7.5
		for note: Array in [[0.0, 0.45], [0.75, 0.16], [0.95, 0.4], [1.55, 0.4], [2.15, 0.45]]:
			_add_tone(buf, rate, owl + float(note[0]), float(note[1]), 330.0, 300.0, 0.22, 0.25)
		)


## Wind over granite and through the high country's lodgepole pines.
func _amb_wind() -> PackedFloat32Array:
	_rng.seed = 3
	return _loop(14.0, 2.0, RATE_BED, func(buf: PackedFloat32Array, rate: int) -> void:
		var n := buf.size()
		_add_band_noise(buf, rate, _wander(n, rate, 2.2, 220.0, 900.0), 2.5, _wander(n, rate, 1.8, 0.02, 0.12))
		_add_band_noise(buf, rate, _wander(n, rate, 3.1, 600.0, 1400.0), 4.0, _wander(n, rate, 2.6, 0.0, 0.05))
		_add_noise(buf, rate, 0.15, 400.0)
		)


## Steady rain on leaves and the ground, with drips.
func _amb_rain() -> PackedFloat32Array:
	_rng.seed = 4
	return _loop(10.0, 1.0, RATE_BED, func(buf: PackedFloat32Array, rate: int) -> void:
		_add_noise(buf, rate, 0.5, 5000.0, 900.0)
		_add_noise(buf, rate, 0.25, 600.0)
		var t := 0.0
		while t < float(buf.size()) / rate:
			_add_click(buf, rate, t, 0.004, _rng.randf_range(0.2, 0.7), _rng.randf_range(2500.0, 7000.0))
			t += _rng.randf_range(0.005, 0.05)
		)


## A waterfall's roar: deep rumble from the plunge pool and a bright hiss of
## spray, rising and falling a little as gusts move it.
func _waterfall() -> PackedFloat32Array:
	_rng.seed = 5
	return _loop(8.0, 1.5, RATE_BED, func(buf: PackedFloat32Array, rate: int) -> void:
		var n := buf.size()
		_add_noise(buf, rate, 1.0, 160.0)
		_add_noise(buf, rate, 0.45, 700.0, 120.0)
		_add_noise(buf, rate, 0.12, 2600.0, 600.0)
		_add_band_noise(buf, rate, _wander(n, rate, 1.4, 900.0, 1800.0), 1.2, _wander(n, rate, 1.1, 0.04, 0.12))
		var swell := _wander(n, rate, 1.7, 0.8, 1.0)
		for i in n:
			buf[i] *= swell[i]
		)


## A river running over cobbles: a soft rush, a wandering burble in the
## middle, and small bubbles rising, quieter than a waterfall.
func _river() -> PackedFloat32Array:
	_rng.seed = 7
	return _loop(9.0, 1.5, RATE_BED, func(buf: PackedFloat32Array, rate: int) -> void:
		var n := buf.size()
		_add_noise(buf, rate, 0.35, 420.0, 90.0)
		_add_noise(buf, rate, 0.08, 1800.0, 500.0)
		_add_band_noise(buf, rate, _wander(n, rate, 0.6, 500.0, 1300.0), 2.2, _wander(n, rate, 0.5, 0.05, 0.16))
		# bubbles: quick upward chirps, a few a second
		var t := 0.05
		while t < float(n) / rate - 0.05:
			var f := _rng.randf_range(380.0, 900.0)
			_add_tone(buf, rate, t, _rng.randf_range(0.015, 0.04), f, f * _rng.randf_range(1.3, 1.8), _rng.randf_range(0.03, 0.08))
			t += _rng.randf_range(0.08, 0.35)
		)


## A story moment opening: a warm chord swelling up under a high chime, the
## way a scene in a film begins.
func _sting() -> PackedFloat32Array:
	_rng.seed = 9
	var buf := _buf(3.6, RATE_FX)
	# D, A, F#, E: open and a little wistful
	for k in 4:
		var f := 440.0 * pow(2.0, (float([50, 57, 66, 64][k]) - 69.0) / 12.0)
		_add_tone(buf, RATE_FX, 0.05 + k * 0.06, 3.4, f, f, 0.16, 0.25)
	for k in 3:
		var f := 440.0 * pow(2.0, (float([81, 86, 88][k]) - 69.0) / 12.0)
		_add_ping(buf, RATE_FX, 0.35 + k * 0.22, [[f, 1.0], [f * 2.0, 0.2]], 0.5, 0.22)
	return buf


## A campfire: a low breathy roar, constant small crackles, and pops.
func _campfire() -> PackedFloat32Array:
	_rng.seed = 6
	return _loop(9.0, 1.0, RATE_BED, func(buf: PackedFloat32Array, rate: int) -> void:
		var n := buf.size()
		_add_band_noise(buf, rate, _wander(n, rate, 0.9, 150.0, 300.0), 0.9, _wander(n, rate, 0.7, 0.3, 0.6))
		_add_noise(buf, rate, 0.08, 500.0)
		var t := 0.0
		while t < float(n) / rate:
			_add_click(buf, rate, t, _rng.randf_range(0.002, 0.008), _rng.randf_range(0.15, 0.5), _rng.randf_range(2000.0, 6000.0))
			t += _rng.randf_range(0.01, 0.16)
		t = 0.4
		while t < float(n) / rate:
			_add_click(buf, rate, t, _rng.randf_range(0.01, 0.025), _rng.randf_range(0.7, 1.0), 4000.0)
			t += _rng.randf_range(0.6, 2.2)
		)


# ------------------------------------------------------------------ footsteps

## Boot on packed dirt and duff: a soft heel thud and a scuff.
func _step_dirt(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(0.16, RATE_FX)
	_add_ping(buf, RATE_FX, 0.0, [[_rng.randf_range(85.0, 110.0), 1.0]], 0.02, 0.6)
	_add_noise(buf, RATE_FX, 0.5, _rng.randf_range(500.0, 700.0), 60.0, 0, int(0.07 * RATE_FX))
	_add_noise(buf, RATE_FX, 0.12, 1600.0, 300.0, int(0.035 * RATE_FX), int(0.13 * RATE_FX))
	_envelope(buf, 0.003, RATE_FX)
	return buf


## Snow: a squeaky, granular crunch.
func _step_snow(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(0.22, RATE_FX)
	var t := 0.0
	while t < 0.17:
		_add_click(buf, RATE_FX, t, 0.003, _rng.randf_range(0.3, 1.0), _rng.randf_range(2500.0, 6000.0))
		t += _rng.randf_range(0.002, 0.012)
	_add_noise(buf, RATE_FX, 0.2, 700.0, 100.0)
	_envelope(buf, 0.01, RATE_FX)
	return buf


## A boot on a wooden floor: a hollow knock.
func _step_wood(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(0.18, RATE_FX)
	var f := _rng.randf_range(150.0, 190.0)
	_add_ping(buf, RATE_FX, 0.0, [[f, 1.0], [f * 2.3, 0.4], [f * 4.1, 0.15]], 0.025, 0.8)
	_add_click(buf, RATE_FX, 0.0, 0.012, 0.6, 2500.0)
	return buf


## Wet ground: a thud with a short squelch.
func _step_wet(seed_value: int) -> PackedFloat32Array:
	var buf := _step_dirt(seed_value)
	_add_tone(buf, RATE_FX, 0.03, 0.08, _rng.randf_range(600.0, 800.0), 1300.0, 0.12)
	_add_noise(buf, RATE_FX, 0.1, 3000.0, 1200.0, int(0.03 * RATE_FX), int(0.1 * RATE_FX))
	return buf


# ------------------------------------------------------------------ climbing

## A hand and shoe finding the next hold: a gritty scrape on granite.
func _climb_move(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(0.2, RATE_FX)
	_add_noise(buf, RATE_FX, 1.0, 2200.0, 400.0)
	for i in buf.size():
		var t := float(i) / buf.size()
		buf[i] *= sin(PI * t) * (0.6 + 0.4 * sin(t * 40.0 + seed_value))
	_add_click(buf, RATE_FX, 0.13, 0.01, 0.6, 1500.0)
	return buf


## Clipping the rope: the gate opening, then snapping shut.
func _clip(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(0.35, RATE_FX)
	var metal := [[2350.0, 1.0], [3720.0, 0.6], [5480.0, 0.4], [8100.0, 0.25]]
	_add_ping(buf, RATE_FX, 0.0, metal, 0.012, 0.35)
	_add_click(buf, RATE_FX, 0.0, 0.004, 0.4)
	_add_ping(buf, RATE_FX, 0.09, metal, 0.03, 0.9)
	_add_click(buf, RATE_FX, 0.09, 0.005, 0.8)
	return buf


## A cam going into a crack: trigger clicks, then a clink as it seats.
func _cam(seed_value: int) -> PackedFloat32Array:
	var buf := _ratchet(seed_value, 3)
	_add_ping(buf, RATE_FX, 0.2, [[1850.0, 1.0], [3100.0, 0.7], [4650.0, 0.4]], 0.05, 0.8)
	return buf


## Quick ratcheting clicks (an ascender biting, a cam's trigger).
func _ratchet(seed_value: int, clicks: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(0.45, RATE_FX)
	for k in clicks:
		var at := 0.02 + k * 0.05
		_add_click(buf, RATE_FX, at, 0.004, 0.9, 7000.0)
		_add_ping(buf, RATE_FX, at, [[4200.0, 1.0], [6300.0, 0.5]], 0.006, 0.4)
	return buf


## A dip into the chalk bag: a soft dusty puff.
func _chalk(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(0.4, RATE_FX)
	_add_noise(buf, RATE_FX, 1.0, 1000.0, 150.0)
	for i in buf.size():
		var t := float(i) / buf.size()
		buf[i] *= sin(PI * pow(t, 0.6))
	return buf


## A bite of something crunchy, three chews.
func _eat(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(0.6, RATE_FX)
	for k in 3:
		var at := k * 0.18
		var t := 0.0
		while t < 0.07:
			_add_click(buf, RATE_FX, at + t, 0.003, _rng.randf_range(0.3, 1.0), 3500.0)
			t += _rng.randf_range(0.003, 0.01)
	return buf


## Falling: air rushing, then the rope coming tight with a thump and a creak.
func _fall(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(0.9, RATE_FX)
	var n := buf.size()
	var center := PackedFloat32Array()
	var gain := PackedFloat32Array()
	center.resize(n)
	gain.resize(n)
	for i in n:
		var t := float(i) / RATE_FX
		center[i] = 300.0 + t * 2600.0
		gain[i] = 0.25 * clampf(t / 0.35, 0.0, 1.0) if t < 0.45 else 0.0
	_add_band_noise(buf, RATE_FX, center, 1.5, gain)
	_add_ping(buf, RATE_FX, 0.45, [[70.0, 1.0], [140.0, 0.4]], 0.06, 1.0)
	_add_click(buf, RATE_FX, 0.45, 0.03, 0.8, 800.0)
	_add_tone(buf, RATE_FX, 0.5, 0.3, 180.0, 140.0, 0.25, 0.6)
	return buf


## A small bell melody (MIDI note numbers), each note [param gap] seconds after
## the last and ringing [param ring] seconds.
func _chime(notes: Array, gap: float, ring: float) -> PackedFloat32Array:
	var buf := _buf(gap * notes.size() + ring, RATE_FX)
	for k in notes.size():
		var f := 440.0 * pow(2.0, (float(notes[k]) - 69.0) / 12.0)
		_add_ping(buf, RATE_FX, k * gap, [[f, 1.0], [f * 2.0, 0.3], [f * 3.01, 0.1]], ring / 5.0, 0.5)
	return buf


## The slackline bucking under you: a low thrum of webbing, plucked, with
## the slap of a foot.
func _twang(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(0.5, RATE_FX)
	_add_ping(buf, RATE_FX, 0.0, [[73.0, 1.0], [146.0, 0.55], [221.0, 0.25], [297.0, 0.1]], 0.07, 1.0)
	_add_click(buf, RATE_FX, 0.0, 0.012, 0.5, 1800.0)
	return buf


## Wind coming off the wall: a long swell of band noise that rises and falls.
func _gust(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(1.6, RATE_FX)
	var center := PackedFloat32Array()
	var gain := PackedFloat32Array()
	center.resize(buf.size())
	gain.resize(buf.size())
	for i in buf.size():
		var t := float(i) / buf.size()
		center[i] = 380.0 + sin(PI * t) * 900.0
		gain[i] = pow(sin(PI * t), 1.6) * 0.32
	_add_band_noise(buf, RATE_FX, center, 1.1, gain)
	_add_noise(buf, RATE_FX, 0.05, 900.0, 120.0)
	_envelope(buf, 0.35, RATE_FX)
	return buf


## A few climbers cheering from the boulders: rising "whoo"s and claps.
func _cheer(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(1.3, RATE_FX)
	for k in 4:
		var at := _rng.randf_range(0.0, 0.25)
		var f := _rng.randf_range(260.0, 420.0)
		_add_tone(buf, RATE_FX, at, _rng.randf_range(0.45, 0.7), f, f * _rng.randf_range(1.35, 1.6), 0.22, 0.45)
	for k in 14:
		_add_click(buf, RATE_FX, 0.1 + k * 0.075 + _rng.randf_range(-0.02, 0.02), 0.01, _rng.randf_range(0.5, 0.9), 2600.0)
	var center := PackedFloat32Array()
	var gain := PackedFloat32Array()
	center.resize(buf.size())
	gain.resize(buf.size())
	for i in buf.size():
		var t := float(i) / buf.size()
		center[i] = 1100.0
		gain[i] = 0.12 * sin(PI * minf(t * 1.6, 1.0))
	_add_band_noise(buf, RATE_FX, center, 0.9, gain)
	return buf


# ------------------------------------------------------------------ menus

func _tick(freq: float, length: float) -> PackedFloat32Array:
	var buf := _buf(length, RATE_FX)
	_add_ping(buf, RATE_FX, 0.0, [[freq, 1.0], [freq * 2.7, 0.3]], length / 4.0, 1.0)
	return buf


## A soft page-turn swish: a puff of band noise that rises (opening) or
## falls (closing).
func _swish(seed_value: int, rising: bool) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(0.16, RATE_FX)
	var center := PackedFloat32Array()
	var gain := PackedFloat32Array()
	center.resize(buf.size())
	gain.resize(buf.size())
	for i in buf.size():
		var t := float(i) / buf.size()
		center[i] = lerpf(900.0, 3200.0, t if rising else 1.0 - t)
		gain[i] = sin(PI * t) * 0.5
	_add_band_noise(buf, RATE_FX, center, 1.4, gain)
	return buf


## A round, bubbly pop for picking something up: two quick rising blips.
func _pickup() -> PackedFloat32Array:
	var buf := _buf(0.16, RATE_FX)
	_add_tone(buf, RATE_FX, 0.0, 0.07, 520.0, 980.0, 0.8, 0.15)
	_add_tone(buf, RATE_FX, 0.055, 0.09, 780.0, 1480.0, 0.6, 0.1)
	return buf


## One syllable of the talking blip: a short, soft, slightly reedy tone.
## Sound.play pitches it per speaker, so each person has their own voice.
func _talk() -> PackedFloat32Array:
	var buf := _buf(0.05, RATE_FX)
	var phase := 0.0
	for i in buf.size():
		var t := float(i) / buf.size()
		phase += TAU * lerpf(330.0, 300.0, t) / RATE_FX
		var env := minf(t * 12.0, 1.0) * pow(1.0 - t, 1.5)
		buf[i] = (sin(phase) + 0.35 * sin(phase * 2.0) + 0.12 * sin(phase * 3.0)) * env
	return buf


## Wings taking off: a quick run of soft feathery beats.
func _flutter(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(0.42, RATE_FX)
	for k in 7:
		var at := k * 0.055 * (1.0 + k * 0.04)
		var start := int(at * RATE_FX)
		_add_noise(buf, RATE_FX, 0.6 * pow(0.85, k), 2400.0, 500.0, start, mini(start + int(0.035 * RATE_FX), buf.size()))
	return buf


## Leaves brushed aside: a short, airy swish with a few crackles in it.
func _rustle(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(0.24, RATE_FX)
	_add_noise(buf, RATE_FX, 0.5, 5200.0, 1400.0)
	for k in 5:
		_add_click(buf, RATE_FX, _rng.randf_range(0.01, 0.16), 0.004, 0.5, 7000.0)
	_envelope(buf, 0.02, RATE_FX)
	return buf


## A wooden knock, like tapping the timber frame of the menus.
func _knock(freq: float, length: float) -> PackedFloat32Array:
	var buf := _buf(length, RATE_FX)
	_add_ping(buf, RATE_FX, 0.0, [[freq, 1.0], [freq * 2.4, 0.5], [freq * 3.9, 0.2]], length / 5.0, 1.0)
	_add_click(buf, RATE_FX, 0.0, 0.006, 0.4, 3000.0)
	return buf
