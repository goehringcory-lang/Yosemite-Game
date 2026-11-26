extends SceneTree
## Synthesizes the climbing v2 sounds (thread 10's look) into assets/audio/
## as 16-bit mono WAVs, beside the ones tools/audio/build_sounds.gd makes:
## rope pulled up hand over hand, a cam's trigger, a nut seating, a piece
## popping, the rope catching a fall, the air of a fall, a hand slapping a
## jug, a jam's scrunch, breathing hard (three takes), a crux sent. Nothing
## is recorded or downloaded; each sound has a fixed seed.
##
##   godot --headless --path . -s res://tools/audio/build_climb_v2_sounds.gd
##   godot --headless --path . --import
##
## LookSound (scripts/climb/v2/look/look_sound.gd) plays them.

const OUT := "res://assets/audio/"
const RATE_FX := 32000

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_save("climb2_rope_pull", _rope_pull(301), -9.0)
	_save("climb2_cam_trigger", _trigger(302), -12.0)
	_save("climb2_nut", _nut(303), -6.0)
	_save("climb2_pop", _pop(304), -4.0)
	_save("climb2_catch", _catch(305), -3.0)
	_save("climb2_whoosh", _whoosh(306), -6.0)
	_save("climb2_slap", _slap(307), -7.0)
	_save("climb2_jam", _jam(308), -9.0)
	for i in 3:
		_save("climb2_breath_%d" % (i + 1), _breath(310 + i), -14.0)
	_save("climb2_sent", _sent(), -8.0)
	quit()


## Normalizes [param buf] to [param peak_db], fades its last 8 ms, and writes
## OUT/<name>.wav.
func _save(sound_name: String, buf: PackedFloat32Array, peak_db: float) -> void:
	var tail := mini(int(0.008 * RATE_FX), buf.size())
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
	wav.mix_rate = RATE_FX
	wav.stereo = false
	wav.data = data
	var err := wav.save_to_wav(OUT + sound_name + ".wav")
	if err != OK:
		push_error("Could not write %s: %s" % [sound_name, error_string(err)])


# ------------------------------------------------------------------ sounds

## Rope drawn up through the hand: a soft nylon hiss that swells and stops,
## with a faint creak as the hand closes.
func _rope_pull(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(0.32, RATE_FX)
	_add_noise(buf, RATE_FX, 1.0, 3200.0, 700.0)
	for i in buf.size():
		var t := float(i) / buf.size()
		buf[i] *= pow(sin(PI * pow(t, 0.7)), 1.5)
	_add_tone(buf, RATE_FX, 0.26, 0.05, 420.0, 380.0, 0.08)
	return buf


## A cam's trigger pulled back: a dry spring creak and two tiny clicks.
func _trigger(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(0.22, RATE_FX)
	_add_click(buf, RATE_FX, 0.01, 0.003, 0.7, 8000.0)
	_add_tone(buf, RATE_FX, 0.02, 0.12, 1900.0, 2300.0, 0.08)
	_add_click(buf, RATE_FX, 0.15, 0.003, 0.5, 8000.0)
	return buf


## A nut seating: aluminium on granite (a short gritty scrape), then a
## bright tink as the wire comes tight.
func _nut(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(0.4, RATE_FX)
	_add_noise(buf, RATE_FX, 0.5, 4000.0, 900.0, 0, int(0.09 * RATE_FX))
	_add_click(buf, RATE_FX, 0.1, 0.004, 0.8, 9000.0)
	_add_ping(buf, RATE_FX, 0.1, [[2650.0, 1.0], [4100.0, 0.5], [6900.0, 0.25]], 0.03, 0.7)
	return buf


## A piece ripping out: a sharp crack of grit and the metal ringing off.
func _pop(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(0.5, RATE_FX)
	_add_click(buf, RATE_FX, 0.0, 0.02, 1.0, 5000.0)
	_add_noise(buf, RATE_FX, 0.4, 2500.0, 300.0, 0, int(0.06 * RATE_FX))
	_add_ping(buf, RATE_FX, 0.02, [[1700.0, 1.0], [2900.0, 0.6], [4400.0, 0.3]], 0.05, 0.6)
	return buf


## The rope catching: a stretch creak rising as it loads, the harness's
## thump, and a low twang.
func _catch(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(0.7, RATE_FX)
	_add_click(buf, RATE_FX, 0.0, 0.04, 0.9, 600.0)
	_add_tone(buf, RATE_FX, 0.0, 0.09, 90.0, 60.0, 0.8)
	_add_tone(buf, RATE_FX, 0.03, 0.35, 160.0, 240.0, 0.22, 0.5)
	_add_ping(buf, RATE_FX, 0.02, [[82.0, 1.0], [164.0, 0.5], [247.0, 0.2]], 0.08, 0.5)
	return buf


## Air rushing past in a fall.
func _whoosh(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(0.6, RATE_FX)
	var center := PackedFloat32Array()
	var gain := PackedFloat32Array()
	center.resize(buf.size())
	gain.resize(buf.size())
	for i in buf.size():
		var t := float(i) / buf.size()
		center[i] = 400.0 + t * 1800.0
		gain[i] = 0.3 * sin(PI * t)
	_add_band_noise(buf, RATE_FX, center, 1.3, gain)
	return buf


## A hand landing on a big hold: a slap with a little chalk puff.
func _slap(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(0.25, RATE_FX)
	_add_click(buf, RATE_FX, 0.0, 0.012, 1.0, 2800.0)
	_add_tone(buf, RATE_FX, 0.0, 0.04, 220.0, 150.0, 0.4)
	_add_noise(buf, RATE_FX, 0.18, 1400.0, 300.0, int(0.01 * RATE_FX), int(0.2 * RATE_FX))
	for i in range(int(0.01 * RATE_FX), buf.size()):
		buf[i] *= exp(-float(i) / RATE_FX * 14.0)
	return buf


## A hand jam twisting in: skin and tape scrunching on crystals.
func _jam(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(0.3, RATE_FX)
	var t := 0.0
	while t < 0.24:
		_add_click(buf, RATE_FX, t, 0.004, _rng.randf_range(0.2, 0.7), 3000.0)
		t += _rng.randf_range(0.006, 0.02)
	_add_noise(buf, RATE_FX, 0.3, 1800.0, 400.0)
	for i in buf.size():
		buf[i] *= sin(PI * float(i) / buf.size())
	return buf


## One hard breath out and in, through the mouth.
func _breath(seed_value: int) -> PackedFloat32Array:
	_rng.seed = seed_value
	var buf := _buf(0.9, RATE_FX)
	var center := PackedFloat32Array()
	var gain := PackedFloat32Array()
	center.resize(buf.size())
	gain.resize(buf.size())
	var out_len := _rng.randf_range(0.3, 0.38)
	for i in buf.size():
		var s := float(i) / RATE_FX
		if s < out_len:
			var f := s / out_len
			center[i] = 900.0 + 300.0 * (1.0 - f)
			gain[i] = 0.35 * pow(sin(PI * pow(f, 0.5)), 1.2)
		else:
			var f := (s - out_len - 0.08) / 0.42
			center[i] = 1300.0 + 400.0 * f
			gain[i] = 0.22 * sin(PI * clampf(f, 0.0, 1.0))
	_add_band_noise(buf, RATE_FX, center, 0.9, gain)
	return buf


## A crux sent clean: two soft rising notes.
func _sent() -> PackedFloat32Array:
	var buf := _buf(0.9, RATE_FX)
	for k in 2:
		var f := 440.0 * pow(2.0, (float([74, 81][k]) - 69.0) / 12.0)
		_add_ping(buf, RATE_FX, k * 0.1, [[f, 1.0], [f * 2.0, 0.25]], 0.12, 0.5)
	return buf


# ------------------------------------------------------------------ building blocks
# (the same as tools/audio/build_sounds.gd's)

func _buf(seconds: float, rate: int) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * rate))
	return buf

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
