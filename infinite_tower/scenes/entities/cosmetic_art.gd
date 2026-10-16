extends RefCounted
## Pictures for cosmetics: collection icons (tower swatch, pet portrait, aura
## orb) and the aura drawn under each hero on the stairs.

const Cosmetics = preload("res://core/cosmetics.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")

static var _icons := {}


static func icon(id: String) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var d := Cosmetics.def(id)
	var tex: Texture2D = null
	match String(d.get("kind", "")):
		"tower":
			tex = _tower_icon(d["colors"])
		"pet":
			var f := PixelArt.unit_frames(String(d["art"]), String(d["sprite"]), {}, false, float(d.get("hue", -1.0)), d.get("fx", []))
			tex = f[0] if not f.is_empty() else null
		"aura":
			tex = _aura_icon(String(d["style"]), Color(d["color"]))
	_icons[id] = tex
	return tex


## A little helical tower in the skin's colours.
static func _tower_icon(c: Dictionary) -> Texture2D:
	var n := 28
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var sky := Color(c["sky"])
	var wall := Color(c["wall"])
	var dark := Color(c["wall_dark"])
	var step := Color(c["step"])
	var edge := Color(c["step_edge"])
	for y in n:
		for x in n:
			if Vector2(x - 13.5, y - 13.5).length() < 13.5:
				img.set_pixel(x, y, sky)
	for y in range(3, 26):
		for x in range(9, 19):
			var shade := wall if x < 15 else dark
			if (y + (x / 3)) % 5 == 0:
				shade = shade.darkened(0.2)
			img.set_pixel(x, y, shade)
	# helical steps winding round the tower
	for k in 5:
		var y0 := 5 + k * 5
		for x in range(4, 24):
			var y := y0 + int((x - 4) / 5)
			if y < 27 and (x < 9 or x > 18 or k % 2 == 0):
				img.set_pixel(x, y, step)
				if y - 1 >= 0:
					img.set_pixel(x, y - 1, edge)
	return ImageTexture.create_from_image(img)


static func _aura_icon(style: String, col: Color) -> Texture2D:
	var n := 28
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in n:
		for x in n:
			var d := Vector2(x - 13.5, y - 13.5).length()
			if d < 12.0:
				var c := col if style != "rainbow" else Color.from_hsv(fposmod((x + y) / 40.0, 1.0), 0.7, 1.0)
				c.a = clampf(1.0 - d / 12.0, 0.0, 1.0) * 0.9
				img.set_pixel(x, y, c)
	for i in 7:
		var a := i * TAU / 7.0
		var p := Vector2i(int(13.5 + cos(a) * 9.0), int(13.5 + sin(a) * 9.0))
		img.set_pixel(p.x, p.y, Color.WHITE)
	return ImageTexture.create_from_image(img)


## Draws an aura at a hero's feet. `t` is the stage time, `px` the art pixel size.
static func draw_aura(ci: CanvasItem, feet: Vector2, px: float, style: String, col: Color, t: float, seed_i: int) -> void:
	var glow := col
	glow.a = 0.22 + 0.08 * sin(t * 3.0 + seed_i)
	var w := 9.0 * px
	ci.draw_set_transform(feet, 0.0, Vector2(1.0, 0.35))
	ci.draw_circle(Vector2.ZERO, w, glow)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var s := px
	match style:
		"halo":
			var top := feet + Vector2(0, -26.0 * px)
			ci.draw_set_transform(top, 0.0, Vector2(1.0, 0.35))
			ci.draw_arc(Vector2.ZERO, 5.0 * px, 0, TAU, 20, col, maxf(1.0, px))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_particles(ci, feet, px, col, t, seed_i, 4, -1.0)
		"orbit":
			for i in 3:
				var a := t * 2.5 + i * TAU / 3.0 + seed_i
				var p := feet + Vector2(cos(a) * 8.0 * px, -10.0 * px + sin(a) * 3.0 * px)
				ci.draw_rect(Rect2(p, Vector2(s * 2, s * 2)), col)
		"storm":
			_particles(ci, feet, px, col, t, seed_i, 5, -1.0)
			if fmod(t * 1.7 + seed_i, 2.0) < 0.12:
				var x := (fmod(seed_i * 7.0 + t, 8.0) - 4.0) * px
				var y := -20.0 * px
				for k in 4:
					var nx := x + (k % 2 * 2 - 1) * 2.0 * px
					ci.draw_line(feet + Vector2(x, y), feet + Vector2(nx, y + 4.0 * px), Color.WHITE, maxf(1.0, px))
					x = nx
					y += 4.0 * px
		"rainbow":
			for i in 6:
				var c := Color.from_hsv(fposmod(t * 0.3 + i / 6.0, 1.0), 0.75, 1.0)
				var ph := fmod(t * 0.8 + i / 6.0, 1.0)
				ci.draw_rect(Rect2(feet + Vector2((i - 2.5) * 2.5 * px, -ph * 16.0 * px), Vector2(s, s)), c)
		"embers":
			_particles(ci, feet, px, col, t, seed_i, 6, -1.0)
		"snow", "leaves", "dust":
			_particles(ci, feet, px, col, t, seed_i, 5, 1.0 if style != "dust" else -0.4)
		"hearts":
			for i in 3:
				var ph := fmod(t * 0.5 + i / 3.0 + seed_i * 0.13, 1.0)
				var p := feet + Vector2((i - 1) * 6.0 * px, -ph * 22.0 * px)
				var c := col
				c.a = 1.0 - ph
				ci.draw_rect(Rect2(p, Vector2(s, s)), c)
				ci.draw_rect(Rect2(p + Vector2(s * 2, 0), Vector2(s, s)), c)
				ci.draw_rect(Rect2(p + Vector2(0, s), Vector2(s * 3, s)), c)
				ci.draw_rect(Rect2(p + Vector2(s, s * 2), Vector2(s, s)), c)
		_:
			_particles(ci, feet, px, col, t, seed_i, 5, -1.0)


## Pixels rising (dir < 0) or falling (dir > 0) around the hero.
static func _particles(ci: CanvasItem, feet: Vector2, px: float, col: Color, t: float, seed_i: int, n: int, dir: float) -> void:
	for i in n:
		var ph := fmod(t * 0.6 + i / float(n) + seed_i * 0.17, 1.0)
		var x := (fmod(i * 37.0 + seed_i * 11.0, 16.0) - 8.0) * px + sin(t * 2.0 + i) * px
		var y := (-ph * 22.0 * px) if dir < 0.0 else (-22.0 * px + ph * 22.0 * px)
		y *= absf(dir) if absf(dir) < 1.0 else 1.0
		var c := col
		c.a = 1.0 - ph * 0.8
		ci.draw_rect(Rect2(feet + Vector2(x, y), Vector2(px, px)), c)
