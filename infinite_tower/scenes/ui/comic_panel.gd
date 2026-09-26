extends Control
## One comic panel: an animated scene drawn in code (1-bit ink & paper plus the
## colour hero art), a thick ink border and a caption box that types itself.

const DataDB = preload("res://core/data_db.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")

const INK := Color("#16151a")
const PAPER := Color("#efe9d8")
const MID := Color("#9c968a")
const CAPTION_BG := Color("#f6e7a8")

var scene_id := ""
var caption := ""
var reveal := 0.0          # 0 -> 1 when the panel appears
var typed := 0.0           # characters shown in the caption
var t := 0.0
var active := false
var caption_top := true
var _heroes := {}
var _dither: ImageTexture


func setup(id: String, text: String, top: bool) -> void:
	scene_id = id
	caption = text
	caption_top = top
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for cls in ["stairborn", "knight", "ranger", "arcanist"]:
		var f := PixelArt.unit_frames(cls, DataDB.classes()[cls]["sprite"], {}, false)
		_heroes[cls] = f
	_dither = _make_dither()


func caption_done() -> bool:
	return typed >= caption.length()


func finish_caption() -> void:
	typed = caption.length()


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	reveal = minf(1.0, reveal + delta * 2.5)
	if reveal >= 1.0:
		typed = minf(caption.length(), typed + delta * 38.0)
	queue_redraw()


func _draw() -> void:
	if reveal <= 0.0 or size.x < 40.0 or size.y < 40.0:
		return
	var r := Rect2(Vector2.ZERO, size)
	# Pop-in: the panel grows from 94% while fading in.
	var k := ease(reveal, 0.4)
	var grow := size * (1.0 - (0.94 + 0.06 * k)) * 0.5
	draw_set_transform(grow, 0.0, Vector2.ONE * (0.94 + 0.06 * k))
	draw_rect(r, PAPER)
	match scene_id:
		"tower": _scene_tower()
		"heroes": _scene_heroes()
		"lost": _scene_lost()
		"withering": _scene_withering()
		"birth": _scene_birth()
		"first_step": _scene_first_step()
	_draw_caption()
	draw_rect(r, INK, false, 6.0)
	draw_set_transform(Vector2.ZERO)
	if reveal < 1.0:
		draw_rect(r, Color(PAPER.r, PAPER.g, PAPER.b, 1.0 - k))


# ------------------------------------------------------------------ helpers

func _make_dither() -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for p in [Vector2i(0, 0), Vector2i(2, 2)]:
		img.set_pixel(p.x, p.y, INK)
	return ImageTexture.create_from_image(img)


func _dither_rect(r: Rect2, alpha: float = 1.0) -> void:
	draw_texture_rect(_dither, r, true, Color(1, 1, 1, alpha))


func _sky(top: Color, bottom: Color) -> void:
	var bands := 24
	for i in bands:
		var y := size.y * i / bands
		draw_rect(Rect2(0, y, size.x, size.y / bands + 1), top.lerp(bottom, float(i) / bands))


func _stars(n: int, max_y: float) -> void:
	for i in n:
		var x := fposmod(i * 97.31, size.x)
		var y := fposmod(i * 53.17, max_y)
		var a := 0.4 + 0.4 * sin(t * 2.0 + i)
		draw_rect(Rect2(x, y, 2, 2), Color(PAPER.r, PAPER.g, PAPER.b, a))


## An endless dithered tower wrapped by a continuous spiral staircase.
func _tower(cx: float, w: float, top_y: float, bottom_y: float, spin: float = 0.0) -> void:
	var half := w * 0.5
	var h := bottom_y - top_y
	var pad := w * 0.16
	var turn_h := maxf(w * 0.7, 12.0)
	var phase := fposmod(t * 0.08 + spin, 1.0)
	# Back half of the spiral first (peeks out at the edges).
	_spiral(cx, half + pad, top_y, bottom_y, turn_h, phase, false)
	# Cylinder: paper, dithered shade, ink core on the dark side, brick courses.
	draw_rect(Rect2(cx - half, top_y, w, h), PAPER)
	_dither_rect(Rect2(cx + half * 0.15, top_y, half * 0.85, h))
	draw_rect(Rect2(cx + half * 0.62, top_y, half * 0.38, h), INK)
	var by := bottom_y
	var row := 0
	while by > top_y:
		draw_line(Vector2(cx - half, by), Vector2(cx + half * 0.62, by), Color(INK.r, INK.g, INK.b, 0.35), 1.0)
		for j in 6:
			var a := ((j + (0.5 if row % 2 == 0 else 0.0)) / 6.0 + phase) * PI
			var x := cx - cos(a) * half
			if x < cx + half * 0.6:
				draw_line(Vector2(x, by), Vector2(x, by - w * 0.08), Color(INK.r, INK.g, INK.b, 0.3), 1.0)
		by -= w * 0.08
		row += 1
	draw_rect(Rect2(cx - half, top_y, w, h), INK, false, 3.0)
	# Front half of the spiral.
	_spiral(cx, half + pad, top_y, bottom_y, turn_h, phase, true)
	# The top vanishes into clouds: nobody has ever seen it.
	for i in 7:
		var c := PAPER
		c.a = 0.95 - i * 0.12
		draw_circle(Vector2(cx - w * 0.7 + i * w * 0.24, top_y + 10.0 + (i % 2) * 8.0), w * 0.42, c)


## One band of stairs spiralling up the tower (front or back half only).
func _spiral(cx: float, radius: float, top_y: float, bottom_y: float, turn_h: float, phase: float, front: bool) -> void:
	var y0 := bottom_y + turn_h
	var turns := int((bottom_y - top_y) / turn_h) + 3
	for k in turns:
		var pts := PackedVector2Array()
		var ticks := []
		for s in 25:
			var u := s / 24.0
			var a := (u * 0.5 + (0.0 if front else 0.5)) * TAU + phase * TAU
			var x := cx - cos(a) * radius
			var y := y0 - (k + u * 0.5 + (0.0 if front else 0.5)) * turn_h
			if y < top_y - 10.0 or y > bottom_y + 10.0:
				continue
			pts.append(Vector2(x, y))
			if s % 2 == 0:
				ticks.append(Vector2(x, y))
		if pts.size() < 2:
			continue
		var band := 9.0 if front else 6.0
		draw_polyline(pts, INK, band + 4.0)
		draw_polyline(pts, PAPER if front else MID, band)
		if front:
			for p in ticks:
				draw_line(p + Vector2(0, -band * 0.5), p + Vector2(0, band * 0.5), INK, 1.5)


func _hills(y: float, color: Color) -> void:
	var pts := PackedVector2Array([Vector2(0, size.y)])
	for i in 13:
		var x := size.x * i / 12.0
		pts.append(Vector2(x, y - sin(i * 1.3) * 14.0 - cos(i * 0.7) * 8.0))
	pts.append(Vector2(size.x, size.y))
	draw_colored_polygon(pts, color)


func _house(x: float, ground: float, w: float, lit: bool) -> void:
	var h := w * 0.7
	draw_rect(Rect2(x, ground - h, w, h), INK)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 4, ground - h), Vector2(x + w + 4, ground - h), Vector2(x + w * 0.5, ground - h - w * 0.5)]), INK)
	if lit:
		var glow := Color("#ffcf6b")
		glow.a = 0.75 + 0.25 * sin(t * 3.0 + x)
		draw_rect(Rect2(x + w * 0.35, ground - h * 0.6, w * 0.3, h * 0.3), glow)


func _hero(cls: String, feet: Vector2, height: float, silhouette: bool = false, alpha: float = 1.0, walking: bool = false) -> void:
	var frames: Array = _heroes.get(cls, [])
	if frames.is_empty():
		return
	var tex: Texture2D = frames[int(t * 6.0) % frames.size()] if walking else frames[0]
	var s := height / tex.get_height()
	var sz := Vector2(tex.get_width(), tex.get_height()) * s
	var mod := Color(0.08, 0.08, 0.1, alpha) if silhouette else Color(1, 1, 1, alpha)
	draw_texture_rect(tex, Rect2(feet - Vector2(sz.x * 0.5, sz.y), sz), false, mod)


func _fire(base: Vector2, scale: float) -> void:
	var glow := Color(1.0, 0.6, 0.2, 0.18 + 0.06 * sin(t * 6.0))
	draw_circle(base + Vector2(0, -10 * scale), 60.0 * scale, glow)
	draw_rect(Rect2(base + Vector2(-14, -4) * scale, Vector2(28, 6) * scale), Color("#5a3a22"))
	var cols := [Color("#ff6a1a"), Color("#ffb13d"), Color("#fff1a8")]
	for layer in 3:
		var h := (26.0 - layer * 7.0 + sin(t * 9.0 + layer) * 4.0) * scale
		var w := (22.0 - layer * 6.0) * scale
		draw_colored_polygon(PackedVector2Array([base + Vector2(-w * 0.5, -4 * scale), base + Vector2(w * 0.5, -4 * scale),
			base + Vector2(sin(t * 7.0 + layer) * 3.0 * scale, -4 * scale - h)]), cols[layer])


# ------------------------------------------------------------------ scenes

func _scene_tower() -> void:
	_sky(Color("#15131f"), Color("#3a3552"))
	_stars(60, size.y * 0.7)
	var cx := size.x * 0.62
	_tower(cx, size.y * 0.24, -10.0, size.y * 0.86)
	_hills(size.y * 0.8, Color("#23202e"))
	var ground := size.y * 0.9
	for i in 5:
		_house(size.x * 0.08 + i * 46.0, ground - (i % 2) * 6.0, 30.0, i % 2 == 0)
	draw_rect(Rect2(0, ground, size.x, size.y - ground), INK)


func _scene_heroes() -> void:
	_sky(Color("#2b2740"), Color("#8a7f9a"))
	var cx := size.x * 0.82
	_tower(cx, size.y * 0.35, -10.0, size.y * 0.9)
	var ground := size.y * 0.9
	draw_rect(Rect2(0, ground, size.x, size.y - ground), INK)
	# A procession of past heroes marching toward the door.
	var classes := ["knight", "ranger", "arcanist", "knight", "ranger"]
	for i in classes.size():
		var x := fposmod(t * 30.0 + i * size.x * 0.17, size.x * 0.75)
		_hero(classes[i], Vector2(x, ground), size.y * 0.3, true, 0.9, true)
	draw_rect(Rect2(cx - 14, ground - 44, 28, 44), INK)


func _scene_lost() -> void:
	_sky(Color("#3a3552"), Color("#c9c2b0"))
	var ground := size.y * 0.85
	# Empty steps, an abandoned helmet and sword, drifting fog.
	for i in 6:
		draw_rect(Rect2(size.x * 0.1 + i * size.x * 0.13, ground - i * 16.0, size.x * 0.14, 10), PAPER)
		draw_rect(Rect2(size.x * 0.1 + i * size.x * 0.13, ground - i * 16.0, size.x * 0.14, 10), INK, false, 2.0)
	var helm := PixelArt.frames("item_helm")
	if not helm.is_empty():
		draw_texture_rect(helm[0], Rect2(size.x * 0.28, ground - 64, 40, 40), false)
	var sword := PixelArt.frames("item_sword")
	if not sword.is_empty():
		draw_set_transform(Vector2(size.x * 0.52, ground - 70), 0.8, Vector2.ONE)
		draw_texture_rect(sword[0], Rect2(0, 0, 44, 44), false)
		draw_set_transform(Vector2.ZERO)
	for i in 5:
		var fog := PAPER
		fog.a = 0.25
		draw_circle(Vector2(fposmod(t * 20.0 + i * 90.0, size.x + 120) - 60, ground - 10 - i * 8.0), 60.0, fog)
	draw_rect(Rect2(0, ground, size.x, size.y - ground), INK)


func _scene_withering() -> void:
	_sky(Color("#5a1f1a"), Color("#d98a4a"))
	var ground := size.y * 0.78
	_hills(ground, Color("#3b2a22"))
	# Dead tree: trunk with bare, crooked branches.
	var base := Vector2(size.x * 0.3, ground + 4)
	var top := base + Vector2(0, -size.y * 0.4)
	draw_line(base, top, INK, 12.0)
	for b in [[0.45, -60.0, -40.0], [0.62, 55.0, -45.0], [0.8, -35.0, -30.0], [0.95, 30.0, -35.0]]:
		var p: Vector2 = base.lerp(top, b[0])
		var tip: Vector2 = p + Vector2(b[1], b[2])
		draw_line(p, tip, INK, 6.0)
		draw_line(tip, tip + Vector2(b[1] * 0.35, -18.0), INK, 3.0)
	# Cracked soil.
	for i in 8:
		var x := size.x * 0.05 + i * size.x * 0.12
		draw_line(Vector2(x, size.y * 0.88), Vector2(x + 20, size.y * 0.95), INK, 2.0)
	# The tower far away, still standing.
	_tower(size.x * 0.8, size.y * 0.12, -10.0, ground)


func _scene_birth() -> void:
	_sky(Color("#15131f"), Color("#2b2740"))
	_stars(40, size.y * 0.5)
	var ground := size.y * 0.86
	_tower(size.x * 0.75, size.y * 0.3, -10.0, ground)
	draw_rect(Rect2(0, ground, size.x, size.y - ground), INK)
	var fire := Vector2(size.x * 0.34, ground)
	_fire(fire, 1.3)
	_hero("stairborn", Vector2(size.x * 0.2, ground), size.y * 0.24)


func _scene_first_step() -> void:
	_sky(Color("#1d1a2b"), Color("#5a5378"))
	_stars(50, size.y * 0.6)
	var ground := size.y * 0.9
	_tower(size.x * 0.5, size.y * 0.42, -10.0, ground, 0.3)
	draw_rect(Rect2(0, ground, size.x, size.y - ground), INK)
	# The Stairborn on the first step, looking up.
	var step := Rect2(size.x * 0.5 + size.y * 0.21, ground - 22, 70, 22)
	draw_rect(step, PAPER)
	draw_rect(step, INK, false, 3.0)
	_hero("stairborn", Vector2(step.position.x + 26, step.position.y), size.y * 0.3, false, 1.0, sin(t) > 0.0)
	# Title.
	var font := get_theme_default_font()
	var fs := int(size.y * 0.12)
	var title := "STAIRBORN"
	var pos := Vector2(0, size.y * 0.2)
	draw_string_outline(font, pos, title, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, 10, INK)
	draw_string(font, pos, title, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color("#f2c14e"))


func _draw_caption() -> void:
	if caption == "" or reveal < 1.0:
		return
	var font := get_theme_default_font()
	var fs := 17
	var text := caption.substr(0, int(typed))
	var box_w := size.x - 28.0
	var lines := font.get_multiline_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, box_w - 20.0, fs)
	var box := Rect2(14, 14 if caption_top else size.y - lines.y - 34.0, box_w, lines.y + 18.0)
	draw_rect(box.grow(2), INK)
	draw_rect(box, CAPTION_BG)
	draw_multiline_string(font, box.position + Vector2(10, 8 + fs), text, HORIZONTAL_ALIGNMENT_LEFT, box_w - 20.0, fs, -1, INK)
