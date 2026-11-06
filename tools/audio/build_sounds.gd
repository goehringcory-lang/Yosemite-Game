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
	# Wildlife calls, played now and then over the beds (Sound._update_calls),
	# so the birds and the owl never come round on a loop. Two takes of each.
	for i in 2:
		var take := "_%d" % (i + 1)
		_save("call_chickadee" + take, _call_chickadee(100 + i), RATE_FX, -13.0)
		_save("call_jay" + take, _call_jay(102 + i), RATE_FX, -14.0)
		_save("call_robin" + take, _call_robin(104 + i), RATE_FX, -14.0)
		_save("call_warbler" + take, _call_warbler(106 + i), RATE_FX, -16.0)
		_save("call_woodpecker" + take, _call_woodpecker(108 + i), RATE_FX, -11.0)
		_save("call_raven" + take, _call_raven(110 + i), RATE_FX, -14.0)
		_save("call_owl" + take, _call_owl(112 + i), RATE_FX, -14.0)
		_save("call_frogs" + take, _call_frogs(114 + i), RATE_FX, -13.0)
		_save("call_swift" + take, _call_swift(116 + i), RATE_FX, -16.0)
		_save("call_coyote" + take, _call_coyote(118 + i), RATE_FX, -17.0)
		_save("thunder" + take, _thunder(120 + i), RATE_BED, -7.0)
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


## [param n] samples of noise through [method _add_noise]'s filters, on their
## own so a layer can be shaped by a swell before it is mixed in.
func _noise(n: int, rate: int, lp: float, hp := 0.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	_add_noise(out, rate, 1.0, lp, hp)
	return out


## How hard the wind blows, one value a sample, about 0 to 1: a slow swell
## times a quicker flutter, raised to a power so most of the time is a lull
## and the gusts stand out. [param floor] is the lull's level.
func _gusts(n: int, rate: int, period: float, floor: float) -> PackedFloat32Array:
	var slow := _wander(n, rate, period, 0.0, 1.0)
	var quick := _wander(n, rate, period * 0.31, 0.5, 1.0)
	for i in n:
		slow[i] = lerpf(floor, 1.0, pow(slow[i] * quick[i], 1.5))
	return slow


## Wind following [param gust]: the air's low rush ([param air]), and a hush
## in the needles ([param needles]) that only opens up near a gust's top and
## brightens from [param lo] towards [param lo] + [param span] Hz as it does.
func _add_breeze(buf: PackedFloat32Array, rate: int, gust: PackedFloat32Array, air: float, needles: float, lo: float, span: float) -> void:
	var n := buf.size()
	var rush := _noise(n, rate, 350.0, 40.0)
	var center := PackedFloat32Array()
	var gain := PackedFloat32Array()
	center.resize(n)
	gain.resize(n)
	for i in n:
		var g := gust[i]
		buf[i] += rush[i] * air * g
		center[i] = lo + span * g
		gain[i] = needles * g * g * g
	_add_band_noise(buf, rate, center, 0.9, gain)


## Leaves rustling as [param gust] moves them: little runs of short, airy
## grains, often when the wind is up and hardly at all in a lull.
## [param busy] is how often a run starts at the top of a gust.
func _add_leaves(buf: PackedFloat32Array, rate: int, gust: PackedFloat32Array, busy: float, amp: float) -> void:
	var seconds := float(buf.size()) / rate
	var t := 0.0
	while t < seconds - 0.2:
		var g := gust[int(t * rate)]
		if _rng.randf() < busy * g * g:
			var at := t
			for k in _rng.randi_range(2, 6):
				_add_grain(buf, rate, at, _rng.randf_range(0.012, 0.05), _rng.randf_range(2200.0, 4800.0), amp * g * _rng.randf_range(0.4, 1.0))
				at += _rng.randf_range(0.015, 0.05)
		t += _rng.randf_range(0.05, 0.16)


## A rustle: a few milliseconds of band-passed noise around [param center] Hz,
## quick to start and quick to die.
func _add_grain(buf: PackedFloat32Array, rate: int, at: float, length: float, center: float, amp: float) -> void:
	var start := int(at * rate)
	var n := int(length * rate)
	var f := 2.0 * sin(PI * minf(center, rate / 6.0) / rate)
	var low := 0.0
	var band := 0.0
	for i in n:
		if start + i >= buf.size():
			break
		var high := _rng.randf_range(-1.0, 1.0) - low - band / 1.5
		band += f * high
		low += f * band
		var t := float(i) / n
		buf[start + i] += band * amp * minf(t * 8.0, 1.0) * (1.0 - t) * (1.0 - t)


## One bubble ringing as it forms in running water: a sine at [param freq] Hz
## that rises as it dies away over about [param decay] seconds.
func _add_bubble(buf: PackedFloat32Array, rate: int, at: float, freq: float, decay: float, amp: float) -> void:
	var start := int(at * rate)
	var n := int(decay * 5.0 * rate)
	var phase := 0.0
	for i in n:
		if start + i >= buf.size():
			break
		var t := float(i) / rate
		phase += TAU * freq * (1.0 + t / decay * 0.25) / rate
		buf[start + i] += sin(phase) * amp * exp(-t / decay) * minf(i / (0.0008 * rate), 1.0)


## A raindrop striking a leaf close by: a tap and a tiny ringing splash.
func _add_drop(buf: PackedFloat32Array, rate: int, at: float, amp: float) -> void:
	_add_click(buf, rate, at, 0.003, amp, 3500.0)
	_add_bubble(buf, rate, at + 0.002, _rng.randf_range(1200.0, 2600.0), 0.006, amp * 0.35)


# ------------------------------------------------------------------ ambience

## A light breeze in the pines. Wind isn't a steady hiss: it comes in gusts
## with near-quiet lulls between, and only a gust is strong enough to sound in
## the needles and set the leaves rustling. So everything here rides one gust
## swell: a low, soft rush of air, a hush in the needles that brightens as the
## gust builds, and little rustles of leaves, more of them the harder it blows.
## The birds sing over it on their own (the call_* sounds), so the loop has
## nothing in it to recognize.
func _amb_day() -> PackedFloat32Array:
	_rng.seed = 1
	return _loop(32.0, 3.0, RATE_BED, func(buf: PackedFloat32Array, rate: int) -> void:
		var n := buf.size()
		var gust := _gusts(n, rate, 6.5, 0.06)
		_add_breeze(buf, rate, gust, 0.35, 0.08, 650.0, 1300.0)
		_add_leaves(buf, rate, gust, 0.9, 0.05)
		# Insects far off in the grass: a faint, slow-beating shimmer.
		var hum := _wander(n, rate, 4.0, 0.0, 0.006)
		var phase := 0.0
		for i in n:
			phase += TAU * 2900.0 / rate
			buf[i] += sin(phase) * hum[i] * (0.6 + 0.4 * sin(TAU * 7.0 * i / rate))
		)


## Crickets in the meadow grass and the night air barely moving. The owls,
## frogs and coyotes call over it on their own.
func _amb_night() -> PackedFloat32Array:
	_rng.seed = 2
	return _loop(20.0, 1.5, RATE_BED, func(buf: PackedFloat32Array, rate: int) -> void:
		var n := buf.size()
		_add_breeze(buf, rate, _gusts(n, rate, 8.0, 0.1), 0.12, 0.012, 500.0, 800.0)
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
		)


## Wind over granite and through the high country's lodgepole pines: stronger
## gusts than the valley's, a low moan where it pours over the rock, and the
## needles roaring at the top of each gust.
func _amb_wind() -> PackedFloat32Array:
	_rng.seed = 3
	return _loop(30.0, 3.0, RATE_BED, func(buf: PackedFloat32Array, rate: int) -> void:
		var n := buf.size()
		var gust := _gusts(n, rate, 5.0, 0.15)
		_add_breeze(buf, rate, gust, 0.6, 0.07, 500.0, 1100.0)
		# The moan over the rock: a narrow band that slides up as a gust builds.
		var center := PackedFloat32Array()
		var gain := PackedFloat32Array()
		center.resize(n)
		gain.resize(n)
		for i in n:
			center[i] = 180.0 + 260.0 * gust[i]
			gain[i] = 0.012 * gust[i] * gust[i]
		_add_band_noise(buf, rate, center, 6.0, gain)
		_add_leaves(buf, rate, gust, 0.5, 0.035)
		)


## Steady rain on leaves and the ground: a soft wash, and drops, near and far,
## doing most of the work (a wash alone sounds like a radio between stations).
func _amb_rain() -> PackedFloat32Array:
	_rng.seed = 4
	return _loop(10.0, 1.0, RATE_BED, func(buf: PackedFloat32Array, rate: int) -> void:
		var n := buf.size()
		var wash := _wander(n, rate, 1.6, 0.75, 1.0)
		var hiss := _noise(n, rate, 2800.0, 500.0)
		var low := _noise(n, rate, 500.0)
		for i in n:
			buf[i] += (hiss[i] * 0.28 + low[i] * 0.3) * wash[i]
		var t := 0.0
		while t < float(n) / rate:
			# Mostly small far drops; now and then a big one close by.
			if _rng.randf() < 0.12:
				_add_drop(buf, rate, t, _rng.randf_range(0.25, 0.6))
			else:
				_add_click(buf, rate, t, 0.004, _rng.randf_range(0.1, 0.4), _rng.randf_range(1800.0, 4500.0))
			t += _rng.randf_range(0.004, 0.04)
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


## A river running over cobbles. What makes water sound like water and not
## noise is its bubbles: each one rings as it forms, a little tone that rises
## and dies in a few milliseconds, and thousands of them make the burble. So
## this is a low rush under a dense spray of bubbles, the near ones bigger and
## lower, coming in little runs where the current breaks over a stone.
func _river() -> PackedFloat32Array:
	_rng.seed = 7
	return _loop(12.0, 1.5, RATE_BED, func(buf: PackedFloat32Array, rate: int) -> void:
		var n := buf.size()
		var flow := _wander(n, rate, 1.3, 0.7, 1.0)
		var rush := _noise(n, rate, 320.0, 60.0)
		var spray := _noise(n, rate, 1600.0, 600.0)
		for i in n:
			buf[i] += (rush[i] * 0.2 + spray[i] * 0.012) * flow[i]
		var t := 0.0
		while t < float(n) / rate - 0.05:
			var f := _rng.randf_range(250.0, 1400.0)
			# Small bubbles ring higher, shorter and quieter.
			var size := 1.0 - (f - 250.0) / 1150.0
			_add_bubble(buf, rate, t, f, lerpf(0.004, 0.018, size), lerpf(0.04, 0.14, size) * flow[int(t * rate)])
			t += _rng.randf_range(0.004, 0.04) if _rng.randf() < 0.8 else _rng.randf_range(0.05, 0.15)
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


# ------------------------------------------------------------------ wildlife calls

## A voice for a call: a tone sweeping [param f0] to [param f1] Hz over
## [param dur] seconds, with [param partials] (multiples of the tone, and
## their levels), a flutter of [param am_hz] at [param am_depth], and a
## breath of noise for a rough throat. [param bend] curves the sweep: below 1
## it moves early, above 1 late.
func _add_voice(buf: PackedFloat32Array, rate: int, at: float, dur: float, f0: float, f1: float, amp: float,
		partials := [[1.0, 1.0]], am_hz := 0.0, am_depth := 0.0, noise := 0.0, bend := 1.0) -> void:
	var start := int(at * rate)
	var n := int(dur * rate)
	var phase := 0.0
	var low := 0.0
	var a := _one_pole(3000.0, rate)
	for i in n:
		if start + i >= buf.size():
			break
		var t := float(i) / n
		var freq := lerpf(f0, f1, pow(t, bend))
		phase += TAU * freq / rate
		# A quick start and a softer end, like a bird's note.
		var env := minf(t * 14.0, 1.0) * pow(1.0 - t, 0.8)
		var v := 0.0
		for p: Array in partials:
			v += sin(phase * float(p[0])) * float(p[1])
		if am_hz > 0.0:
			v *= 1.0 - am_depth * (0.5 + 0.5 * sin(TAU * am_hz * float(i) / rate))
		if noise > 0.0:
			low += a * (_rng.randf_range(-1.0, 1.0) - low)
			v += low * noise * 3.0
		buf[start + i] += v * env * amp


## Softens a call heard from farther off: a one-pole low-pass at [param cutoff].
func _distance(buf: PackedFloat32Array, rate: int, cutoff: float) -> void:
	var a := _one_pole(cutoff, rate)
	var low := 0.0
	for i in buf.size():
		low += a * (buf[i] - low)
		buf[i] = low


## A mountain chickadee: "fee-bee-bee", a clear whistle and two lower notes.
func _call_chickadee(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(1.6, RATE_FX)
	var f := _rng.randf_range(3600.0, 4100.0)
	var at := 0.05
	_add_voice(buf, RATE_FX, at, 0.34, f, f * 0.985, 0.3)
	at += 0.42
	for k in _rng.randi_range(1, 2):
		_add_voice(buf, RATE_FX, at, 0.22, f * 0.85, f * 0.83, 0.26)
		at += 0.3
	if _rng.randf() < 0.5:
		# and a "chick-a-dee-dee" buzz after it
		_add_voice(buf, RATE_FX, at + 0.05, 0.06, 5200.0, 4200.0, 0.12)
		for k in 2:
			_add_voice(buf, RATE_FX, at + 0.14 + k * 0.13, 0.11, 3200.0, 3000.0, 0.15, [[1.0, 1.0], [2.0, 0.3]], 90.0, 0.7)
	return buf


## A Steller's jay: three to five harsh "shook" calls.
func _call_jay(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(1.4, RATE_FX)
	var f := _rng.randf_range(1900.0, 2300.0)
	var calls := _rng.randi_range(3, 5)
	for k in calls:
		_add_voice(buf, RATE_FX, 0.04 + k * _rng.randf_range(0.17, 0.21), 0.12, f, f * 0.72, 0.35,
			[[1.0, 1.0], [2.0, 0.6], [3.0, 0.4], [4.0, 0.2]], 75.0, 0.6, 0.12, 0.6)
	return buf


## An American robin caroling: "cheerily, cheer-up, cheerio", slurred
## phrases rising and falling.
func _call_robin(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(2.6, RATE_FX)
	var at := 0.05
	for phrase in _rng.randi_range(3, 5):
		var base := _rng.randf_range(2100.0, 2700.0)
		for note in _rng.randi_range(2, 3):
			var lo := base * _rng.randf_range(0.85, 1.0)
			var hi := base * _rng.randf_range(1.12, 1.3)
			var up := _rng.randf() < 0.5
			_add_voice(buf, RATE_FX, at, _rng.randf_range(0.09, 0.14), lo if up else hi, hi if up else lo, 0.3, [[1.0, 1.0], [2.0, 0.12]])
			at += _rng.randf_range(0.11, 0.15)
		at += _rng.randf_range(0.18, 0.32)
	return buf


## A warbler's song: a quick trill of falling notes, then a flourish.
func _call_warbler(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(1.3, RATE_FX)
	var f := _rng.randf_range(5000.0, 5600.0)
	var notes := _rng.randi_range(8, 11)
	for k in notes:
		var top := f - k * 110.0
		_add_voice(buf, RATE_FX, 0.04 + k * 0.07, 0.055, top, top - 900.0, 0.3)
	var end := 0.04 + notes * 0.07
	_add_voice(buf, RATE_FX, end + 0.05, 0.14, 3800.0, 5600.0, 0.3, [[1.0, 1.0]], 0.0, 0.0, 0.0, 2.0)
	return buf


## A woodpecker drumming on a dead snag: a fast roll that slows a little
## and fades, from a little way off.
func _call_woodpecker(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(1.4, RATE_FX)
	var wood := _rng.randf_range(700.0, 1000.0)
	var at := 0.02
	var gap := _rng.randf_range(0.045, 0.055)
	for k in _rng.randi_range(14, 20):
		var amp := 0.9 * pow(0.95, k)
		_add_ping(buf, RATE_FX, at, [[wood, 1.0], [wood * 2.3, 0.45], [wood * 3.7, 0.2]], 0.008, amp)
		_add_click(buf, RATE_FX, at, 0.003, amp * 0.7, 3500.0)
		at += gap
		gap *= 1.012
	_distance(buf, RATE_FX, 4000.0)
	return buf


## A common raven: one to three deep, rough croaks, sometimes a "tok".
func _call_raven(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(1.8, RATE_FX)
	var f := _rng.randf_range(380.0, 460.0)
	var at := 0.05
	for k in _rng.randi_range(1, 3):
		_add_voice(buf, RATE_FX, at, 0.34, f * 1.05, f * 0.88, 0.32,
			[[1.0, 0.8], [2.0, 1.0], [3.0, 0.8], [4.0, 0.5], [5.0, 0.35], [6.0, 0.2]], 34.0, 0.55, 0.2, 0.5)
		at += _rng.randf_range(0.45, 0.6)
	if _rng.randf() < 0.5:
		_add_ping(buf, RATE_FX, at, [[1150.0, 1.0], [2300.0, 0.4]], 0.012, 0.6)
	_distance(buf, RATE_FX, 3500.0)
	return buf


## A great horned owl: "hoo, h-hoo, hoo, hoo", low and soft.
func _call_owl(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(3.0, RATE_FX)
	var f := _rng.randf_range(300.0, 340.0)
	var notes := [[0.0, 0.45], [0.75, 0.16], [0.95, 0.4], [1.55, 0.4], [2.15, 0.45]]
	if _rng.randf() < 0.5:
		notes = [[0.0, 0.5], [0.7, 0.14], [0.88, 0.38], [1.5, 0.5]]
	for note: Array in notes:
		_add_voice(buf, RATE_FX, 0.05 + float(note[0]), float(note[1]), f, f * 0.9, 0.4, [[1.0, 1.0], [2.0, 0.18]], 0.0, 0.0, 0.03)
	_distance(buf, RATE_FX, 1500.0)
	return buf


## Pacific chorus frogs by the water: a few "rib-bit"s at different pitches,
## two pulsed buzzes each.
func _call_frogs(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(3.2, RATE_FX)
	for frog in 3:
		var f := _rng.randf_range(1700.0, 2400.0)
		var amp := _rng.randf_range(0.18, 0.32)
		var at := _rng.randf_range(0.05, 0.6)
		while at < 2.7:
			_add_voice(buf, RATE_FX, at, 0.07, f * 0.9, f, amp, [[1.0, 1.0], [2.0, 0.4]], 110.0, 0.9)
			_add_voice(buf, RATE_FX, at + 0.1, 0.12, f, f * 1.08, amp, [[1.0, 1.0], [2.0, 0.4]], 120.0, 0.9)
			at += _rng.randf_range(0.5, 0.9)
	_distance(buf, RATE_FX, 3800.0)
	return buf


## White-throated swifts screaming past the wall: a high, falling twitter.
func _call_swift(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(1.2, RATE_FX)
	var f := _rng.randf_range(5800.0, 6400.0)
	var notes := _rng.randi_range(9, 13)
	for k in notes:
		var top := f * pow(0.965, k)
		_add_voice(buf, RATE_FX, 0.03 + k * 0.065, 0.05, top, top * 0.9, 0.3 * (1.0 - 0.4 * float(k) / notes))
	return buf


## Coyotes far off across the meadow: yips, then a howl that rises, holds
## and falls, and a second one joining in.
func _call_coyote(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(3.6, RATE_FX)
	var at := 0.05
	for k in _rng.randi_range(3, 5):
		var f := _rng.randf_range(800.0, 1000.0)
		_add_voice(buf, RATE_FX, at, 0.09, f, f * 1.35, 0.25, [[1.0, 1.0], [2.0, 0.3]], 0.0, 0.0, 0.02, 0.5)
		at += _rng.randf_range(0.13, 0.2)
	for voice in 2:
		var f := _rng.randf_range(520.0, 620.0) * (1.0 + voice * 0.18)
		var start := at + 0.1 + voice * 0.6
		var dur := _rng.randf_range(1.4, 1.9)
		# rise, hold with a waver, then fall away
		var n := int(dur * RATE_FX)
		var s0 := int(start * RATE_FX)
		var phase := 0.0
		for i in n:
			if s0 + i >= buf.size():
				break
			var t := float(i) / n
			var shape := smoothstep(0.0, 0.25, t) * (1.0 - 0.35 * smoothstep(0.7, 1.0, t))
			var freq := f * (1.0 + 0.9 * shape) * (1.0 + 0.012 * sin(TAU * 5.5 * float(i) / RATE_FX))
			phase += TAU * freq / RATE_FX
			var env := minf(t * 8.0, 1.0) * pow(1.0 - t, 1.2)
			buf[s0 + i] += (sin(phase) + 0.25 * sin(phase * 2.0)) * env * 0.25
	_distance(buf, RATE_FX, 2000.0)
	return buf


## Thunder rolling down the Valley: sometimes a crack first, then a long,
## lumpy rumble off the walls.
func _thunder(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(6.5, RATE_BED)
	var n := buf.size()
	var near := seed_value % 2 == 0
	if near:
		_add_noise(buf, RATE_BED, 0.9, 1400.0, 80.0, 0, int(0.25 * RATE_BED))
	var from := int(0.15 * RATE_BED)
	_add_noise(buf, RATE_BED, 1.0, 110.0, 0.0, from, n)
	_add_noise(buf, RATE_BED, 0.3, 380.0, 60.0, from, n)
	var swell := _wander(n, RATE_BED, 0.45, 0.2, 1.0)
	for i in range(from, n):
		var t := float(i - from) / (n - from)
		buf[i] *= swell[i] * minf(t * 6.0, 1.0) * pow(1.0 - t, 1.6)
	return buf
