extends MarginContainer
## Ascension (prestige): reset the climb for Souls, spend Souls on a permanent tree.

const DataDB = preload("res://core/data_db.gd")
const Progression = preload("res://core/progression.gd")
const UiUtil = preload("res://scenes/ui/ui_util.gd")
const Loc = preload("res://core/loc.gd")

var _info: Label
var _ascend_btn: Button
var _confirm: ConfirmationDialog
var _node_buttons := {}


func _ready() -> void:
	var v := VBoxContainer.new()
	add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_info = Label.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(_info)
	_ascend_btn = Button.new()
	_ascend_btn.focus_mode = Control.FOCUS_NONE
	_ascend_btn.pressed.connect(func(): _confirm.popup_centered())
	top.add_child(_ascend_btn)

	_confirm = ConfirmationDialog.new()
	_confirm.title = Loc.t("Ascend?")
	_confirm.dialog_text = Loc.t("Your party returns to the base of the tower.\nLevels, gear, gold and training are lost.\nSouls, Crystals, Gems and the Ascension Tree are kept.")
	_confirm.confirmed.connect(func(): Game.ascend())
	add_child(_confirm)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	scroll.add_child(grid)
	var nodes := DataDB.ascension_nodes()
	var max_row := 0
	for id in nodes:
		max_row = maxi(max_row, int(nodes[id]["row"]))
	# Lay nodes out on their (col,row) grid position; gaps are empty spacers.
	for r in max_row + 1:
		for c in 4:
			var found := ""
			for id in nodes:
				if int(nodes[id]["row"]) == r and int(nodes[id]["col"]) == c:
					found = id
			if found == "":
				grid.add_child(Control.new())
				continue
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(150, 72)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.add_theme_font_size_override("font_size", 12)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var node_id := found
			b.pressed.connect(func(): Game.buy_ascension_node(node_id); _refresh())
			grid.add_child(b)
			_node_buttons[found] = b
	Game.state_changed.connect(_refresh)
	visibility_changed.connect(_refresh)


func _refresh() -> void:
	if not is_visible_in_tree():
		return
	var s: Dictionary = Game.state
	var souls := Progression.souls_for_ascension(s)
	var min_floor := int(DataDB.balance()["ascension_min_floor"])
	_info.text = Loc.t("Souls: %s   ·   Ascensions: %d   ·   Best floor ever: %d\nAscending now would grant %s Souls (based on max floor %d this run%s).") % [
		UiUtil.num(s["souls"]), s["ascensions"], s["best_floor_ever"], UiUtil.num(souls), s["max_floor"],
		"" if souls > 0 else Loc.t(", requires floor %d") % min_floor]
	_ascend_btn.text = Loc.t("  ASCEND (+%s Souls)  ") % UiUtil.num(souls)
	_ascend_btn.disabled = souls <= 0
	var nodes := DataDB.ascension_nodes()
	for id in _node_buttons:
		var n: Dictionary = nodes[id]
		var lvl := Progression.node_level(s, id)
		var b: Button = _node_buttons[id]
		var maxed := lvl >= int(n["max"])
		var unlocked := Progression.node_unlocked(s, id)
		var cost := Progression.node_cost(s, id)
		var reqs := []
		for req in n["requires"]:
			reqs.append("%s %d" % [nodes[req]["name"], n["requires"][req]])
		b.text = "%s  [%d/%d]\n%s\n%s" % [n["name"], lvl, n["max"], n["text"],
			Loc.t("MAX") if maxed else (Loc.t("Cost: %d Souls") % cost if unlocked else Loc.t("Requires ") + ", ".join(reqs))]
		b.disabled = maxed or not unlocked or int(s["souls"]) < cost
