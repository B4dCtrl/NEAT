extends VBoxContainer
## INVENTORY: paper doll around the hero portrait, supplies, the bag grid and
## round action buttons (forge, salvage, auto-equip). Drag items onto the
## slots or double-click them; the Forge burns items into a better one.

const DataDB = preload("res://core/data_db.gd")
const StatCalc = preload("res://core/stat_calculator.gd")
const Inventory = preload("res://core/inventory.gd")
const Loot = preload("res://core/loot_calculator.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")
const UiUtil = preload("res://scenes/ui/ui_util.gd")
const Ornate = preload("res://scenes/ui/menu/ornate.gd")
const ItemSlot = preload("res://scenes/ui/item_slot.gd")
const HeroPicker = preload("res://scenes/ui/menu/hero_picker.gd")
const Forge = preload("res://core/forge.gd")

const CELL := 38.0
const COLS := 7
const LEFT_SLOTS := ["helm", "chest", "boots"]
const RIGHT_SLOTS := ["weapon", "gloves", "ring"]

var host
var hero_idx := 0
var _picker
var _slots := {}
var _portrait: TextureRect
var _power: Label
var _supplies: HBoxContainer
var _grid: GridContainer
var _bag_label: Label
var _selected_uid := -1
var _info: Label
var _equip_btn: Button
var _salvage_btn: Button
var _forge_btn: Button
var _forge_rarity: OptionButton
var _dirty := true


func mark_dirty() -> void:
	_dirty = true


func _ready() -> void:
	if host != null:
		hero_idx = host.hero_idx
	_picker = HeroPicker.new()
	_picker.picked.connect(func(i):
		hero_idx = i
		if host != null:
			host.select_hero(i)
		_dirty = true)
	add_child(_picker)

	var doll := PanelContainer.new()
	add_child(doll)
	var dh := HBoxContainer.new()
	dh.alignment = BoxContainer.ALIGNMENT_CENTER
	doll.add_child(dh)
	dh.add_child(_slot_column(LEFT_SLOTS))
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dh.add_child(mid)
	_portrait = TextureRect.new()
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.custom_minimum_size = Vector2(90, 90)
	_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(_portrait)
	_power = Ornate.small_label("", Ornate.ACCENT, 11)
	_power.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_power)
	dh.add_child(_slot_column(RIGHT_SLOTS))

	_supplies = HBoxContainer.new()
	add_child(_supplies)

	var bag_head := HBoxContainer.new()
	add_child(bag_head)
	_bag_label = Ornate.header_label("Bag")
	_bag_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_head.add_child(_bag_label)
	var auto := CheckBox.new()
	auto.focus_mode = Control.FOCUS_NONE
	auto.text = "Auto-equip"
	auto.button_pressed = Game.state["settings"].get("auto_equip", true)
	auto.toggled.connect(func(on): Game.set_setting("auto_equip", on))
	bag_head.add_child(auto)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, CELL * 1.6)
	add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 3)
	_grid.add_theme_constant_override("v_separation", 3)
	scroll.add_child(_grid)

	_info = Ornate.small_label("Double-click to equip · drag to a slot", Ornate.TEXT_DIM, 11)
	_info.clip_text = true
	add_child(_info)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	add_child(actions)
	_equip_btn = _button(actions, "Equip", _equip_selected)
	_salvage_btn = _button(actions, "Salvage", _salvage_selected)
	var forge_row := actions
	_forge_rarity = OptionButton.new()
	_forge_rarity.focus_mode = Control.FOCUS_NONE
	for r in Forge.forgeable_rarities():
		_forge_rarity.add_item(DataDB.rarities()[r]["name"])
		_forge_rarity.set_item_metadata(_forge_rarity.item_count - 1, r)
	_forge_rarity.item_selected.connect(func(_i): _forge_rarity.set_meta("touched", true); _dirty = true)
	forge_row.add_child(_forge_rarity)
	_forge_btn = _button(forge_row, "Forge", _forge)
	_forge_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	Game.inventory_changed.connect(func(): _dirty = true)
	Game.party_changed.connect(func(): _picker.rebuild(); _dirty = true)
	Game.state_changed.connect(_refresh_supplies)


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _slot_column(slots: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	for slot in slots:
		var cell = ItemSlot.new()
		cell.setup(null, 0, slot, CELL)
		cell.selected.connect(_on_selected)
		cell.activated.connect(func(c): if c.item != null: Game.unequip(c.hero_idx, c.slot_name))
		col.add_child(cell)
		_slots[slot] = cell
	return col


func _process(_delta: float) -> void:
	if _dirty and is_visible_in_tree():
		_dirty = false
		_rebuild()


func _rebuild() -> void:
	var heroes: Array = Game.state["heroes"]
	hero_idx = clampi(hero_idx, 0, heroes.size() - 1)
	if _picker.selected != hero_idx:
		_picker.select(hero_idx, false)
	_picker.refresh()
	var hero: Dictionary = heroes[hero_idx]
	_portrait.texture = PixelArt.unit_frames(hero["class"], DataDB.classes()[hero["class"]]["sprite"], {}, false)[0]
	for slot in _slots:
		var cell = _slots[slot]
		cell.setup(hero["equipment"][slot], hero_idx, slot, CELL)
		cell.is_selected = cell.item != null and int(cell.item["uid"]) == _selected_uid
		cell.queue_redraw()
	_power.text = "Power %s" % UiUtil.num(StatCalc.power_rating(StatCalc.hero_stats(Game.state, hero)))
	for c in _grid.get_children():
		c.queue_free()
	var items: Array = Game.state["inventory"].duplicate()
	items.sort_custom(func(a, b):
		var ra := DataDB.rarity_order(a["rarity"])
		var rb := DataDB.rarity_order(b["rarity"])
		return ra > rb if ra != rb else int(a["ilvl"]) > int(b["ilvl"]))
	for it in items:
		var cell = ItemSlot.new()
		cell.setup(it, -1, "", CELL)
		cell.is_selected = int(it["uid"]) == _selected_uid
		cell.selected.connect(_on_selected)
		cell.activated.connect(func(c): Game.equip(hero_idx, int(c.item["uid"])))
		_grid.add_child(cell)
	var pad := COLS * 2 - items.size() if items.size() < COLS * 2 else (COLS - items.size() % COLS) % COLS
	for i in pad:
		var empty = ItemSlot.new()
		empty.setup(null, -1, "", CELL)
		_grid.add_child(empty)
	_bag_label.text = "Bag %d/%d" % [Game.state["inventory"].size(), int(DataDB.balance()["inventory_cap"])]
	_refresh_actions()
	_refresh_supplies()


func _refresh_supplies() -> void:
	if not is_visible_in_tree():
		return
	var bag: Dictionary = Game.state.get("consumables", {})
	var sig := str(bag)
	if _supplies.has_meta("sig") and _supplies.get_meta("sig") == sig:
		return
	_supplies.set_meta("sig", sig)
	for c in _supplies.get_children():
		c.queue_free()
	var table: Dictionary = DataDB.items().get("consumables", {})
	var any := false
	for id in table:
		var n := int(bag.get(id, 0))
		if n <= 0:
			continue
		any = true
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.icon = PixelArt.frames(table[id]["icon"])[0]
		b.expand_icon = false
		b.text = str(n)
		b.tooltip_text = "%s\n%s\n(click to use)" % [table[id]["name"], table[id]["text"]]
		b.pressed.connect(func(): Game.use_consumable(id))
		_supplies.add_child(b)
	if not any:
		_supplies.add_child(Ornate.small_label("No supplies: monsters and the Market have them.", Ornate.TEXT_DIM, 11))


func _on_selected(cell) -> void:
	_selected_uid = int(cell.item["uid"]) if cell.item != null else -1
	_dirty = true


func _selected() -> Variant:
	for it in Game.state["inventory"]:
		if int(it["uid"]) == _selected_uid:
			return {"item": it, "equipped": false}
	for h in Game.state["heroes"]:
		for slot in h["equipment"]:
			var it = h["equipment"][slot]
			if it != null and int(it["uid"]) == _selected_uid:
				return {"item": it, "equipped": true}
	return null


func _refresh_actions() -> void:
	var sel: Variant = _selected()
	var hero: Dictionary = Game.state["heroes"][hero_idx]
	_equip_btn.disabled = sel == null
	_salvage_btn.disabled = sel == null or sel["equipped"]
	_equip_btn.text = "Equip"
	_salvage_btn.text = "Salvage"
	_salvage_btn.tooltip_text = ""
	if sel == null:
		_info.text = "Double-click to equip · drag onto a slot"
		_info.add_theme_color_override("font_color", Ornate.TEXT_DIM)
	else:
		var it: Dictionary = sel["item"]
		if sel["equipped"]:
			_equip_btn.text = "Unequip"
			_info.text = it["name"]
		else:
			_salvage_btn.tooltip_text = "Destroy for +%s gold" % UiUtil.num(Loot.salvage_value(it))
			if Loot.can_equip(it, hero["class"]):
				var mods := StatCalc.party_mods(Game.state)
				var now := StatCalc.power_rating(StatCalc.hero_stats(Game.state, hero, mods))
				var delta := Inventory.power_with(Game.state, hero, it["slot"], it, mods) / maxf(now, 0.001) - 1.0
				_info.text = "%s  (%s%s power)" % [it["name"], "+" if delta >= 0.0 else "", UiUtil.pct(delta, 1)]
			else:
				_equip_btn.disabled = true
				_info.text = "%s — %s cannot use it" % [it["name"], hero["name"]]
		_info.add_theme_color_override("font_color", UiUtil.rarity_color(it["rarity"]))
	# Forge: burn N items of a rarity into one of the next.
	if not _forge_rarity.has_meta("touched") and _forge_rarity.item_count > 0:
		# Until the player picks one, suggest the rarity with the most spare items.
		var best := 0
		var most := -1
		for i in _forge_rarity.item_count:
			var have: int = Forge.quote(Game.state, _forge_rarity.get_item_metadata(i))["have"]
			if have > most:
				most = have
				best = i
		_forge_rarity.select(best)
	if _forge_rarity.item_count > 0:
		var r: String = _forge_rarity.get_item_metadata(_forge_rarity.selected)
		var q := Forge.quote(Game.state, r)
		_forge_btn.text = "Forge %d→1" % q["count"]
		_forge_btn.disabled = not q["ok"]
		_forge_btn.tooltip_text = "FORGE: burns the %d weakest %s items in the bag (you have %d)\nand forges one %s item (item level %d) that %s can use.\nCost: %s gold%s. The burned items are destroyed for good." % [
			q["count"], DataDB.rarities()[r]["name"], q["have"], DataDB.rarities()[q["to"]]["name"], q["ilvl"], hero["name"],
			UiUtil.num(q["gold"]), (" + %d crystals" % q["crystals"]) if int(q["crystals"]) > 0 else ""]
		if sel == null:
			_info.text = "Forge: %d %s (have %d) → 1 %s · %s gold%s" % [q["count"], DataDB.rarities()[r]["name"], q["have"],
				DataDB.rarities()[q["to"]]["name"], UiUtil.num(q["gold"]), (" + %d crystals" % q["crystals"]) if int(q["crystals"]) > 0 else ""]


func _equip_selected() -> void:
	var sel: Variant = _selected()
	if sel == null:
		return
	var it: Dictionary = sel["item"]
	if sel["equipped"]:
		for i in Game.state["heroes"].size():
			var eq = Game.state["heroes"][i]["equipment"][it["slot"]]
			if eq != null and int(eq["uid"]) == int(it["uid"]):
				Game.unequip(i, it["slot"])
	else:
		Game.equip(hero_idx, int(it["uid"]))


func _salvage_selected() -> void:
	var sel: Variant = _selected()
	if sel != null and not sel["equipped"]:
		Game.salvage(int(sel["item"]["uid"]))
		_selected_uid = -1


func _forge() -> void:
	var r: String = _forge_rarity.get_item_metadata(_forge_rarity.selected)
	var made: Dictionary = Game.forge(r, hero_idx)
	if not made.is_empty():
		_selected_uid = int(made["uid"])
		_dirty = true
