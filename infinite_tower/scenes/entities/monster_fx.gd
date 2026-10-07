extends RefCounted
## Visual effects layered on a monster drawing, so a colour variant is not just
## a recolour: a Frost Skeleton has an ice crown, icicles and snow, a Cinder
## Skeleton burns, a Moss Slime grows grass, a Void Hound has a violet rim, ...
## Effects are chosen with "fx": [...] in data/enemies.json. Placement uses a
## coordinate hash (stable across the animation frames); particles shimmer per frame.

const PAD_X := 3
const PAD_TOP := 4

const FX_IDS := ["frost", "ember", "lava", "slag", "moss", "thorn", "rot", "shard", "geode", "prism", "void", "shade", "abyss", "crown", "horns", "halo"]


## frames: Array of Texture2D. Returns new frames (padded) with the effects drawn.
static func apply(frames: Array, fx: Array, seed_key: String, mono: bool) -> Array:
	var out := []
	var seed_i: int = hash(seed_key)
	for fi in frames.size():
		var src: Image = frames[fi].get_image()
		src.convert(Image.FORMAT_RGBA8)
		var img := Image.create(src.get_width() + PAD_X * 2, src.get_height() + PAD_TOP, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		img.blit_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(PAD_X, PAD_TOP))
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_i + fi * 7919
		for id in fx:
			_apply_one(img, String(id), seed_i, rng)
		if mono:
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					if c.a > 0.1:
						var t := preload("res://scenes/entities/pixel_art.gd").mono_tone(c, c.v < 0.18)
						t.a = c.a
						img.set_pixel(x, y, t)
		out.append(ImageTexture.create_from_image(img))
	return out


# ------------------------------------------------------------------ helpers

static func _op(img: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and img.get_pixel(x, y).a > 0.3


static func _h(x: int, y: int, s: int) -> float:
	return float(absi(hash(Vector3i(x, y, s))) % 1000) / 1000.0


static func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


## Pixels of the body that count as the top / bottom / inside of the silhouette.
static func _scan(img: Image, kind: String) -> Array:
	var out := []
	for y in img.get_height():
		for x in img.get_width():
			if not _op(img, x, y):
				continue
			match kind:
				"top":
					if not _op(img, x, y - 1):
						out.append(Vector2i(x, y))
				"bottom":
					if not _op(img, x, y + 1):
						out.append(Vector2i(x, y))
				"side":
					if not _op(img, x - 1, y) or not _op(img, x + 1, y):
						out.append(Vector2i(x, y))
				"inner":
					if _op(img, x - 1, y) and _op(img, x + 1, y) and _op(img, x, y - 1) and _op(img, x, y + 1):
						out.append(Vector2i(x, y))
	return out


static func _tint(img: Image, to: Color, amount: float, only_dark: bool = false) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.3 and (not only_dark or c.v < 0.55):
				var t := c.lerp(to, amount)
				t.a = c.a
				img.set_pixel(x, y, t)


static func _particles(img: Image, rng: RandomNumberGenerator, cols: Array, n: int, rise: bool = false) -> void:
	var spots := []
	for y in img.get_height():
		for x in img.get_width():
			if not _op(img, x, y) and img.get_pixel(x, y).a < 0.05:
				for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, 2), Vector2i(-2, -2)]:
					if _op(img, x + d.x, y + d.y):
						spots.append(Vector2i(x, y))
						break
	for i in mini(n, spots.size()):
		var p: Vector2i = spots.pop_at(rng.randi() % spots.size())
		_put(img, p.x, p.y - (1 if rise else 0), Color(cols[rng.randi() % cols.size()]))


static func _rim(img: Image, col: Color) -> void:
	var edge := []
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a < 0.05:
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if _op(img, x + d.x, y + d.y):
						edge.append(Vector2i(x, y))
						break
	for p in edge:
		img.set_pixel(p.x, p.y, col)


# ------------------------------------------------------------------ effects

static func _apply_one(img: Image, id: String, s: int, rng: RandomNumberGenerator) -> void:
	match id:
		"frost":
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					if c.a > 0.3:
						var t := c.lerp(Color.WHITE, 0.45) if c.v > 0.72 else c.lerp(Color(0.7, 0.88, 1.0), 0.25)
						t.a = c.a
						img.set_pixel(x, y, t)
			for p in _scan(img, "top"):
				var h := _h(p.x, p.y, s)
				if h < 0.4:
					for k in 1 + int(h * 8.0) % 3:
						_put(img, p.x, p.y - 1 - k, Color("#e8fbff") if k % 2 == 0 else Color("#8fdcff"))
			for p in _scan(img, "bottom"):
				if _h(p.x, p.y, s + 1) < 0.14:
					_put(img, p.x, p.y + 1, Color("#8fdcff"))
					if _h(p.x, p.y, s + 2) < 0.5:
						_put(img, p.x, p.y + 2, Color("#e8fbff"))
			_particles(img, rng, ["#ffffff", "#bfefff", "#6fe0ff"], 6)
		"ember":
			_tint(img, Color(0.16, 0.09, 0.09), 0.38, true)
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					if c.a > 0.3 and c.s > 0.5 and c.v > 0.7:
						img.set_pixel(x, y, Color("#ffa030"))
			for p in _scan(img, "top"):
				if _h(p.x, p.y, s) < 0.34:
					var hh := 2 + int(_h(p.x, p.y, s + 5) * 3.0)
					for k in hh:
						_put(img, p.x, p.y - 1 - k, [Color("#ff5a1c"), Color("#ffa030"), Color("#ffe08a"), Color("#ffe08a")][mini(k, 3)])
			for p in _scan(img, "inner"):
				if _h(p.x, p.y, s + 3) < 0.07:
					_put(img, p.x, p.y, Color("#ff8a2a"))
			_particles(img, rng, ["#ffb347", "#ff6a1c", "#ffe08a"], 5, true)
		"lava", "slag":
			var slag := id == "slag"
			if slag:
				_tint(img, Color(0.28, 0.2, 0.18), 0.4)
			var dens := 0.08 if slag else 0.13
			for p in _scan(img, "inner"):
				if _h(p.x, p.y, s + 4) < dens:
					_put(img, p.x, p.y, Color("#ffd23f"))
					if _op(img, p.x + 1, p.y):
						_put(img, p.x + 1, p.y, Color("#ff7a1c"))
					if _op(img, p.x, p.y + 1):
						_put(img, p.x, p.y + 1, Color("#ff5a1c"))
			for p in _scan(img, "bottom"):
				if _h(p.x, p.y, s + 6) < 0.14:
					_put(img, p.x, p.y + 1, Color("#ff7a1c"))
			_particles(img, rng, ["#ffb347", "#ff6a1c"], 3, true)
		"moss":
			_tint(img, Color("#4f8c3e"), 0.18)
			for p in _scan(img, "top"):
				if _h(p.x, p.y, s) < 0.45:
					_put(img, p.x, p.y - 1, Color("#6bd45a"))
					if _h(p.x, p.y, s + 1) < 0.5:
						_put(img, p.x, p.y - 2, Color("#3a8a3a"))
			for p in _scan(img, "inner"):
				if _h(p.x, p.y, s + 2) < 0.13:
					_put(img, p.x, p.y, Color("#3a8a3a"))
					if _op(img, p.x + 1, p.y):
						_put(img, p.x + 1, p.y, Color("#6bd45a"))
			var tops := _scan(img, "top")
			if not tops.is_empty():
				var f: Vector2i = tops[tops.size() / 2]
				_put(img, f.x, f.y - 3, Color("#f06ab0"))
				_put(img, f.x, f.y - 2, Color("#3a8a3a"))
			_particles(img, rng, ["#9be36b", "#e8f56a"], 3)
		"thorn":
			_tint(img, Color("#5a8a3a"), 0.12)
			for p in _scan(img, "top") + _scan(img, "side"):
				if _h(p.x, p.y, s) < 0.26:
					var dir := Vector2i(0, -1) if not _op(img, p.x, p.y - 1) else (Vector2i(-1, 0) if not _op(img, p.x - 1, p.y) else Vector2i(1, 0))
					_put(img, p.x + dir.x, p.y + dir.y, Color("#c9d98a"))
					_put(img, p.x + dir.x * 2, p.y + dir.y * 2, Color("#e0463a"))
			_particles(img, rng, ["#9be36b", "#e0463a"], 3)
		"rot":
			_tint(img, Color("#7a8a3a"), 0.32)
			for p in _scan(img, "inner"):
				if _h(p.x, p.y, s) < 0.16:
					_put(img, p.x, p.y, Color("#3a4a1a"))
			for p in _scan(img, "bottom"):
				if _h(p.x, p.y, s + 3) < 0.15:
					_put(img, p.x, p.y + 1, Color("#9acd32"))
					if _h(p.x, p.y, s + 4) < 0.5:
						_put(img, p.x, p.y + 2, Color("#9acd32"))
			_particles(img, rng, ["#2a2a1a", "#9acd32"], 4)
		"shard", "geode":
			var geode := id == "geode"
			var a := Color("#ff8ae8") if geode else Color("#8fe8ff")
			var b := Color("#fff0ff") if geode else Color("#ffffff")
			for p in _scan(img, "top"):
				if _h(p.x, p.y, s) < 0.3:
					var hh := 2 + int(_h(p.x, p.y, s + 5) * 3.0)
					for k in hh:
						_put(img, p.x, p.y - 1 - k, b if k == hh - 1 else a)
			for p in _scan(img, "side"):
				if _h(p.x, p.y, s + 7) < 0.2:
					var dx := -1 if not _op(img, p.x - 1, p.y) else 1
					_put(img, p.x + dx, p.y, a)
					_put(img, p.x + dx * 2, p.y - 1, b)
			if geode:
				for p in _scan(img, "inner"):
					if _h(p.x, p.y, s + 8) < 0.12:
						_put(img, p.x, p.y, a)
			_particles(img, rng, ["#ffffff", a.to_html()], 4)
		"prism":
			var w := float(img.get_width())
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					if c.a > 0.3 and c.v > 0.2:
						var t := Color.from_hsv(fposmod((x + y * 0.6) / w, 1.0), clampf(maxf(c.s, 0.55), 0.0, 1.0), minf(1.0, c.v * 1.05 + 0.08), c.a)
						img.set_pixel(x, y, t)
			_particles(img, rng, ["#ffffff", "#ffe0ff", "#e0ffff"], 6)
		"void":
			_tint(img, Color(0.1, 0.05, 0.2), 0.4)
			_rim(img, Color(0.75, 0.25, 1.0, 0.55))
			_particles(img, rng, ["#ffffff", "#ff3df0", "#b04dff"], 4)
		"shade":
			_tint(img, Color(0.1, 0.07, 0.16), 0.38)
			var snap: Image = img.duplicate()
			for y in img.get_height():
				for x in img.get_width():
					if snap.get_pixel(x, y).a > 0.3:
						if x - 3 >= 0 and snap.get_pixel(x - 3, y).a < 0.05:
							img.set_pixel(x - 3, y, Color(0.4, 0.2, 0.6, 0.35))
						if x - 5 >= 0 and snap.get_pixel(x - 5, y).a < 0.05 and img.get_pixel(x - 5, y).a < 0.05:
							img.set_pixel(x - 5, y, Color(0.4, 0.2, 0.6, 0.18))
			_particles(img, rng, ["#6a3a9c", "#2a1a40"], 4)
		"abyss":
			_tint(img, Color(0.08, 0.04, 0.2), 0.4)
			_rim(img, Color(0.35, 0.2, 0.9, 0.5))
			_particles(img, rng, ["#9a8aff", "#cfc8ff"], 5, true)
		"crown":
			var tops := _scan(img, "top")
			if not tops.is_empty():
				var minx := 999
				var maxx := 0
				var topy := 999
				for p in tops:
					topy = mini(topy, p.y)
				for p in tops:
					if p.y <= topy + 1:
						minx = mini(minx, p.x)
						maxx = maxi(maxx, p.x)
				var cx := (minx + maxx) / 2
				for dx in range(-3, 4):
					_put(img, cx + dx, topy - 1, Color("#f2c14e"))
				for dx in [-3, -1, 1, 3]:
					_put(img, cx + dx, topy - 2, Color("#f2c14e"))
				for dx in [-3, 0, 3]:
					_put(img, cx + dx, topy - 3, Color("#ffe08a"))
				_put(img, cx, topy - 2, Color("#e0463a"))
		"horns":
			var tops := _scan(img, "top")
			if not tops.is_empty():
				var minx := 999
				var maxx := 0
				for p in tops:
					minx = mini(minx, p.x)
					maxx = maxi(maxx, p.x)
				for side in [0, 1]:
					var hx: int = minx + (maxx - minx) / 4 if side == 0 else maxx - (maxx - minx) / 4
					var hy := 999
					for p in tops:
						if absi(p.x - hx) <= 1:
							hy = mini(hy, p.y)
					if hy == 999:
						continue
					var dir := -1 if side == 0 else 1
					for k in 3:
						_put(img, hx, hy - 1 - k, Color("#e8e4d4"))
					_put(img, hx + dir, hy - 4, Color("#e8e4d4"))
					_put(img, hx + dir * 2, hy - 5, Color("#ff6a1c"))
		"halo":
			_rim(img, Color(1.0, 0.85, 0.3, 0.55))
			_particles(img, rng, ["#ffe08a", "#ffffff"], 4)
