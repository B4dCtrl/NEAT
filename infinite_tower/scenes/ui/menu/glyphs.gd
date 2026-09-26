extends RefCounted
## Tiny pixel icons for the menu (skills, talents, menu buttons), rasterised
## from simple shapes on a 16x16 grid and given a dark outline, so they share
## the chunky look of the sprites without hand-drawing every one.

const N := 16
const OUTLINE := Color("#140c0a")

static var _cache := {}


static func texture(glyph: String) -> Texture2D:
	if _cache.has(glyph):
		return _cache[glyph]
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_paint(img, glyph)
	_outline(img)
	var tex := ImageTexture.create_from_image(img)
	_cache[glyph] = tex
	return tex


# ------------------------------------------------------------------ raster helpers

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < N and y < N:
		img.set_pixel(x, y, c)


static func _line(img: Image, a: Vector2i, b: Vector2i, c: Color, w: int = 1) -> void:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in steps + 1:
		var t := float(i) / maxf(1.0, steps)
		var p := Vector2(a).lerp(Vector2(b), t).round()
		for dx in w:
			for dy in w:
				_px(img, int(p.x) + dx, int(p.y) + dy, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


static func _circle(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for y in N:
		for x in N:
			if Vector2(x + 0.5 - cx, y + 0.5 - cy).length() <= r:
				_px(img, x, y, c)


static func _ring(img: Image, cx: float, cy: float, r: float, w: float, c: Color) -> void:
	for y in N:
		for x in N:
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			if d <= r and d > r - w:
				_px(img, x, y, c)


static func _poly(img: Image, pts: Array, c: Color) -> void:
	var poly := PackedVector2Array(pts)
	for y in N:
		for x in N:
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
				_px(img, x, y, c)


## Transparent pixels touching a painted one become outline.
static func _outline(img: Image) -> void:
	var copy := img.duplicate()
	for y in N:
		for x in N:
			if copy.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < N and q.y < N and copy.get_pixel(q.x, q.y).a > 0.0 and copy.get_pixel(q.x, q.y) != OUTLINE:
					img.set_pixel(x, y, OUTLINE)
					break


# ------------------------------------------------------------------ glyphs

const STEEL := Color("#dfe6ee")
const STEEL_LO := Color("#8d97a6")
const GOLD := Color("#f2c14e")
const WOOD := Color("#9a6434")
const RED := Color("#e0413a")
const RED_HI := Color("#ff8f7a")
const GREEN := Color("#5fd35f")
const BLUE := Color("#6ab8ff")
const FIRE := Color("#ff7a1a")
const FIRE_HI := Color("#ffe07a")
const PURPLE := Color("#b57bff")
const CREAM := Color("#f3e5c4")


static func _paint(img: Image, glyph: String) -> void:
	match glyph:
		"sword":
			_line(img, Vector2i(4, 11), Vector2i(12, 3), STEEL, 2)
			_line(img, Vector2i(5, 12), Vector2i(12, 5), STEEL_LO)
			_line(img, Vector2i(3, 8), Vector2i(7, 12), GOLD, 2)
			_rect(img, 2, 12, 2, 2, WOOD)
		"axe":
			_line(img, Vector2i(3, 13), Vector2i(11, 4), WOOD, 2)
			_poly(img, [Vector2(8, 2), Vector2(14, 5), Vector2(13, 9), Vector2(10, 8)], STEEL)
			_line(img, Vector2i(13, 5), Vector2i(12, 9), STEEL_LO)
		"shield":
			_poly(img, [Vector2(3, 2), Vector2(13, 2), Vector2(13, 8), Vector2(8, 14.5), Vector2(3, 8)], STEEL_LO)
			_poly(img, [Vector2(4, 3), Vector2(12, 3), Vector2(12, 8), Vector2(8, 13), Vector2(4, 8)], BLUE)
			_rect(img, 7, 4, 2, 8, GOLD)
			_rect(img, 5, 6, 6, 2, GOLD)
		"bash":
			_paint(img, "shield")
			_poly(img, [Vector2(12, 0), Vector2(13, 3), Vector2(16, 3), Vector2(13.5, 5), Vector2(15, 8), Vector2(12, 6), Vector2(9, 8), Vector2(10.5, 5), Vector2(8, 3), Vector2(11, 3)], FIRE_HI)
		"heart":
			_circle(img, 5.5, 6, 3.2, RED)
			_circle(img, 10.5, 6, 3.2, RED)
			_poly(img, [Vector2(2.4, 7), Vector2(13.6, 7), Vector2(8, 13.5)], RED)
			_rect(img, 4, 4, 2, 2, RED_HI)
		"heal":
			_paint(img, "heart")
			_rect(img, 7, 5, 2, 6, CREAM)
			_rect(img, 5, 7, 6, 2, CREAM)
		"cross":
			_rect(img, 6, 2, 4, 12, GREEN)
			_rect(img, 2, 6, 12, 4, GREEN)
			_rect(img, 7, 3, 1, 4, Color("#b8ffb0"))
		"arrow":
			_line(img, Vector2i(2, 13), Vector2i(12, 3), WOOD)
			_poly(img, [Vector2(10, 2), Vector2(14.5, 1.5), Vector2(14, 6)], STEEL)
			_line(img, Vector2i(2, 11), Vector2i(4, 13), CREAM)
			_line(img, Vector2i(1, 12), Vector2i(3, 14), CREAM)
		"pierce":
			_paint(img, "arrow")
			_line(img, Vector2i(9, 9), Vector2i(14, 14), FIRE_HI)
			_line(img, Vector2i(1, 5), Vector2i(4, 2), FIRE_HI)
		"volley":
			for off in [Vector2i(0, 0), Vector2i(4, 0), Vector2i(8, 0)]:
				_line(img, Vector2i(2, 5) + off, Vector2i(2, 14) + off, WOOD)
				_poly(img, [Vector2(0.5 + off.x, 5 + off.y), Vector2(4.5 + off.x, 5 + off.y), Vector2(2.5 + off.x, 1 + off.y)], STEEL)
		"flame":
			_poly(img, [Vector2(8, 1), Vector2(13, 8), Vector2(12, 13), Vector2(8, 15), Vector2(4, 13), Vector2(3, 8), Vector2(6, 9)], FIRE)
			_poly(img, [Vector2(8, 6), Vector2(10.5, 10), Vector2(10, 13), Vector2(8, 14), Vector2(6, 13), Vector2(5.5, 11)], FIRE_HI)
		"firebolt":
			_line(img, Vector2i(1, 14), Vector2i(8, 7), FIRE, 2)
			_circle(img, 10.5, 5.5, 4.2, FIRE)
			_circle(img, 11, 5, 2.2, FIRE_HI)
		"meteor":
			_line(img, Vector2i(1, 1), Vector2i(8, 8), FIRE, 2)
			_line(img, Vector2i(3, 0), Vector2i(9, 6), FIRE_HI)
			_circle(img, 10.5, 10.5, 4.5, Color("#7a4a2a"))
			_circle(img, 11.5, 9.5, 2, Color("#b0703a"))
		"mend":
			_paint(img, "flame")
			_rect(img, 7, 7, 2, 6, CREAM)
			_rect(img, 5, 9, 6, 2, CREAM)
		"skull":
			_circle(img, 8, 7, 5.2, CREAM)
			_rect(img, 5, 11, 6, 3, CREAM)
			_rect(img, 5, 6, 2, 3, OUTLINE)
			_rect(img, 9, 6, 2, 3, OUTLINE)
			_rect(img, 7, 12, 1, 2, OUTLINE)
			_rect(img, 9, 12, 1, 2, OUTLINE)
		"drop":
			_poly(img, [Vector2(8, 1), Vector2(12.5, 9), Vector2(8, 14.5), Vector2(3.5, 9)], RED)
			_circle(img, 8, 10, 4.3, RED)
			_rect(img, 6, 8, 1, 3, RED_HI)
		"boot":
			_poly(img, [Vector2(4, 2), Vector2(9, 2), Vector2(9, 9), Vector2(14, 11), Vector2(14, 14), Vector2(4, 14)], WOOD)
			_rect(img, 4, 12, 10, 2, Color("#5a3a1e"))
			_rect(img, 4, 3, 5, 1, GOLD)
		"wind":
			for i in 3:
				var y := 4 + i * 4
				_line(img, Vector2i(1 + i * 2, y), Vector2i(11, y), CREAM)
				_px(img, 12, y - 1, CREAM)
				_px(img, 13, y - 2, CREAM)
		"eye":
			_poly(img, [Vector2(1, 8), Vector2(5, 4), Vector2(11, 4), Vector2(15, 8), Vector2(11, 12), Vector2(5, 12)], CREAM)
			_circle(img, 8, 8, 3, BLUE)
			_circle(img, 8, 8, 1.3, OUTLINE)
		"target":
			_ring(img, 8, 8, 7, 2, RED)
			_ring(img, 8, 8, 4, 2, CREAM)
			_circle(img, 8, 8, 1.5, RED)
		"hourglass":
			_rect(img, 3, 1, 10, 2, WOOD)
			_rect(img, 3, 13, 10, 2, WOOD)
			_poly(img, [Vector2(4, 3), Vector2(12, 3), Vector2(8.5, 8), Vector2(12, 13), Vector2(4, 13), Vector2(7.5, 8)], Color("#bfe8ff"))
			_poly(img, [Vector2(5.5, 12.5), Vector2(10.5, 12.5), Vector2(8, 9)], GOLD)
		"bolt":
			_poly(img, [Vector2(9, 0), Vector2(3, 9), Vector2(7, 9), Vector2(5, 16), Vector2(13, 6), Vector2(9, 6), Vector2(11, 0)], FIRE_HI)
		"burst":
			var pts := []
			for i in 16:
				var r := 7.2 if i % 2 == 0 else 3.2
				pts.append(Vector2(8, 8) + Vector2.RIGHT.rotated(i * PI / 8.0) * r)
			_poly(img, pts, FIRE)
			_circle(img, 8, 8, 2.5, FIRE_HI)
		"horn":
			_poly(img, [Vector2(2, 6), Vector2(8, 4), Vector2(8, 12), Vector2(2, 10)], GOLD)
			_rect(img, 1, 6, 2, 4, GOLD)
			for i in 3:
				_ring(img, 8, 8, 3.5 + i * 2.5, 1, CREAM if i % 2 == 0 else FIRE_HI)
			_rect(img, 0, 0, 8, 16, Color(0, 0, 0, 0))
			_poly(img, [Vector2(2, 6), Vector2(8, 4), Vector2(8, 12), Vector2(2, 10)], GOLD)
		"banner":
			_rect(img, 3, 1, 2, 14, WOOD)
			_poly(img, [Vector2(5, 2), Vector2(14, 2), Vector2(11, 6), Vector2(14, 10), Vector2(5, 10)], RED)
			_rect(img, 7, 4, 3, 3, GOLD)
		"star":
			var pts := []
			for i in 10:
				var r := 7.0 if i % 2 == 0 else 3.0
				pts.append(Vector2(8, 8.5) + Vector2.UP.rotated(i * PI / 5.0) * r)
			_poly(img, pts, GOLD)
		"gear":
			for i in 8:
				var d := Vector2.RIGHT.rotated(i * PI / 4.0)
				_rect(img, int(8 + d.x * 6 - 1), int(8 + d.y * 6 - 1), 2, 2, STEEL_LO)
			_circle(img, 8, 8, 5.5, STEEL)
			_circle(img, 8, 8, 2, OUTLINE)
		"bag":
			_circle(img, 8, 10, 5.5, WOOD)
			_poly(img, [Vector2(5, 2), Vector2(11, 2), Vector2(9.5, 5), Vector2(6.5, 5)], WOOD)
			_rect(img, 5, 5, 6, 1, GOLD)
			_rect(img, 6, 9, 4, 3, GOLD)
		"tree":
			_rect(img, 7, 9, 3, 6, WOOD)
			_circle(img, 8.5, 6.5, 5.5, GREEN)
			_circle(img, 6.5, 5, 1.6, Color("#9dff8f"))
		"helm":
			_circle(img, 8, 8, 6, STEEL)
			_rect(img, 2, 8, 12, 6, STEEL)
			_rect(img, 4, 8, 8, 2, OUTLINE)
			_rect(img, 7, 10, 2, 4, STEEL_LO)
			_rect(img, 7, 1, 2, 4, RED)
		"book":
			_rect(img, 3, 2, 10, 12, PURPLE)
			_rect(img, 4, 3, 1, 10, Color("#6a3aa8"))
			_poly(img, [Vector2(7, 5), Vector2(11, 5), Vector2(9, 10)], GOLD)
		"expand":
			_line(img, Vector2i(2, 13), Vector2i(13, 2), CREAM, 2)
			_poly(img, [Vector2(8, 1), Vector2(15, 1), Vector2(15, 8)], CREAM)
			_poly(img, [Vector2(1, 8), Vector2(1, 15), Vector2(8, 15)], CREAM)
		"close":
			_line(img, Vector2i(3, 3), Vector2i(12, 12), CREAM, 2)
			_line(img, Vector2i(3, 12), Vector2i(12, 3), CREAM, 2)
		"coin":
			_circle(img, 8, 8, 6, GOLD)
			_ring(img, 8, 8, 6, 1, Color("#b07a1c"))
			_rect(img, 7, 4, 2, 8, Color("#b07a1c"))
		"lock":
			_ring(img, 8, 6, 4, 2, STEEL_LO)
			_rect(img, 3, 7, 10, 8, GOLD)
			_rect(img, 7, 9, 2, 4, OUTLINE)
		_:
			_circle(img, 8, 8, 5, CREAM)
