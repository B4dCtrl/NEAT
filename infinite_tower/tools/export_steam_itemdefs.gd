extends SceneTree
## Generates the Steam Inventory Service item-definition schema from the game data.
##   godot --headless --path . -s res://tools/export_steam_itemdefs.gd -- steam/itemdefs.json
## Upload the result in Steamworks > Inventory Service > Item Definitions.
## Tradable/marketable: relics and Legendary+ set pieces (one definition per set piece).

const DataDB = preload("res://core/data_db.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if not args.is_empty() else "res://steam/itemdefs.json"
	var cfg: Dictionary = DataDB.platform()
	var inv: Dictionary = cfg["steam_inventory"]
	var next_id := int(inv["itemdef_base"])
	var items := []
	for relic_id in DataDB.relics():
		var r: Dictionary = DataDB.relics()[relic_id]
		items.append(_def(next_id, r["name"], r["description"], "relic", relic_id))
		next_id += 1
	for set_id in DataDB.sets():
		var s: Dictionary = DataDB.sets()[set_id]
		for slot in s["pieces"]:
			items.append(_def(next_id, s["pieces"][slot], "%s set · %s" % [s["name"], slot.capitalize()], "set_piece", "%s:%s" % [set_id, slot]))
			next_id += 1
	# Playtime generator: Steam rolls one of the relic definitions for time played.
	var bundle := []
	for it in items:
		if it["tags"].begins_with("kind:relic"):
			bundle.append("%d" % it["itemdefid"])
	items.append({
		"itemdefid": int(inv["playtime_drop_itemdef"]),
		"type": "playtimegenerator",
		"bundle": ";".join(bundle),
		"name": "Stairborn playtime drop",
		"drop_interval": 120,
	})
	var schema := {"appid": int(cfg["steam_app_id"]), "items": items}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path).get_base_dir())
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(schema, "\t"))
	print("Wrote %d item definitions to %s" % [items.size(), out_path])
	quit()


func _def(id: int, item_name: String, desc: String, kind: String, game_id: String) -> Dictionary:
	return {
		"itemdefid": id,
		"type": "item",
		"name": item_name,
		"description": desc,
		"tradable": true,
		"marketable": true,
		"icon_url": "",
		"tags": "kind:%s;game_id:%s" % [kind, game_id],
	}
