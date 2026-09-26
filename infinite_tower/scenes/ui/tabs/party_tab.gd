extends MarginContainer
## Party management: hero cards (row, stats, gear, sets), training and relic slots.

const DataDB = preload("res://core/data_db.gd")
const StatCalc = preload("res://core/stat_calculator.gd")
const Progression = preload("res://core/progression.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")
const UiUtil = preload("res://scenes/ui/ui_util.gd")

var _cards: Array = []       # per hero: {level, xp, row_btn, stats, slots:{slot:Button}, sets, skill}
var _train_buttons := {}
var _relic_box: HBoxContainer
var _auto_train: CheckBox


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)

	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 10)
	root.add_child(cards_row)
	for i in Game.state["heroes"].size():
		cards_row.add_child(_build_card(i))

	# Training
	var train_panel := PanelContainer.new()
	root.add_child(train_panel)
	var train_row := HBoxContainer.new()
	train_panel.add_child(train_row)
	var tl := Label.new()
	tl.text = "Training (party-wide):"
	train_row.add_child(tl)
	for key in DataDB.balance()["training"]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): Game.train(key); _refresh())
		train_row.add_child(b)
		_train_buttons[key] = b
	_auto_train = CheckBox.new()
	_auto_train.text = "Auto-train"
	_auto_train.focus_mode = Control.FOCUS_NONE
	_auto_train.toggled.connect(func(on): Game.set_setting("auto_train", on))
	train_row.add_child(_auto_train)

	# Relics
	var relic_panel := PanelContainer.new()
	root.add_child(relic_panel)
	_relic_box = HBoxContainer.new()
	relic_panel.add_child(_relic_box)

	Game.state_changed.connect(_refresh)
	Game.inventory_changed.connect(_refresh_gear)
	visibility_changed.connect(func(): if is_visible_in_tree(): _refresh_gear())
	_refresh_gear()


func _build_card(i: int) -> Control:
	var hero: Dictionary = Game.state["heroes"][i]
	var cdef: Dictionary = DataDB.classes()[hero["class"]]
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	panel.add_child(v)

	var top := HBoxContainer.new()
	v.add_child(top)
	var portrait := TextureRect.new()
	portrait.texture = PixelArt.frames(cdef["sprite"])[0]
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.custom_minimum_size = Vector2(40, 40)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(portrait)
	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_constant_override("separation", 0)
	top.add_child(name_box)
	var name_lbl := Label.new()
	name_lbl.text = "%s the %s" % [hero["name"], cdef["name"]]
	name_box.add_child(name_lbl)
	var level_lbl := Label.new()
	level_lbl.add_theme_color_override("font_color", Color("#9a96a8"))
	name_box.add_child(level_lbl)
	var row_btn := Button.new()
	row_btn.focus_mode = Control.FOCUS_NONE
	row_btn.tooltip_text = "Frontline heroes draw most enemy attacks."
	row_btn.pressed.connect(func():
		var h: Dictionary = Game.state["heroes"][i]
		Game.set_row(i, "back" if h["row"] == "front" else "front")
		_refresh())
	top.add_child(row_btn)

	var xp := ProgressBar.new()
	xp.custom_minimum_size = Vector2(0, 6)
	xp.show_percentage = false
	v.add_child(xp)

	var stats := GridContainer.new()
	stats.columns = 4
	stats.add_theme_constant_override("h_separation", 12)
	v.add_child(stats)
	var stat_labels := {}
	for key in ["hp", "power", "defense", "attack_speed", "crit_chance", "crit_damage", "dodge", "rating"]:
		var k := Label.new()
		k.add_theme_color_override("font_color", Color("#9a96a8"))
		k.add_theme_font_size_override("font_size", 12)
		var val := Label.new()
		val.add_theme_font_size_override("font_size", 12)
		stats.add_child(k)
		stats.add_child(val)
		stat_labels[key] = [k, val]

	var skill := Label.new()
	skill.text = "%s: %s" % [cdef["skill"]["name"], cdef["skill"]["description"]]
	skill.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill.add_theme_font_size_override("font_size", 12)
	skill.add_theme_color_override("font_color", Color("#7fe0ff"))
	v.add_child(skill)

	v.add_child(HSeparator.new())
	var slots := {}
	for slot in DataDB.items()["slots"]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(func(): Game.unequip(i, slot))
		v.add_child(b)
		slots[slot] = b
	var sets_lbl := Label.new()
	sets_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sets_lbl.add_theme_font_size_override("font_size", 12)
	sets_lbl.add_theme_color_override("font_color", Color("#5fd35f"))
	v.add_child(sets_lbl)

	_cards.append({"level": level_lbl, "xp": xp, "row_btn": row_btn, "stats": stat_labels, "slots": slots, "sets": sets_lbl})
	return panel


func _refresh() -> void:
	if not is_visible_in_tree():
		return
	var mods := StatCalc.party_mods(Game.state)
	for i in _cards.size():
		var hero: Dictionary = Game.state["heroes"][i]
		var card: Dictionary = _cards[i]
		var st := StatCalc.hero_stats(Game.state, hero, mods)
		card["level"].text = "Level %d" % hero["level"]
		card["xp"].max_value = Progression.xp_to_next(int(hero["level"]))
		card["xp"].value = float(hero["xp"])
		card["row_btn"].text = "Front" if hero["row"] == "front" else "Back"
		var is_magic: bool = st["damage_type"] == "magic"
		var values := {
			"hp": ["HP", UiUtil.num(st["hp"])],
			"power": ["Magic" if is_magic else "Attack", UiUtil.num(st["magic_power"] if is_magic else st["attack"])],
			"defense": ["Defense", UiUtil.num(st["defense"])],
			"attack_speed": ["Atk Spd", "%.2f/s" % st["attack_speed"]],
			"crit_chance": ["Crit", UiUtil.pct(st["crit_chance"], 1)],
			"crit_damage": ["Crit Dmg", "x%.2f" % st["crit_damage"]],
			"dodge": ["Dodge", UiUtil.pct(st["dodge"], 1)],
			"rating": ["Power", UiUtil.num(StatCalc.power_rating(st))],
		}
		for key in values:
			card["stats"][key][0].text = values[key][0]
			card["stats"][key][1].text = values[key][1]
	for key in _train_buttons:
		var t: Dictionary = DataDB.balance()["training"][key]
		var cost := Progression.training_cost(Game.state, key)
		var b: Button = _train_buttons[key]
		b.text = "%s Lv %d  (%s gold)" % [t["name"], Game.state["training"][key], UiUtil.num(cost)]
		b.disabled = Game.state["gold"] < cost
	_auto_train.set_pressed_no_signal(Game.state["settings"].get("auto_train", true))


func _refresh_gear() -> void:
	if not is_visible_in_tree():
		return
	var sets := DataDB.sets()
	for i in _cards.size():
		var hero: Dictionary = Game.state["heroes"][i]
		var card: Dictionary = _cards[i]
		for slot in card["slots"]:
			var b: Button = card["slots"][slot]
			var item = hero["equipment"][slot]
			if item == null:
				b.text = "%s: —" % slot.capitalize()
				b.tooltip_text = "Empty"
				b.remove_theme_color_override("font_color")
			else:
				b.text = "%s: %s" % [slot.capitalize(), item["name"]]
				b.tooltip_text = item_tooltip(item) + "\n\n(click to unequip)"
				b.add_theme_color_override("font_color", UiUtil.rarity_color(item["rarity"]))
		var lines := []
		var active := StatCalc.active_sets(hero)
		for set_id in active:
			var parts := []
			for threshold in sets[set_id]["bonuses"]:
				var on: bool = active[set_id] >= int(threshold)
				parts.append(("[%s] " % threshold) + sets[set_id]["bonuses"][threshold]["text"] + ("" if on else " (inactive)"))
			lines.append("%s (%d/6): %s" % [sets[set_id]["name"], active[set_id], "; ".join(parts)])
		card["sets"].text = "\n".join(lines)
	_refresh_relics()
	_refresh()


func _refresh_relics() -> void:
	for c in _relic_box.get_children():
		c.queue_free()
	var slots := StatCalc.relic_slots(Game.state)
	var lbl := Label.new()
	lbl.text = "Relics (%d/%d):" % [Game.state["relics_equipped"].size(), slots]
	_relic_box.add_child(lbl)
	var relics := DataDB.relics()
	for relic_id in Game.state["relics_equipped"]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = relics[relic_id]["name"]
		b.tooltip_text = relics[relic_id]["description"] + "\n\n(click to unequip)"
		b.add_theme_color_override("font_color", UiUtil.rarity_color("relic"))
		b.pressed.connect(func(): Game.unequip_relic(relic_id))
		_relic_box.add_child(b)
	for i in slots - Game.state["relics_equipped"].size():
		var empty := Label.new()
		empty.text = "[ empty ]"
		empty.add_theme_color_override("font_color", Color("#5a566a"))
		_relic_box.add_child(empty)


static func item_tooltip(item: Dictionary) -> String:
	var lines := []
	lines.append("%s" % item["name"])
	var rarity_name: String = DataDB.rarities()[item["rarity"]]["name"]
	var cls: String = item["class"]
	lines.append("%s %s  ·  iLvl %d%s" % [rarity_name, item["slot"].capitalize(), item["ilvl"], ("  ·  " + DataDB.classes()[cls]["name"] + " only") if cls != "" else ""])
	for key in item["stats"]:
		lines.append("  " + UiUtil.stat_line(key, float(item["stats"][key])))
	if item.get("set", "") != "":
		var set_def: Dictionary = DataDB.sets()[item["set"]]
		lines.append("")
		lines.append("Set: %s" % set_def["name"])
		for threshold in set_def["bonuses"]:
			lines.append("  (%s) %s" % [threshold, set_def["bonuses"][threshold]["text"]])
	return "\n".join(lines)
