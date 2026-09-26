extends RefCounted
## Builds nearest-filtered textures from the text grids in data/sprites.json.
## Palettes can be overridden per enemy, so one shape serves many monsters.

const DataDB = preload("res://core/data_db.gd")

static var _cache: Dictionary = {}


## Returns the animation frames for a sprite id as ImageTextures.
static func frames(sprite_id: String, palette_override: Dictionary = {}) -> Array:
	var key := sprite_id + str(palette_override)
	if _cache.has(key):
		return _cache[key]
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


static func icon(icon_id: String) -> Texture2D:
	var f := frames("icon_" + icon_id)
	return f[0] if not f.is_empty() else null
