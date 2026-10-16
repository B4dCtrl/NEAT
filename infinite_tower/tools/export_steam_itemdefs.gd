extends SceneTree
## Generates the Steam Inventory Service item-definition schema from the game data.
##   godot --headless --path . -s res://tools/export_steam_itemdefs.gd -- steam/itemdefs.json
## Upload the result in Steamworks > Inventory Service > Item Definitions.
## Follows core/trade.gd: cosmetics, Lord's Sigils and Legendary set pieces are
## tradable/marketable; a playtime generator drops Climber's Cache cosmetics with
## the same odds and weekly cap as the game.

const DataDB = preload("res://core/data_db.gd")
const Cosmetics = preload("res://core/cosmetics.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if not args.is_empty() else "res://steam/itemdefs.json"
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
			items.append(_def(next_id, "%s (Legendary)" % b.get("name_en", b["name"]), "%s set · tier %d · %s" % [s.get("name_en", s["name"]), int(s["tier"]), String(b["slot"]).capitalize()], "set_piece", String(b["id"]), "legendary"))
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
