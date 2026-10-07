extends SceneTree
## Draws the pixel-art icon of every equipment piece (20 sets x 8 pieces) and every
## gem, from the set definitions in data/items.json (`art`: palette + motif).
## Each piece gets its own silhouette family (cycled by tier, then varied by the
## set's seed), the set palette, an emblem of the set's motif and a few motif
## particles. Rarity is applied at runtime by PixelArt.item_icon.
##   godot --headless --path . -s res://tools/gen_item_art.gd            # writes assets/sprites/<base>.png
##   godot --headless --path . -s res://tools/gen_item_art.gd -- sheet <dir>   # also writes contact sheets

const DataDB = preload("res://core/data_db.gd")
const N := 32

const EMBLEMS := {
	"none": [".4.", "444", ".4."],
	"bone": [".444.", "43434", "44444", ".4.4."],
	"ember": ["..4..", ".44..", ".444.", "44444", ".444."],
	"thorn": ["..44.", ".444.", "4444.", ".44..", "4...."],
	"bolt": ["..444", ".44..", "4444.", "..44.", ".4..."],
	"frost": ["4.4.4", ".444.", "44444", ".444.", "4.4.4"],
	"prism": ["..4..", ".444.", "44244", ".444.", "..4.."],
	"wave": ["4..4.", ".44.4", "4..44", ".44.."],
	"sun": ["4.4.4", ".444.", "44244", ".444.", "4.4.4"],
	"rivet": ["4...4", ".....", "..4..", ".....", "4...4"],
	"fang": ["4...4", "44.44", ".444.", "..4.."],
	"bloom": ["..4..", ".424.", "44244", ".424.", "..4.."],
	"eye": [".444.", "43234", ".444."],
	"wisp": [".44..", "4444.", "4444.", ".44.4", "....4"],
	"halo": [".444.", "4...4", ".444."],
	"scale": ["44.44", ".444.", "44.44"],
	"stars": ["..4..", "..4..", "44444", "..4..", "..4.."],
	"corona": [".444.", "4...4", "4...4", "4...4", ".444."],
	"regal": ["4.4.4", "44444", "44244", "44444"],
}
const PARTICLES := {
	"none": [], "bone": ["#7be07b", "#d8d2bd"], "ember": ["#ffb347", "#ff6a1c", "#ffe08a"],
	"thorn": ["#9be36b", "#4f8c3e"], "bolt": ["#fff070", "#ffffff"], "frost": ["#ffffff", "#bfefff", "#6fe0ff"],
	"prism": ["#ffffff", "#e07fe8", "#7fd6e8"], "wave": ["#bffffa", "#7cf0e0"], "sun": ["#ffe08a", "#ffffff"],
	"rivet": ["#ffd060", "#ff8a2a"], "fang": ["#ff4060", "#8c1f2f"], "bloom": ["#c06ae0", "#9bff6a"],
	"eye": ["#e05aff", "#ffffff"], "wisp": ["#8affd8", "#e8fff6"], "halo": ["#fff6a0", "#ffffff"],
	"scale": ["#ffcf4a", "#3a8a4a"], "stars": ["#ffffff", "#ffe680"], "corona": ["#ffd060", "#ff9a2a"],
	"regal": ["#f2c14e", "#9bd8ff", "#ffffff"],
}


## Index canvas: 0 empty, 1 main, 2 accent, 3 dark, 4 glow.
class Canvas extends RefCounted:
	var g := PackedInt32Array()

	func _init() -> void:
		g.resize(32 * 32)

	func px(x: int, y: int, k: int) -> void:
		if x >= 0 and x < 32 and y >= 0 and y < 32:
			g[y * 32 + x] = k

	func at(x: int, y: int) -> int:
		return g[y * 32 + x] if x >= 0 and x < 32 and y >= 0 and y < 32 else 0

	func rect(x: int, y: int, w: int, h: int, k: int) -> void:
		for j in h:
			for i in w:
				px(x + i, y + j, k)

	## Centered rectangle: half-width hw, mirrored around the 15/16 seam.
	func sr(y: int, h: int, hw: int, k: int) -> void:
		rect(16 - hw, y, hw * 2, h, k)

	func spx(dx: int, y: int, k: int) -> void:
		px(16 + dx, y, k)
		px(15 - dx, y, k)

	func line(x0: int, y0: int, x1: int, y1: int, k: int, thick: int = 1) -> void:
		var dx: int = absi(x1 - x0)
		var dy: int = -absi(y1 - y0)
		var sx: int = 1 if x0 < x1 else -1
		var sy: int = 1 if y0 < y1 else -1
		var err: int = dx + dy
		var x: int = x0
		var y: int = y0
		while true:
			rect(x - thick / 2, y - thick / 2, thick, thick, k)
			if x == x1 and y == y1:
				break
			var e2: int = 2 * err
			if e2 >= dy:
				err += dy
				x += sx
			if e2 <= dx:
				err += dx
				y += sy

	func disc(cx: float, cy: float, r: float, k: int) -> void:
		for y in range(int(cy - r - 1), int(cy + r + 2)):
			for x in range(int(cx - r - 1), int(cx + r + 2)):
				if Vector2(x + 0.5 - cx, y + 0.5 - cy).length() <= r:
					px(x, y, k)

	func ell(cx: float, cy: float, rx: float, ry: float, k: int) -> void:
		for y in range(int(cy - ry - 1), int(cy + ry + 2)):
			for x in range(int(cx - rx - 1), int(cx + rx + 2)):
				var d := Vector2((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
				if d.length() <= 1.0:
					px(x, y, k)

	func poly(pts: Array, k: int) -> void:
		var ys: Array = pts.map(func(p): return p.y)
		var y0: int = int(ys.min())
		var y1: int = int(ys.max())
		for y in range(y0, y1 + 1):
			var xs := []
			var m: int = pts.size()
			for i in m:
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[(i + 1) % m]
				if (a.y <= y + 0.5 and b.y > y + 0.5) or (b.y <= y + 0.5 and a.y > y + 0.5):
					xs.append(a.x + (y + 0.5 - a.y) / (b.y - a.y) * (b.x - a.x))
			xs.sort()
			var i2: int = 0
			while i2 + 1 < xs.size():
				for x in range(int(round(xs[i2])), int(round(xs[i2 + 1]))):
					px(x, y, k)
				i2 += 2

	## Mirrors the left half onto the right (x -> 31 - x).
	func mirror_left() -> void:
		for y in 32:
			for x in 16:
				if g[y * 32 + x] != 0:
					g[y * 32 + 31 - x] = g[y * 32 + x]


var out_dir := "res://assets/sprites/"
var sheet_dir := ""
var _pending := []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "sheet":
		sheet_dir = args[1]
	_run()


func _run() -> void:
	var sets := DataDB.sets()
	var tiers := {}
	var sheet_imgs := {}
	for b in DataDB.items()["bases"]:
		var s: Dictionary = sets[b["set"]]
		var key := _kind(b)
		var tier: int = int(s["tier"]) - 1
		var c := Canvas.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(b["id"])
		var v: int = (tier + _salt(key)) % 8
		_draw_piece(c, key, v, rng)
		_emblem(c, key, String(s["art"]["motif"]))
		var img := _render(c, s["art"], rng, b["id"])
		img.save_png(out_dir.path_join(b["id"] + ".png"))
		if sheet_dir != "":
			if not sheet_imgs.has(key):
				sheet_imgs[key] = []
			sheet_imgs[key].append(img)
	for gid in DataDB.relics():
		var d: Dictionary = DataDB.relics()[gid]
		if not d.has("gem"):
			continue
		var gi := _gem(d["gem"])
		gi.save_png(out_dir.path_join("gem_" + gid + ".png"))
		if sheet_dir != "":
			if not sheet_imgs.has("gems"):
				sheet_imgs["gems"] = []
			sheet_imgs["gems"].append(gi)
	if sheet_dir != "":
		DirAccess.make_dir_recursive_absolute(sheet_dir)
		for key in sheet_imgs:
			var imgs: Array = sheet_imgs[key]
			var cols: int = 10
			var rows: int = ceili(imgs.size() / float(cols))
			var sheet := Image.create(cols * 34, rows * 34, false, Image.FORMAT_RGBA8)
			sheet.fill(Color("#1a1824"))
			for i in imgs.size():
				var im: Image = imgs[i]
				sheet.blend_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i((i % cols) * 34 + 1, (i / cols) * 34 + 1))
			sheet.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
			sheet.save_png(sheet_dir.path_join("sheet_" + String(key).replace("/", "_") + ".png"))
	print("item art written")
	quit()


func _kind(b: Dictionary) -> String:
	if b["slot"] == "weapon":
		return "weapon_" + String(b["class"])
	return String(b["slot"])


func _salt(key: String) -> int:
	return {"weapon_knight": 0, "weapon_ranger": 3, "weapon_arcanist": 5, "helm": 1, "chest": 2, "gloves": 4, "boots": 6, "ring": 7}.get(key, 0)


# ------------------------------------------------------------------ rendering

func _render(c: Canvas, art: Dictionary, rng: RandomNumberGenerator, id: String) -> Image:
	var pal: Array = [Color(0, 0, 0, 0), Color(art["main"]), Color(art["accent"]), Color(art["dark"]), Color(art["glow"])]
	var outline: Color = Color(art["dark"]).darkened(0.65)
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in N:
		for x in N:
			var k: int = c.at(x, y)
			if k == 0:
				continue
			var col: Color = pal[k]
			if k != 4:
				var up: int = c.at(x, y - 1)
				var dn: int = c.at(x, y + 1)
				var lf: int = c.at(x - 1, y)
				var rt: int = c.at(x + 1, y)
				if up != k:
					col = col.lerp(Color.WHITE, 0.32)
				elif lf != k:
					col = col.lerp(Color.WHITE, 0.16)
				if dn != k:
					col = col.lerp(Color.BLACK, 0.30)
				elif rt != k:
					col = col.lerp(Color.BLACK, 0.16)
			else:
				if c.at(x, y - 1) != 4 or c.at(x - 1, y) != 4:
					col = col.lerp(Color.WHITE, 0.55)
			img.set_pixel(x, y, col)
	var edge := Image.create(N, N, false, Image.FORMAT_RGBA8)
	edge.fill(Color(0, 0, 0, 0))
	for y in N:
		for x in N:
			if c.at(x, y) == 0:
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if c.at(x + d.x, y + d.y) != 0:
						edge.set_pixel(x, y, outline)
						break
	for y in N:
		for x in N:
			if edge.get_pixel(x, y).a > 0.0:
				img.set_pixel(x, y, outline)
	# Motif particles in empty cells close to the piece.
	var cols: Array = PARTICLES.get(String(art["motif"]), [])
	if not cols.is_empty():
		var spots := []
		for y in N:
			for x in N:
				if img.get_pixel(x, y).a == 0.0 and _near(c, x, y, 3) and not _near(c, x, y, 1):
					spots.append(Vector2i(x, y))
		var n: int = mini(7, spots.size())
		for i in n:
			var p: Vector2i = spots.pop_at(rng.randi() % spots.size())
			img.set_pixel(p.x, p.y, Color(cols[rng.randi() % cols.size()]))
	return img


func _near(c: Canvas, x: int, y: int, r: int) -> bool:
	for j in range(-r, r + 1):
		for i in range(-r, r + 1):
			if c.at(x + i, y + j) != 0:
				return true
	return false


func _emblem(c: Canvas, key: String, motif: String) -> void:
	var pat: Array = EMBLEMS.get(motif, EMBLEMS["none"])
	var anchor := _anchor(key)
	var w: int = String(pat[0]).length()
	for j in pat.size():
		var row: String = pat[j]
		for i in row.length():
			var ch := row[i]
			if ch != ".":
				c.px(anchor.x - w / 2 + i, anchor.y + j, int(ch))


func _anchor(key: String) -> Vector2i:
	match key:
		"weapon_knight": return Vector2i(16, 21)
		"weapon_ranger": return Vector2i(16, 13)
		"weapon_arcanist": return Vector2i(16, 4)
		"helm": return Vector2i(16, 9)
		"chest": return Vector2i(16, 14)
		"gloves": return Vector2i(16, 15)
		"boots": return Vector2i(13, 8)
		"ring": return Vector2i(16, 20)
	return Vector2i(16, 16)


# ------------------------------------------------------------------ piece families

func _draw_piece(c: Canvas, key: String, v: int, rng: RandomNumberGenerator) -> void:
	match key:
		"weapon_knight": _knight_weapon(c, v, rng)
		"weapon_ranger": _bow(c, v, rng)
		"weapon_arcanist": _staff(c, v, rng)
		"helm": _helm(c, v, rng)
		"chest": _chest(c, v, rng)
		"gloves": _gloves(c, v, rng)
		"boots": _boots(c, v, rng)
		"ring": _ring(c, v, rng)


func _knight_weapon(c: Canvas, v: int, rng: RandomNumberGenerator) -> void:
	var len: int = rng.randi_range(12, 16)
	var hw: int = rng.randi_range(1, 2)
	match v:
		0, 3:   # sword / claymore
			if v == 3:
				hw = 3
				len = 16
			c.sr(4, len, hw, 1)
			c.sr(3, 1, hw - 1, 1)
			c.spx(0, 6, 2)
			for y in range(6, 4 + len - 1):
				c.px(15, y, 2)
				c.px(16, y, 2)
			c.sr(4 + len, 2, hw + 4, 2)
			c.sr(6 + len, 5, 1, 3)
			c.sr(11 + len, 2, 2, 2)
		1, 6:   # axe / double axe
			c.sr(4, 25, 1, 3)
			var head := [Vector2(17, 4), Vector2(27, 2), Vector2(29, 9), Vector2(27, 17), Vector2(17, 14), Vector2(21, 9)]
			c.poly(head, 1)
			c.line(27, 3, 28, 9, 2)
			c.line(28, 9, 27, 16, 2)
			if v == 6:
				var head2 := head.map(func(p): return Vector2(32 - p.x, p.y))
				c.poly(head2, 1)
				c.line(4, 3, 3, 9, 2)
				c.line(3, 9, 4, 16, 2)
			c.sr(2, 3, 1, 2)
			c.sr(28, 2, 2, 2)
		2:      # mace
			c.sr(13, 16, 1, 3)
			c.disc(15.5, 8, 6, 1)
			c.disc(15.5, 8, 3, 2)
			for a in 8:
				var ang: float = a * PI / 4.0
				c.px(int(15.5 + cos(ang) * 7.2), int(8 + sin(ang) * 7.2), 2)
			c.sr(26, 3, 2, 2)
		4:      # war hammer
			c.sr(10, 20, 1, 3)
			c.sr(3, 8, 8, 1)
			c.sr(3, 8, 2, 2)
			c.sr(5, 1, 8, 2)
			c.sr(28, 2, 2, 2)
		5:      # curved blade
			for t in 19:
				var x: int = 11 + int(round(5.0 * sin(t / 18.0 * 1.4)))
				c.rect(x, 3 + t, 3, 1, 1)
				c.px(x + 1, 3 + t, 2)
			c.sr(22, 2, 5, 2)
			c.sr(24, 5, 1, 3)
			c.sr(29, 2, 2, 2)
		7:      # halberd / spear
			c.sr(8, 22, 1, 3)
			c.poly([Vector2(16, 1), Vector2(21, 9), Vector2(16, 12), Vector2(11, 9)], 1)
			c.sr(8, 2, 3, 2)
			c.poly([Vector2(18, 12), Vector2(26, 14), Vector2(18, 18)], 1)
			c.sr(14, 3, 1, 2)


func _bow(c: Canvas, v: int, rng: RandomNumberGenerator) -> void:
	var amp: int = rng.randi_range(5, 9)
	if v == 4:
		amp += 4
	match v:
		0, 1, 3, 4, 6, 7:   # short / long / recurve / wide / spiked / twin-arrow
			var top: int = 2 if v == 1 else 4
			var bot: int = 29 if v == 1 else 27
			var span: int = bot - top
			for t in span + 1:
				var f: float = float(t) / span
				var x: int = 9 + int(round(amp * sin(f * PI)))
				if v == 3:
					x += int(round(-3.0 * sin(f * PI * 2.0)))
				c.rect(x, top + t, 3, 1, 1)
				c.px(x + 1, top + t, 2)
			c.line(22, top, 22, bot, 2)
			c.px(22, top, 1)
			c.px(22, bot, 1)
			if v == 7:
				c.line(11, 12, 26, 12, 3)
				c.poly([Vector2(26, 10), Vector2(30, 12), Vector2(26, 14)], 2)
			if v == 6:
				c.px(10, top + 1, 2)
				c.px(10, bot - 1, 2)
				c.px(9, top, 2)
				c.px(9, bot, 2)
			c.rect(14, 14, 3, 5, 3)   # grip
			if v != 3:
				c.line(11, 16, 26, 16, 3)
				c.poly([Vector2(26, 14), Vector2(30, 16), Vector2(26, 18)], 2)
				c.rect(11, 15, 3, 3, 2)
		2, 5:   # crossbows
			c.sr(8, 22, 1, 3)
			c.rect(15, 10, 2, 14, 1)
			var bw: int = 11 if v != 4 else 13
			c.sr(8, 3, bw, 1)
			c.sr(6, 2, bw, 2)
			c.line(16 - bw, 8, 16, 21, 2)
			c.line(15 + bw, 8, 15, 21, 2)
			c.sr(2, 8, 1, 2)
			c.poly([Vector2(16, 0), Vector2(19, 6), Vector2(13, 6)], 1)
			if v == 7:
				c.sr(26, 3, 3, 2)


func _staff(c: Canvas, v: int, rng: RandomNumberGenerator) -> void:
	match v:
		0:      # orb staff
			c.sr(10, 21, 1, 3)
			c.disc(15.5, 7, 5, 4)
			c.line(10, 12, 14, 9, 1)
			c.line(21, 12, 17, 9, 1)
			c.sr(11, 2, 2, 2)
		1:      # crescent
			c.sr(11, 20, 1, 3)
			c.disc(15.5, 7, 7, 1)
			c.disc(17.5, 7, 5, 0)
			c.disc(14, 7, 2, 4)
			c.sr(11, 2, 2, 2)
		2:      # crystal
			c.sr(13, 18, 1, 3)
			c.poly([Vector2(16, 0), Vector2(22, 8), Vector2(16, 15), Vector2(10, 8)], 4)
			c.poly([Vector2(16, 0), Vector2(16, 15), Vector2(10, 8)], 2)
			c.sr(13, 2, 3, 1)
		3:      # wand
			c.sr(12, 17, 1, 3)
			c.sr(10, 3, 2, 2)
			c.poly([Vector2(16, 0), Vector2(18, 4), Vector2(23, 5), Vector2(19, 8), Vector2(20, 12), Vector2(16, 10), Vector2(12, 12), Vector2(13, 8), Vector2(9, 5), Vector2(14, 4)], 4)
		4:      # tome
			c.rect(7, 4, 18, 23, 1)
			c.rect(7, 4, 3, 23, 3)
			c.rect(10, 6, 13, 19, 2)
			c.rect(24, 6, 1, 19, 3)
			c.rect(12, 4, 8, 1, 2)
			c.rect(13, 26, 6, 2, 2)
		5:      # skull staff
			c.sr(14, 17, 1, 3)
			c.ell(15.5, 8, 6, 6, 1)
			c.sr(13, 5, 3, 1)
			c.rect(11, 6, 3, 3, 3)
			c.rect(18, 6, 3, 3, 3)
			c.sr(10, 2, 1, 3)
			c.rect(13, 14, 1, 2, 3)
			c.rect(18, 14, 1, 2, 3)
		6:      # halo ring
			c.sr(12, 19, 1, 3)
			c.disc(15.5, 7, 7, 1)
			c.disc(15.5, 7, 4.5, 0)
			c.disc(15.5, 7, 2, 4)
			c.sr(12, 2, 2, 2)
		7:      # flame tip
			c.sr(12, 19, 1, 3)
			c.poly([Vector2(16, 0), Vector2(22, 7), Vector2(20, 12), Vector2(12, 12), Vector2(10, 7)], 4)
			c.poly([Vector2(16, 4), Vector2(19, 9), Vector2(16, 12), Vector2(13, 9)], 2)
			c.sr(12, 2, 3, 1)


func _helm(c: Canvas, v: int, rng: RandomNumberGenerator) -> void:
	match v:
		0:      # cap
			c.ell(15.5, 16, 10, 9, 1)
			c.rect(5, 17, 22, 8, 1)
			c.rect(5, 22, 22, 3, 2)
		1:      # great helm
			c.rect(7, 5, 18, 22, 1)
			c.rect(7, 5, 18, 3, 2)
			c.rect(9, 12, 14, 2, 3)
			c.rect(15, 9, 2, 14, 3)
			c.rect(7, 24, 18, 3, 2)
		2:      # horned
			c.ell(15.5, 17, 9, 8, 1)
			c.rect(7, 18, 18, 7, 1)
			c.rect(11, 21, 10, 4, 3)
			c.line(8, 14, 3, 6, 2, 2)
			c.line(24, 14, 29, 6, 2, 2)
			c.px(3, 5, 2)
			c.px(28, 5, 2)
		3:      # hood
			c.poly([Vector2(16, 2), Vector2(26, 14), Vector2(27, 27), Vector2(5, 27), Vector2(6, 14)], 1)
			c.ell(15.5, 19, 6, 7, 3)
			c.rect(12, 16, 2, 2, 4)
			c.rect(18, 16, 2, 2, 4)
			c.sr(25, 2, 11, 2)
		4:      # crown
			c.rect(6, 17, 20, 9, 1)
			c.rect(6, 22, 20, 3, 2)
			for i in 5:
				c.poly([Vector2(6 + i * 5, 17), Vector2(8.5 + i * 5, 7), Vector2(11 + i * 5, 17)], 1)
				c.px(8 + i * 5, 6 + (i % 2), 4)
		5:      # plumed
			c.ell(15.5, 16, 9, 9, 1)
			c.rect(6, 17, 20, 8, 1)
			c.rect(6, 22, 20, 3, 2)
			c.rect(10, 19, 12, 3, 3)
			c.line(16, 8, 24, 2, 2, 2)
			c.line(16, 9, 27, 7, 2, 2)
			c.line(17, 10, 28, 12, 2, 2)
		6:      # skull helm
			c.ell(15.5, 15, 10, 9, 1)
			c.rect(8, 19, 16, 8, 1)
			c.rect(10, 15, 4, 4, 3)
			c.rect(18, 15, 4, 4, 3)
			c.rect(15, 20, 2, 3, 3)
			c.rect(10, 24, 12, 2, 3)
			for i in 4:
				c.px(11 + i * 3, 25, 1)
		7:      # winged
			c.ell(15.5, 17, 8, 8, 1)
			c.rect(8, 18, 16, 7, 1)
			c.rect(8, 22, 16, 3, 2)
			c.poly([Vector2(8, 15), Vector2(1, 6), Vector2(2, 14), Vector2(0, 14), Vector2(5, 18)], 2)
			c.poly([Vector2(24, 15), Vector2(31, 6), Vector2(30, 14), Vector2(32, 14), Vector2(27, 18)], 2)


func _chest(c: Canvas, v: int, rng: RandomNumberGenerator) -> void:
	var torso := [Vector2(10, 5), Vector2(22, 5), Vector2(25, 9), Vector2(23, 14), Vector2(22, 27), Vector2(10, 27), Vector2(9, 14), Vector2(7, 9)]
	match v:
		0:      # plate
			c.poly(torso, 1)
			c.disc(7, 8, 4, 1)
			c.disc(25, 8, 4, 1)
			c.rect(15, 8, 2, 14, 2)
			c.rect(9, 22, 14, 3, 2)
		1:      # robe
			c.poly([Vector2(11, 4), Vector2(21, 4), Vector2(24, 8), Vector2(28, 28), Vector2(4, 28), Vector2(8, 8)], 1)
			c.rect(12, 4, 8, 4, 3)
			c.rect(8, 16, 16, 3, 2)
			c.rect(15, 19, 2, 9, 2)
		2:      # leather jerkin with straps
			c.poly(torso, 1)
			c.line(10, 7, 22, 24, 3, 2)
			c.line(22, 7, 10, 24, 3, 2)
			c.rect(14, 14, 4, 4, 2)
			c.rect(9, 24, 14, 3, 3)
		3:      # scale
			c.poly(torso, 1)
			for y in range(7, 26, 3):
				for x in range(10 + (y / 3 % 2) * 2, 23, 4):
					c.rect(x, y, 3, 2, 2)
		4:      # mail with spiked spaulders
			c.poly(torso, 1)
			c.rect(4, 5, 8, 6, 2)
			c.rect(20, 5, 8, 6, 2)
			c.px(6, 3, 2)
			c.px(25, 3, 2)
			c.rect(10, 22, 12, 2, 3)
		5:      # tabard
			c.poly(torso, 1)
			c.poly([Vector2(12, 5), Vector2(20, 5), Vector2(19, 29), Vector2(16, 26), Vector2(13, 29)], 2)
			c.rect(9, 16, 14, 2, 3)
		6:      # coat with high collar
			c.poly([Vector2(8, 6), Vector2(24, 6), Vector2(26, 12), Vector2(25, 28), Vector2(7, 28), Vector2(6, 12)], 1)
			c.poly([Vector2(8, 3), Vector2(14, 6), Vector2(16, 12), Vector2(18, 6), Vector2(24, 3), Vector2(22, 9), Vector2(10, 9)], 2)
			for i in 4:
				c.px(16, 14 + i * 3, 3)
		7:      # cuirass with sash
			c.poly(torso, 1)
			c.poly([Vector2(8, 7), Vector2(12, 7), Vector2(24, 22), Vector2(20, 24)], 2)
			c.rect(14, 15, 4, 4, 4)
			c.rect(9, 24, 14, 3, 3)


func _gloves(c: Canvas, v: int, rng: RandomNumberGenerator) -> void:
	# palm + cuff, fingers up
	c.rect(9, 13, 15, 9, 1)
	for i in 4:
		var h: int = 9 if i in [1, 2] else 7
		c.rect(9 + i * 4, 13 - h, 3, h + 1, 1)
		if v == 0 or v == 5:
			c.px(10 + i * 4, 13 - h + 1, 2)
	c.rect(4, 15, 5, 5, 1)   # thumb
	if v == 0:
		c.rect(4, 15, 5, 1, 2)
	c.rect(8, 22, 17, 7, 2)
	c.rect(8, 22, 17, 2, 1)
	match v:
		1:      # mitten
			c.rect(10, 5, 13, 9, 1)
			c.rect(15, 6, 1, 5, 3)
		2:      # claws
			for i in 4:
				c.px(11 + i * 3, 4, 2)
				c.px(11 + i * 3, 3, 2)
		3:      # wraps
			for y in range(14, 22, 2):
				c.rect(10, y, 13, 1, 3)
		4:      # spiked knuckles
			for i in 4:
				c.px(11 + i * 3, 7, 2)
				c.px(11 + i * 3, 6, 2)
		5:      # long cuff with gem
			c.rect(14, 24, 5, 4, 4)
		6:      # fingerless
			c.rect(10, 9, 13, 2, 3)
		7:      # plated back
			c.rect(12, 14, 9, 6, 2)


func _boots(c: Canvas, v: int, rng: RandomNumberGenerator) -> void:
	c.rect(8, 5, 10, 17, 1)
	c.rect(8, 20, 20, 7, 1)
	c.rect(8, 26, 20, 2, 3)
	c.rect(8, 5, 10, 3, 2)
	match v:
		1:      # greave with knee plate
			c.rect(7, 2, 12, 5, 2)
			c.rect(12, 8, 2, 12, 2)
		2:      # spiked toe
			c.poly([Vector2(27, 20), Vector2(31, 23), Vector2(27, 27)], 2)
		3:      # winged
			c.poly([Vector2(8, 13), Vector2(1, 8), Vector2(3, 14), Vector2(0, 16), Vector2(8, 18)], 2)
		4:      # sandal straps
			c.rect(8, 10, 10, 2, 3)
			c.rect(8, 15, 10, 2, 3)
			c.rect(9, 20, 2, 6, 3)
		5:      # fold-over cuff
			c.rect(6, 5, 14, 5, 2)
			c.rect(6, 10, 14, 1, 3)
		6:      # curled toe
			c.line(27, 22, 30, 17, 1, 2)
			c.px(30, 16, 2)
		7:      # segmented sabaton
			for y in range(21, 26, 2):
				c.rect(14, y, 14, 1, 3)
			c.rect(8, 14, 10, 1, 3)


func _ring(c: Canvas, v: int, rng: RandomNumberGenerator) -> void:
	c.disc(15.5, 19, 9, 1)
	c.disc(15.5, 19, 6, 0)
	match v:
		0:      # gem on band
			c.poly([Vector2(16, 3), Vector2(21, 8), Vector2(16, 13), Vector2(11, 8)], 4)
			c.rect(13, 11, 6, 2, 2)
		1:      # signet
			c.rect(9, 3, 14, 10, 2)
			c.rect(11, 5, 10, 6, 1)
		2:      # twisted
			for a in 16:
				var ang: float = a * PI / 8.0
				if a % 2 == 0:
					c.px(int(15.5 + cos(ang) * 8), int(19 + sin(ang) * 8), 2)
			c.poly([Vector2(16, 5), Vector2(19, 9), Vector2(16, 12), Vector2(13, 9)], 4)
		3:      # thorned
			for a in 8:
				var ang2: float = a * PI / 4.0 + PI / 8.0
				c.line(int(15.5 + cos(ang2) * 9), int(19 + sin(ang2) * 9), int(15.5 + cos(ang2) * 12), int(19 + sin(ang2) * 12), 2)
			c.disc(15.5, 8, 3, 4)
		4:      # double band
			c.disc(15.5, 19, 11, 1)
			c.disc(15.5, 19, 8, 0)
			c.disc(15.5, 6, 3, 4)
		5:      # skull
			c.ell(15.5, 8, 5, 5, 2)
			c.rect(12, 7, 3, 3, 3)
			c.rect(17, 7, 3, 3, 3)
		6:      # three gems
			c.disc(15.5, 9, 3, 4)
			c.disc(8, 12, 2, 4)
			c.disc(23, 12, 2, 4)
		7:      # crown ring
			for i in 3:
				c.poly([Vector2(10 + i * 5, 12), Vector2(12.5 + i * 5, 4), Vector2(15 + i * 5, 12)], 2)
			c.rect(10, 11, 11, 3, 2)
			c.px(16, 3, 4)


# ------------------------------------------------------------------ gems

func _gem(spec: Dictionary) -> Image:
	var col := Color(spec["color"])
	var cut: String = spec.get("cut", "round")
	var c := Canvas.new()
	match cut:
		"round":
			c.disc(15.5, 16, 10, 1)
		"diamond":
			c.poly([Vector2(16, 3), Vector2(27, 13), Vector2(16, 29), Vector2(5, 13)], 1)
		"emerald":
			c.poly([Vector2(10, 4), Vector2(22, 4), Vector2(27, 9), Vector2(27, 23), Vector2(22, 28), Vector2(10, 28), Vector2(5, 23), Vector2(5, 9)], 1)
		"pear":
			c.poly([Vector2(16, 2), Vector2(24, 14), Vector2(25, 22), Vector2(16, 29), Vector2(7, 22), Vector2(8, 14)], 1)
		"heart":
			c.disc(11, 11, 7, 1)
			c.disc(21, 11, 7, 1)
			c.poly([Vector2(4, 14), Vector2(28, 14), Vector2(16, 29)], 1)
		"hex":
			c.poly([Vector2(9, 5), Vector2(23, 5), Vector2(30, 16), Vector2(23, 27), Vector2(9, 27), Vector2(2, 16)], 1)
		"star":
			c.poly([Vector2(16, 2), Vector2(20, 12), Vector2(30, 13), Vector2(22, 19), Vector2(25, 29), Vector2(16, 23), Vector2(7, 29), Vector2(10, 19), Vector2(2, 13), Vector2(12, 12)], 1)
		"drop":
			c.poly([Vector2(16, 2), Vector2(24, 15)], 1)
			c.disc(15.5, 19, 9, 1)
			c.poly([Vector2(16, 2), Vector2(24, 16), Vector2(8, 16)], 1)
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dark := col.darkened(0.55)
	var outline := col.darkened(0.8)
	for y in N:
		for x in N:
			if c.at(x, y) == 0:
				continue
			# facets: lighter top-left, darker bottom-right, bright centre cross
			var t: float = (x + y) / 62.0
			var shade: Color = col.lerp(Color.WHITE, 0.45).lerp(col, clampf(t * 1.6, 0.0, 1.0)).lerp(dark, clampf(t - 0.5, 0.0, 0.5) * 1.4)
			if (x - 16 == y - 16) or (x - 16 == -(y - 16)):
				shade = shade.lerp(Color.WHITE, 0.18)
			if (x + y) % 7 == 0:
				shade = shade.darkened(0.1)
			img.set_pixel(x, y, shade)
	for y in N:
		for x in N:
			if c.at(x, y) == 0:
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if c.at(x + d.x, y + d.y) != 0:
						img.set_pixel(x, y, outline)
						break
	# sparkle
	for p in [Vector2i(10, 10), Vector2i(11, 10), Vector2i(10, 11), Vector2i(9, 10), Vector2i(10, 9)]:
		if c.at(p.x, p.y) != 0:
			img.set_pixel(p.x, p.y, Color.WHITE)
	return img
