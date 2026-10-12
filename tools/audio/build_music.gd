extends SceneTree
## Composes and synthesizes the game's music into assets/audio/music_*.wav:
## a short piece for each season by day, one for the night, and the title
## theme. Like the sounds (build_sounds.gd), nothing is recorded or
## downloaded, and each piece has a fixed seed, so a rebuild writes the same
## files.
##
##   godot --headless --path . -s res://tools/audio/build_music.gd
##   godot --headless --path . --import
##
## Each piece is 16 bars in four phrases (A A' B A''): a two-bar motif is
## made up from the piece's seed, repeated over the next chords with its
## strong beats moved onto chord tones, and answered by a new motif in the
## B phrase. Under the tune: plucked arpeggios (a Karplus-Strong string), a
## soft pad, and a bass on the downbeats, with a little room reverb over all.
##
## The world pieces end with a ringing tail and are played once, with a rest
## of ambience between them (Sound plays them). The title theme is built as a
## seamless loop: notes that ring past the end wrap round to the start.

const OUT := "res://assets/audio/"
const RATE := 22050
## Seconds of ring after the last bar of a world piece.
const TAIL := 3.5

const MAJOR := [0, 2, 4, 5, 7, 9, 11]
const DORIAN := [0, 2, 3, 5, 7, 9, 10]
const MINOR := [0, 2, 3, 5, 7, 8, 10]
const LYDIAN := [0, 2, 4, 6, 7, 9, 11]

## Each piece: tempo, key (MIDI root), scale, one chord a bar (scale degrees,
## 0 = the tonic), the arpeggio (eighth notes into the chord's tones over two
## octaves; -1 rests), and which instruments play.
const PIECES := {
	"music_spring": {
		"seed": 11, "bpm": 84.0, "root": 55, "scale": MAJOR,
		"chords": [0, 4, 5, 3, 0, 4, 3, 4, 5, 3, 0, 4, 0, 4, 3, 0],
		"arp": [0, 2, 4, 2, 3, 2, 4, 2], "arp_voice": "guitar", "lead": "flute",
		"lead_octave": 12, "pad": 0.10, "bass": 0.5, "busy": 0.55,
	},
	"music_summer": {
		"seed": 23, "bpm": 96.0, "root": 50, "scale": MAJOR,
		"chords": [0, 3, 0, 4, 5, 3, 1, 4, 3, 4, 2, 5, 0, 3, 4, 0],
		"arp": [0, 4, 2, 4, 3, 4, 2, 4], "arp_voice": "guitar", "lead": "whistle",
		"lead_octave": 12, "pad": 0.06, "bass": 0.55, "busy": 0.7, "swing": 0.12,
	},
	"music_fall": {
		"seed": 37, "bpm": 76.0, "root": 57, "scale": DORIAN,
		"chords": [0, 6, 5, 6, 0, 3, 6, 4, 5, 6, 0, 3, 0, 6, 5, 0],
		"arp": [0, 2, 4, 5, 4, 2, 3, 2], "arp_voice": "guitar", "lead": "clarinet",
		"lead_octave": 0, "pad": 0.12, "bass": 0.5, "busy": 0.5,
	},
	"music_winter": {
		"seed": 41, "bpm": 66.0, "root": 52, "scale": MINOR,
		"chords": [0, 5, 2, 6, 0, 5, 3, 4, 5, 2, 6, 3, 0, 5, 4, 0],
		"arp": [0, -1, 4, -1, 3, -1, 4, -1], "arp_voice": "harp", "lead": "music_box",
		"lead_octave": 24, "pad": 0.16, "bass": 0.3, "busy": 0.4,
	},
	"music_night": {
		"seed": 53, "bpm": 60.0, "root": 53, "scale": MAJOR,
		"chords": [0, 3, 5, 4, 0, 3, 1, 4, 3, 2, 5, 4, 0, 3, 4, 0],
		"arp": [0, -1, 2, 4, -1, 3, -1, -1], "arp_voice": "bell", "lead": "",
		"lead_octave": 12, "pad": 0.14, "bass": 0.35, "busy": 0.3,
	},
	"music_title": {
		"seed": 67, "bpm": 72.0, "root": 48, "scale": LYDIAN,
		"chords": [0, 1, 5, 4, 0, 1, 3, 4, 5, 3, 0, 4, 0, 1, 4, 0],
		"arp": [0, 2, 4, 5, 3, 4, 2, 4], "arp_voice": "harp", "lead": "flute",
		"lead_octave": 12, "pad": 0.12, "bass": 0.45, "busy": 0.5, "loop": true,
	},
}

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	# Loaded by a test (not run with -s), it only lends out its instruments.
	if Engine.get_main_loop() != null and Engine.get_main_loop() != self:
		return
	var only := OS.get_environment("MUSIC_ONLY")
	for piece_name: String in PIECES:
		if only != "" and only != piece_name:
			continue
		var start := Time.get_ticks_msec()
		_save(piece_name, _render(PIECES[piece_name]))
		print("%s: %.1f s to build" % [piece_name, (Time.get_ticks_msec() - start) / 1000.0])
	print("Music written to %s. Run godot --headless --path . --import next." % OUT)
	quit()


func _save(piece_name: String, buf: PackedFloat32Array) -> void:
	var peak := 0.0
	for v in buf:
		peak = maxf(peak, absf(v))
	var gain := db_to_linear(-2.0) / maxf(peak, 0.000001)
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, clampi(int(roundf(buf[i] * gain * 32767.0)), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	var err := wav.save_to_wav(OUT + piece_name + ".wav")
	if err != OK:
		push_error("Could not write %s: %s" % [piece_name, error_string(err)])


# ------------------------------------------------------------ composing

static func midi_hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


## The MIDI note of scale degree [param degree] (any integer; 7 is the
## octave) in [param spec]'s key.
static func degree_note(spec: Dictionary, degree: int) -> int:
	var scale: Array = spec.scale
	var octave := floori(degree / 7.0)
	return int(spec.root) + octave * 12 + int(scale[posmod(degree, 7)])


## The degrees of the triad on [param chord] (plus its seventh).
static func chord_degrees(chord: int) -> Array:
	return [chord, chord + 2, chord + 4, chord + 6]


## One motif: two bars of (start eighth, length in eighths, scale degree).
## It moves mostly by step, follows a leap by a step back the other way,
## avoids striking the same note three times, and lands its strong beats
## (each half bar) on tones of the chord under them.
func _motif(chords: Array, busy: float) -> Array:
	var rhythms := [
		[2, 2, 4, 2, 2, 4],
		[3, 1, 2, 2, 4, 4],
		[2, 2, 2, 2, 6, 2],
		[4, 2, 2, 4, 4],
		[1, 1, 2, 4, 2, 2, 4],
		[2, 4, 2, 2, 2, 4],
		[3, 1, 4, 3, 1, 4],
	]
	var pick: Array = rhythms[_rng.randi() % rhythms.size()]
	if busy < 0.45:
		pick = [[4, 4, 6, 2], [6, 2, 8], [4, 2, 2, 8]][_rng.randi() % 3]
	var notes := []
	var at := 0
	var degree: int = _nearest_chord_tone(7 + _rng.randi_range(0, 4), chords[0])
	var direction := 1 if _rng.randf() < 0.5 else -1
	var last_leap := 0
	var repeats := 0
	for k in pick.size():
		var length: int = pick[k]
		var chord: int = chords[mini(at / 8, chords.size() - 1)]
		if k > 0:
			var step := 1
			var roll := _rng.randf()
			if last_leap != 0:
				# recover from a leap by a step back
				direction = -signi(last_leap)
				step = 1
			elif roll < 0.25:
				step = 2
			elif roll < 0.33:
				step = 3
			elif roll < 0.45:
				direction = -direction
			var next := degree + direction * step
			if next > 13 or next < 4:
				direction = -direction
				next = degree + direction * step
			if at % 4 == 0:
				next = _nearest_chord_tone(next, chord, degree if repeats > 0 else -99)
			last_leap = (next - degree) if absi(next - degree) >= 2 else 0
			repeats = repeats + 1 if next == degree else 0
			degree = next
		# a rest now and then, never on the first or last note
		if k > 0 and k < pick.size() - 1 and _rng.randf() < 0.06:
			at += length
			continue
		notes.append([at, length, degree])
		at += length
	return notes


## The chord tone nearest [param degree], skipping [param avoid].
func _nearest_chord_tone(degree: int, chord: int, avoid := -99) -> int:
	var best := degree
	var best_d := 99
	for octave in [-7, 0, 7, 14]:
		for d: int in chord_degrees(chord).slice(0, 3):
			var cand: int = d + octave
			if cand == avoid or cand < 3 or cand > 14:
				continue
			if absi(cand - degree) < best_d:
				best_d = absi(cand - degree)
				best = cand
	return best


## The motif moved onto new chords as a sequence: shifted by the step between
## the old and new chord roots, its strong beats then set on chord tones.
func _vary(motif: Array, from_chords: Array, chords: Array) -> Array:
	var shift: int = posmod(int(chords[0]) - int(from_chords[0]) + 3, 7) - 3
	var out := []
	for n: Array in motif:
		var chord: int = chords[mini(n[0] / 8, chords.size() - 1)]
		var degree: int = n[2] + shift
		if n[0] % 4 == 0:
			degree = _nearest_chord_tone(degree, chord)
		out.append([n[0], n[1], clampi(degree, 3, 14)])
	return out


## The tune for all 16 bars, as (start eighth, length, degree).
func _melody(spec: Dictionary) -> Array:
	var chords: Array = spec.chords
	var busy: float = spec.busy
	var c := func(bar: int) -> Array: return chords.slice(bar, bar + 2)
	var a := _motif(c.call(0), busy)
	var a2 := _motif(c.call(2), busy)
	var b := _motif(c.call(8), busy)
	var tune := []
	# phrase by phrase: A A' B A'', each two motifs long; the B phrase
	# answers with new material, and the last phrase brings A back home
	var plan := [
		[a, 0], [a2, 2], [_vary(a, c.call(0), c.call(4)), 4], [_vary(a2, c.call(2), c.call(6)), 6],
		[b, 8], [_vary(b, c.call(8), c.call(10)), 10], [_vary(a, c.call(0), c.call(12)), 12],
	]
	for part: Array in plan:
		for n: Array in part[0]:
			tune.append([n[0] + part[1] * 8, n[1], n[2]])
	# the last two bars settle on the tonic: a step down into it, held
	var home := 7
	tune.append([14 * 8, 2, home + 2])
	tune.append([14 * 8 + 2, 2, home + 1])
	tune.append([14 * 8 + 4, 12, home])
	return tune


# ------------------------------------------------------------ rendering

func _render(spec: Dictionary) -> PackedFloat32Array:
	_rng.seed = int(spec.seed)
	var beat := 60.0 / float(spec.bpm)
	var eighth := beat / 2.0
	var bars: int = spec.chords.size()
	var loop: bool = spec.get("loop", false)
	var length := bars * 4 * beat + (0.0 if loop else TAIL)
	var buf := PackedFloat32Array()
	buf.resize(int(length * RATE))
	var swing: float = spec.get("swing", 0.0)
	var time_of := func(e: int) -> float:
		return e * eighth + (swing * eighth if e % 2 == 1 else 0.0)
	# pad and bass, bar by bar
	for bar in bars:
		var chord: int = spec.chords[bar]
		var t := bar * 4 * beat
		if float(spec.pad) > 0.0:
			for d: int in chord_degrees(chord).slice(0, 3):
				_pad(buf, t, 4 * beat, midi_hz(degree_note(spec, d) - 12 + (12 if d < chord + 1 else 0)), float(spec.pad), loop)
		if float(spec.bass) > 0.0:
			var root := degree_note(spec, chord) - 12
			while root > int(spec.root) - 5:
				root -= 12
			_bass(buf, t, beat * 1.8, midi_hz(root), float(spec.bass), loop)
			_bass(buf, t + 2 * beat, beat * 1.8, midi_hz(root + (7 if bar % 2 == 0 else 12)), float(spec.bass) * 0.7, loop)
	# the arpeggio
	var arp: Array = spec.arp
	for bar in bars:
		var chord: int = spec.chords[bar]
		var tones := []
		for d: int in chord_degrees(chord).slice(0, 3):
			tones.append(degree_note(spec, d))
		for d: int in chord_degrees(chord).slice(0, 3):
			tones.append(degree_note(spec, d) + 12)
		for i in 8:
			if int(arp[i]) < 0:
				continue
			# the last bar of a world piece just rings its first note
			if not loop and bar == bars - 1 and i > 0:
				break
			var note: int = tones[int(arp[i])]
			var at: float = bar * 4 * beat + time_of.call(i)
			var amp := 0.32 if i % 4 == 0 else 0.24
			match String(spec.arp_voice):
				"guitar":
					_pluck(buf, at, midi_hz(note), amp, 0.9965, 1800.0, loop)
				"harp":
					_pluck(buf, at, midi_hz(note + 12), amp * 0.85, 0.998, 3200.0, loop)
				"bell":
					_bell(buf, at, midi_hz(note + 12), amp * 0.6, 1.6, loop)
	# the tune
	if String(spec.lead) != "":
		for n: Array in _melody(spec):
			var at: float = time_of.call(int(n[0]))
			var dur: float = n[1] * eighth
			var hz := midi_hz(degree_note(spec, int(n[2])) + int(spec.lead_octave) - 12)
			match String(spec.lead):
				"flute":
					_wind(buf, at, dur, hz, 0.22, [1.0, 0.22, 0.06], 0.012, loop)
				"whistle":
					_wind(buf, at, dur, hz, 0.25, [1.0, 0.05, 0.0], 0.008, loop)
				"clarinet":
					_wind(buf, at, dur, hz, 0.2, [1.0, 0.02, 0.35, 0.02, 0.15], 0.006, loop)
				"music_box":
					_bell(buf, at, hz, 0.3, 1.2, loop)
	_reverb(buf, loop)
	return buf


## Adds sample [param v] at index [param i], wrapping round on a loop and
## dropping it past the end otherwise.
func _put(buf: PackedFloat32Array, i: int, v: float, loop: bool) -> void:
	if loop:
		buf[i % buf.size()] += v
	elif i < buf.size():
		buf[i] += v


## A plucked string (Karplus-Strong): a burst of filtered noise circulating in
## a delay line one period long, softened a little on every pass.
##
## The averaging that softens it shortens the loop by half a sample, and the
## line can only be a whole number of samples long, which put high notes up
## to a quarter-tone out of tune. An all-pass filter in the loop adds the
## missing fraction of a sample (Jaffe and Smith), so every string is in tune
## with the pad and the tune.
func _pluck(buf: PackedFloat32Array, at: float, hz: float, amp: float, decay: float, brightness: float, loop: bool) -> void:
	var exact := RATE / hz
	# A high string makes many more trips round the loop each second, so it
	# would die far sooner than a low one; lighten its damping (the weight
	# of the newer sample, S) and its loss per trip to match (Jaffe and
	# Smith's decay stretching). [param decay] is the loss per trip at 220 Hz.
	var stretch := clampf(0.5 * 330.0 / hz, 0.1, 0.5)
	decay = pow(decay, 220.0 / hz) if hz > 220.0 else decay
	# loop delay = period - S (damping) + frac (all-pass), frac in [0.5, 1.5)
	var period := maxi(2, floori(exact + stretch - 0.5))
	var frac := exact - period + stretch
	var coef := (1.0 - frac) / (1.0 + frac)
	var ap_in := 0.0
	var ap_out := 0.0
	var line := PackedFloat32Array()
	line.resize(period)
	var a := 1.0 - exp(-TAU * brightness / RATE)
	var low := 0.0
	# The string's shape when let go: pulled out at a point a third of the
	# way along (a triangle), with a little noise for the bite of the pick.
	for i in period:
		var x := float(i) / period
		var shape := x / 0.3 if x < 0.3 else (1.0 - x) / 0.7
		low += a * (_rng.randf_range(-1.0, 1.0) - low)
		line[i] = shape + low * 0.5
	# Take out the burst's average (the string would hold it as a silent
	# offset) and set its energy, so every note of an arpeggio is as loud
	# as the next however few samples a high string has.
	var mean := 0.0
	for v in line:
		mean += v
	mean /= period
	var energy := 0.0
	for i in period:
		line[i] -= mean
		energy += line[i] * line[i]
	var gain := 0.5 / maxf(sqrt(energy / period), 0.0001)
	for i in period:
		line[i] *= gain
	var start := int(at * RATE)
	var n := int(minf(3.0, 2.2 * 220.0 / hz + 1.2) * RATE)
	var idx := 0
	var prev := 0.0
	for i in n:
		var v := line[idx]
		var next := line[(idx + 1) % period]
		var soft := (v * (1.0 - stretch) + next * stretch) * decay
		ap_out = coef * soft + ap_in - coef * ap_out
		ap_in = soft
		line[idx] = ap_out
		# a gentle body: a one-pole smoothing of the string
		prev += 0.6 * (v - prev)
		var env := minf(1.0, float(i) / 40.0)
		_put(buf, start + i, prev * amp * env, loop)
		idx = (idx + 1) % period


## A wind instrument: a few harmonics with a soft attack, slight vibrato
## that grows on long notes, and a breath of noise at the start.
func _wind(buf: PackedFloat32Array, at: float, dur: float, hz: float, amp: float, harmonics: Array, vibrato: float, loop: bool) -> void:
	var start := int(at * RATE)
	var release := 0.12
	var n := int((dur + release) * RATE)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.05)
		if t > dur:
			env *= maxf(0.0, 1.0 - (t - dur) / release)
		else:
			env *= 1.0 - 0.15 * (t / maxf(dur, 0.01))
		var vib := 1.0 + vibrato * minf(1.0, t / 0.4) * sin(TAU * 5.2 * t)
		phase += TAU * hz * vib / RATE
		var v := 0.0
		for k in harmonics.size():
			v += sin(phase * (k + 1)) * float(harmonics[k])
		if t < 0.04:
			v += _rng.randf_range(-0.3, 0.3) * (1.0 - t / 0.04)
		_put(buf, start + i, v * env * amp, loop)


## A struck bell or music-box tine: inharmonic partials dying away.
func _bell(buf: PackedFloat32Array, at: float, hz: float, amp: float, ring: float, loop: bool) -> void:
	var start := int(at * RATE)
	var partials := [[1.0, 1.0, 1.0], [2.0, 0.35, 0.6], [3.01, 0.12, 0.4], [4.17, 0.08, 0.25]]
	var n := int(ring * 2.5 * RATE)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for p: Array in partials:
			v += sin(TAU * hz * float(p[0]) * t) * float(p[1]) * exp(-t / (ring * float(p[2])))
		_put(buf, start + i, v * amp * minf(1.0, float(i) / 30.0), loop)


## A soft pad note: three slightly detuned voices swelling in and out.
func _pad(buf: PackedFloat32Array, at: float, dur: float, hz: float, amp: float, loop: bool) -> void:
	var start := int(at * RATE)
	var n := int((dur + 0.8) * RATE)
	var detune := [0.997, 1.0, 1.003]
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.7)
		if t > dur:
			env *= maxf(0.0, 1.0 - (t - dur) / 0.8)
		var v := 0.0
		for d: float in detune:
			var ph := TAU * hz * d * t
			v += sin(ph) + 0.25 * sin(ph * 2.0)
		_put(buf, start + i, v * env * amp / 3.0, loop)


func _bass(buf: PackedFloat32Array, at: float, dur: float, hz: float, amp: float, loop: bool) -> void:
	var start := int(at * RATE)
	var n := int((dur + 0.1) * RATE)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.01) * exp(-t / (dur * 0.6))
		var ph := TAU * hz * t
		_put(buf, start + i, (sin(ph) + 0.3 * sin(ph * 2.0)) * env * amp * 0.6, loop)


## A small room: four feedback combs into two all-passes (Schroeder),
## mixed in under the dry sound. A loop runs through twice, so the reverb
## at its start already holds the end's tail.
func _reverb(buf: PackedFloat32Array, loop: bool) -> void:
	var combs := [int(0.0297 * RATE), int(0.0371 * RATE), int(0.0411 * RATE), int(0.0437 * RATE)]
	var lines := []
	for length: int in combs:
		var l := PackedFloat32Array()
		l.resize(length)
		lines.append(l)
	var idx := [0, 0, 0, 0]
	var ap_len := [int(0.005 * RATE), int(0.0017 * RATE)]
	var ap := [PackedFloat32Array(), PackedFloat32Array()]
	ap[0].resize(ap_len[0])
	ap[1].resize(ap_len[1])
	var ap_idx := [0, 0]
	var n := buf.size()
	var wet := PackedFloat32Array()
	wet.resize(n)
	var laps := 2 if loop else 1
	var damp := [0.0, 0.0, 0.0, 0.0]
	for lap in laps:
		for i in n:
			var x := buf[i] * 0.25
			var sum := 0.0
			for k in 4:
				var line: PackedFloat32Array = lines[k]
				var y := line[idx[k]]
				damp[k] = y * 0.7 + damp[k] * 0.3
				line[idx[k]] = x + damp[k] * 0.82
				idx[k] = (idx[k] + 1) % combs[k]
				sum += y
			for k in 2:
				var line: PackedFloat32Array = ap[k]
				var d := line[ap_idx[k]]
				var v := sum + d * 0.5
				line[ap_idx[k]] = v
				sum = d - v * 0.5
				ap_idx[k] = (ap_idx[k] + 1) % ap_len[k]
			if lap == laps - 1:
				wet[i] = sum
	for i in n:
		buf[i] += wet[i] * 0.35
