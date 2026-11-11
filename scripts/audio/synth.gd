class_name Synth
extends RefCounted
## Tiny chiptune synthesiser: every sound effect and ambience loop of the
## game is rendered here at runtime into an AudioStreamWAV (no audio files).
##
## A sound is a list of voices mixed together. Voice keys:
##   wave   square | triangle | saw | sine | noise (sample-and-hold, NES style)
##   f, f1  start / end frequency in Hz (exponential slide; f1 defaults to f)
##   dur    seconds; at  start delay in seconds; vol  0..1
##   duty   square pulse width; attack  seconds; decay  envelope curve (higher = snappier)
##   arp    semitone steps cycled every `step` seconds
##   vib    [rate Hz, depth semitones]
## Sound-level key "echo": [delay s, repeats, falloff].

const RATE := 22050

const SOUNDS := {
	"swing": {"v": [{"wave": "noise", "f": 5200, "f1": 900, "dur": 0.09, "vol": 0.22, "decay": 2.0}]},
	"hit": {"v": [{"wave": "square", "f": 220, "f1": 80, "dur": 0.09, "vol": 0.3, "duty": 0.5},
		{"wave": "noise", "f": 2400, "f1": 600, "dur": 0.06, "vol": 0.3}]},
	"block": {"v": [{"wave": "square", "f": 1250, "dur": 0.05, "vol": 0.2, "duty": 0.25},
		{"wave": "triangle", "f": 1870, "dur": 0.12, "vol": 0.25, "decay": 3.0}]},
	"break": {"v": [{"wave": "noise", "f": 3200, "f1": 400, "dur": 0.18, "vol": 0.3, "decay": 2.0},
		{"wave": "square", "f": 520, "f1": 140, "dur": 0.22, "vol": 0.2, "duty": 0.25}]},
	"hurt": {"v": [{"wave": "square", "f": 330, "f1": 110, "dur": 0.2, "vol": 0.3, "duty": 0.25, "vib": [30, 1.0]}]},
	"death": {"v": [{"wave": "noise", "f": 900, "f1": 80, "dur": 0.4, "vol": 0.3},
		{"wave": "square", "f": 200, "f1": 50, "dur": 0.35, "vol": 0.22, "duty": 0.5}]},
	"chop": {"v": [{"wave": "noise", "f": 1100, "f1": 500, "dur": 0.07, "vol": 0.3},
		{"wave": "triangle", "f": 170, "f1": 110, "dur": 0.1, "vol": 0.45}]},
	"mine": {"v": [{"wave": "square", "f": 1320, "f1": 1180, "dur": 0.06, "vol": 0.18, "duty": 0.125},
		{"wave": "noise", "f": 6000, "f1": 3000, "dur": 0.05, "vol": 0.25},
		{"wave": "triangle", "f": 1980, "dur": 0.16, "vol": 0.15, "at": 0.02, "decay": 4.0}]},
	"pickup": {"v": [{"wave": "square", "f": 660, "dur": 0.13, "vol": 0.18, "duty": 0.25, "arp": [0, 7, 12], "step": 0.04}]},
	"craft": {"v": [{"wave": "triangle", "f": 523, "dur": 0.32, "vol": 0.35, "arp": [0, 4, 7, 12], "step": 0.07, "decay": 1.0},
		{"wave": "noise", "f": 3000, "dur": 0.05, "vol": 0.15}]},
	"build": {"v": [{"wave": "noise", "f": 500, "f1": 200, "dur": 0.12, "vol": 0.3},
		{"wave": "triangle", "f": 120, "f1": 90, "dur": 0.14, "vol": 0.5}]},
	"door": {"v": [{"wave": "square", "f": 190, "f1": 140, "dur": 0.09, "vol": 0.15, "duty": 0.5},
		{"wave": "noise", "f": 900, "dur": 0.05, "vol": 0.2, "at": 0.06}]},
	"eat": {"v": [{"wave": "noise", "f": 1500, "dur": 0.05, "vol": 0.22},
		{"wave": "noise", "f": 1300, "dur": 0.05, "vol": 0.2, "at": 0.09},
		{"wave": "noise", "f": 1100, "dur": 0.05, "vol": 0.18, "at": 0.18}]},
	"drink": {"v": [{"wave": "sine", "f": 500, "f1": 1100, "dur": 0.09, "vol": 0.35},
		{"wave": "sine", "f": 450, "f1": 1000, "dur": 0.09, "vol": 0.3, "at": 0.13}]},
	"level": {"v": [{"wave": "square", "f": 523, "dur": 0.6, "vol": 0.2, "duty": 0.25, "arp": [0, 4, 7, 12, 16, 19, 24], "step": 0.07, "decay": 0.6},
		{"wave": "triangle", "f": 262, "dur": 0.6, "vol": 0.3, "decay": 1.0}]},
	"shoot": {"v": [{"wave": "noise", "f": 1800, "f1": 7000, "dur": 0.08, "vol": 0.2},
		{"wave": "triangle", "f": 900, "f1": 380, "dur": 0.09, "vol": 0.3}]},
	"dodge": {"v": [{"wave": "noise", "f": 700, "f1": 250, "dur": 0.16, "vol": 0.2, "attack": 0.03}]},
	"tame": {"v": [{"wave": "sine", "f": 784, "dur": 0.42, "vol": 0.3, "arp": [0, 4, 7, 12], "step": 0.09, "decay": 0.8},
		{"wave": "triangle", "f": 392, "dur": 0.42, "vol": 0.2, "decay": 1.0}]},
	"glyph": {"v": [{"wave": "sine", "f": 880, "dur": 0.8, "vol": 0.25, "vib": [5, 0.3], "attack": 0.05, "decay": 1.2},
		{"wave": "sine", "f": 1320, "dur": 0.8, "vol": 0.18, "attack": 0.15, "decay": 1.2}], "echo": [0.18, 2, 0.4]},
	"horn": {"v": [{"wave": "saw", "f": 110, "f1": 100, "dur": 1.1, "vol": 0.28, "attack": 0.15, "decay": 0.7, "vib": [5, 0.25]},
		{"wave": "saw", "f": 165, "f1": 150, "dur": 1.1, "vol": 0.18, "attack": 0.2, "decay": 0.7}]},
	"dawn": {"v": [{"wave": "triangle", "f": 392, "dur": 0.8, "vol": 0.3, "arp": [0, 7, 12], "step": 0.16, "decay": 0.8}], "echo": [0.2, 2, 0.35]},
	"dusk": {"v": [{"wave": "triangle", "f": 330, "dur": 0.9, "vol": 0.3, "arp": [12, 7, 3, 0], "step": 0.18, "decay": 0.8}], "echo": [0.22, 2, 0.35]},
	"shift": {"v": [{"wave": "noise", "f": 140, "f1": 60, "dur": 1.4, "vol": 0.35, "attack": 0.3, "decay": 0.8},
		{"wave": "square", "f": 55, "f1": 46, "dur": 1.4, "vol": 0.15, "duty": 0.5, "attack": 0.3, "decay": 0.8}]},
	"ui": {"v": [{"wave": "square", "f": 880, "dur": 0.035, "vol": 0.12, "duty": 0.25}]},
	"bird": {"v": [{"wave": "sine", "f": 2600, "f1": 3500, "dur": 0.07, "vol": 0.14},
		{"wave": "sine", "f": 2900, "f1": 3800, "dur": 0.06, "vol": 0.12, "at": 0.1},
		{"wave": "sine", "f": 3300, "f1": 2500, "dur": 0.09, "vol": 0.1, "at": 0.19}]},
	"clank": {"v": [{"wave": "square", "f": 150, "dur": 0.14, "vol": 0.16, "duty": 0.125, "decay": 3.0},
		{"wave": "noise", "f": 3500, "dur": 0.05, "vol": 0.15}], "echo": [0.25, 3, 0.45]},
	"growl": {"v": [{"wave": "saw", "f": 70, "f1": 55, "dur": 0.7, "vol": 0.18, "attack": 0.15, "vib": [9, 0.6], "decay": 1.0},
		{"wave": "noise", "f": 300, "dur": 0.7, "vol": 0.08, "attack": 0.2}], "echo": [0.3, 2, 0.35]},
}

## Looping beds: wind, crickets and the maze's hum.
const AMBIENCE := ["meadow", "night", "maze", "maze_night"]
const LOOP_SECONDS := 6.0


static func has_sound(id: String) -> bool:
	return SOUNDS.has(id)


## Renders a sound effect (deterministic for a given seed).
static func render(id: String, seed_value := 1) -> AudioStreamWAV:
	var def: Dictionary = SOUNDS[id]
	var length := 0.0
	for v in def.v:
		length = maxf(length, float(v.get("at", 0.0)) + float(v.dur))
	var echo: Array = def.get("echo", [])
	if not echo.is_empty():
		length += float(echo[0]) * int(echo[1])
	var buf := PackedFloat32Array()
	buf.resize(int(length * RATE) + 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for v in def.v:
		_voice(buf, v, rng)
	if not echo.is_empty():
		var lag := int(float(echo[0]) * RATE)
		var dry := buf.duplicate()
		for r in range(1, int(echo[1]) + 1):
			var g := pow(float(echo[2]), r)
			for i in dry.size():
				if i + lag * r < buf.size():
					buf[i + lag * r] += dry[i] * g
	return _to_wav(buf, false)


## Adds one voice into the buffer.
static func _voice(buf: PackedFloat32Array, v: Dictionary, rng: RandomNumberGenerator) -> void:
	var start := int(float(v.get("at", 0.0)) * RATE)
	var n := int(float(v.dur) * RATE)
	var f0: float = float(v.f)
	var f1: float = float(v.get("f1", f0))
	var vol: float = float(v.get("vol", 0.3))
	var duty: float = float(v.get("duty", 0.5))
	var attack := maxf(float(v.get("attack", 0.004)), 0.001)
	var curve: float = float(v.get("decay", 1.5))
	var arp: Array = v.get("arp", [])
	var step: float = float(v.get("step", 0.06))
	var vib: Array = v.get("vib", [])
	var wave: String = v.wave
	var phase := 0.0
	var held := 0.0
	for i in n:
		var t := i / float(RATE)
		var k := i / float(n)
		var f := f0 * pow(f1 / f0, k)
		if not arp.is_empty():
			f *= pow(2.0, float(arp[int(t / step) % arp.size()]) / 12.0)
		if not vib.is_empty():
			f *= pow(2.0, sin(TAU * float(vib[0]) * t) * float(vib[1]) / 12.0)
		var last := phase
		phase = fmod(phase + f / RATE, 1.0)
		var s := 0.0
		match wave:
			"square":
				s = 1.0 if phase < duty else -1.0
			"triangle":
				s = 4.0 * absf(phase - 0.5) - 1.0
			"saw":
				s = 2.0 * phase - 1.0
			"sine":
				s = sin(TAU * phase)
			_:
				if phase < last:
					held = rng.randf_range(-1.0, 1.0)
				s = held
		var env := minf(t / attack, 1.0) * pow(1.0 - k, curve)
		var j := start + i
		if j < buf.size():
			buf[j] += s * env * vol


## A seamless ambience loop (LOOP_SECONDS long, every periodic part fits a
## whole number of cycles; noise is cross-faded over the seam).
static func render_ambience(kind: String, seed_value := 7) -> AudioStreamWAV:
	var n := int(LOOP_SECONDS * RATE)
	var fade := int(0.5 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n + fade)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var lp := 0.0
	for i in buf.size():
		var t := i / float(RATE)
		var cycle := t / LOOP_SECONDS
		var white := rng.randf_range(-1.0, 1.0)
		var s := 0.0
		match kind:
			"meadow":
				lp += (white - lp) * 0.035
				s = lp * (0.55 + 0.45 * sin(TAU * cycle * 2.0)) * 1.6
			"night":
				lp += (white - lp) * 0.02
				s = lp * 0.9
				var chirp := fmod(t, 0.75)
				if chirp < 0.12 and fmod(chirp, 0.04) < 0.022:
					s += sin(TAU * 4200.0 * t) * 0.07
				var far := fmod(t + 0.31, 1.5)
				if far < 0.1 and fmod(far, 0.033) < 0.018:
					s += sin(TAU * 3800.0 * t) * 0.035
			"maze":
				lp += (white - lp) * 0.01
				s = sin(TAU * 55.0 * t) * 0.16 + sin(TAU * 82.5 * t) * 0.09 * (0.6 + 0.4 * sin(TAU * cycle * 3.0)) + lp * 0.8
			"maze_night":
				lp += (white - lp) * 0.008
				var beat := fmod(t, 1.5)
				s = sin(TAU * 49.0 * t) * 0.18 + sin(TAU * 73.5 * t) * 0.07 + lp * 0.9
				if beat < 0.12 or (beat > 0.25 and beat < 0.35):
					s += sin(TAU * 40.0 * t) * 0.25 * (1.0 - fmod(beat, 0.25) / 0.12)
		buf[i] = s * 0.6
	for i in fade:
		var w := i / float(fade)
		buf[i] = buf[i] * w + buf[n + i] * (1.0 - w)
	buf.resize(n)
	return _to_wav(buf, true)


static func _to_wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


## Loudest absolute sample (0..1), for tests.
static func peak(w: AudioStreamWAV) -> float:
	var best := 0
	for i in range(0, w.data.size(), 2):
		best = maxi(best, absi(w.data.decode_s16(i)))
	return best / 32000.0
