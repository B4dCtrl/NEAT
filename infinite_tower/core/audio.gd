extends Node
## Autoload "Audio": every sound is synthesised at runtime (chiptune style), so
## the game ships without audio files. SFX are short cached AudioStreamWAVs;
## the music is a set of looping tracks rendered a few notes per frame, and the
## game picks one from what is happening (see _pick_track).

const RATE := 22050
const MUSIC_RATE := 16000
const VOICES := 10

var _cache := {}
var _players: Array = []
var _next := 0
var _last_played := {}
var _music: AudioStreamPlayer       # the track playing now
var _music_b: AudioStreamPlayer     # the other player: crossfades swap the two
var _fade_tween: Tween
var _tracks := {}
var _current_track := ""
var _wanted_track := "climb"
var _forced := ""           # test mode: play this track whatever happens
var _since_switch := 99.0
var _pick_clock := 0.0
var _building := {}         # tracks being rendered
var _build_queue: Array = []
var _abort := false         # set on exit: a running render stops early

## Every theme, in the order they are prepared in the background. The first
## ones are the ones needed soonest.
const TRACK_ORDER := ["climb", "boss", "camp", "fall", "elite", "lord", "rage"]
const FADE_TIME := 1.4
## Loudness every rendered track is brought to, so a switch never jumps.
const TARGET_RMS := 0.075


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
	_music_b = AudioStreamPlayer.new()
	_music_b.bus = "Music"
	add_child(_music_b)
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
		# The climbing theme first (it starts at once), the rest one by one behind it.
		_build_queue = TRACK_ORDER.duplicate()
		_build_next()


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
		"fall":
			play("fall")
		"milestone":
			play("fanfare")


func _process(delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	_since_switch += delta
	_pick_clock += delta
	if _pick_clock >= 0.2:
		_pick_clock = 0.0
		var want := _pick_track()
		if want != _wanted_track and (_since_switch > 3.0 or _forced != ""):
			set_track(want)
	# Silence the music while the game hides in the tray.
	_music.stream_paused = WindowManager.hidden
	_music_b.stream_paused = WindowManager.hidden


## The theme that fits the moment: Guardians, Elite Guardians and Tower Lords
## each have their own battle music (and a faster one once the boss enrages),
## a defeat has a lament, the bonfire a calm tune, the rest of the climb a
## steady one.
func _pick_track() -> String:
	if _forced != "":
		return _forced
	var e = Game.expedition
	if e == null:
		return "climb"
	if e.phase == "pause" and e.falling == "fall":
		return "fall"
	if e.phase == "camp" or (e.phase == "pause" and e.floor_info.get("type", "") == "bonfire" and e.falling == ""):
		return "camp"
	if e.phase in ["intro", "combat"] and e.floor_info.get("type", "") == "guardian":
		if e.combat != null:
			for u in e.combat.enemies:
				if u.is_boss and u.alive and u.enraged:
					return "rage"
		match String(e.floor_info.get("tier", "")):
			"lord":
				return "lord"
			"elite":
				return "elite"
		return "boss"
	return "climb"


## Test mode: play this theme whatever happens ("" = back to automatic).
func force_track(track: String) -> void:
	_forced = track
	if track != "":
		set_track(track)


static func track_names() -> Array:
	return TRACK_ORDER.duplicate()


## The theme currently playing (test mode shows it).
func current_track() -> String:
	return _current_track


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
		"spirit": s = _mix([_swell(180.0, 760.0, 1.1, 0.26, 12.0), _swell(270.0, 1140.0, 1.1, 0.1, 8.0), _sweep_noise(0.9, 0.12)])
		"reform": s = _mix([_arp([392.0, 523.0, 659.0, 784.0, 1047.0], 0.1, "triangle", 0.26), _swell(98.0, 130.0, 0.9, 0.2, 0.0)])
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


## A tone that swells in and out (spirits, auras) instead of striking and fading.
func _swell(f0: float, f1: float, dur: float, vol: float, vibrato: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		var f := lerpf(f0, f1, k * k) * (1.0 + (sin(i / float(RATE) * TAU * vibrato) * 0.025 if vibrato > 0.0 else 0.0))
		phase = fmod(phase + f / RATE, 1.0)
		out[i] = sin(phase * TAU) * vol * sin(k * PI) * (0.6 + 0.4 * k)
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
	return _wav_from_bytes(bytes, rate, loop)


func _wav_from_bytes(bytes: PackedByteArray, rate: int, loop: bool) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = bytes.size() / 2
	return w


# ------------------------------------------------------------------ music

func set_track(track: String) -> void:
	_wanted_track = track
	if _tracks.has(track):
		_start_track(track)
	else:
		_build_track_async(track)


## Crossfades to the track: the new one fades in on the idle player while the
## old one fades out.
func _start_track(track: String) -> void:
	if _current_track == track or DisplayServer.get_name() == "headless":
		return
	_since_switch = 0.0
	var first := _current_track == ""
	_current_track = track
	var inn := _music_b
	var out := _music
	inn.stream = _tracks[track]
	inn.volume_db = 0.0 if first else -60.0
	inn.play()
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if not first:
		_fade_tween = create_tween().set_parallel(true)
		_fade_tween.tween_property(inn, "volume_db", 0.0, FADE_TIME)
		_fade_tween.tween_property(out, "volume_db", -60.0, FADE_TIME)
		_fade_tween.chain().tween_callback(out.stop)
	else:
		out.stop()
	_music = inn
	_music_b = out


func _build_track_async(track: String) -> void:
	if _building.has(track) or _tracks.has(track):
		return
	# Wanted now: it jumps the queue of background tracks.
	_build_queue.erase(track)
	_building[track] = true
	_finish_build(track)


func _finish_build(track: String) -> void:
	var wav = await render(track)
	if wav != null:
		_on_track_ready(track, wav)
	else:
		_building.erase(track)


## Background preparation: the next track in line, once the last one is ready.
func _build_next() -> void:
	while not _build_queue.is_empty():
		var t: String = _build_queue.pop_front()
		if _tracks.has(t) or _building.has(t):
			continue
		_building[t] = true
		var wav = await render(t)
		if _abort:
			return
		if wav != null:
			_on_track_ready(t, wav)
		else:
			_building.erase(t)
		# Nothing waits on the later themes, so give the frames back between tracks.
		for i in 30:
			await get_tree().process_frame


## Rendering runs on the main thread, a few notes per frame. (It used to run
## on a worker thread, but GDScript there corrupted memory and crashed the
## game on exit.)
func _exit_tree() -> void:
	_abort = true


func _on_track_ready(track: String, wav: AudioStreamWAV) -> void:
	_tracks[track] = wav
	_building.erase(track)
	# Something plays as soon as anything is ready, then the wanted theme takes over.
	if _wanted_track == track or _current_track == "":
		_start_track(track)


# ------------------------------------------------------------------ track recipes

const CHORDS := {"m": [0, 3, 7], "": [0, 4, 7], "dim": [0, 3, 6], "m7": [0, 3, 7, 10], "sus": [0, 5, 7], "maj7": [0, 4, 7, 11]}
const REST := -99

## Recipes for the themes drawn by _render_spec (the two oldest, climb and boss,
## keep their own code). Per bar: a bass root (MIDI) and a chord kind; a melody on
## a grid of `grid` steps per bar (0 rest, -1 hold the last note); bass offsets on
## eighth notes (REST = silent); drum patterns of 16 steps ("x" hit).
const SPECS := {
	# Elite Guardian: E minor, driving, heroic and a little desperate.
	"elite": {
		"bpm": 114, "loops": 4, "grid": 8,
		"bars": [[40, "m"], [36, ""], [43, ""], [38, ""]],
		"melody": [[76, 79, 83, 79, 76, 79, 81, 83], [84, 83, 79, 76, 79, 76, 72, 76], [74, 79, 83, 86, 83, 79, 74, 79], [78, 81, 86, 81, 78, 74, 78, 81]],
		"lead_octave": [0, 0, 12, 0],
		"lead": "pulse", "lead_vol": 0.06, "arp": "square", "arp_vol": 0.04, "arp_every": 1, "arp_pat": "updown",
		"bass": [0, 0, 12, 0, 0, 12, 7, 0], "bass_wave": "triangle", "bass_vol": 0.17,
		"kick": "x.......x...x...", "snare": "....x.......x...", "hat": "x.x.x.x.x.x.x.x.", "drum_vol": 1.0,
		"pad": "", "echo": 0,
	},
	# Tower Lord: F minor, slow and enormous, a choir over a heavy half-time beat.
	"lord": {
		"bpm": 84, "loops": 3, "grid": 4,
		"bars": [[41, "m"], [37, ""], [39, ""], [36, ""]],
		"melody": [[77, 80, 84, 80], [80, 77, 73, 77], [82, 79, 75, 79], [76, 79, 84, 0]],
		"lead_octave": [0, 12, 0],
		"lead": "pulse", "lead_vol": 0.05, "arp": "triangle", "arp_vol": 0.05, "arp_every": 2, "arp_pat": "updown",
		"bass": [0, REST, REST, REST, 0, REST, 7, REST], "bass_wave": "square", "bass_vol": 0.12,
		"kick": "x.....x.x.......", "snare": "........x.......", "hat": "..x...x...x...x.", "drum_vol": 1.2,
		"pad": "sine", "pad_vol": 0.07, "echo": 6,
	},
	# A Guardian that has gone into a rage: D minor, fast, relentless.
	"rage": {
		"bpm": 156, "loops": 4, "grid": 16,
		"bars": [[38, "m"], [34, ""], [31, "m"], [33, ""]],
		"melody": [
			[74, 77, 81, 77, 74, 77, 81, 86, 85, 81, 77, 81, 85, 81, 77, 74],
			[70, 74, 77, 74, 70, 74, 77, 82, 81, 77, 74, 77, 82, 77, 74, 70],
			[67, 70, 74, 70, 67, 70, 74, 79, 77, 74, 70, 74, 79, 74, 70, 67],
			[69, 73, 76, 73, 69, 73, 76, 81, 85, 81, 76, 73, 76, 73, 69, 0],
		],
		"lead_octave": [0, 0, 12, 0],
		"lead": "pulse", "lead_vol": 0.05, "arp": "square", "arp_vol": 0.035, "arp_every": 1, "arp_pat": "up",
		"bass": [0, 0, 0, 12, 0, 0, 12, 0], "bass_wave": "square", "bass_vol": 0.1,
		"kick": "x..xx..xx..xx.x.", "snare": "....x.......x..x", "hat": "xxxxxxxxxxxxxxxx", "drum_vol": 1.2,
		"pad": "", "echo": 0,
	},
	# Defeat: A minor, slow, no drums but a far-off heartbeat.
	"fall": {
		"bpm": 60, "loops": 3, "grid": 4,
		"bars": [[45, "m"], [41, ""], [38, "m"], [40, ""]],
		"melody": [[81, 79, 76, 0], [77, 76, 72, 0], [74, 72, 69, 0], [68, 71, 76, 0]],
		"lead_octave": [0, 0, -12],
		"lead": "triangle", "lead_vol": 0.09, "lead_vibrato": 1.0,
		"arp": "sine", "arp_vol": 0.04, "arp_every": 4, "arp_pat": "updown",
		"bass": [0, REST, REST, REST, REST, REST, REST, REST], "bass_wave": "sine", "bass_vol": 0.18,
		"kick": "x.......x.......", "snare": "", "hat": "", "drum_vol": 0.5,
		"pad": "triangle", "pad_vol": 0.05, "echo": 6,
	},
	# Bonfire: C major, warm, unhurried, a few crackles.
	"camp": {
		"bpm": 72, "loops": 3, "grid": 4,
		"bars": [[48, ""], [45, "m"], [41, ""], [43, ""]],
		"melody": [[79, 76, 79, 84], [76, 72, 76, 81], [77, 81, 84, 81], [79, 83, 79, 74]],
		"lead_octave": [0, 0, 0],
		"lead": "triangle", "lead_vol": 0.08, "lead_vibrato": 1.0,
		"arp": "triangle", "arp_vol": 0.05, "arp_every": 2, "arp_pat": "updown",
		"bass": [0, REST, REST, REST, 7, REST, REST, REST], "bass_wave": "triangle", "bass_vol": 0.14,
		"kick": "", "snare": "", "hat": "", "drum_vol": 0.0,
		"pad": "sine", "pad_vol": 0.05, "echo": 4, "crackle": true,
	},
}


## Renders a theme (a coroutine: it yields every few notes so the game never
## stutters) and returns the looping stream, or null when the game is closing.
func render(track: String) -> AudioStreamWAV:
	if SPECS.has(track):
		return await _render_spec(track)
	return await _render_classic(track)


func _render_spec(track: String) -> AudioStreamWAV:
	var sp: Dictionary = SPECS[track]
	var bpm := float(sp["bpm"])
	var beat := 60.0 / bpm
	var bars: Array = sp["bars"]
	var loops := int(sp["loops"])
	var grid := int(sp["grid"])
	var melody: Array = sp["melody"]
	var octaves: Array = sp.get("lead_octave", [0])
	var total_beats := bars.size() * 4 * loops
	var n := int(round(total_beats * beat * MUSIC_RATE))
	var out := PackedFloat32Array()
	out.resize(n)
	var step := beat / 4.0     # 16th notes
	var steps := total_beats * 4
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(track)
	var cell := 16 / grid      # 16ths per melody step
	var jobs: Array = []       # notes waiting to be drawn into the buffer
	var bass_pat: Array = sp["bass"]
	var arp_every := int(sp.get("arp_every", 1))
	var dvol := float(sp.get("drum_vol", 1.0))
	var echo := int(sp.get("echo", 0))
	for sidx in steps:
		var bar: Array = bars[int(sidx / 16) % bars.size()]
		var loop_i := int(sidx / (16 * bars.size()))
		var in_bar := sidx % 16
		var root: int = bar[0]
		var tones: Array = []
		for iv in CHORDS[bar[1]]:
			tones.append(root + 24 + int(iv))
		tones.append(root + 36)
		var t0 := int(round(sidx * step * MUSIC_RATE))
		var len := int(round(step * MUSIC_RATE))
		# Arpeggio.
		if in_bar % arp_every == 0:
			var ai := sidx / arp_every
			var idx: int = [0, 1, 2, 3, 2, 1][ai % 6] if sp.get("arp_pat", "up") == "updown" else ai % 4
			_queue(jobs, t0, int(len * arp_every * 0.95), _midi(tones[idx % tones.size()]), String(sp["arp"]), float(sp["arp_vol"]), 50, 0.4)
		# Bass, on eighth notes: each note lasts until the next one.
		if in_bar % 2 == 0:
			var e := int(in_bar / 2)
			var off: int = bass_pat[e]
			if off != REST:
				var gap := 1
				while gap < 8 and bass_pat[(e + gap) % 8] == REST:
					gap += 1
				_queue(jobs, t0, int(len * 2 * gap * 0.94), _midi(root + off), String(sp["bass_wave"]), float(sp["bass_vol"]), 80, 0.2)
		# Lead melody.
		if in_bar % cell == 0:
			var mel: Array = melody[int(sidx / 16) % bars.size()]
			var m: int = mel[int(in_bar / cell)]
			if m > 0:
				var oct := int(octaves[loop_i % octaves.size()])
				var gap := 1
				while int(in_bar / cell) + gap < grid and mel[int(in_bar / cell) + gap] == -1:
					gap += 1
				var nlen := int(len * cell * gap * 0.92)
				var vib := 5.5 if sp.get("lead_vibrato", 0.0) > 0.0 else 0.0
				_queue(jobs, t0, nlen, _midi(m + oct), String(sp["lead"]), float(sp["lead_vol"]), 60, 0.35, vib)
				if echo > 0:
					_queue(jobs, t0 + len * echo, nlen, _midi(m + oct), String(sp["lead"]), float(sp["lead_vol"]) * 0.35, 60, 0.5, vib)
		# Pad: the whole bar, slow in and out.
		if in_bar == 0 and sp.get("pad", "") != "":
			for k in 3:
				_queue(jobs, t0, len * 16, _midi(tones[k] - 12), String(sp["pad"]), float(sp["pad_vol"]), len * 5, 0.3, 4.0 + k)
		# Percussion.
		if dvol > 0.0:
			if _hit(sp, "kick", in_bar):
				_kick(out, t0, 0.2 * dvol)
			if _hit(sp, "snare", in_bar):
				_snare(out, t0, 0.18 * dvol, rng)
			if _hit(sp, "hat", in_bar):
				_hat(out, t0, 0.05 * dvol * (1.4 if in_bar % 4 == 2 else 0.8), rng)
		if sp.get("crackle", false) and rng.randf() < 0.22:
			_hat(out, t0 + rng.randi_range(0, len - 1), 0.05, rng)
		# A fixed amount of drawing per frame keeps the game smooth while it renders.
		_drain(out, jobs, 20000)
		await get_tree().process_frame
		if _abort:
			return null
	while not jobs.is_empty():
		_drain(out, jobs, 20000)
		await get_tree().process_frame
		if _abort:
			return null
	return await _finish(out)


static func _hit(sp: Dictionary, lane: String, in_bar: int) -> bool:
	var pat: String = sp.get(lane, "")
	return pat.length() == 16 and pat[in_bar] == "x"


## Brings a rendered buffer to the common loudness and wraps it as a loop.
func _finish(out: PackedFloat32Array) -> AudioStreamWAV:
	var sum := 0.0
	for i in out.size():
		if i % 40000 == 0:
			await get_tree().process_frame
			if _abort:
				return null
		sum += out[i] * out[i]
	var rms := sqrt(sum / maxf(1.0, out.size()))
	var gain := TARGET_RMS / maxf(rms, 0.0001)
	var bytes := PackedByteArray()
	bytes.resize(out.size() * 2)
	for i in out.size():
		if i % 20000 == 0:
			await get_tree().process_frame
			if _abort:
				return null
		# A soft knee keeps the loudest hits from clipping.
		var v := out[i] * gain
		bytes.encode_s16(i * 2, int(tanh(v * 1.2) / 1.2 * 32000.0))
	return _wav_from_bytes(bytes, MUSIC_RATE, true)


## The two oldest themes: "climb" is calm (A minor, 96 BPM); "boss" is tense
## (D minor, 132). A small chiptune loop: triangle bass, square arpeggios, a
## pulse melody and noise hats.
func _render_classic(track: String) -> AudioStreamWAV:
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
		if sidx % 2 == 0:
			await get_tree().process_frame
			if _abort:
				return null
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
	var bytes := PackedByteArray()
	bytes.resize(out.size() * 2)
	for i in out.size():
		if i % 20000 == 0:
			await get_tree().process_frame
			if _abort:
				return null
		bytes.encode_s16(i * 2, int(clampf(out[i], -1.0, 1.0) * 32000.0))
	return _wav_from_bytes(bytes, MUSIC_RATE, true)


## Queues a note: a short attack, a release that dies away to silence, and
## optional vibrato (Hz). Drawing happens in _drain.
static func _queue(jobs: Array, start: int, length: int, freq: float, wave: String, vol: float, attack: int = 60, release: float = 0.3, vibrato: float = 0.0) -> void:
	jobs.append({"s": start, "n": length, "f": freq, "w": wave, "v": vol, "a": attack, "r": release, "vb": vibrato, "i": 0})


## Draws up to `budget` samples of the queued notes into the buffer.
static func _drain(buf: PackedFloat32Array, jobs: Array, budget: int) -> void:
	var done := 0
	while not jobs.is_empty() and done < budget:
		var j: Dictionary = jobs[0]
		var take := mini(int(j["n"]) - int(j["i"]), budget - done)
		_note_range(buf, j, int(j["i"]), int(j["i"]) + take)
		j["i"] = int(j["i"]) + take
		done += take
		if int(j["i"]) >= int(j["n"]):
			jobs.pop_front()


## Samples [i0, i1) of a note. Notes wrap round the end of the buffer so loops
## are seamless.
static func _note_range(buf: PackedFloat32Array, j: Dictionary, i0: int, i1: int) -> void:
	var n := buf.size()
	var length: int = j["n"]
	var freq: float = j["f"]
	var wave: String = j["w"]
	var vol: float = j["v"]
	var attack := maxf(1.0, float(j["a"]))
	var release: float = j["r"]
	var vib: float = j["vb"]
	var start: int = j["s"]
	var rel_start := 1.0 - release
	var w := TAU * vib
	for i in range(i0, i1):
		var k := float(i) / length
		var env := minf(1.0, float(i) / attack)
		if k > rel_start:
			env *= (1.0 - k) / release
		env *= 1.0 - 0.25 * k
		var t := float(i) / MUSIC_RATE
		var ph := freq * t
		if vib > 0.0:
			ph += freq * 0.008 * (1.0 - cos(w * t)) / w
		buf[(start + i) % n] += _wave(wave, fposmod(ph, 1.0)) * vol * env


static func _kick(buf: PackedFloat32Array, start: int, vol: float) -> void:
	var n := buf.size()
	var len := int(0.16 * MUSIC_RATE)
	var phase := 0.0
	for i in len:
		var k := float(i) / len
		var f := lerpf(140.0, 42.0, minf(1.0, k * 3.0))
		phase = fmod(phase + f / MUSIC_RATE, 1.0)
		buf[(start + i) % n] += sin(phase * TAU) * vol * pow(1.0 - k, 2.0)


static func _snare(buf: PackedFloat32Array, start: int, vol: float, rng: RandomNumberGenerator) -> void:
	var n := buf.size()
	var len := int(0.13 * MUSIC_RATE)
	for i in len:
		var k := float(i) / len
		var tone := sin(float(i) / MUSIC_RATE * TAU * 190.0) * 0.5
		buf[(start + i) % n] += (rng.randf_range(-1.0, 1.0) * 0.7 + tone) * vol * pow(1.0 - k, 2.2)


static func _hat(buf: PackedFloat32Array, start: int, vol: float, rng: RandomNumberGenerator) -> void:
	var n := buf.size()
	var len := int(0.035 * MUSIC_RATE)
	var prev := 0.0
	for i in len:
		var k := float(i) / len
		var r := rng.randf_range(-1.0, 1.0)
		buf[(start + i) % n] += (r - prev) * 0.5 * vol * (1.0 - k)
		prev = r


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
