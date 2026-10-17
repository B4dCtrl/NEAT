extends SceneTree
## Draws the app icon (helical tower + the Stairborn on its steps) at the sizes
## Windows wants and writes them as PNGs; tools/installer/make_ico.py packs them
## into icon.ico. The 256 px one is also the in-game window icon (icon.png).
##   godot --headless --path . -s res://tools/make_icon.gd -- <out_dir>

const SIZES := [16, 24, 32, 48, 64, 128, 256]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if not args.is_empty() else "res://tools/installer/icon"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var big := _draw(256)
	for s in SIZES:
		var img: Image = big.duplicate()
		if s != 256:
			img.resize(s, s, Image.INTERPOLATE_LANCZOS if s >= 48 else Image.INTERPOLATE_BILINEAR)
		img.save_png(out_dir.path_join("icon_%d.png" % s))
	big.save_png("res://icon.png")
	_save_bmp(_welcome(), out_dir.path_join("../welcome.bmp"))
	print("icon written to ", out_dir)
	quit()


## 256 x 256, drawn on a 64 x 64 pixel grid so it stays crisp pixel art.
func _draw(size: int) -> Image:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var top := Color("#1d1a2b")
	var bottom := Color("#5a4a7a")
	# Rounded dark square with a sunset gradient.
	for y in n:
		for x in n:
			if _inside_round(x, y, n, 10):
				img.set_pixel(x, y, top.lerp(bottom, float(y) / n))
	# Moon.
	_disc(img, Vector2(14, 13), 6.0, Color("#fff4d6"))
	# Tower body with a shaded side.
	for y in range(4, 58):
		for x in range(30, 46):
			if _inside_round(x, y, n, 10):
				var c := Color("#efe9d8") if x < 39 else (Color("#b9b2a0") if x < 43 else Color("#6f6a5e"))
				img.set_pixel(x, y, c)
	# Helical stair: on the front face each turn climbs left to right in
	# chunky gold steps, then disappears behind the tower.
	for turn in 3:
		var base_y := 54 - turn * 17
		for i in 8:
			var x := 18 + i * 4
			var y := base_y - i * 2
			for dx in 5:
				_put(img, x + dx, y, Color("#ffe08a"), n)
				_put(img, x + dx, y + 1, Color("#f2c14e"), n)
				_put(img, x + dx, y + 2, Color("#c9953a"), n)
				_put(img, x + dx, y + 3, Color("#5a3a20"), n)
	# The Stairborn, in front of the tower.
	var hero_tex := load("res://assets/sprites/stairborn.png") as Texture2D
	if hero_tex != null:
		var strip := hero_tex.get_image()
		strip.convert(Image.FORMAT_RGBA8)
		var fh := strip.get_height()
		var frame := strip.get_region(Rect2i(0, 0, fh, fh))
		frame.resize(42, 42, Image.INTERPOLATE_NEAREST)
		img.blend_rect(frame, Rect2i(0, 0, 42, 42), Vector2i(-2, 19))
	# Dark outline around the rounded square.
	for y in n:
		for x in n:
			if _inside_round(x, y, n, 10) and not _inside_round(x, y, n, 10, 1):
				img.set_pixel(x, y, Color("#0c0b10"))
	img.resize(size, size, Image.INTERPOLATE_NEAREST)
	return img


func _put(img: Image, x: int, y: int, c: Color, n: int) -> void:
	if x >= 0 and y >= 0 and x < n and y < n and _inside_round(x, y, n, 10, 1):
		img.set_pixel(x, y, c)


func _disc(img: Image, c: Vector2, r: float, col: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			if Vector2(x, y).distance_to(c) <= r:
				img.set_pixel(x, y, col)


## Inside a rounded square of side n with corner radius r, shrunk by `inset`.
func _inside_round(x: int, y: int, n: int, r: int, inset: int = 0) -> bool:
	var lo := inset
	var hi := n - 1 - inset
	if x < lo or y < lo or x > hi or y > hi:
		return false
	var rr := r - inset
	var cx := clampi(x, lo + rr, hi - rr)
	var cy := clampi(y, lo + rr, hi - rr)
	return Vector2(x, y).distance_to(Vector2(cx, cy)) <= rr + 0.5


## Installer side picture (164 x 314): the tower climbing out of frame at night.
func _welcome() -> Image:
	var w := 41
	var h := 79
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			img.set_pixel(x, y, Color("#0e0c18").lerp(Color("#4a3a6a"), float(y) / h))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 30:
		img.set_pixel(rng.randi_range(0, w - 1), rng.randi_range(0, h / 2), Color(1, 1, 1, rng.randf_range(0.3, 0.9)))
	_disc(img, Vector2(9, 12), 4.0, Color("#fff4d6"))
	for y in h:
		for x in range(17, 29):
			img.set_pixel(x, y, Color("#efe9d8") if x < 23 else (Color("#b9b2a0") if x < 26 else Color("#6f6a5e")))
	for turn in 6:
		var base_y := 74 - turn * 14
		for i in 7:
			var x := 11 + i * 3
			var y := base_y - i * 2
			for dx in 4:
				for dy in 3:
					var c: Color = [Color("#ffe08a"), Color("#f2c14e"), Color("#5a3a20")][dy]
					if x + dx < w and y + dy >= 0 and y + dy < h:
						img.set_pixel(x + dx, y + dy, c)
	for x in w:
		for y in range(h - 3, h):
			img.set_pixel(x, y, Color("#0c0b10"))
	var hero_tex := load("res://assets/sprites/stairborn.png") as Texture2D
	if hero_tex != null:
		var strip := hero_tex.get_image()
		strip.convert(Image.FORMAT_RGBA8)
		var fh := strip.get_height()
		var frame := strip.get_region(Rect2i(0, 0, fh, fh))
		frame.resize(22, 22, Image.INTERPOLATE_NEAREST)
		img.blend_rect(frame, Rect2i(0, 0, 22, 22), Vector2i(0, h - 24))
	img.resize(w * 4, h * 4, Image.INTERPOLATE_NEAREST)
	return img.get_region(Rect2i(0, 0, 164, 314))


## Uncompressed 24-bit BMP (what NSIS wants for installer pictures).
func _save_bmp(img: Image, path: String) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var row := (w * 3 + 3) & ~3
	var data := PackedByteArray()
	data.resize(54 + row * h)
	data.fill(0)
	data[0] = 0x42
	data[1] = 0x4D
	data.encode_u32(2, data.size())
	data.encode_u32(10, 54)
	data.encode_u32(14, 40)
	data.encode_s32(18, w)
	data.encode_s32(22, h)
	data.encode_u16(26, 1)
	data.encode_u16(28, 24)
	data.encode_u32(34, row * h)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, h - 1 - y)
			var o := 54 + y * row + x * 3
			data[o] = c.b8
			data[o + 1] = c.g8
			data[o + 2] = c.r8
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(data)
