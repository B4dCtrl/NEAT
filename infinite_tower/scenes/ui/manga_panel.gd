extends Control
## One manga panel: a scene drawn in code (ink, paper and screentone, with the
## game's colour sprites as spot colour), manga overlays (speed lines, focus
## lines, rain), speech bubbles (talk / shout / whisper) with tails, caption
## boxes, onomatopoeia and chapter titles. Texts type themselves in order.
## Scenes are named in data/story.json.

const DataDB = preload("res://core/data_db.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")
const Loc = preload("res://core/loc.gd")

const INK := Color("#121116")
const PAPER := Color("#f1ece0")
const GREY := Color("#8d887e")
const LIGHT := Color("#cfc8b8")
const GOLD := Color("#f2c14e")

var spec: Dictionary = {}
var hero_name := "Stairborn"
var reveal := 0.0
var typed := 0.0
var t := 0.0
var active := false
var _texts: Array = []       # [{kind, text, data}] in reading order (captions, bubbles)
var _total := 0
var _tone: ImageTexture
var _tex := {}


func setup(panel: Dictionary, name_of_hero: String) -> void:
	spec = panel
	hero_name = name_of_hero
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tone = _make_tone()
	if spec.has("caption") and not spec.get("caption_bottom", false):
		_texts.append({"kind": "caption", "text": _t(spec["caption"])})
	for b in spec.get("bubbles", []):
		_texts.append({"kind": "bubble", "text": _t(b["text"]), "data": b})
	if spec.has("caption") and spec.get("caption_bottom", false):
		_texts.append({"kind": "caption", "text": _t(spec["caption"]), "bottom": true})
	_total = 0
	for x in _texts:
		_total += String(x["text"]).length()


func _t(key: String) -> String:
	return Loc.t(key).replace("{hero}", hero_name)


func text_done() -> bool:
	return reveal >= 1.0 and typed >= _total


func finish() -> void:
	reveal = 1.0
	typed = _total


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	reveal = minf(1.0, reveal + delta * 3.0)
	if reveal >= 1.0:
		typed = minf(_total, typed + delta * 42.0)
	queue_redraw()


func _draw() -> void:
	if reveal <= 0.0 or size.x < 30.0 or size.y < 30.0:
		return
	var r := Rect2(Vector2.ZERO, size)
	var k := ease(reveal, 0.35)
	var s := 0.96 + 0.04 * k
	draw_set_transform(size * (1.0 - s) * 0.5, 0.0, Vector2.ONE * s)
	draw_rect(r, PAPER)
	var fn := "_s_" + String(spec.get("scene", ""))
	if has_method(fn):
		call(fn)
	match String(spec.get("lines", "")):
		"speed": _speed_lines()
		"focus": _focus_lines()
		"rain": _rain()
	if spec.has("title"):
		_title(_t(spec["title"]))
	for sfx in spec.get("sfx", []):
		_sfx(sfx)
	_draw_texts()
	draw_rect(r, INK, false, 5.0)
	draw_set_transform(Vector2.ZERO)
	if reveal < 1.0:
		draw_rect(r, Color(PAPER.r, PAPER.g, PAPER.b, 1.0 - k))


# ================================================================== textures

func _make_tone() -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for p in [Vector2i(0, 0), Vector2i(2, 2)]:
		img.set_pixel(p.x, p.y, INK)
	return ImageTexture.create_from_image(img)


func _unit(art: String, hue: float = -1.0, fx: Array = []) -> Texture2D:
	var key := "%s|%.2f|%s" % [art, hue, ",".join(fx)]
	if not _tex.has(key):
		var def := DataDB.unit_def(art) if DataDB.enemies().has(art) or DataDB.bosses().has(art) else {}
		var sprite: String = def.get("sprite", DataDB.classes().get(art, {}).get("sprite", art))
		var f := PixelArt.unit_frames(String(def.get("art", art)), sprite, def.get("palette", {}), false, hue, fx)
		_tex[key] = f
	var frames: Array = _tex[key]
	return frames[int(t * 7.0) % frames.size()] if not frames.is_empty() else null


func _item(id: String) -> Texture2D:
	var f := PixelArt.frames(id)
	return f[0] if not f.is_empty() else null


## Draws a sprite with its feet at `feet`, `h` pixels tall.
func _sprite(tex: Texture2D, feet: Vector2, h: float, rot: float = 0.0, alpha: float = 1.0, flip: bool = false, tint: Color = Color.WHITE) -> void:
	if tex == null:
		return
	var sc := h / tex.get_height()
	var sz := Vector2(tex.get_width(), tex.get_height()) * sc
	draw_set_transform(feet, rot, Vector2(-1.0 if flip else 1.0, 1.0))
	var c := tint
	c.a = alpha
	draw_texture_rect(tex, Rect2(Vector2(-sz.x * 0.5, -sz.y), sz), false, c)
	draw_set_transform(Vector2.ZERO)


# ================================================================== helpers

func _tone_rect(r: Rect2, alpha: float = 1.0) -> void:
	draw_texture_rect(_tone, r, true, Color(1, 1, 1, alpha))


func _sky(top: Color, bottom: Color) -> void:
	var n := 20
	for i in n:
		draw_rect(Rect2(0, size.y * i / n, size.x, size.y / n + 1), top.lerp(bottom, float(i) / n))


func _ground(y: float, c: Color = INK) -> void:
	draw_rect(Rect2(0, y, size.x, size.y - y), c)


func _stars(n: int, max_y: float) -> void:
	for i in n:
		var a := 0.35 + 0.35 * sin(t * 2.0 + i)
		draw_rect(Rect2(fposmod(i * 97.3, size.x), fposmod(i * 53.1, max_y), 2, 2), Color(1, 1, 1, a))


## Endless tower with a helical stair, vanishing into clouds.
func _tower(cx: float, w: float, top_y: float, bottom_y: float, body: Color = PAPER, shade: Color = INK, mist: Color = PAPER) -> void:
	var half := w * 0.5
	draw_rect(Rect2(cx - half, top_y, w, bottom_y - top_y), body)
	_tone_rect(Rect2(cx + half * 0.1, top_y, half * 0.9, bottom_y - top_y))
	draw_rect(Rect2(cx + half * 0.6, top_y, half * 0.4, bottom_y - top_y), shade)
	var turn := maxf(w * 0.65, 14.0)
	var y := bottom_y
	var i := 0
	while y > top_y:
		var ph := fmod(t * 0.05, 1.0)
		var pts := PackedVector2Array()
		for s in 13:
			var u := s / 12.0
			pts.append(Vector2(cx - cos((u * 0.5 + ph) * TAU) * (half + w * 0.18), y - u * turn * 0.5))
		draw_polyline(pts, shade, 7.0)
		draw_polyline(pts, body, 4.0)
		y -= turn
		i += 1
	draw_rect(Rect2(cx - half, top_y, w, bottom_y - top_y), shade, false, 2.0)
	var cr := minf(w * 0.42, size.y * 0.12)
	for c in 6:
		var cl := mist
		cl.a = mist.a * (0.9 - c * 0.13)
		draw_circle(Vector2(cx - cr * 1.4 + c * cr * 0.6, top_y + 6.0 + (c % 2) * 8.0), cr, cl)


func _fire(base: Vector2, sc: float, with_eyes: bool = false) -> void:
	draw_circle(base + Vector2(0, -12 * sc), 70.0 * sc, Color(1.0, 0.6, 0.2, 0.16 + 0.05 * sin(t * 6.0)))
	draw_rect(Rect2(base + Vector2(-18, -5) * sc, Vector2(36, 7) * sc), Color("#4a3020"))
	var cols := [Color("#ff5a1a"), Color("#ffb13d"), Color("#fff1a8")]
	for layer in 3:
		var h := (36.0 - layer * 9.0 + sin(t * 9.0 + layer) * 5.0) * sc
		var w := (30.0 - layer * 8.0) * sc
		draw_colored_polygon(PackedVector2Array([base + Vector2(-w * 0.5, -5 * sc), base + Vector2(w * 0.5, -5 * sc),
			base + Vector2(sin(t * 7.0 + layer) * 4.0 * sc, -5 * sc - h)]), cols[layer])
	if with_eyes:
		var blink := 1.0 if fmod(t, 3.5) > 0.15 else 0.1
		for sx in [-1.0, 1.0]:
			_eye(base + Vector2(sx * 7.0 * sc, -20.0 * sc), 9.0 * sc, blink, Color("#2a1408"), false, Color("#fff8d0"))


## A manga eye: almond white, iris, highlight, heavy upper lid.
func _eye(c: Vector2, w: float, open: float, iris: Color, lashes: bool = true, white: Color = PAPER) -> void:
	var h := w * 0.55 * open
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i in 13:
		var u := i / 12.0
		var x := c.x - w + u * w * 2.0
		top.append(Vector2(x, c.y - sin(u * PI) * h))
		bottom.append(Vector2(x, c.y + sin(u * PI) * h * 0.7))
	var shape := top.duplicate()
	for i in range(bottom.size() - 1, -1, -1):
		shape.append(bottom[i])
	if h > 0.5:
		draw_colored_polygon(shape, white)
		draw_circle(c + Vector2(0, h * 0.1), minf(h, w * 0.45), iris)
		draw_circle(c + Vector2(-w * 0.15, -h * 0.25), maxf(1.5, w * 0.1), Color.WHITE)
	draw_polyline(top, INK, maxf(2.0, w * 0.18))
	if lashes:
		for i in 3:
			var p := top[2 + i * 4]
			draw_line(p, p + Vector2(-2.0 + i * 2.0, -w * 0.25), INK, 2.0)


## A silhouette person: "adult", "elder" (hunched, staff), "kid", "woman" (hair, torn cape).
func _figure(feet: Vector2, h: float, kind: String = "adult", col: Color = INK, rot: float = 0.0) -> void:
	draw_set_transform(feet, rot, Vector2.ONE)
	var head_r := h * (0.14 if kind == "kid" else 0.1)
	var neck := -h * (0.72 if kind == "kid" else 0.8)
	var lean := h * 0.12 if kind == "elder" else 0.0
	var body := PackedVector2Array([Vector2(-h * 0.16, 0), Vector2(h * 0.16, 0), Vector2(h * 0.12 + lean, neck), Vector2(-h * 0.1 + lean, neck)])
	if kind == "woman":
		body = PackedVector2Array([Vector2(-h * 0.22, 0), Vector2(h * 0.2, 0), Vector2(h * 0.1, neck), Vector2(-h * 0.1, neck)])
		draw_colored_polygon(PackedVector2Array([Vector2(-h * 0.08, neck - head_r), Vector2(-h * 0.2, neck + h * 0.3), Vector2(-h * 0.02, neck + h * 0.1)]), col)
	draw_colored_polygon(body, col)
	draw_circle(Vector2(lean * 1.2, neck - head_r * 0.9), head_r, col)
	if kind == "elder":
		draw_line(Vector2(h * 0.3, 0), Vector2(h * 0.26, -h * 0.85), col, maxf(2.0, h * 0.03))
	draw_set_transform(Vector2.ZERO)


func _bundle(c: Vector2, r: float) -> void:
	draw_circle(c, r * 1.8, Color(1, 0.9, 0.6, 0.25 + 0.1 * sin(t * 4.0)))
	draw_set_transform(c, 0.3, Vector2(1.4, 1.0))
	draw_circle(Vector2.ZERO, r, PAPER)
	draw_arc(Vector2.ZERO, r, 0, TAU, 20, INK, 2.0)
	draw_set_transform(Vector2.ZERO)


func _steps(origin: Vector2, n: int, w: float, h: float, dir: float = 1.0) -> void:
	for i in n:
		var r := Rect2(origin + Vector2(i * w * dir, -i * h), Vector2(w * 1.05, h))
		draw_rect(r, PAPER)
		draw_rect(r, INK, false, 2.0)


func _burst(c: Vector2, r_in: float, r_out: float, n: int, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in n * 2:
		var a := i * PI / n + t * 0.5
		var r := r_out if i % 2 == 0 else r_in
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), INK, 2.0)


# ================================================================== overlays

func _speed_lines() -> void:
	for i in 28:
		var y := fposmod(i * 37.0 + t * 260.0 * (0.5 + fmod(i * 0.37, 0.5)), size.y)
		var x0 := fposmod(i * 71.0, size.x * 0.5)
		draw_line(Vector2(x0, y), Vector2(x0 + size.x * (0.3 + fmod(i * 0.13, 0.4)), y), Color(INK.r, INK.g, INK.b, 0.35), 1.5)


func _focus_lines() -> void:
	var c := size * 0.5
	var rad := size.length() * 0.6
	for i in 64:
		var a := i * TAU / 64.0 + fmod(i * 0.37, 0.05)
		var inner := rad * (0.55 + fmod(i * 0.29, 0.2))
		draw_line(c + Vector2(cos(a), sin(a)) * inner, c + Vector2(cos(a), sin(a)) * rad, Color(INK.r, INK.g, INK.b, 0.55), 1.0 + fmod(i, 3.0))


func _rain() -> void:
	for i in 70:
		var x := fposmod(i * 41.0 + t * 90.0, size.x + 40.0) - 20.0
		var y := fposmod(i * 67.0 + t * 520.0, size.y + 40.0) - 20.0
		draw_line(Vector2(x, y), Vector2(x - 6.0, y + 18.0), Color(0.85, 0.88, 0.95, 0.45), 1.0)


# ================================================================== text

func _font() -> Font:
	return get_theme_default_font()


func _fs() -> int:
	return int(clampf(size.y * 0.05, 12.0, 19.0))


func _draw_texts() -> void:
	if reveal < 1.0:
		return
	var left := typed
	for x in _texts:
		var full: String = x["text"]
		if left <= 0.0:
			break
		var shown := full.substr(0, int(minf(left, full.length())))
		left -= full.length()
		if x["kind"] == "caption":
			_caption(full, shown, x.get("bottom", false))
		else:
			_bubble(x["data"], full, shown)


func _caption(full: String, shown: String, bottom: bool) -> void:
	var fs := _fs()
	var w := minf(size.x - 20.0, maxf(160.0, size.x * 0.62))
	var sz := _font().get_multiline_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, w - 16.0, fs)
	var box := Rect2(Vector2(10, size.y - sz.y - 26.0) if bottom else Vector2(10, 10), Vector2(w, sz.y + 14.0))
	draw_rect(box.grow(2.0), INK)
	draw_rect(box, Color("#fbf6e6"))
	draw_multiline_string(_font(), box.position + Vector2(8, 6 + fs), shown, HORIZONTAL_ALIGNMENT_LEFT, w - 16.0, fs, -1, INK)


func _bubble(b: Dictionary, full: String, shown: String) -> void:
	var fs := _fs()
	var style: String = b.get("style", "talk")
	# The text block must sit inside the ellipse (corners included) and the
	# ellipse inside the panel: wrap narrower, then shrink the font if needed.
	var grow := 1.3 * (1.12 if style == "shout" else 1.0)
	var w := clampf(float(b.get("w", 0.5)) * size.x, 60.0, (size.x - 44.0) / grow)
	var sz := _font().get_multiline_string_size(full, HORIZONTAL_ALIGNMENT_CENTER, w, fs)
	while fs > 10 and sz.y * 0.5 * grow + 14.0 > size.y * 0.45:
		fs -= 1
		sz = _font().get_multiline_string_size(full, HORIZONTAL_ALIGNMENT_CENTER, w, fs)
	var c := Vector2(float(b["at"][0]) * size.x, float(b["at"][1]) * size.y)
	var rx := sz.x * 0.5 * grow + 14.0
	var ry := sz.y * 0.5 * grow + 12.0
	c.x = clampf(c.x, rx + 4.0, size.x - rx - 4.0)
	c.y = clampf(c.y, ry + 4.0, size.y - ry - 4.0)
	var tail := Vector2(float(b["tail"][0]) * size.x, float(b["tail"][1]) * size.y)
	var dir := (tail - c).normalized()
	var base := c + Vector2(dir.x * rx, dir.y * ry) * 0.8
	var side := Vector2(-dir.y, dir.x) * 9.0
	var tip := base + (tail - base) * 0.6
	var pts := PackedVector2Array()
	var n := 40
	for i in n:
		var a := i * TAU / n
		var rr := 1.0
		if style == "shout":
			rr = 1.1 if i % 2 == 0 else 0.94
		pts.append(c + Vector2(cos(a) * rx * rr, sin(a) * ry * rr))
	draw_colored_polygon(PackedVector2Array([base + side, base - side, tip]), INK)
	draw_colored_polygon(pts, INK)
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c + (p - c) * (1.0 - 3.0 / maxf(rx, ry)))
	draw_colored_polygon(PackedVector2Array([base + side * 0.6, base - side * 0.6, tip + (base - tip) * 0.12]), Color.WHITE)
	draw_colored_polygon(inner, Color.WHITE)
	if style == "whisper":
		for i in range(0, n, 2):
			draw_line(pts[i], pts[(i + 1) % n], Color.WHITE, 3.0)
	var top := c - Vector2(w * 0.5, sz.y * 0.5)
	draw_multiline_string(_font(), top + Vector2(0, fs * 0.85), shown, HORIZONTAL_ALIGNMENT_CENTER, w, fs, -1, INK)


func _sfx(s: Dictionary) -> void:
	var text := _t(s["text"])
	var fs := int(size.y * float(s.get("size", 0.18)))
	var at := Vector2(float(s["at"][0]) * size.x, float(s["at"][1]) * size.y)
	var shake := Vector2(sin(t * 40.0), cos(t * 37.0)) * 1.5 if reveal >= 1.0 and t < 0.6 else Vector2.ZERO
	draw_set_transform(at + shake, float(s.get("rot", 0.0)), Vector2.ONE)
	var w := _font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(_font(), Vector2(-w * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(6, fs / 6), INK)
	draw_string(_font(), Vector2(-w * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	draw_set_transform(Vector2.ZERO)


func _title(text: String) -> void:
	var f := _font()
	var big := _fit(f, "STAIRBORN", int(size.y * 0.1), size.x - 24.0)
	var small := _fit(f, text, int(size.y * 0.045), size.x - 24.0)
	var y := size.y * 0.14
	draw_string_outline(f, Vector2(0, y), "STAIRBORN", HORIZONTAL_ALIGNMENT_CENTER, size.x, big, 10, INK)
	draw_string(f, Vector2(0, y), "STAIRBORN", HORIZONTAL_ALIGNMENT_CENTER, size.x, big, GOLD)
	draw_string_outline(f, Vector2(0, y + small * 1.6), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, small, 6, INK)
	draw_string(f, Vector2(0, y + small * 1.6), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, small, PAPER)


## Largest font size (up to `fs`) at which `text` fits in `width`.
func _fit(f: Font, text: String, fs: int, width: float) -> int:
	while fs > 10 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		fs -= 1
	return fs


# ================================================================== scenes (chapter 1)

func _s_tower_withered() -> void:
	_sky(Color("#3a3640"), Color("#a8a090"))
	draw_circle(Vector2(size.x * 0.18, size.y * 0.25), size.y * 0.1, Color(0.95, 0.9, 0.8, 0.8))
	_tone_rect(Rect2(size.x * 0.08, size.y * 0.15, size.y * 0.2, size.y * 0.2), 0.5)
	_tower(size.x * 0.62, size.y * 0.22, -10.0, size.y * 0.84)
	var g := size.y * 0.84
	var pts := PackedVector2Array([Vector2(0, size.y)])
	for i in 13:
		pts.append(Vector2(size.x * i / 12.0, g - sin(i * 1.3) * 10.0))
	pts.append(Vector2(size.x, size.y))
	draw_colored_polygon(pts, INK)
	# dead tree and a village of dark windows
	var b := Vector2(size.x * 0.1, g)
	draw_line(b, b + Vector2(0, -size.y * 0.3), INK, 8.0)
	for br in [[0.5, -40.0, -30.0], [0.7, 35.0, -36.0], [0.9, -25.0, -22.0]]:
		var p: Vector2 = b + Vector2(0, -size.y * 0.3 * br[0])
		draw_line(p, p + Vector2(br[1], br[2]), INK, 4.0)
	for i in 4:
		var x := size.x * 0.24 + i * 34.0
		draw_rect(Rect2(x, g - 22, 26, 22), INK)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 3, g - 22), Vector2(x + 29, g - 22), Vector2(x + 13, g - 36)]), INK)


func _s_elder_kids() -> void:
	_sky(Color("#4a4440"), Color("#d8ceb8"))
	_tone_rect(Rect2(0, 0, size.x, size.y * 0.6), 0.35)
	var g := size.y * 0.9
	_ground(g)
	_fire(Vector2(size.x * 0.5, g), size.y / 260.0)
	_figure(Vector2(size.x * 0.22, g), size.y * 0.62, "elder")
	_figure(Vector2(size.x * 0.68, g), size.y * 0.36, "kid")
	_figure(Vector2(size.x * 0.82, g), size.y * 0.3, "kid")


func _s_helmet_falls() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	_tone_rect(Rect2(0, size.y * 0.75, size.x, size.y * 0.25), 0.6)
	var y := fposmod(t * 60.0, size.y * 0.15) + size.y * 0.35
	_sprite(_item("gravebound_helm"), Vector2(size.x * 0.42, y + size.y * 0.3), size.y * 0.42, -0.3 + sin(t * 2.0) * 0.1)
	for i in 6:
		draw_circle(Vector2(size.x * (0.2 + i * 0.12), size.y * 0.86), 8.0 + (i % 3) * 4.0, LIGHT)


func _s_storm_return() -> void:
	var flash := fmod(t, 4.0) < 0.12
	_sky(Color("#0e0d12") if not flash else Color("#d8d8e8"), Color("#2a2832"))
	if flash:
		var x := size.x * 0.7
		var y := 0.0
		while y < size.y * 0.5:
			var nx := x + randf_range(-18.0, 18.0)
			draw_line(Vector2(x, y), Vector2(nx, y + 24.0), Color.WHITE, 3.0)
			x = nx
			y += 24.0
	_tower(size.x * 0.75, size.x * 0.5, -10.0, size.y * 0.8, LIGHT, INK, Color("#3a3844"))
	_steps(Vector2(size.x * 0.05, size.y * 0.92), 6, size.x * 0.13, size.y * 0.035)
	_figure(Vector2(size.x * 0.42, size.y * 0.78), size.y * 0.32, "woman", INK, 0.12)
	_ground(size.y * 0.92)


func _s_eyes_mother() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#2a2730"))
	_tone_rect(Rect2(Vector2.ZERO, size), 0.8)
	var open := 0.55 + 0.1 * sin(t * 1.3)
	_eye(Vector2(size.x * 0.3, size.y * 0.4), size.x * 0.13, open, Color("#4a6a8a"))
	_eye(Vector2(size.x * 0.7, size.y * 0.4), size.x * 0.13, open, Color("#4a6a8a"))
	var drop := Vector2(size.x * 0.3, size.y * 0.5 + fmod(t * 20.0, size.y * 0.15))
	draw_circle(drop, 4.0, Color("#bfe6ff"))


func _s_birth_bonfire() -> void:
	_sky(Color("#0e0d12"), Color("#2a2430"))
	_stars(30, size.y * 0.4)
	var g := size.y * 0.86
	_ground(g)
	draw_rect(Rect2(size.x * 0.05, g - 18, size.x * 0.55, 18), PAPER)
	draw_rect(Rect2(size.x * 0.05, g - 18, size.x * 0.55, 18), INK, false, 2.0)
	_fire(Vector2(size.x * 0.78, g), size.y / 220.0)
	_figure(Vector2(size.x * 0.12, g - 18), size.y * 0.42, "woman", INK, -1.45)
	_bundle(Vector2(size.x * 0.32, g - 30), size.y * 0.05)


func _s_elder_baby() -> void:
	_sky(Color("#b0a890"), Color("#f4ead0"))
	var c := Vector2(size.x * 0.55, size.y * 0.25)
	for i in 18:
		var a := i * TAU / 18.0 + t * 0.05
		draw_line(c, c + Vector2(cos(a), sin(a)) * size.x, Color(1, 1, 1, 0.25), 6.0)
	_tower(size.x * 0.8, size.y * 0.28, -10.0, size.y * 0.88)
	_ground(size.y * 0.88)
	_figure(Vector2(size.x * 0.48, size.y * 0.88), size.y * 0.6, "elder")
	_bundle(Vector2(size.x * 0.51, size.y * 0.3), size.y * 0.06)


func _s_grown_hero() -> void:
	_sky(Color("#6a6458"), Color("#e8e0cc"))
	_tower(size.x * 0.78, size.x * 0.3, -10.0, size.y * 0.9)
	_ground(size.y * 0.9)
	_sprite(_unit("stairborn"), Vector2(size.x * 0.32, size.y * 0.92), size.y * 0.66)


func _s_gilt_peek() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#2a2730"))
	_tone_rect(Rect2(Vector2.ZERO, size), 0.5)
	var bob := sin(t * 3.0) * 6.0
	_sprite(_unit("ember_imp", 0.13, ["halo", "crown"]), Vector2(size.x * 0.55, size.y * 0.72 + bob), size.y * 0.5)
	_steps(Vector2(0, size.y), 4, size.x * 0.3, size.y * 0.16)
	for i in 6:
		var p := Vector2(size.x * (0.15 + i * 0.15), size.y * (0.35 + fmod(i * 0.37 + t * 0.4, 0.4)))
		draw_rect(Rect2(p, Vector2(4, 4)), GOLD)


func _s_title_splash() -> void:
	_sky(Color("#1d1a2b"), Color("#6a6290"))
	_stars(60, size.y * 0.6)
	var g := size.y * 0.9
	_tower(size.x * 0.5, size.y * 0.36, -10.0, g)
	_ground(g)
	var step := Rect2(size.x * 0.5 + size.y * 0.2, g - 24, 80, 24)
	draw_rect(step, PAPER)
	draw_rect(step, INK, false, 3.0)
	_sprite(_unit("stairborn"), Vector2(step.position.x + 30, step.position.y), size.y * 0.3)


# ================================================================== scenes (chapter 2)

func _s_guardian_hit() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	_tone_rect(Rect2(size.x * 0.5, 0, size.x * 0.5, size.y), 0.7)
	_burst(Vector2(size.x * 0.5, size.y * 0.5), size.y * 0.12, size.y * 0.3, 10, Color.WHITE)
	_sprite(_unit("ashen_king"), Vector2(size.x * 0.75, size.y * 0.98), size.y * 0.95, 0.0, 1.0, true)
	_sprite(_unit("stairborn"), Vector2(size.x * 0.25, size.y * 0.85), size.y * 0.55, -0.5)


func _s_fall_tumble() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), LIGHT)
	_steps(Vector2(0, size.y), 7, size.x * 0.16, size.y * 0.1)
	var ph := fmod(t * 0.6, 1.0)
	_sprite(_unit("stairborn"), Vector2(size.x * (0.75 - ph * 0.4), size.y * (0.35 + ph * 0.3)), size.y * 0.36, t * 5.0)
	for i in 5:
		draw_circle(Vector2(size.x * (0.6 + i * 0.07), size.y * (0.5 + fmod(t * 0.5 + i * 0.2, 0.4))), 4.0, GOLD)


func _s_bonfire_eyes() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0e0c10"))
	_fire(Vector2(size.x * 0.5, size.y * 0.95), size.y / 110.0, true)


func _s_hero_at_fire() -> void:
	_sky(Color("#0e0d12"), Color("#242030"))
	_stars(40, size.y * 0.5)
	var g := size.y * 0.88
	_ground(g)
	_fire(Vector2(size.x * 0.62, g), size.y / 200.0, true)
	_sprite(_unit("stairborn"), Vector2(size.x * 0.32, g), size.y * 0.5)


func _s_ash_echo() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#1a1820"))
	var g := size.y * 0.8
	_fire(Vector2(size.x * 0.5, g), size.y / 260.0)
	var a := clampf(fmod(t * 0.35, 1.2), 0.0, 1.0)
	_sprite(_unit("knight"), Vector2(size.x * 0.5, g - size.y * 0.08), size.y * 0.5, 0.0, a, false, Color(1.2, 1.1, 0.9))
	for i in 24:
		var ph := fmod(t * 0.4 + i * 0.13, 1.0)
		draw_rect(Rect2(Vector2(size.x * 0.5 + sin(i * 2.3) * size.x * 0.2 * (1.0 - ph), g - ph * size.y * 0.8), Vector2(3, 3)), Color(1, 0.8, 0.5, 1.0 - ph))


func _s_armor_rain() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	var g := size.y * 0.76
	var ids := ["wayfarer_helm", "iron_sword", "wayfarer_chest", "wayfarer_boots", "short_bow"]
	for i in ids.size():
		var y := fposmod(t * 70.0 + i * size.y * 0.27, g * 0.95)
		_sprite(_item(ids[i]), Vector2(size.x * (0.15 + i * 0.18), y), size.y * 0.14, sin(t + i) * 0.6)
	_ground(g)
	_sprite(_unit("stairborn"), Vector2(size.x * 0.72, g), size.y * 0.3)


func _s_party_climbs() -> void:
	_sky(Color("#f4c888"), Color("#fff4e0"))
	draw_circle(Vector2(size.x * 0.2, size.y * 0.3), size.y * 0.12, Color("#fff8e8"))
	var g := size.y * 0.8
	_tower(size.x * 0.7, size.y * 0.34, -10.0, g, PAPER, INK)
	_ground(g)
	_steps(Vector2(size.x * 0.02, g), 8, size.x * 0.12, size.y * 0.05)
	var cls := ["arcanist", "knight", "stairborn"]
	for i in cls.size():
		var x := size.x * (0.12 + i * 0.13)
		var step_y := g - int((x - size.x * 0.02) / (size.x * 0.12)) * size.y * 0.05
		_sprite(_unit(cls[i]), Vector2(x, step_y), size.y * 0.26)


# ================================================================== scenes (chapter 3)

func _s_guardian_falls() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), LIGHT)
	_sprite(_unit("moss_colossus"), Vector2(size.x * 0.5, size.y * 1.05), size.y * 0.9, 0.25)
	for i in 5:
		var p := Vector2(size.x * (0.3 + i * 0.1), size.y * (0.2 + i * 0.12))
		draw_line(p, p + Vector2(18, 22), INK, 3.0)
		draw_line(p + Vector2(18, 22), p + Vector2(4, 40), INK, 3.0)


func _s_guardian_eyes() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#141216"))
	_tone_rect(Rect2(Vector2.ZERO, size), 0.7)
	var k := clampf(fmod(t * 0.3, 1.3), 0.0, 1.0)
	var iris := Color("#ff3030").lerp(Color("#5a7a4a"), k)
	_eye(Vector2(size.x * 0.3, size.y * 0.42), size.x * 0.15, 0.7, iris, false, PAPER.lerp(Color("#ffdcdc"), 1.0 - k))
	_eye(Vector2(size.x * 0.7, size.y * 0.42), size.x * 0.15, 0.7, iris, false, PAPER.lerp(Color("#ffdcdc"), 1.0 - k))


func _s_hero_shock() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	_tone_rect(Rect2(Vector2.ZERO, size), 0.4)
	_sprite(_unit("stairborn"), Vector2(size.x * 0.5, size.y * 1.1), size.y * 1.0)
	draw_circle(Vector2(size.x * 0.62, size.y * 0.22), 6.0, Color("#bfe6ff"))


func _s_souls_rise() -> void:
	_sky(Color("#0e0c14"), Color("#2a2440"))
	var g := size.y * 0.9
	_ground(g)
	for i in 3:
		_figure(Vector2(size.x * (0.2 + i * 0.3), g), size.y * 0.18, "adult", Color("#2a2832"), 1.4)
	var soul := PixelArt.icon("soul")
	for i in 9:
		var ph := fmod(t * 0.25 + i * 0.11, 1.0)
		var p := Vector2(size.x * (0.15 + fmod(i * 0.37, 0.7)) + sin(t * 2.0 + i) * 8.0, g - ph * size.y * 0.85)
		if soul != null:
			draw_texture_rect(soul, Rect2(p - Vector2(10, 10), Vector2(20, 20)), false, Color(1, 1, 1, 1.0 - ph * 0.6))


func _s_first_step_souls() -> void:
	_sky(Color("#1d1a2b"), Color("#5a5378"))
	var g := size.y * 0.78
	_tower(size.x * 0.5, size.x * 0.5, -10.0, g, PAPER, INK, Color("#5a5378"))
	_ground(g)
	var hero_feet := Vector2(size.x * 0.5, g)
	_sprite(_unit("stairborn"), hero_feet, size.y * 0.24)
	var soul := PixelArt.icon("soul")
	for i in 7:
		var a := t * 1.2 + i * TAU / 7.0
		var p := hero_feet + Vector2(cos(a) * size.x * 0.3, -size.y * 0.15 + sin(a) * size.y * 0.06)
		if soul != null:
			draw_texture_rect(soul, Rect2(p - Vector2(9, 9), Vector2(18, 18)), false)


func _s_guardian_armor() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#2a2730"))
	_tone_rect(Rect2(Vector2.ZERO, size), 0.5)
	var g := size.y * 0.86
	_ground(g)
	for i in 14:
		var p := Vector2(size.x * (0.08 + fmod(i * 0.43, 0.84)), g - fmod(i * 7.3, 3.0) * 6.0)
		draw_circle(p, 10.0 + fmod(i * 5.1, 12.0), Color("#5a5560"))
		draw_arc(p, 10.0 + fmod(i * 5.1, 12.0), PI, TAU, 10, INK, 2.0)
	_sprite(_item("gravebound_chest"), Vector2(size.x * 0.45, g + 4.0), size.y * 0.42, -0.15)
	_sprite(_item("gravebound_helm"), Vector2(size.x * 0.62, g + 2.0), size.y * 0.22, 0.6)
	_pendant(Vector2(size.x * 0.32, g - size.y * 0.05), size.y * 0.04)


## A small gold pendant engraved with a spiral stair (the mark of Aria's party).
func _pendant(c: Vector2, r: float) -> void:
	draw_circle(c, r * 2.4, Color(1, 0.85, 0.4, 0.18 + 0.1 * sin(t * 3.0)))
	draw_arc(c + Vector2(0, -r * 1.6), r * 1.2, PI * 0.15, PI * 0.85, 12, GOLD.darkened(0.3), maxf(1.5, r * 0.12))
	draw_circle(c, r, GOLD)
	draw_arc(c, r, 0, TAU, 24, INK, maxf(1.5, r * 0.12))
	var pts := PackedVector2Array()
	for i in 41:
		var u := i / 40.0
		var a := u * TAU * 2.25
		pts.append(c + Vector2(cos(a), sin(a)) * r * 0.75 * u)
	draw_polyline(pts, INK, maxf(1.5, r * 0.1))
	var glint := c + Vector2(cos(t * 2.0), sin(t * 2.0)) * r * 0.5
	draw_circle(glint, maxf(1.5, r * 0.12), Color.WHITE)


func _s_pendant_close() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#141216"))
	_tone_rect(Rect2(Vector2.ZERO, size), 0.6)
	_pendant(Vector2(size.x * 0.5, size.y * 0.62), size.y * 0.2)


func _s_hero_tears() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	_tone_rect(Rect2(0, 0, size.x, size.y), 0.3)
	_sprite(_unit("stairborn"), Vector2(size.x * 0.5, size.y * 1.15), size.y * 1.05)
	var drop := Vector2(size.x * 0.56, size.y * 0.42 + fmod(t * 30.0, size.y * 0.2))
	draw_circle(drop, 5.0, Color("#bfe6ff"))
	draw_arc(drop, 5.0, 0, TAU, 12, INK, 1.5)


# ================================================================== scenes (chapter 4)

func _s_nightmare_tower() -> void:
	_sky(Color("#000000"), Color("#3a0a10"))
	_tower(size.x * 0.5, size.y * 0.3, -10.0, size.y * 0.95, Color("#e8d8d8"), Color("#5a0a14"), Color("#3a0a10"))
	_eye(Vector2(size.x * 0.5, size.y * 0.22), size.x * 0.12, 0.6 + 0.3 * sin(t), Color("#ff2020"), false, Color("#ffe0e0"))
	_ground(size.y * 0.95)


func _s_lord_sigil() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#2a0c10"))
	var c := size * 0.5
	for i in 16:
		var a := i * TAU / 16.0 + t * 0.3
		draw_line(c, c + Vector2(cos(a), sin(a)) * size.length(), Color(1, 0.8, 0.4, 0.25), 8.0)
	var tex := _item("cons_lords_sigil")
	if tex != null:
		draw_texture_rect(tex, Rect2(c - Vector2.ONE * size.y * 0.3, Vector2.ONE * size.y * 0.6), false)
	draw_line(c + Vector2(-size.y * 0.05, -size.y * 0.25), c + Vector2(size.y * 0.04, 0), Color.WHITE, 3.0)
	draw_line(c + Vector2(size.y * 0.04, 0), c + Vector2(-size.y * 0.02, size.y * 0.22), Color.WHITE, 3.0)


func _s_gilt_laughs() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	_tone_rect(Rect2(0, size.y * 0.6, size.x, size.y * 0.4), 0.6)
	var shake := sin(t * 18.0) * 3.0
	_sprite(_unit("ember_imp", 0.13, ["halo", "crown"]), Vector2(size.x * 0.5 + shake, size.y * 0.95), size.y * 0.6)
	draw_circle(Vector2(size.x * 0.75, size.y * 0.8), size.y * 0.13, Color("#8a5a2a"))
	for i in 7:
		draw_circle(Vector2(size.x * (0.68 + fmod(i * 0.13, 0.15)), size.y * (0.68 + fmod(i * 0.21, 0.1))), 5.0, GOLD)


func _s_hero_vs_nightmare() -> void:
	_sky(Color("#000000"), Color("#4a0a14"))
	_tower(size.x * 0.62, size.x * 0.4, -10.0, size.y * 0.9, Color("#e8d8d8"), Color("#5a0a14"), Color("#4a0a14"))
	for sx in [-1.0, 1.0]:
		_eye(Vector2(size.x * 0.62 + sx * size.x * 0.07, size.y * 0.28), size.x * 0.05, 0.7, Color("#ff2020"), false, Color("#ffe0e0"))
	_ground(size.y * 0.9)
	var cls := ["arcanist", "ranger", "knight"]
	for i in cls.size():
		_sprite(_unit(cls[i]), Vector2(size.x * (0.08 + i * 0.08), size.y * 0.9), size.y * 0.22, 0.0, 0.85)
	_sprite(_unit("stairborn"), Vector2(size.x * 0.34, size.y * 0.9), size.y * 0.34)


# ================================================================== scenes (chapter 5)

## Carved names on stone blocks: dashes of different lengths, a few glowing.
func _s_wall_names() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#6a6458"))
	var bw := size.x / 7.0
	var bh := size.y / 6.0
	for row in 7:
		for col in 8:
			var r := Rect2(col * bw - (bw * 0.5 if row % 2 == 1 else 0.0), row * bh, bw, bh)
			draw_rect(r, Color("#7a7468") if (row + col) % 3 else Color("#706a5e"))
			draw_rect(r, INK, false, 2.0)
			for line in 3:
				var ln := bw * (0.3 + fmod((row * 7 + col * 3 + line) * 0.37, 0.5))
				var p := r.position + Vector2(bw * 0.1, bh * (0.28 + line * 0.24))
				var lit := (row * 8 + col + line) % 17 == 0
				draw_line(p, p + Vector2(ln, 0), Color(1, 0.85, 0.5, 0.6 + 0.4 * sin(t * 2.0 + row)) if lit else Color("#3a3630"), 3.0)
	_sprite(_unit("stairborn"), Vector2(size.x * 0.82, size.y * 1.02), size.y * 0.42, 0.0, 1.0, true)


func _s_finger_name() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#5a554a"))
	_tone_rect(Rect2(Vector2.ZERO, size), 0.4)
	var f := _font()
	var fs := _fit(f, "ARIA", int(size.y * 0.3), size.x - 40.0)
	var glow := 0.55 + 0.45 * sin(t * 2.0)
	var y := size.y * 0.68
	draw_string(f, Vector2(2, y + 3), "ARIA", HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color("#2a2620"))
	draw_string(f, Vector2(0, y), "ARIA", HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color(1.0, 0.82, 0.45).lerp(Color("#8a8070"), 1.0 - glow))


func _s_own_name() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#4a453c"))
	_tone_rect(Rect2(Vector2.ZERO, size), 0.5)
	var f := _font()
	var carved := hero_name.to_upper()
	var fs := _fit(f, carved, int(size.y * 0.22), size.x - 40.0)
	var shown := carved.substr(0, mini(carved.length(), int(t * 2.5) % (carved.length() + 4)))
	var y := size.y * 0.55
	var w := f.get_string_size(carved, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x0 := (size.x - w) * 0.5
	draw_string(f, Vector2(x0 + 2, y + 3), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#1e1b16"))
	draw_string(f, Vector2(x0, y), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#c8bfa8"))
	if shown.length() < carved.length():
		var tip := Vector2(x0 + f.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, y - fs * 0.35)
		for i in 6:
			var a := t * 9.0 + i
			draw_line(tip, tip + Vector2(cos(a), sin(a)) * (8.0 + i * 2.0), GOLD, 2.0)


func _s_tower_voice() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#050406"))
	var c := Vector2(size.x * 0.5, size.y * 0.55)
	for i in 3:
		draw_arc(c, size.y * (0.3 + i * 0.12) + sin(t * 2.0 + i) * 4.0, 0, TAU, 48, Color(0.6, 0.05, 0.1, 0.5 - i * 0.12), 3.0)
	_eye(c, size.x * 0.16, 0.5 + 0.25 * sin(t * 0.8), Color("#ff2020"), false, Color("#ffe0e0"))


func _s_first_climber() -> void:
	_sky(Color("#120e1c"), Color("#4a3a6a"))
	_stars(40, size.y * 0.5)
	var top := size.y * 0.55
	_tower(size.x * 0.5, size.x * 0.34, top, size.y + 10.0, LIGHT, INK, Color(0, 0, 0, 0))
	var c := Vector2(size.x * 0.5, top - size.y * 0.02)
	for i in 12:
		var a := i * TAU / 12.0 + t * 0.2
		draw_line(c + Vector2(cos(a), sin(a)) * size.y * 0.12, c + Vector2(cos(a), sin(a)) * size.y * 0.4, Color(1, 0.9, 0.6, 0.25), 3.0)
	_figure(Vector2(size.x * 0.5, top), size.y * 0.3, "adult", INK)
	var head := Vector2(size.x * 0.5, top - size.y * 0.3 * 0.8 - size.y * 0.3 * 0.1 * 0.9)
	var cw := size.y * 0.035
	draw_colored_polygon(PackedVector2Array([head + Vector2(-cw, -cw * 0.6), head + Vector2(-cw, -cw * 1.8), head + Vector2(-cw * 0.4, -cw * 1.1),
		head + Vector2(0, -cw * 2.0), head + Vector2(cw * 0.4, -cw * 1.1), head + Vector2(cw, -cw * 1.8), head + Vector2(cw, -cw * 0.6)]), GOLD)


func _s_hero_grip() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#3a0a10"))
	_sprite(_unit("stairborn"), Vector2(size.x * 0.5, size.y * 1.12), size.y * 1.0)


func _s_summit_call() -> void:
	_sky(Color("#0a0812"), Color("#3a2a50"))
	_stars(70, size.y * 0.7)
	var g := size.y * 0.8
	var cx := size.x * 0.62
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 20, 0), Vector2(cx + 20, 0), Vector2(cx + size.x * 0.12, g), Vector2(cx - size.x * 0.12, g)]), Color(1, 0.9, 0.6, 0.12 + 0.05 * sin(t * 2.0)))
	_tower(cx, size.y * 0.3, -10.0, g, PAPER, INK, Color("#3a2a50"))
	_ground(g)
	_steps(Vector2(size.x * 0.04, g), 6, size.x * 0.1, size.y * 0.045)
	var cls := ["ranger", "arcanist", "knight", "stairborn"]
	for i in cls.size():
		var x := size.x * (0.1 + i * 0.1)
		var step_y := g - int((x - size.x * 0.04) / (size.x * 0.1)) * size.y * 0.045
		_sprite(_unit(cls[i]), Vector2(x, step_y), size.y * (0.2 if i < 3 else 0.26))
