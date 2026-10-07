extends MarginContainer
## Every monster and guardian met so far, with kill counts.

const DataDB = preload("res://core/data_db.gd")
const TowerGen = preload("res://core/tower_generator.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")
const Loc = preload("res://core/loc.gd")

var _tree: Tree


func _ready() -> void:
	_tree = Tree.new()
	_tree.columns = 5
	_tree.hide_root = true
	_tree.column_titles_visible = true
	for i in 5:
		_tree.set_column_title(i, ["", Loc.t("Name"), Loc.t("Kills"), Loc.t("First seen"), Loc.t("Type")][i])
	_tree.set_column_expand(0, false)
	_tree.set_column_custom_minimum_width(0, 40)
	add_child(_tree)
	visibility_changed.connect(_rebuild)


func _rebuild() -> void:
	if not is_visible_in_tree():
		return
	_tree.clear()
	var root := _tree.create_item()
	var seen: Dictionary = Game.state["bestiary"]
	var all := {}
	for id in DataDB.enemies():
		all[id] = "Monster"
	for id in DataDB.bosses():
		all[id] = "Guardian"
	for id in all:
		var def := DataDB.unit_def(id)
		var row := _tree.create_item(root)
		if seen.has(id):
			var tex: Texture2D = PixelArt.frames(def["sprite"], def.get("palette", {}))[0]
			row.set_icon(0, tex)
			row.set_icon_max_width(0, 24)
			row.set_text(1, def["name"])
			row.set_text(2, str(int(seen[id]["kills"])))
			row.set_text(3, Loc.t("Floor %d") % int(seen[id]["first_floor"]))
		else:
			row.set_text(1, "???")
			row.set_text(2, "-")
			row.set_text(3, "-")
			row.set_custom_color(1, Color("#5a566a"))
		row.set_text(4, Loc.t(all[id]))
		if all[id] == "Guardian":
			row.set_custom_color(4, Color("#ff6b6b"))
