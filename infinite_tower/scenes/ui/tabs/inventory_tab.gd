extends MarginContainer
## Bag, item comparison, equip/salvage, auto-loot rules and the relic collection.

const DataDB = preload("res://core/data_db.gd")
const StatCalc = preload("res://core/stat_calculator.gd")
const Inventory = preload("res://core/inventory.gd")
const Loot = preload("res://core/loot_calculator.gd")
const UiUtil = preload("res://scenes/ui/ui_util.gd")
const PartyTab = preload("res://scenes/ui/tabs/party_tab.gd")

var _list: ItemList
var _detail: RichTextLabel
var _equip_buttons: Array = []
var _salvage_btn: Button
var _count_lbl: Label
var _auto_equip: CheckBox
var _auto_salvage: OptionButton
var _relic_list: VBoxContainer
var _items: Array = []   # items shown, in list order
var _dirty := true


func _ready() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	add_child(h)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	var top := HBoxContainer.new()
	left.add_child(top)
	_count_lbl = Label.new()
	_count_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_count_lbl)
	var bulk := Button.new()
	bulk.text = "Salvage all below Rare"
	bulk.focus_mode = Control.FOCUS_NONE
	bulk.pressed.connect(func(): Game.salvage_below("rare"))
	top.add_child(bulk)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(_i): _show_detail())
	left.add_child(_list)
	var rules := HBoxContainer.new()
	left.add_child(rules)
	_auto_equip = CheckBox.new()
	_auto_equip.text = "Auto-equip upgrades"
	_auto_equip.focus_mode = Control.FOCUS_NONE
	_auto_equip.toggled.connect(func(on): Game.set_setting("auto_equip", on))
	rules.add_child(_auto_equip)
	var al := Label.new()
	al.text = "   Auto-salvage below:"
	rules.add_child(al)
	_auto_salvage = OptionButton.new()
	_auto_salvage.focus_mode = Control.FOCUS_NONE
	for r in ["common", "uncommon", "rare", "epic"]:
		_auto_salvage.add_item(DataDB.rarities()[r]["name"])
		_auto_salvage.set_item_metadata(_auto_salvage.item_count - 1, r)
	_auto_salvage.item_selected.connect(func(idx): Game.set_setting("auto_salvage_below", _auto_salvage.get_item_metadata(idx)))
	rules.add_child(_auto_salvage)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(360, 0)
	h.add_child(right)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.fit_content = false
	right.add_child(_detail)
	var btns := HBoxContainer.new()
	right.add_child(btns)
	for i in Game.state["heroes"].size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = "Equip: " + Game.state["heroes"][i]["name"]
		b.pressed.connect(func(): _equip_selected(i))
		btns.add_child(b)
		_equip_buttons.append(b)
	_salvage_btn = Button.new()
	_salvage_btn.focus_mode = Control.FOCUS_NONE
	_salvage_btn.pressed.connect(_salvage_selected)
	right.add_child(_salvage_btn)

	right.add_child(HSeparator.new())
	var rl := Label.new()
	rl.text = "Relic Collection"
	rl.add_theme_color_override("font_color", UiUtil.rarity_color("relic"))
	right.add_child(rl)
	_relic_list = VBoxContainer.new()
	right.add_child(_relic_list)

	Game.inventory_changed.connect(func(): _dirty = true)
	Game.settings_changed.connect(func(): _dirty = true)
	visibility_changed.connect(func(): _dirty = true)


func _process(_delta: float) -> void:
	if _dirty and is_visible_in_tree():
		_dirty = false
		_rebuild()


func _rebuild() -> void:
	var selected_uid := -1
	var sel := _list.get_selected_items()
	if not sel.is_empty() and sel[0] < _items.size():
		selected_uid = int(_items[sel[0]]["uid"])
	_items = Game.state["inventory"].duplicate()
	_items.sort_custom(func(a, b):
		var ra := DataDB.rarity_order(a["rarity"])
		var rb := DataDB.rarity_order(b["rarity"])
		return ra > rb if ra != rb else int(a["ilvl"]) > int(b["ilvl"]))
	_list.clear()
	for item in _items:
		var idx := _list.add_item("%s   (iLvl %d, %s)" % [item["name"], item["ilvl"], item["slot"]])
		_list.set_item_custom_fg_color(idx, UiUtil.rarity_color(item["rarity"]))
		_list.set_item_tooltip(idx, PartyTab.item_tooltip(item))
		if int(item["uid"]) == selected_uid:
			_list.select(idx)
	_count_lbl.text = "Bag: %d / %d" % [_items.size(), int(DataDB.balance()["inventory_cap"])]
	_auto_equip.set_pressed_no_signal(Game.state["settings"].get("auto_equip", true))
	var rule: String = Game.state["settings"].get("auto_salvage_below", "uncommon")
	for i in _auto_salvage.item_count:
		if _auto_salvage.get_item_metadata(i) == rule:
			_auto_salvage.select(i)
	_show_detail()
	_rebuild_relics()


func _selected_item():
	var sel := _list.get_selected_items()
	if sel.is_empty() or sel[0] >= _items.size():
		return null
	return _items[sel[0]]


func _show_detail() -> void:
	var item = _selected_item()
	_salvage_btn.disabled = item == null
	for i in _equip_buttons.size():
		_equip_buttons[i].disabled = item == null or not Loot.can_equip(item, Game.state["heroes"][i]["class"])
	if item == null:
		_detail.text = "[color=#9a96a8]Select an item to inspect it.[/color]"
		_salvage_btn.text = "Salvage"
		return
	_salvage_btn.text = "Salvage for %s gold" % UiUtil.num(Loot.salvage_value(item))
	var col := UiUtil.rarity_color(item["rarity"]).to_html(false)
	var lines := ["[color=#%s][b]%s[/b][/color]" % [col, PartyTab.item_tooltip(item).split("\n")[0]]]
	for l in PartyTab.item_tooltip(item).split("\n").slice(1):
		lines.append(l)
	# Power comparison against what each eligible hero wears now.
	lines.append("")
	var mods := StatCalc.party_mods(Game.state)
	for hero in Game.state["heroes"]:
		if not Loot.can_equip(item, hero["class"]):
			continue
		var now := StatCalc.power_rating(StatCalc.hero_stats(Game.state, hero, mods))
		var with_item := Inventory.power_with(Game.state, hero, item["slot"], item, mods)
		var delta := with_item / maxf(now, 0.001) - 1.0
		var c := "#5fd35f" if delta > 0.0 else "#ff6b6b"
		lines.append("%s: [color=%s]%s%s power[/color]" % [hero["name"], c, "+" if delta >= 0.0 else "", UiUtil.pct(delta, 1)])
	_detail.text = "\n".join(lines)


func _equip_selected(hero_idx: int) -> void:
	var item = _selected_item()
	if item != null:
		Game.equip(hero_idx, int(item["uid"]))


func _salvage_selected() -> void:
	var item = _selected_item()
	if item != null:
		Game.salvage(int(item["uid"]))


func _rebuild_relics() -> void:
	for c in _relic_list.get_children():
		c.queue_free()
	var relics := DataDB.relics()
	var slots := StatCalc.relic_slots(Game.state)
	for relic_id in relics:
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 12)
		var owned: bool = relic_id in Game.state["relics_owned"]
		if owned:
			lbl.text = relics[relic_id]["name"]
			lbl.tooltip_text = relics[relic_id]["description"]
			lbl.mouse_filter = Control.MOUSE_FILTER_PASS
			lbl.add_theme_color_override("font_color", UiUtil.rarity_color("relic"))
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", 12)
			var equipped: bool = relic_id in Game.state["relics_equipped"]
			b.text = "Unequip" if equipped else "Equip"
			b.disabled = not equipped and Game.state["relics_equipped"].size() >= slots
			b.pressed.connect(func():
				if equipped:
					Game.unequip_relic(relic_id)
				else:
					Game.equip_relic(relic_id))
			row.add_child(lbl)
			row.add_child(b)
		else:
			lbl.text = "??? (undiscovered)"
			lbl.add_theme_color_override("font_color", Color("#5a566a"))
			row.add_child(lbl)
		_relic_list.add_child(row)
