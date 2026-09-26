extends Node2D
## Shared visual for heroes and enemies. Purely cosmetic: it mirrors combat
## state pushed by the stage and never influences the simulation.

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
var _anim_t := 0.0
var _lunge := 0.0
var _dodge := 0.0
var _flash := 0.0
var _fade := 1.0
var _bob_phase := 0.0
var _tint := Color.WHITE


## Built-in text sprites are 12 art pixels tall and drawn at px_scale. Imported
## PNG art (PixelLab) is higher resolution, so it is drawn at px_scale / 2: native
## size in the taskbar (px 2), 1.5x in the expedition view (px 3).
const EXTERNAL_MIN_HEIGHT := 17

var _norm := 1.0


func configure(sprite_id: String, palette: Dictionary = {}, scale_px: float = 2.0, left: bool = false, mono: bool = false, unit_id: String = "", hue: float = -1.0) -> void:
	textures = PixelArt.unit_frames(unit_id, sprite_id, palette, mono, hue)
	_norm = 0.5 if not textures.is_empty() and textures[0].get_height() >= EXTERNAL_MIN_HEIGHT else 1.0
	px_scale = scale_px
	face_left = left
	dead = false
	_fade = 1.0
	hp_ratio = 1.0
	_bob_phase = randf() * TAU
	queue_redraw()


func size_px() -> Vector2:
	if textures.is_empty():
		return Vector2.ZERO
	return Vector2(textures[0].get_width(), textures[0].get_height()) * px_scale * _norm


func lunge() -> void:
	_lunge = 1.0


## Quick hop backwards when an attack misses.
func dodge() -> void:
	_dodge = 1.0


func hurt() -> void:
	_flash = 1.0


func set_dead(value: bool) -> void:
	dead = value
	if not value:
		_fade = 1.0


func set_tint(c: Color) -> void:
	_tint = c
	queue_redraw()


func _process(delta: float) -> void:
	_anim_t += delta
	_lunge = maxf(0.0, _lunge - delta * 5.0)
	_dodge = maxf(0.0, _dodge - delta * 4.0)
	_flash = maxf(0.0, _flash - delta * 6.0)
	if dead:
		_fade = maxf(0.0, _fade - delta * 2.5)
	queue_redraw()


func _draw() -> void:
	if textures.is_empty() or _fade <= 0.0:
		return
	var frame_idx := 0
	if textures.size() > 1:
		var speed := 6.0 if walking else 2.0
		frame_idx = int(_anim_t * speed + _bob_phase) % textures.size()
	var tex: Texture2D = textures[frame_idx]
	var sz := Vector2(tex.get_width(), tex.get_height()) * px_scale * _norm
	var bob: float = 0.0 if walking else round(sin(_anim_t * 3.0 + _bob_phase)) * 0.5 * px_scale
	var dir := -1.0 if face_left else 1.0
	var offset := Vector2(dir * (sin(_lunge * PI) * 4.0 - sin(_dodge * PI) * 5.0) * px_scale, bob - sin(_dodge * PI) * 2.0 * px_scale)
	# Origin is the feet (bottom-center) so sprites stand on the steps.
	var rect := Rect2(Vector2(-sz.x * 0.5, -sz.y) + offset, sz)
	if face_left:
		rect.position.x += rect.size.x
		rect.size.x = -rect.size.x
	var mod := _tint
	mod.a = _fade
	if _flash > 0.0:
		mod = mod.lerp(Color(3, 3, 3, _fade), _flash * 0.6)
	draw_texture_rect(tex, rect, false, mod)
	if show_hp_bar and not dead and mp_ratio >= 0.0 and (hp_ratio < 0.999 or mp_ratio < 0.999):
		var mw := absf(sz.x) * 0.8
		var mh := maxf(1.0, px_scale * 0.75)
		var mp := Vector2(-mw * 0.5, -sz.y - maxf(1.0, px_scale)) + offset
		draw_rect(Rect2(mp, Vector2(mw, mh)), Color(0, 0, 0, 0.7 * _fade))
		draw_rect(Rect2(mp, Vector2(mw * mp_ratio, mh)), Color(0.35, 0.6, 1.0, _fade))
	if show_hp_bar and not dead and (hp_ratio < 0.999 or (mp_ratio >= 0.0 and mp_ratio < 0.999)):
		var bw := absf(sz.x) * 0.8
		var bh := maxf(1.0, px_scale)
		var bp := Vector2(-bw * 0.5, -sz.y - bh * 2.0) + offset
		draw_rect(Rect2(bp, Vector2(bw, bh)), Color(0, 0, 0, 0.7 * _fade))
		var col := Color("#5fd35f") if hp_ratio > 0.5 else (Color("#ffd23f") if hp_ratio > 0.25 else Color("#ff4f4f"))
		col.a = _fade
		draw_rect(Rect2(bp, Vector2(bw * hp_ratio, bh)), col)
