extends Node
## Autoload "Audio": every sound is synthesised at runtime (chiptune style), so
## the game ships without audio files. SFX are short cached AudioStreamWAVs;
## the music is a looping track rendered on a worker thread.

const RATE := 22050
const MUSIC_RATE := 16000
const VOICES := 10

var _cache := {}
var _players: Array = []
var _next := 0
var _last_played := {}
var _music: AudioStreamPlayer
var _tracks := {}
var _current_track := ""
var _wanted_track := "climb"
var _building := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	Game.sfx_requested.connect(play)
	Game.settings_changed.connect(apply_volumes)
	Game.notified.connect(_on_notified)
	Game.loot_dropped.connect(func(d: Dictionary):
		if d.has("relic"):
			play("relic")
		elif d.has("rarity") and DataDB.rarity_order(d["rarity"]) >= 4:
			play("legendary")
		else:
			play("loot"))
	apply_volumes()
	if DisplayServer.get_name() != "headless":
		_build_track_async("climb")


const DataDB = preload("res://core/data_db.gd")


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func apply_volumes() -> void:
	var s: Dictionary = Game.state["settings"]
	_set_bus("Music", float(s.get("music_volume", 0.35)))
	_set_bus("SFX", float(s.get("sfx_volume", 0.5)))


func _set_bus(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(idx, v <= 0.001)


func _on_notified(kind: String, _text: String) -> void:
	match kind:
		"boss":
			play("boss")
			set_track("boss")
		"fall":
			play("fall")
		"milestone":
			play("fanfare")


func _process(_delta: float) -> void:
	# Back to the climbing theme once the guardian fight is over.
	if _wanted_track == "boss" and Game.expedition != null and not Game.expedition.floor_info.is_empty():
		if Game.expedition.floor_info.get("type", "") != "guardian":
			set_track("climb")
	# Silence the music while the game hides in the tray.
	_music.stream_paused = WindowManager.hidden


# ------------------------------------------------------------------ SFX

## Plays a named cue. Frequent cues (hits) are rate-limited.
func play(cue: String) -> void:
	if cue == "" or DisplayServer.get_name() == "headless":
		return
	var now := Time.get_ticks_msec()
	var gap := 70 if cue in ["hit", "miss"] else 40
	if now - int(_last_played.get(cue, 0)) < gap:
		return
	_last_played[cue] = now
	if not _cache.has(cue):
		_cache[cue] = _make_sfx(cue)
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _cache[cue]
	p.pitch_scale = randf_range(0.94, 1.06) if cue in ["hit", "miss", "death"] else 1.0
	p.play()


func _make_sfx(cue: String) -> AudioStreamWAV:
	var s := PackedFloat32Array()
	match cue:
		"hit": s = _mix([_tone(160.0, 90.0, 0.07, "square", 0.35), _noise(0.05, 0.25)])
		"crit": s = _mix([_tone(520.0, 260.0, 0.12, "square", 0.35), _noise(0.12, 0.35), _tone(1040.0, 780.0, 0.1, "square", 0.15)])
		"miss": s = _sweep_noise(0.16, 0.3)
		"death": s = _tone(300.0, 60.0, 0.25, "square", 0.3)
		"level": s = _arp([523.0, 659.0, 784.0, 1047.0], 0.07, "square", 0.25)
		"loot": s = _arp([880.0, 1318.0], 0.06, "triangle", 0.3)
		"legendary": s = _arp([784.0, 988.0, 1175.0, 1568.0, 1976.0], 0.06, "square", 0.22)
		"relic": s = _arp([659.0, 831.0, 988.0, 1319.0, 1661.0, 1976.0], 0.07, "triangle", 0.3)
		"boss": s = _mix([_tone(110.0, 55.0, 0.6, "square", 0.35), _noise(0.25, 0.3)])
		"fall": s = _tone(700.0, 90.0, 0.7, "triangle", 0.3)
		"fanfare": s = _arp([523.0, 659.0, 784.0, 659.0, 1047.0], 0.09, "square", 0.25)
		"heal", "potion": s = _arp([440.0, 554.0, 659.0, 880.0], 0.05, "triangle", 0.25)
		"shield": s = _mix([_tone(880.0, 1320.0, 0.3, "triangle", 0.2), _tone(660.0, 990.0, 0.3, "triangle", 0.15)])
		"slam", "bomb", "meteor": s = _mix([_tone(90.0, 35.0, 0.45, "square", 0.4), _noise(0.4, 0.45)])
		"volley": s = _mix([_noise(0.04, 0.2), _noise(0.04, 0.2, 0.06), _noise(0.04, 0.2, 0.12)])
		"summon": s = _tone(200.0, 420.0, 0.35, "square", 0.2, 18.0)
		"drain": s = _tone(500.0, 180.0, 0.4, "triangle", 0.25, 12.0)
		"enrage": s = _tone(140.0, 220.0, 0.35, "square", 0.3, 25.0)
		"use", "click": s = _tone(900.0, 700.0, 0.05, "square", 0.2)
		_: s = _tone(440.0, 440.0, 0.05, "square", 0.2)
	return _to_wav(s, RATE, false)


func _tone(f0: float, f1: float, dur: float, wave: String, vol: float, vibrato: float = 0.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		var f := lerpf(f0, f1, k) * (1.0 + (sin(i / float(RATE) * TAU * vibrato) * 0.03 if vibrato > 0.0 else 0.0))
		phase = fmod(phase + f / RATE, 1.0)
		var env := minf(1.0, i / (RATE * 0.004)) * (1.0 - k) * (1.0 - k)
		out[i] = _wave(wave, phase) * vol * env
	return out


func _noise(dur: float, vol: float, delay: float = 0.0) -> PackedFloat32Array:
	var n := int((dur + delay) * RATE)
	var d := int(delay * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(d, n):
		var k := float(i - d) / (n - d)
		out[i] = randf_range(-1.0, 1.0) * vol * (1.0 - k) * (1.0 - k)
	return out


func _sweep_noise(dur: float, vol: float) -> PackedFloat32Array:
	# Crude low-pass sweep: a whoosh.
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var k := float(i) / n
		var alpha := lerpf(0.05, 0.5, sin(k * PI))
		y += (randf_range(-1.0, 1.0) - y) * alpha
		out[i] = y * vol * sin(k * PI)
	return out


func _arp(freqs: Array, step: float, wave: String, vol: float) -> PackedFloat32Array:
	var parts := []
	for i in freqs.size():
		var t := _tone(freqs[i], freqs[i], step * 2.2, wave, vol)
		var pad := PackedFloat32Array()
		pad.resize(int(i * step * RATE))
		pad.append_array(t)
		parts.append(pad)
	return _mix(parts)


func _mix(parts: Array) -> PackedFloat32Array:
	var n := 0
	for p in parts:
		n = maxi(n, p.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p in parts:
		for i in p.size():
			out[i] += p[i]
	return out


static func _wave(wave: String, phase: float) -> float:
	match wave:
		"square":
			return 1.0 if phase < 0.5 else -1.0
		"triangle":
			return 4.0 * absf(phase - 0.5) - 1.0
		"pulse":
			return 1.0 if phase < 0.25 else -1.0
	return sin(phase * TAU)


func _to_wav(samples: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


# ------------------------------------------------------------------ music

func set_track(track: String) -> void:
	_wanted_track = track
	if _tracks.has(track):
		_start_track(track)
	else:
		_build_track_async(track)


func _start_track(track: String) -> void:
	if _current_track == track or DisplayServer.get_name() == "headless":
		return
	_current_track = track
	_music.stream = _tracks[track]
	_music.play()


func _build_track_async(track: String) -> void:
	if _building.has(track) or _tracks.has(track):
		return
	_building[track] = true
	WorkerThreadPool.add_task(func():
		var wav := _render_track(track)
		call_deferred("_on_track_ready", track, wav))


func _on_track_ready(track: String, wav: AudioStreamWAV) -> void:
	_tracks[track] = wav
	_building.erase(track)
	if _wanted_track == track:
		_start_track(track)


## A small chiptune loop: triangle bass, square arpeggios, a pulse melody and
## noise hats. "climb" is calm (A minor, 96 BPM); "boss" is tense (D minor, 132).
func _render_track(track: String) -> AudioStreamWAV:
	var boss := track == "boss"
	var bpm := 132.0 if boss else 96.0
	var beat := 60.0 / bpm
	# Chord roots (MIDI) and qualities per bar.
	var bars: Array = [[50, "m"], [46, ""], [53, ""], [48, ""]] if boss else [[45, "m"], [41, ""], [48, ""], [43, ""]]
	var melody: Array = [74, 72, 69, 72, 70, 69, 65, 69, 77, 76, 72, 76, 72, 70, 67, 70] if boss else [76, 72, 69, 72, 77, 72, 69, 72, 72, 67, 64, 67, 74, 71, 67, 71]
	var loops := 2
	var total_beats := bars.size() * 4 * loops
	var n := int(total_beats * beat * MUSIC_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var step := beat / 4.0     # 16th notes
	var steps := int(total_beats * 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for sidx in steps:
		var bar: Array = bars[int(sidx / 16) % bars.size()]
		var root: int = bar[0]
		var third := 3 if bar[1] == "m" else 4
		var chord := [root + 12, root + 12 + third, root + 19, root + 24]
		var t0 := int(sidx * step * MUSIC_RATE)
		var len := int(step * MUSIC_RATE)
		# Arpeggio (square, quiet).
		_add_note(out, t0, len, _midi(chord[sidx % 4]), "square", 0.045)
		# Bass on beats (triangle).
		if sidx % 4 == 0:
			_add_note(out, t0, len * 3, _midi(root - 12), "triangle", 0.16)
		# Melody on 8ths, with rests.
		if sidx % 2 == 0:
			var m: int = melody[(sidx / 2) % melody.size()]
			if (sidx / 2) % 8 != 7:
				_add_note(out, t0, len * 2, _midi(m), "pulse", 0.05)
		# Hats / snare.
		if boss or sidx % 2 == 0:
			_add_noise(out, t0, int(len * 0.35), 0.03 if sidx % 8 != 4 else 0.08, rng)
		if boss and sidx % 8 == 0:
			_add_note(out, t0, len, 55.0, "triangle", 0.2)
	return _to_wav(out, MUSIC_RATE, true)


static func _midi(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)


static func _add_note(buf: PackedFloat32Array, start: int, length: int, freq: float, wave: String, vol: float) -> void:
	var phase := 0.0
	var end := mini(buf.size(), start + length)
	for i in range(start, end):
		var k := float(i - start) / length
		phase = fmod(phase + freq / MUSIC_RATE, 1.0)
		var env := minf(1.0, (i - start) / 80.0) * (1.0 - k * 0.7)
		buf[i] += _wave(wave, phase) * vol * env


static func _add_noise(buf: PackedFloat32Array, start: int, length: int, vol: float, rng: RandomNumberGenerator) -> void:
	var end := mini(buf.size(), start + length)
	for i in range(start, end):
		var k := float(i - start) / length
		buf[i] += rng.randf_range(-1.0, 1.0) * vol * (1.0 - k)
