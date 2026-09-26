extends MarginContainer
## Paper doll + bag. Pick a hero, then drag items from the bag onto the slots
## (or double-click an item). Drag an equipped item back to the bag to remove it.

const DataDB = preload("res://core/data_db.gd")
const StatCalc = preload("res://core/stat_calculator.gd")
const Inventory = preload("res://core/inventory.gd")
const Loot = preload("res://core/loot_calculator.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")
const UiUtil = preload("res://scenes/ui/ui_util.gd")
const PartyTab = preload("res://scenes/ui/tabs/party_tab.gd")
const ItemSlot = preload("res://scenes/ui/item_slot.gd")

const DOLL_SIZE := Vector2(300, 300)
const SLOT_CELL := 56.0
## Paper-doll layout (slot -> top-left position inside the doll panel).
const DOLL_LAYOUT := {
	"helm": Vector2(122, 6), "weapon": Vector2(18, 110), "ring": Vector2(226, 110),
	"gloves": Vector2(18, 214), "chest": Vector2(122, 214), "boots": Vector2(226, 214),
}
const FILTERS := ["all", "weapon", "helm", "chest", "gloves", "boots", "ring"]

var hero_idx := 0
var _filter := "all"
var _selected_uid := -1
var _hero_buttons: Array = []
var _picker: HBoxContainer
var _doll: Control
var _portrait: TextureRect
var _doll_slots := {}
var _hero_info: Label
var _sets_info: Label
var _grid: GridContainer
var _bag_label: Label
var _detail: RichTextLabel
var _equip_btn: Button
var _salvage_btn: Button
var _auto_equip: CheckBox
var _auto_salvage: OptionButton
var _dirty := true
var _supplies: HFlowContainer


func _ready() -> void:
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	# ---- left: hero picker + doll
	var left := VBoxContainer.new()
	root.add_child(left)
	_picker = HBoxContainer.new()
	left.add_child(_picker)
	var doll_panel := PanelContainer.new()
	left.add_child(doll_panel)
	_doll = Control.new()
	_doll.custom_minimum_size = DOLL_SIZE
	doll_panel.add_child(_doll)
	_portrait = TextureRect.new()
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.position = Vector2(96, 70)
	_portrait.size = Vector2(108, 132)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_doll.add_child(_portrait)
	for slot in DOLL_LAYOUT:
		var cell = ItemSlot.new()
		cell.position = DOLL_LAYOUT[slot]
		cell.size = Vector2(SLOT_CELL, SLOT_CELL)
		cell.selected.connect(_on_cell_selected)
		cell.activated.connect(func(c): if c.item != null: Game.unequip(c.hero_idx, c.slot_name))
		_doll.add_child(cell)
		_doll_slots[slot] = cell
	_hero_info = Label.new()
	_hero_info.add_theme_font_size_override("font_size", 12)
	left.add_child(_hero_info)
	_sets_info = Label.new()
	_sets_info.add_theme_font_size_override("font_size", 12)
	_sets_info.add_theme_color_override("font_color", Color("#5fd35f"))
	_sets_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sets_info.custom_minimum_size = Vector2(DOLL_SIZE.x, 0)
	left.add_child(_sets_info)

	# ---- right: bag
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)
	var top := HBoxContainer.new()
	right.add_child(top)
	_bag_label = Label.new()
	top.add_child(_bag_label)
	for f in FILTERS:
		var fb := Button.new()
		fb.focus_mode = Control.FOCUS_NONE
		fb.text = f.capitalize()
		fb.add_theme_font_size_override("font_size", 12)
		fb.pressed.connect(func(): _filter = f; _dirty = true)
		top.add_child(fb)
	# Usable items: click to use (potions also fire automatically in fights).
	var sup_panel := PanelContainer.new()
	right.add_child(sup_panel)
	_supplies = HFlowContainer.new()
	sup_panel.add_child(_supplies)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 150)
	right.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 9
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_grid)

	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.custom_minimum_size = Vector2(0, 110)
	right.add_child(_detail)
	var actions := HBoxContainer.new()
	right.add_child(actions)
	_equip_btn = Button.new()
	_equip_btn.focus_mode = Control.FOCUS_NONE
	_equip_btn.pressed.connect(_equip_selected)
	actions.add_child(_equip_btn)
	_salvage_btn = Button.new()
	_salvage_btn.focus_mode = Control.FOCUS_NONE
	_salvage_btn.pressed.connect(_salvage_selected)
	actions.add_child(_salvage_btn)
	var bulk := Button.new()
	bulk.focus_mode = Control.FOCUS_NONE
	bulk.text = "Salvage all below Rare"
	bulk.pressed.connect(func(): Game.salvage_below("rare"))
	actions.add_child(bulk)
	var rules := HBoxContainer.new()
	right.add_child(rules)
	_auto_equip = CheckBox.new()
	_auto_equip.focus_mode = Control.FOCUS_NONE
	_auto_equip.text = "Auto-equip upgrades"
	_auto_equip.toggled.connect(func(on): Game.set_setting("auto_equip", on))
	rules.add_child(_auto_equip)
	var al := Label.new()
	al.text = "  Auto-salvage below:"
	rules.add_child(al)
	_auto_salvage = OptionButton.new()
	_auto_salvage.focus_mode = Control.FOCUS_NONE
	for r in ["common", "uncommon", "rare", "epic"]:
		_auto_salvage.add_item(DataDB.rarities()[r]["name"])
		_auto_salvage.set_item_metadata(_auto_salvage.item_count - 1, r)
	_auto_salvage.item_selected.connect(func(idx): Game.set_setting("auto_salvage_below", _auto_salvage.get_item_metadata(idx)))
	rules.add_child(_auto_salvage)

	Game.inventory_changed.connect(func(): _dirty = true)
	Game.state_changed.connect(_rebuild_supplies)
	Game.party_changed.connect(func(): _dirty = true)
	Game.settings_changed.connect(func(): _dirty = true)
	visibility_changed.connect(func(): _dirty = true)


func _process(_delta: float) -> void:
	if _dirty and is_visible_in_tree():
		_dirty = false
		_rebuild()


func _rebuild_picker() -> void:
	for c in _picker.get_children():
		c.queue_free()
	_hero_buttons.clear()
	for i in Game.state["heroes"].size():
		var h: Dictionary = Game.state["heroes"][i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.text = h["name"]
		b.icon = PixelArt.unit_frames(h["class"], DataDB.classes()[h["class"]]["sprite"], {}, false)[0]
		b.pressed.connect(func(): hero_idx = i; _dirty = true)
		_picker.add_child(b)
		_hero_buttons.append(b)


func _rebuild() -> void:
	hero_idx = clampi(hero_idx, 0, Game.state["heroes"].size() - 1)
	_rebuild_picker()
	var hero: Dictionary = Game.state["heroes"][hero_idx]
	var mono: bool = Game.state["settings"].get("art_style", "mono") == "mono"
	for i in _hero_buttons.size():
		_hero_buttons[i].set_pressed_no_signal(i == hero_idx)
	_portrait.texture = PixelArt.unit_frames(hero["class"], DataDB.classes()[hero["class"]]["sprite"], {}, mono)[0]
	for slot in _doll_slots:
		var cell = _doll_slots[slot]
		cell.setup(hero["equipment"][slot], hero_idx, slot, SLOT_CELL)
		cell.is_selected = cell.item != null and int(cell.item["uid"]) == _selected_uid
	var st := StatCalc.hero_stats(Game.state, hero)
	var magic: bool = st["damage_type"] == "magic"
	_hero_info.text = "Lv %d %s   ·   Power %s\nHP %s   %s %s   DEF %s   Crit %s" % [
		hero["level"], DataDB.classes()[hero["class"]]["name"], UiUtil.num(StatCalc.power_rating(st)),
		UiUtil.num(st["hp"]), "MAG" if magic else "ATK", UiUtil.num(st["magic_power"] if magic else st["attack"]),
		UiUtil.num(st["defense"]), UiUtil.pct(st["crit_chance"])]
	var sets := DataDB.sets()
	var lines := []
	var active := StatCalc.active_sets(hero)
	for set_id in active:
		lines.append("%s %d/6" % [sets[set_id]["name"], active[set_id]])
	_sets_info.text = "  ".join(lines)

	for c in _grid.get_children():
		c.queue_free()
	var items: Array = Game.state["inventory"].filter(func(it): return _filter == "all" or it["slot"] == _filter)
	items.sort_custom(func(a, b):
		var ra := DataDB.rarity_order(a["rarity"])
		var rb := DataDB.rarity_order(b["rarity"])
		return ra > rb if ra != rb else int(a["ilvl"]) > int(b["ilvl"]))
	for it in items:
		var cell = ItemSlot.new()
		cell.setup(it, -1, "", 48.0)
		cell.is_selected = int(it["uid"]) == _selected_uid
		cell.selected.connect(_on_cell_selected)
		cell.activated.connect(func(c): Game.equip(hero_idx, int(c.item["uid"])))
		_grid.add_child(cell)
	# A few empty cells keep the bag a valid drop target even when it is empty.
	var pad := 9 if items.is_empty() else (9 - items.size() % 9) % 9
	for i in pad:
		var empty = ItemSlot.new()
		empty.setup(null, -1, "", 48.0)
		_grid.add_child(empty)
	_bag_label.text = "Bag %d/%d  " % [Game.state["inventory"].size(), int(DataDB.balance()["inventory_cap"])]
	_auto_equip.set_pressed_no_signal(Game.state["settings"].get("auto_equip", true))
	var rule: String = Game.state["settings"].get("auto_salvage_below", "uncommon")
	for i in _auto_salvage.item_count:
		if _auto_salvage.get_item_metadata(i) == rule:
			_auto_salvage.select(i)
	_show_detail()
	_rebuild_supplies()


func _rebuild_supplies() -> void:
	if not is_visible_in_tree():
		return
	for c in _supplies.get_children():
		c.queue_free()
	var l := Label.new()
	l.text = "Supplies:"
	_supplies.add_child(l)
	var table: Dictionary = DataDB.items().get("consumables", {})
	var bag: Dictionary = Game.state.get("consumables", {})
	var any := false
	for id in table:
		var n := int(bag.get(id, 0))
		if n <= 0:
			continue
		any = true
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.icon = PixelArt.frames(table[id]["icon"])[0]
		b.text = "x%d" % n
		b.tooltip_text = "%s\n%s\n\n(click to use)" % [table[id]["name"], table[id]["text"]]
		b.pressed.connect(func(): Game.use_consumable(id))
		_supplies.add_child(b)
	if not any:
		var e := Label.new()
		e.text = "none (they drop from monsters and are sold in the Market)"
		e.add_theme_color_override("font_color", Color("#5a566a"))
		_supplies.add_child(e)
	var auto := CheckBox.new()
	auto.text = "Auto-use in fights"
	auto.focus_mode = Control.FOCUS_NONE
	auto.button_pressed = Game.state["settings"].get("auto_supplies", true)
	auto.toggled.connect(func(on): Game.set_setting("auto_supplies", on))
	_supplies.add_child(auto)


func _on_cell_selected(cell) -> void:
	_selected_uid = int(cell.item["uid"]) if cell.item != null else -1
	_dirty = true


func _selected_item() -> Variant:
	for it in Game.state["inventory"]:
		if int(it["uid"]) == _selected_uid:
			return {"item": it, "equipped": false}
	for h in Game.state["heroes"]:
		for slot in h["equipment"]:
			var it = h["equipment"][slot]
			if it != null and int(it["uid"]) == _selected_uid:
				return {"item": it, "equipped": true}
	return null


func _show_detail() -> void:
	var sel: Variant = _selected_item()
	_equip_btn.disabled = sel == null
	_salvage_btn.disabled = sel == null or sel["equipped"]
	if sel == null:
		_detail.text = "[color=#9a96a8]Drag items onto the hero's slots, or double-click to equip.\nDrag an equipped item back to the bag to remove it.[/color]"
		_equip_btn.text = "Equip"
		_salvage_btn.text = "Salvage"
		return
	var item: Dictionary = sel["item"]
	var tip := PartyTab.item_tooltip(item).split("\n")
	var col := UiUtil.rarity_color(item["rarity"]).to_html(false)
	var lines := ["[color=#%s][b]%s[/b][/color]" % [col, tip[0]]]
	lines.append_array(tip.slice(1))
	var hero: Dictionary = Game.state["heroes"][hero_idx]
	if sel["equipped"]:
		_equip_btn.text = "Unequip"
	else:
		_equip_btn.text = "Equip on " + hero["name"]
		if Loot.can_equip(item, hero["class"]):
			var mods := StatCalc.party_mods(Game.state)
			var now := StatCalc.power_rating(StatCalc.hero_stats(Game.state, hero, mods))
			var delta := Inventory.power_with(Game.state, hero, item["slot"], item, mods) / maxf(now, 0.001) - 1.0
			var worn = hero["equipment"][item["slot"]]
			lines.append("")
			lines.append("[b]vs %s[/b]" % (worn["name"] if worn != null else "empty slot"))
			for c in PartyTab.compare_lines(item, worn):
				lines.append("[color=%s]%s[/color]" % ["#5fd35f" if c[1] else "#ff6b6b", c[0]])
			lines.append("[color=%s][b]%s%s overall power for %s[/b][/color]" % ["#5fd35f" if delta >= 0.0 else "#ff6b6b", "+" if delta >= 0.0 else "", UiUtil.pct(delta, 1), hero["name"]])
		else:
			_equip_btn.disabled = true
			lines.append("[color=#ff6b6b]%s cannot use this.[/color]" % hero["name"])
		_salvage_btn.text = "Salvage (+%s gold)" % UiUtil.num(Loot.salvage_value(item))
	_detail.text = "\n".join(lines)


func _equip_selected() -> void:
	var sel: Variant = _selected_item()
	if sel == null:
		return
	var item: Dictionary = sel["item"]
	if sel["equipped"]:
		for i in Game.state["heroes"].size():
			var eq = Game.state["heroes"][i]["equipment"][item["slot"]]
			if eq != null and int(eq["uid"]) == int(item["uid"]):
				Game.unequip(i, item["slot"])
	else:
		Game.equip(hero_idx, int(item["uid"]))


func _salvage_selected() -> void:
	var sel: Variant = _selected_item()
	if sel != null and not sel["equipped"]:
		Game.salvage(int(sel["item"]["uid"]))
		_selected_uid = -1
