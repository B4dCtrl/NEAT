extends Node2D
## Shared visual for heroes and enemies. Purely cosmetic: it mirrors combat
## state pushed by the stage and never influences the simulation.
##
## Attacks play a real timeline (wind-up, dash, impact hold, recovery) so a
## blow has anticipation and weight; being hit shoves the unit back and freezes
## it for a few frames (hit-stop); deaths wait for the killing blow to land.

const PixelArt = preload("res://scenes/entities/pixel_art.gd")

@export var px_scale := 2.0
@export var face_left := false
@export var show_hp_bar := true

var textures: Array = []
var walking := false
var dead := false
var hp_ratio := 1.0
## Heroes also show a blue mana bar (-1 = no mana bar).
var mp_ratio := -1.0
var unit_uid := ""
## Heroes use their walk strip as poses (frame 0 stands, the stride frames are
## for walking and for the strike); monsters loop their strip as an idle.
var stand_pose := false

## Attack timeline, in seconds from the start of the attack.
const WIND := 0.10       # pull back
const STRIKE := 0.07     # dash forward
const HOLD := 0.05       # impact frame
const RECOVER := 0.22    # return to the spot
const ATK_TOTAL := WIND + STRIKE + HOLD + RECOVER
## When a melee blow lands / when a ranged attack is released.
const MELEE_IMPACT := WIND + STRIKE
const RELEASE := WIND
## How long a unit that died waits for the killing blow before toppling.
const DEATH_DELAY := 0.2

var _anim_t := 0.0
var _atk := -1.0
var _atk_reach := 0.0
var _atk_melee := true
var _stop := 0.0
var _kb := 0.0
var _dodge := 0.0
var _flash := 0.0
var _fade := 1.0
var _bob_phase := 0.0
var _tint := Color.WHITE
var _cast := 0.0
var _cast_col := Color.WHITE
var _death_t := 0.0
var _dead_req := false
var _dead_wait := 0.0
var _hp_lag := 1.0
var _lag_wait := 0.0


## Built-in text sprites are 12 art pixels tall and drawn at px_scale. Imported
## PNG art (PixelLab) is higher resolution, so it is drawn at px_scale / 2: native
## size in the taskbar (px 2), 1.5x in the expedition view (px 3).
const EXTERNAL_MIN_HEIGHT := 17

var _norm := 1.0
var _fx_anim := false


func configure(sprite_id: String, palette: Dictionary = {}, scale_px: float = 2.0, left: bool = false, mono: bool = false, unit_id: String = "", hue: float = -1.0, fx: Array = []) -> void:
	textures = PixelArt.unit_frames(unit_id, sprite_id, palette, mono, hue, fx)
	_fx_anim = not fx.is_empty()
	_norm = 0.5 if not textures.is_empty() and textures[0].get_height() >= EXTERNAL_MIN_HEIGHT else 1.0
	px_scale = scale_px
	face_left = left
	dead = false
	_dead_req = false
	_fade = 1.0
	_death_t = 0.0
	_atk = -1.0
	_stop = 0.0
	_kb = 0.0
	hp_ratio = 1.0
	_hp_lag = 1.0
	_bob_phase = randf() * TAU
	queue_redraw()


func size_px() -> Vector2:
	if textures.is_empty():
		return Vector2.ZERO
	return Vector2(textures[0].get_width(), textures[0].get_height()) * px_scale * _norm


## Starts the attack timeline. `reach_px` is how far a melee unit dashes toward
## its target; ranged units only recoil a little.
func attack(reach_px: float = 8.0, melee: bool = true) -> void:
	_atk = 0.0
	_atk_melee = melee
	_atk_reach = clampf(reach_px, 4.0 * px_scale, 15.0 * px_scale) if melee else 1.4 * px_scale


## Kept for callers that only want "a lunge".
func lunge() -> void:
	attack(8.0 * px_scale, true)


## Quick hop backwards when an attack misses.
func dodge() -> void:
	_dodge = 1.0


## Hit reaction: white flash, a shove away from the attacker and a squash.
## `power` 1 is a normal hit, 2 a critical one.
func hurt(power: float = 1.0) -> void:
	_flash = 1.0
	_kb = maxf(_kb, clampf(power, 0.5, 2.5))


## Freezes the sprite for a moment (impact weight).
func hitstop(seconds: float) -> void:
	_stop = maxf(_stop, seconds)


## Casting pose for skills and item use: a hop with a pulse, glowing in `col`.
func cast(col: Color = Color.WHITE) -> void:
	_cast = 1.0
	_cast_col = col


## A death waits a moment so the blow that caused it is seen landing first.
func set_dead(value: bool) -> void:
	if value:
		if not dead and not _dead_req:
			_dead_req = true
			_dead_wait = DEATH_DELAY
	else:
		_dead_req = false
		dead = false
		_death_t = 0.0
		_fade = 1.0


func set_tint(c: Color) -> void:
	_tint = c
	queue_redraw()


static func _ease_out(x: float, power: float = 2.0) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), power)


func _process(delta: float) -> void:
	if _stop > 0.0:
		_stop -= delta
		queue_redraw()
		return
	_anim_t += delta
	if _atk >= 0.0:
		_atk += delta
		if _atk >= ATK_TOTAL:
			_atk = -1.0
	_dodge = maxf(0.0, _dodge - delta * 4.0)
	_flash = maxf(0.0, _flash - delta * 6.0)
	_cast = maxf(0.0, _cast - delta * 2.2)
	_kb *= exp(-delta * 15.0)
	if _kb < 0.01:
		_kb = 0.0
	# The pale "recent damage" bar trails behind the real one.
	if hp_ratio >= _hp_lag:
		_hp_lag = hp_ratio
		_lag_wait = 0.0
	else:
		_lag_wait += delta
		if _lag_wait > 0.3:
			_hp_lag = maxf(hp_ratio, _hp_lag - delta * 0.7)
	if _dead_req and not dead:
		_dead_wait -= delta
		if _dead_wait <= 0.0:
			dead = true
			_death_t = 0.0
	if dead:
		# Death: flash, topple backwards and squash, then fade out.
		_death_t = minf(1.0, _death_t + delta * 1.8)
		_fade = clampf(1.0 - (_death_t - 0.55) * 2.2, 0.0, 1.0)
	queue_redraw()


## Offset toward the target (px), stretch and squash at time t of the attack.
func _attack_pose(t: float) -> Vector3:
	var back := (2.6 if _atk_melee else 1.6) * px_scale
	if t < WIND:
		var k := _ease_out(t / WIND)
		return Vector3(-back * k, 1.0 - 0.07 * k, 1.0 + 0.09 * k)
	t -= WIND
	if t < STRIKE:
		var k := _ease_out(t / STRIKE, 3.0)
		return Vector3(lerpf(-back, _atk_reach, k), 1.0 + 0.2 * k, 1.0 - 0.1 * k)
	t -= STRIKE
	if t < HOLD:
		return Vector3(_atk_reach + sin(t * 110.0) * 0.45 * px_scale, 1.12, 0.94)
	t -= HOLD
	var r := clampf(t / RECOVER, 0.0, 1.0)
	var e := r * r * (3.0 - 2.0 * r)
	return Vector3(lerpf(_atk_reach, 0.0, e), lerpf(1.12, 1.0, e), lerpf(0.94, 1.0, e))


func _frame_index() -> int:
	var n := textures.size()
	if n <= 1:
		return 0
	if _fx_anim:
		return int(_anim_t * 8.0 + _bob_phase) % n
	if stand_pose:
		if walking:
			return int(_anim_t * 6.5 + _bob_phase) % n
		# The wide stride frame doubles as the strike pose.
		if _atk >= WIND * 0.6 and _atk < WIND + STRIKE + HOLD:
			return mini(3, n - 1)
		return 0
	return int(_anim_t * (6.0 if walking else 5.0) + _bob_phase) % n


func _draw_body(tex: Texture2D, sz: Vector2, off: Vector2, rot: float, sc: Vector2, mod: Color) -> void:
	draw_set_transform(off, rot, sc)
	var rect := Rect2(Vector2(-sz.x * 0.5, -sz.y), sz)
	if face_left:
		# A negative width mirrors the sprite in place (the rect spans position..position+|size|).
		rect.size.x = -rect.size.x
	draw_texture_rect(tex, rect, false, mod)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	if textures.is_empty() or _fade <= 0.0:
		return
	var tex: Texture2D = textures[_frame_index()]
	var sz := Vector2(tex.get_width(), tex.get_height()) * px_scale * _norm
	var bob := 0.0 if walking else sin(_anim_t * 2.6 + _bob_phase) * 0.45 * px_scale
	var dir := -1.0 if face_left else 1.0
	var atk := _attack_pose(_atk) if _atk >= 0.0 else Vector3(0.0, 1.0, 1.0)
	# Origin is the feet (bottom-center) so sprites stand on the steps.
	# Body language on top of the sprite: breathing, walk hop, the attack
	# timeline, cast hop, hit shove and the death topple.
	var off := Vector2(dir * (atk.x - _kb * 3.5 * px_scale - sin(_dodge * PI) * 5.0 * px_scale), bob - sin(_dodge * PI) * 2.0 * px_scale)
	var rot := 0.0
	var sc := Vector2.ONE
	var phase := _anim_t * 9.0 + _bob_phase
	if dead:
		rot = -dir * _death_t * 1.35
		sc.y = 1.0 - 0.35 * _death_t
		off.x -= dir * _death_t * 3.0 * px_scale
	else:
		if walking:
			off.y -= absf(sin(phase)) * 1.4 * px_scale
			rot = 0.05 * sin(phase) * dir
		else:
			var br := sin(_anim_t * 2.4 + _bob_phase)
			sc.y = 1.0 + 0.03 * br
			sc.x = 1.0 - 0.015 * br
		sc.x *= atk.y * (1.0 - 0.10 * minf(_kb, 1.5))
		sc.y *= atk.z * (1.0 + 0.06 * minf(_kb, 1.5))
		var cs := sin(_cast * PI)
		off.y -= cs * 3.0 * px_scale
		sc *= 1.0 + 0.10 * cs
		# A hard shove tips the unit back for a moment.
		rot = -dir * 0.06 * minf(_kb, 2.0)
	off = off.round()
	var mod := _tint
	mod.a = _fade
	if _cast > 0.0:
		mod = mod.lerp(Color(_cast_col.r * 1.6, _cast_col.g * 1.6, _cast_col.b * 1.6, _fade), sin(_cast * PI) * 0.55)
	if dead and _death_t < 0.4:
		mod = mod.lerp(Color(3, 3, 3, _fade), (0.4 - _death_t) / 0.4 * 0.7)
	if _flash > 0.0:
		mod = mod.lerp(Color(3, 3, 3, _fade), _flash * 0.62)
	# Afterimages while dashing in.
	if _atk >= WIND and _atk < WIND + STRIKE + HOLD:
		for i in range(3, 0, -1):
			var gt := _atk - i * 0.014
			if gt < WIND * 0.6:
				continue
			var g := _attack_pose(gt)
			var gm := Color(0.85, 0.92, 1.0, 0.22 * (4 - i) / 3.0 * _fade)
			var goff := Vector2(dir * g.x, off.y).round()
			_draw_body(tex, sz, goff, rot, Vector2(sc.x * g.y / maxf(atk.y, 0.01), sc.y), gm)
	_draw_body(tex, sz, off, rot, sc, mod)
	if show_hp_bar and not dead and mp_ratio >= 0.0 and (hp_ratio < 0.999 or mp_ratio < 0.999):
		var mw := absf(sz.x) * 0.8
		var mh := maxf(1.0, px_scale * 0.75)
		var mp := Vector2(-mw * 0.5, -sz.y - maxf(1.0, px_scale)) + off
		draw_rect(Rect2(mp, Vector2(mw, mh)), Color(0, 0, 0, 0.7 * _fade))
		draw_rect(Rect2(mp, Vector2(mw * mp_ratio, mh)), Color(0.35, 0.6, 1.0, _fade))
	if show_hp_bar and not dead and (hp_ratio < 0.999 or _hp_lag > hp_ratio + 0.004 or (mp_ratio >= 0.0 and mp_ratio < 0.999)):
		var bw := absf(sz.x) * 0.8
		var bh := maxf(1.0, px_scale)
		var bp := Vector2(-bw * 0.5, -sz.y - bh * 2.0) + off
		draw_rect(Rect2(bp, Vector2(bw, bh)), Color(0, 0, 0, 0.7 * _fade))
		if _hp_lag > hp_ratio:
			draw_rect(Rect2(bp, Vector2(bw * _hp_lag, bh)), Color(1.0, 0.92, 0.7, 0.9 * _fade))
		var col := Color("#5fd35f") if hp_ratio > 0.5 else (Color("#ffd23f") if hp_ratio > 0.25 else Color("#ff4f4f"))
		col.a = _fade
		draw_rect(Rect2(bp, Vector2(bw * hp_ratio, bh)), col)
