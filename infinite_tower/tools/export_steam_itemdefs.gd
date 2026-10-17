extends SceneTree
## Generates the Steam Inventory Service item-definition schema from the game data.
##   godot --headless --path . -s res://tools/export_steam_itemdefs.gd -- steam/itemdefs.json
## Upload the result in Steamworks > Inventory Service > Item Definitions.
## Also paints a market picture for every tradable set piece (a framed card in
## the set's colours, the Legendary aura, 256 px and 96 px) next to the json, in
## <dir>/icons/<id>_256.png and <id>_96.png. Host them somewhere public and set
## steam_inventory.icon_base_url in data/platform.json: the itemdefs then point
## at them (icon_url / icon_url_large).
## Follows core/trade.gd: cosmetics, Lord's Sigils and Legendary set pieces are
## tradable/marketable; a playtime generator drops Climber's Cache cosmetics with
## the same odds and weekly cap as the game.

const DataDB = preload("res://core/data_db.gd")
const Cosmetics = preload("res://core/cosmetics.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if not args.is_empty() else "res://steam/itemdefs.json"
	_run(out_path)


func _run(out_path: String) -> void:
	await process_frame
	var icons_dir := ProjectSettings.globalize_path(out_path).get_base_dir().path_join("icons")
	DirAccess.make_dir_recursive_absolute(icons_dir)
	var cfg: Dictionary = DataDB.platform()
	var inv: Dictionary = cfg["steam_inventory"]
	var next_id := int(inv["itemdef_base"])
	var items := []
	var weights := []
	var odds: Dictionary = Cosmetics.rules()["cache"]["odds"]
	var per_rarity := {}
	for id in Cosmetics.items():
		var r: String = Cosmetics.items()[id]["rarity"]
		per_rarity[r] = int(per_rarity.get(r, 0)) + 1
	for id in Cosmetics.items():
		var c: Dictionary = Cosmetics.items()[id]
		items.append(_def(next_id, c.get("name_en", c["name"]), "%s · %s · %s" % [c["kind"].capitalize(), DataDB.rarities()[c["rarity"]].get("name_en", c["rarity"]), c["series"]], "cosmetic", id, c["rarity"]))
		# Steam bundle weights: the cache odds split evenly inside each rarity (x1000 for integers).
		weights.append("%dx%d" % [next_id, maxi(1, roundi(float(odds[c["rarity"]]) * 1000.0 / per_rarity[c["rarity"]]))])
		next_id += 1
	var sig: Dictionary = DataDB.items()["consumables"]["lords_sigil"]
	items.append(_def(next_id, sig.get("name_en", sig["name"]), sig.get("text_en", sig["text"]), "consumable", "lords_sigil", "rare"))
	next_id += 1
	for set_id in DataDB.sets():
		var s: Dictionary = DataDB.sets()[set_id]
		for b in DataDB.items()["bases"]:
			if b["set"] != set_id:
				continue
			var d := _def(next_id, "%s (Legendary)" % b.get("name_en", b["name"]), "%s set · tier %d · %s · %s only" % [s.get("name_en", s["name"]), int(s["tier"]), String(b["slot"]).capitalize(), String(b["class"]).capitalize()], "set_piece", String(b["id"]), "legendary")
			if _market_icon(b, s, icons_dir):
				var base_url := String(inv.get("icon_base_url", ""))
				if base_url != "":
					d["icon_url"] = "%s/%s_96.png" % [base_url.trim_suffix("/"), b["id"]]
					d["icon_url_large"] = "%s/%s_256.png" % [base_url.trim_suffix("/"), b["id"]]
			items.append(d)
			next_id += 1
	var cache: Dictionary = Cosmetics.rules()["cache"]
	items.append({
		"itemdefid": int(inv["playtime_drop_itemdef"]),
		"type": "playtimegenerator",
		"bundle": ";".join(weights),
		"name": "Climber's Cache",
		"drop_interval": int(cache["every_minutes"]),
		"drop_window": 10080,
		"drop_max_per_window": int(cache["weekly_cap"]),
	})
	var schema := {"appid": int(cfg["steam_app_id"]), "items": items}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path).get_base_dir())
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(schema, "\t"))
	print("Wrote %d item definitions to %s" % [items.size(), out_path])
	quit()


## A framed card for the Community Market: set colours, a soft glow behind the
## piece, the Legendary aura. Returns false when the piece has no picture.
func _market_icon(b: Dictionary, set_def: Dictionary, dir: String) -> bool:
	var tex: Texture2D = PixelArt.item_icon({"base": b["id"], "slot": b["slot"], "rarity": "legendary"}, false)
	if tex == null:
		return false
	var src := tex.get_image()
	src.convert(Image.FORMAT_RGBA8)
	var art: Dictionary = set_def["art"]
	var dark := Color(art["dark"]).darkened(0.7)
	var glow := Color(art["glow"])
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - n * 0.5, y - n * 0.5).length() / (n * 0.5)
			var c := dark.lerp(Color.BLACK, float(y) / n * 0.5)
			c = c.lerp(glow, clampf(1.0 - d * 1.15, 0.0, 1.0) * 0.38)
			img.set_pixel(x, y, c)
	var scale := maxi(1, int(floor(n * 0.78 / maxi(src.get_width(), src.get_height()))))
	var big := src.duplicate()
	big.resize(src.get_width() * scale, src.get_height() * scale, Image.INTERPOLATE_NEAREST)
	var at := Vector2i((n - big.get_width()) / 2, (n - big.get_height()) / 2)
	# Contact shadow under the piece.
	for x in range(at.x + 24, at.x + big.get_width() - 24):
		for y in range(n - 40, n - 30):
			var k := 1.0 - absf(y - (n - 35)) / 6.0
			var px := img.get_pixel(x, y)
			img.set_pixel(x, y, px.lerp(Color.BLACK, 0.4 * clampf(k, 0.0, 1.0)))
	img.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), at)
	# Gold double frame.
	var gold := Color("#e0ac48")
	for i in 3:
		for t in n - i * 2 - 4:
			img.set_pixel(2 + i + t, 2 + i, gold if i != 1 else gold.darkened(0.5))
			img.set_pixel(2 + i + t, n - 3 - i, gold if i != 1 else gold.darkened(0.5))
			img.set_pixel(2 + i, 2 + i + t, gold if i != 1 else gold.darkened(0.5))
			img.set_pixel(n - 3 - i, 2 + i + t, gold if i != 1 else gold.darkened(0.5))
	img.save_png(dir.path_join(String(b["id"]) + "_256.png"))
	var small := img.duplicate()
	small.resize(96, 96, Image.INTERPOLATE_LANCZOS)
	small.save_png(dir.path_join(String(b["id"]) + "_96.png"))
	return true


func _def(id: int, item_name: String, desc: String, kind: String, game_id: String, rarity: String) -> Dictionary:
	return {
		"itemdefid": id,
		"type": "item",
		"name": item_name,
		"description": desc,
		"tradable": true,
		"marketable": true,
		"icon_url": "",
		"name_color": DataDB.rarities()[rarity]["color"].trim_prefix("#"),
		"tags": "kind:%s;game_id:%s;rarity:%s" % [kind, game_id, rarity],
	}
