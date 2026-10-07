extends SceneTree
## Writes one PNG strip per fx monster showing all its animation frames.
##   godot --path . -s res://tools/fx_strip.gd -- <out_dir> [id ...]
const DataDB = preload("res://core/data_db.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var ids: Array = args.slice(1)
	for group in ["enemies", "bosses"]:
		var table: Dictionary = DataDB.enemies() if group == "enemies" else DataDB.bosses()
		for id in table:
			var d: Dictionary = table[id]
			if not d.has("fx") or (not ids.is_empty() and not id in ids):
				continue
			var f := PixelArt.unit_frames(String(d.get("art", id)), d["sprite"], d.get("palette", {}), false, float(d.get("hue", -1.0)), d["fx"])
			var w: int = f[0].get_width() * 3
			var h: int = f[0].get_height() * 3
			var sheet := Image.create(w * f.size(), h, false, Image.FORMAT_RGBA8)
			sheet.fill(Color("#1a1824"))
			for i in f.size():
				var im: Image = f[i].get_image()
				im.convert(Image.FORMAT_RGBA8)
				im.resize(w, h, Image.INTERPOLATE_NEAREST)
				sheet.blend_rect(im, Rect2i(0, 0, w, h), Vector2i(i * w, 0))
			sheet.save_png(out.path_join(id + ".png"))
	quit()
