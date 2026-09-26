extends RefCounted
## Builds nearest-filtered textures from the text grids in data/sprites.json.
## Palettes can be overridden per enemy, so one shape serves many monsters.
##
## Art override: a PNG at res://assets/sprites/<id>.png (e.g. generated with
## PixelLab) replaces the text sprite with the same id. A horizontal strip of
## square frames is split into animation frames. Enemy PNGs may also be named
## after the enemy id (assets/sprites/slime.png, assets/sprites/ashen_king.png).

const DataDB = preload("res://core/data_db.gd")

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
static func unit_frames(unit_id: String, sprite_id: String, palette: Dictionary, mono: bool) -> Array:
	if unit_id != "" and ResourceLoader.exists(ASSET_DIR + unit_id + ".png"):
		return frames(unit_id, {}, mono)
	return frames(sprite_id, palette, mono)


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


## Icon for an equipment item: its base's icon, else a generic one for the slot.
static func item_icon(item: Dictionary, mono: bool = false) -> Texture2D:
	if _base_icons.is_empty():
		for base in DataDB.items()["bases"]:
			_base_icons[base["id"]] = base.get("icon", "item_" + String(base["slot"]))
	var id: String = _base_icons.get(item.get("base", ""), "item_" + String(item.get("slot", "chest")))
	var f := frames(id, {}, mono)
	return f[0] if not f.is_empty() else null


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
