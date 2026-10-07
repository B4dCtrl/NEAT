extends RefCounted
## Builds nearest-filtered textures from the text grids in data/sprites.json.
## Palettes can be overridden per enemy, so one shape serves many monsters.
##
## Art override: a PNG at res://assets/sprites/<id>.png (e.g. generated with
## PixelLab) replaces the text sprite with the same id. A horizontal strip of
## square frames is split into animation frames. Enemy PNGs may also be named
## after the enemy id (assets/sprites/slime.png, assets/sprites/ashen_king.png).

const DataDB = preload("res://core/data_db.gd")
const MonsterFx = preload("res://scenes/entities/monster_fx.gd")

static var _cache: Dictionary = {}


## Returns the animation frames for a sprite id as ImageTextures.
## mono=true quantises the palette to 1-bit-style ink / mid / paper tones.
static func frames(sprite_id: String, palette_override: Dictionary = {}, mono: bool = false) -> Array:
	var key := sprite_id + str(palette_override) + ("#mono" if mono else "")
	if _cache.has(key):
		return _cache[key]
	# Imported (PixelLab) art keeps its colours even in 1-bit mode: the tower
	# stays ink-and-paper and the characters pop out of it.
	var external := _external_frames(sprite_id, false)
	if not external.is_empty():
		_cache[key] = external
		return external
	var def: Dictionary = DataDB.sprites().get(sprite_id, {})
	var out := []
	if def.is_empty():
		push_warning("PixelArt: unknown sprite %s" % sprite_id)
		_cache[key] = out
		return out
	var palette: Dictionary = def["palette"].duplicate()
	for k in palette_override:
		palette[k] = palette_override[k]
	var colors := {}
	for k in palette:
		colors[k] = Color.html(palette[k])
		if mono:
			colors[k] = mono_tone(colors[k], k == "o")
	for grid in def["frames"]:
		var h: int = grid.size()
		var w: int = String(grid[0]).length()
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in h:
			var row: String = grid[y]
			for x in w:
				var ch := row[x]
				if ch != "." and colors.has(ch):
					img.set_pixel(x, y, colors[ch])
		out.append(ImageTexture.create_from_image(img))
	_cache[key] = out
	return out


## Frames for a unit: its own PNG (by unit id) wins over the shared shape.
## hue >= 0 recolours the art (monster variants reuse one drawing).
static func unit_frames(unit_id: String, sprite_id: String, palette: Dictionary, mono: bool, hue: float = -1.0, fx: Array = []) -> Array:
	var base: Array
	if unit_id != "" and ResourceLoader.exists(ASSET_DIR + unit_id + ".png"):
		base = frames(unit_id, {}, mono)
	else:
		base = frames(sprite_id, palette, mono)
	if base.is_empty() or (hue < 0.0 and fx.is_empty()):
		return base
	var key := "%s|%s|hue%.3f|fx%s|%s" % [unit_id, sprite_id, hue, ",".join(fx), "m" if mono else "c"]
	if not _cache.has(key):
		var f: Array = _recolor(base, hue) if hue >= 0.0 else base
		if not fx.is_empty():
			f = MonsterFx.apply(f, fx, key, mono)
		_cache[key] = f
	return _cache[key]


## Rotates every coloured pixel to `hue`, keeping its shading (outlines and greys stay).
static func _recolor(base: Array, hue: float) -> Array:
	var out := []
	for tex in base:
		var img: Image = tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.05 and c.s > 0.18:
					img.set_pixel(x, y, Color.from_hsv(hue, clampf(c.s * 1.05, 0.0, 1.0), c.v, c.a))
		out.append(ImageTexture.create_from_image(img))
	return out


const ASSET_DIR := "res://assets/sprites/"


static func _external_frames(sprite_id: String, mono: bool) -> Array:
	var path := ASSET_DIR + sprite_id + ".png"
	if not ResourceLoader.exists(path):
		return []
	var tex: Texture2D = load(path)
	if tex == null:
		return []
	var img := tex.get_image()
	if img == null:
		return []
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var fh := img.get_height()
	var count := maxi(1, img.get_width() / fh)
	var out := []
	for i in count:
		var frame := img.get_region(Rect2i(i * fh, 0, fh, fh)) if count > 1 else img
		if mono:
			for y in frame.get_height():
				for x in frame.get_width():
					var c := frame.get_pixel(x, y)
					if c.a > 0.1:
						var t := mono_tone(c, c.v < 0.18)
						t.a = c.a
						frame.set_pixel(x, y, t)
		out.append(ImageTexture.create_from_image(frame))
	return out


static var _base_icons: Dictionary = {}


## Icon for an equipment item: the art of its base (every set piece has its own),
## wrapped in a rarity aura so a rare is not just a recoloured common.
static func item_icon(item: Dictionary, mono: bool = false) -> Texture2D:
	if _base_icons.is_empty():
		for base in DataDB.items()["bases"]:
			_base_icons[base["id"]] = base.get("icon", "item_" + String(base["slot"]))
	var id: String = _base_icons.get(item.get("base", ""), "item_" + String(item.get("slot", "chest")))
	var f := frames(id, {}, mono)
	if f.is_empty():
		return null
	var rarity: String = item.get("rarity", "common")
	if rarity == "common":
		return f[0]
	var key := "aura|%s|%s" % [id, rarity]
	if not _cache.has(key):
		_cache[key] = [_aura(f[0], rarity, id)]
	return _cache[key][0]


## Rarity look: uncommon a thin green rim; rare a blue glow; epic purple with
## glints; legendary a golden double halo; mythic a crimson halo with stars.
static func _aura(tex: Texture2D, rarity: String, seed_key: String) -> Texture2D:
	var src := tex.get_image()
	src.convert(Image.FORMAT_RGBA8)
	var pad := 3
	var w := src.get_width() + pad * 2
	var h := src.get_height() + pad * 2
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col: Color = Color(DataDB.items()["rarities"][rarity]["color"])
	var rings: int = {"uncommon": 1, "rare": 2, "epic": 2, "legendary": 3, "mythic": 3}.get(rarity, 1)
	var strength: float = {"uncommon": 0.4, "rare": 0.6, "epic": 0.75, "legendary": 0.9, "mythic": 1.0}.get(rarity, 0.5)
	for y in h:
		for x in w:
			var best := 99
			for r in range(1, rings + 1):
				for dy in range(-r, r + 1):
					for dx in range(-r, r + 1):
						var sx := x - pad + dx
						var sy := y - pad + dy
						if sx >= 0 and sy >= 0 and sx < src.get_width() and sy < src.get_height() and src.get_pixel(sx, sy).a > 0.3:
							best = mini(best, maxi(absi(dx), absi(dy)))
			if best <= rings:
				var c := col
				c.a = strength * (1.0 if best == 1 else (0.5 if best == 2 else 0.25))
				img.set_pixel(x, y, c)
	img.blend_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(pad, pad))
	if DataDB.rarity_order(rarity) >= 3:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(seed_key + rarity)
		var glints: int = {"epic": 2, "legendary": 4, "mythic": 6}.get(rarity, 0)
		var spot := 0
		var tries := 0
		while spot < glints and tries < 80:
			tries += 1
			var gx := rng.randi_range(0, w - 1)
			var gy := rng.randi_range(0, h - 1)
			if img.get_pixel(gx, gy).a > 0.0 and img.get_pixel(gx, gy).a < 0.95:
				img.set_pixel(gx, gy, Color.WHITE if spot % 2 == 0 else col.lightened(0.5))
				spot += 1
	return ImageTexture.create_from_image(img)


## Equippable gem (each has its own cut and colour).
static func gem(gem_id: String) -> Texture2D:
	var f := frames("gem_" + gem_id)
	return f[0] if not f.is_empty() else icon("relic")


static func icon(icon_id: String) -> Texture2D:
	var f := frames("icon_" + icon_id)
	return f[0] if not f.is_empty() else null


const INK := Color("#16151a")
const MID := Color("#8f897d")
const PAPER := Color("#efe9d8")


static func mono_tone(c: Color, outline: bool) -> Color:
	if outline:
		return INK
	var lum := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
	if lum < 0.3:
		return INK
	if lum < 0.6:
		return MID
	return PAPER
