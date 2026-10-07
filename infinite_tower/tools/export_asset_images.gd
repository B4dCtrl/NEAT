extends SceneTree
## Renders every picture of the game to a PNG (nearest-neighbour, enlarged) so
## a document can show them: heroes, monsters (with their colour variants),
## bosses, item bases, set pieces' icons, relics, consumables, UI icons and the
## skill / talent glyphs. Uses the same PixelArt code as the game.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/export_asset_images.gd -- <out_dir>
## Writes <out_dir>/<group>/<id>.png and <out_dir>/index.json.

const DataDB = preload("res://core/data_db.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")
const Glyphs = preload("res://scenes/ui/menu/glyphs.gd")

var out_dir := "user://asset_images"
var index := []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	_run()


func _save(group: String, id: String, tex: Texture2D, target: float = 112.0) -> void:
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var s := maxi(1, int(round(target / float(maxi(w, h)))))
	var big := img.duplicate()
	big.resize(w * s, h * s, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(out_dir.path_join(group))
	big.save_png(out_dir.path_join(group).path_join(id + ".png"))
	index.append({"group": group, "id": id, "w": w, "h": h, "scale": s, "png": ResourceLoader.exists("res://assets/sprites/" + id + ".png")})


func _run() -> void:
	await process_frame
	var classes := DataDB.classes()
	for id in classes:
		_save("classes", id, PixelArt.unit_frames(id, classes[id]["sprite"], {}, false)[0])
	for id in DataDB.enemies():
		var d: Dictionary = DataDB.enemies()[id]
		var f := PixelArt.unit_frames(String(d.get("art", id)), d["sprite"], d.get("palette", {}), false, float(d.get("hue", -1.0)), d.get("fx", []))
		_save("enemies", id, f[0] if not f.is_empty() else null)
	for id in DataDB.bosses():
		var d: Dictionary = DataDB.bosses()[id]
		var f := PixelArt.unit_frames(String(d.get("art", id)), d["sprite"], d.get("palette", {}), false, float(d.get("hue", -1.0)), d.get("fx", []))
		_save("bosses", id, f[0] if not f.is_empty() else null, 144.0)
	for b in DataDB.items()["bases"]:
		var f := PixelArt.frames(b.get("icon", "item_" + String(b["slot"])), {}, false)
		_save("items", b["id"], f[0] if not f.is_empty() else null)
	for slot in DataDB.items()["slots"]:
		var f2 := PixelArt.frames("item_" + ("sword" if slot == "weapon" else String(slot)), {}, false)
		_save("slots", slot, f2[0] if not f2.is_empty() else null)
	_save("relics", "relic", PixelArt.icon("relic"))
	for id in DataDB.items()["consumables"]:
		var c: Dictionary = DataDB.items()["consumables"][id]
		var f3 := PixelArt.frames(c["icon"], {}, false)
		_save("consumables", id, f3[0] if not f3.is_empty() else null)
	for icon in ["coin", "skull", "relic", "soul", "crystal", "floor", "sword", "market"]:
		_save("icons", icon, PixelArt.icon(icon))
	# Skill, talent and menu glyphs.
	var seen := {}
	for cid in DataDB.table("skills")["classes"]:
		for nid in DataDB.table("skills")["classes"][cid]["nodes"]:
			var g: String = DataDB.table("skills")["classes"][cid]["nodes"][nid].get("icon", "star")
			if not seen.has(g):
				seen[g] = true
				_save("glyphs", g, Glyphs.texture(g), 64.0)
	for g in ["helm", "banner", "tree", "book", "bag", "star", "skull", "gear", "expand", "close", "coin", "lock", "heart", "drop", "cross"]:
		if not seen.has(g):
			seen[g] = true
			_save("glyphs", g, Glyphs.texture(g), 64.0)
	_sheets()
	var f4 := FileAccess.open(out_dir.path_join("index.json"), FileAccess.WRITE)
	f4.store_string(JSON.stringify(index))
	print("exported %d images to %s" % [index.size(), out_dir])
	quit()


## Contact sheets (one per group) so a whole group can be reviewed at a glance.
func _sheets() -> void:
	var by_group := {}
	for e in index:
		if not by_group.has(e["group"]):
			by_group[e["group"]] = []
		by_group[e["group"]].append(e)
	for group in by_group:
		var cell := 150 if group in ["bosses", "enemies"] else 120
		var cols := 8
		var rows := ceili(by_group[group].size() / float(cols))
		var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
		sheet.fill(Color("#1a1824"))
		for i in by_group[group].size():
			var im := Image.load_from_file(out_dir.path_join(group).path_join(by_group[group][i]["id"] + ".png"))
			if im == null:
				continue
			im.convert(Image.FORMAT_RGBA8)
			sheet.blend_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i((i % cols) * cell + (cell - im.get_width()) / 2, (i / cols) * cell + (cell - im.get_height()) / 2))
		sheet.save_png(out_dir.path_join("_sheet_" + group + ".png"))
