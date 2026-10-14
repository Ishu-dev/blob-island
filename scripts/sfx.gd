extends Node
## Every sound is synthesized at startup (no audio files): grumpy blob grumbles, goo blorps,
## booms, coins, glass, the train horn. Volume falls off with distance from the player.

const RATE := 22050

var sounds := {}
var listener := Vector3.ZERO
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in 20:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_build()


func play(sound: String, at = null, pitch := 1.0, vol := 0.0) -> void:
	if not sounds.has(sound):
		return
	var db := vol
	if at != null:
		var pos: Vector3 = at
		var d := pos.distance_to(listener)
		if d > 24.0:
			return
		db -= d * 0.8
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = sounds[sound]
	p.pitch_scale = clampf(pitch * randf_range(0.93, 1.07), 0.2, 4.0)
	p.volume_db = db
	p.play()


# ---------- synthesis ----------

func _tone(dur: float, f0: float, f1: float, wave := "sine", vol := 0.5, noise := 0.0, vib_hz := 0.0, vib := 0.0, am_hz := 0.0, attack := 0.005) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := float(i) / n
		var f := lerpf(f0, f1, k) * (1.0 + sin(TAU * vib_hz * t) * vib)
		phase += f / RATE
		var ph := fmod(phase, 1.0)
		var x := 0.0
		match wave:
			"sine":
				x = sin(TAU * ph)
			"square":
				x = 1.0 if ph < 0.5 else -1.0
			"saw":
				x = ph * 2.0 - 1.0
			"tri":
				x = 1.0 - 4.0 * absf(ph - 0.5)
		if noise > 0.0:
			x = lerpf(x, randf() * 2.0 - 1.0, noise)
		var env := minf(1.0, t / attack) * (1.0 - k) * (1.0 - k * 0.3)
		if am_hz > 0.0:
			env *= 0.5 + 0.5 * absf(sin(PI * am_hz * t))
		out[i] = x * env * vol
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate() if a.size() >= b.size() else b.duplicate()
	var short := b if a.size() >= b.size() else a
	for i in short.size():
		out[i] += short[i]
	return out


func _cat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


func _build() -> void:
	# Grumbles: a growly low voice that bubbles (amplitude wobble) and sags in pitch.
	sounds["grumble0"] = _wav(_mix(_tone(0.5, 150, 100, "tri", 0.4, 0.05, 28, 0.06, 6), _tone(0.5, 150, 100, "saw", 0.12, 0.0, 28, 0.06, 6)))
	sounds["grumble1"] = _wav(_mix(_tone(0.42, 120, 135, "tri", 0.4, 0.08, 32, 0.08, 9), _tone(0.42, 240, 260, "saw", 0.08)))
	sounds["grumble2"] = _wav(_cat([_tone(0.16, 170, 140, "tri", 0.4, 0.05, 30, 0.05), _tone(0.3, 130, 90, "tri", 0.4, 0.08, 25, 0.08, 5)]))
	sounds["grr"] = _wav(_mix(_tone(0.45, 95, 85, "saw", 0.22, 0.25, 36, 0.1), _tone(0.45, 95, 85, "tri", 0.3)))
	sounds["ow"] = _wav(_tone(0.18, 420, 220, "tri", 0.4, 0.05, 20, 0.05))
	sounds["hurt"] = _wav(_tone(0.22, 320, 120, "saw", 0.3, 0.3))
	sounds["blorp"] = _wav(_tone(0.18, 700, 160, "sine", 0.5, 0.0, 40, 0.12))
	sounds["splat"] = _wav(_mix(_tone(0.2, 200, 60, "sine", 0.4), _tone(0.15, 1, 1, "sine", 0.25, 1.0)))
	sounds["pop"] = _wav(_tone(0.1, 900, 250, "sine", 0.5))
	sounds["boom"] = _wav(_mix(_tone(0.8, 1, 1, "sine", 0.6, 1.0), _tone(0.7, 90, 32, "sine", 0.8)))
	sounds["slam"] = _wav(_mix(_tone(0.9, 60, 28, "sine", 0.9), _tone(0.5, 1, 1, "sine", 0.4, 1.0)))
	sounds["jump"] = _wav(_tone(0.13, 280, 720, "sine", 0.3))
	sounds["spring"] = _wav(_tone(0.35, 180, 820, "sine", 0.4, 0.0, 14, 0.2))
	sounds["throw"] = _wav(_tone(0.12, 1, 1, "sine", 0.2, 1.0))
	sounds["coin"] = _wav(_cat([_tone(0.06, 988, 988, "square", 0.12), _tone(0.2, 1319, 1319, "square", 0.12)]))
	sounds["click"] = _wav(_tone(0.05, 1500, 900, "square", 0.1))
	sounds["pew"] = _wav(_tone(0.1, 1300, 300, "square", 0.12))
	sounds["shotgun"] = _wav(_mix(_tone(0.3, 1, 1, "sine", 0.45, 1.0), _tone(0.25, 150, 50, "sine", 0.5)))
	sounds["glass"] = _wav(_mix(_mix(_tone(0.3, 1, 1, "sine", 0.25, 1.0), _tone(0.35, 2400, 2100, "sine", 0.18)), _tone(0.25, 3150, 3000, "sine", 0.12)))
	sounds["horn"] = _wav(_mix(_tone(1.0, 330, 325, "saw", 0.16, 0.0, 5, 0.01, 0.0, 0.05), _tone(1.0, 415, 410, "saw", 0.16, 0.0, 5, 0.01, 0.0, 0.05)))
	sounds["powerup"] = _wav(_cat([_tone(0.07, 523, 523, "square", 0.13), _tone(0.07, 659, 659, "square", 0.13), _tone(0.07, 784, 784, "square", 0.13), _tone(0.2, 1047, 1047, "square", 0.13)]))
	sounds["respawn"] = _wav(_tone(0.9, 200, 1100, "sine", 0.35, 0.0, 0.0, 0.0, 14))
	sounds["gameover"] = _wav(_cat([_tone(0.3, 392, 392, "tri", 0.35), _tone(0.3, 330, 330, "tri", 0.35), _tone(0.8, 262, 240, "tri", 0.35, 0.0, 6, 0.02)]))
	sounds["punch"] = _wav(_mix(_tone(0.12, 1, 1, "sine", 0.5, 1.0), _tone(0.14, 160, 60, "sine", 0.6)))
	sounds["twang"] = _wav(_tone(0.25, 620, 300, "tri", 0.4, 0.0, 30, 0.08))
	sounds["net"] = _wav(_mix(_tone(0.3, 1, 1, "sine", 0.25, 1.0), _tone(0.3, 500, 200, "sine", 0.25)))
	sounds["laser"] = _wav(_tone(0.12, 880, 840, "square", 0.08, 0.0, 60, 0.05))
	sounds["rocket"] = _wav(_mix(_tone(0.6, 1, 1, "sine", 0.35, 1.0), _tone(0.5, 220, 90, "saw", 0.15)))
	sounds["thunder"] = _wav(_mix(_tone(1.6, 1, 1, "sine", 0.6, 1.0), _tone(1.4, 55, 30, "sine", 0.7)))
	sounds["build"] = _wav(_cat([_tone(0.08, 180, 120, "sine", 0.5, 0.3), _tone(0.05, 1, 1, "sine", 0.0), _tone(0.1, 240, 140, "sine", 0.5, 0.3)]))
	sounds["power_big"] = _wav(_cat([_tone(0.06, 523, 523, "square", 0.12), _tone(0.06, 784, 784, "square", 0.12), _tone(0.06, 1047, 1047, "square", 0.12), _tone(0.35, 1568, 1568, "square", 0.12, 0.0, 8, 0.01)]))
	sounds["wave"] = _wav(_cat([_tone(0.1, 440, 440, "square", 0.12), _tone(0.25, 660, 660, "square", 0.12)]))
