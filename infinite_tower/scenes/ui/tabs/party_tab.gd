extends MarginContainer
## Party: hero cards (row, stats, skill), recruiting (mint / bench), training
## and the relic collection. Gear lives in the Equipment tab, skills in Skills.

const DataDB = preload("res://core/data_db.gd")
const StatCalc = preload("res://core/stat_calculator.gd")
const Progression = preload("res://core/progression.gd")
const Heroes = preload("res://core/heroes.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")
const UiUtil = preload("res://scenes/ui/ui_util.gd")

var _cards_row: HBoxContainer
var _cards: Array = []
var _recruit_box: VBoxContainer
var _mint_btn: Button
var _train_buttons := {}
var _auto_train: CheckBox
var _relic_box: HFlowContainer
var _dirty := true


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)

	_cards_row = HBoxContainer.new()
	_cards_row.add_theme_constant_override("separation", 10)
	root.add_child(_cards_row)

	var recruit_panel := PanelContainer.new()
	root.add_child(recruit_panel)
	_recruit_box = VBoxContainer.new()
	recruit_panel.add_child(_recruit_box)

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
	_auto_train.text = "Auto-train (saves for the next hero)"
	_auto_train.focus_mode = Control.FOCUS_NONE
	_auto_train.toggled.connect(func(on): Game.set_setting("auto_train", on))
	train_row.add_child(_auto_train)

	var relic_panel := PanelContainer.new()
	root.add_child(relic_panel)
	_relic_box = HFlowContainer.new()
	relic_panel.add_child(_relic_box)

	Game.state_changed.connect(_refresh)
	Game.party_changed.connect(func(): _dirty = true)
	Game.inventory_changed.connect(func(): _dirty = true)
	visibility_changed.connect(func(): _dirty = true)


func _process(_delta: float) -> void:
	if _dirty and is_visible_in_tree():
		_dirty = false
		_rebuild()


func _rebuild() -> void:
	for c in _cards_row.get_children():
		c.queue_free()
	_cards.clear()
	for i in Game.state["heroes"].size():
		_cards_row.add_child(_build_card(i))
	for i in range(Game.state["heroes"].size(), Heroes.party_slots()):
		var empty := PanelContainer.new()
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l := Label.new()
		l.text = "\n\nEmpty slot\n\nMint a hero below\nor buy one in the Market"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", Color("#5a566a"))
		empty.add_child(l)
		_cards_row.add_child(empty)
	_rebuild_recruit()
	_rebuild_relics()
	_refresh()


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
	portrait.texture = PixelArt.unit_frames(hero["class"], cdef["sprite"], {}, false)[0]
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
	name_lbl.text = "%s · %s" % [hero["name"], cdef["name"]]
	name_lbl.add_theme_color_override("font_color", UiUtil.rarity_color(hero.get("rarity", "common")))
	name_box.add_child(name_lbl)
	var level_lbl := Label.new()
	level_lbl.add_theme_color_override("font_color", Color("#9a96a8"))
	level_lbl.add_theme_font_size_override("font_size", 12)
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
	if Game.state["heroes"].size() > 1:
		var bench := Button.new()
		bench.focus_mode = Control.FOCUS_NONE
		bench.text = "Send to bench"
		bench.add_theme_font_size_override("font_size", 12)
		bench.pressed.connect(func(): Game.bench_hero(i))
		v.add_child(bench)
	_cards.append({"level": level_lbl, "xp": xp, "row_btn": row_btn, "stats": stat_labels})
	return panel


func _rebuild_recruit() -> void:
	for c in _recruit_box.get_children():
		c.queue_free()
	var head := HBoxContainer.new()
	_recruit_box.add_child(head)
	var t := Label.new()
	t.text = "Heroes: %d/%d in party · %d on the bench" % [Game.state["heroes"].size(), Heroes.party_slots(), Game.state["bench"].size()]
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_mint_btn = Button.new()
	_mint_btn.focus_mode = Control.FOCUS_NONE
	_mint_btn.tooltip_text = "Mint a brand-new hero: random class, name and rarity (potential)."
	_mint_btn.pressed.connect(func(): Game.mint_hero())
	head.add_child(_mint_btn)
	for b in Game.state["bench"].size():
		var hero: Dictionary = Game.state["bench"][b]
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s · %s · Lv %d" % [hero["name"], DataDB.classes()[hero["class"]]["name"], hero["level"]]
		l.add_theme_color_override("font_color", UiUtil.rarity_color(hero.get("rarity", "common")))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		for p in Game.state["heroes"].size():
			var sb := Button.new()
			sb.focus_mode = Control.FOCUS_NONE
			sb.add_theme_font_size_override("font_size", 12)
			sb.text = "Swap with " + Game.state["heroes"][p]["name"]
			sb.pressed.connect(func(): Game.swap_hero(p, b))
			row.add_child(sb)
		if Game.state["heroes"].size() < Heroes.party_slots():
			var jb := Button.new()
			jb.focus_mode = Control.FOCUS_NONE
			jb.text = "Join party"
			jb.pressed.connect(func(): Game.swap_hero(Game.state["heroes"].size(), b))
			row.add_child(jb)
		_recruit_box.add_child(row)


func _refresh() -> void:
	if not is_visible_in_tree() or _cards.size() != Game.state["heroes"].size():
		return
	var mods := StatCalc.party_mods(Game.state)
	for i in _cards.size():
		var hero: Dictionary = Game.state["heroes"][i]
		var card: Dictionary = _cards[i]
		var st := StatCalc.hero_stats(Game.state, hero, mods)
		card["level"].text = "Level %d · %s potential · %d skill pts" % [hero["level"], hero.get("rarity", "common").capitalize(), Heroes.skill_points_free(hero)]
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
	if _mint_btn != null:
		var cost := Heroes.mint_cost(Game.state)
		_mint_btn.text = "  Mint hero (%s gold)  " % UiUtil.num(cost)
		_mint_btn.disabled = Game.state["gold"] < cost
	for key in _train_buttons:
		var t: Dictionary = DataDB.balance()["training"][key]
		var cost := Progression.training_cost(Game.state, key)
		var b: Button = _train_buttons[key]
		b.text = "%s Lv %d  (%s gold)" % [t["name"], Game.state["training"][key], UiUtil.num(cost)]
		b.disabled = Game.state["gold"] < cost
	_auto_train.set_pressed_no_signal(Game.state["settings"].get("auto_train", true))


func _rebuild_relics() -> void:
	for c in _relic_box.get_children():
		c.queue_free()
	var slots := StatCalc.relic_slots(Game.state)
	var lbl := Label.new()
	lbl.text = "Gems %d/%d equipped:" % [Game.state["relics_equipped"].size(), slots]
	_relic_box.add_child(lbl)
	var relics := DataDB.relics()
	for relic_id in relics:
		var owned: bool = relic_id in Game.state["relics_owned"]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
		if not owned:
			b.text = "???"
			b.disabled = true
			b.tooltip_text = "Undiscovered gem"
		else:
			var equipped: bool = relic_id in Game.state["relics_equipped"]
			b.text = ("● " if equipped else "○ ") + relics[relic_id]["name"]
			b.icon = PixelArt.gem(relic_id)
			b.add_theme_constant_override("icon_max_width", 22)
			b.tooltip_text = relics[relic_id]["description"] + ("\n\n(click to unequip)" if equipped else "\n\n(click to equip)")
			b.add_theme_color_override("font_color", UiUtil.rarity_color("relic"))
			b.disabled = not equipped and Game.state["relics_equipped"].size() >= slots
			b.pressed.connect(func():
				if equipped:
					Game.unequip_relic(relic_id)
				else:
					Game.equip_relic(relic_id))
		_relic_box.add_child(b)


static func item_tooltip(item: Dictionary) -> String:
	var lines := []
	var rarity_name: String = DataDB.rarities()[item["rarity"]]["name"]
	lines.append(item["name"])
	lines.append("%s %s  ·  Item Level %d" % [rarity_name, item["slot"].capitalize(), item["ilvl"]])
	lines.append("Usable by: " + users_text(item))
	if item.get("bound", false):
		lines.append("Bound: it was equipped, so it can no longer be traded")
	var base_keys := []
	for b in DataDB.items()["bases"]:
		if b["id"] == item.get("base", ""):
			base_keys = b["stats"].keys() + b.get("fixed", {}).keys()
	lines.append("")
	for key in item["stats"]:
		if key in base_keys:
			lines.append("  " + UiUtil.stat_line(key, float(item["stats"][key])))
	var bonus := []
	for key in item["stats"]:
		if not key in base_keys:
			bonus.append("  " + UiUtil.stat_line(key, float(item["stats"][key])))
	if not bonus.is_empty():
		lines.append("Bonuses:")
		lines.append_array(bonus)
	if item.get("set", "") != "":
		var set_def: Dictionary = DataDB.sets()[item["set"]]
		lines.append("")
		lines.append("Set: %s  (tier %d of %d)" % [set_def["name"], int(set_def.get("tier", 1)), DataDB.sets().size()])
		for threshold in set_def["bonuses"]:
			lines.append("  (%s pieces) %s" % [threshold, set_def["bonuses"][threshold]["text"]])
	return "\n".join(lines)


## "Everyone", or the classes that can wield a class-locked weapon.
static func users_text(item: Dictionary) -> String:
	if item["class"] == "":
		return "every hero"
	var names := []
	for id in DataDB.classes():
		if item["class"] == id or item["class"] in DataDB.classes()[id].get("uses", []):
			names.append(DataDB.classes()[id]["name"])
	return ", ".join(names)


## Per-stat difference between `item` and what is equipped in its slot.
static func compare_lines(item: Dictionary, equipped) -> Array:
	var keys: Array = item["stats"].keys()
	if equipped != null:
		for k in equipped["stats"]:
			if not k in keys:
				keys.append(k)
	var out := []
	for k in keys:
		var a := float(item["stats"].get(k, 0.0))
		var b := float(equipped["stats"].get(k, 0.0)) if equipped != null else 0.0
		if absf(a - b) < 0.0005:
			continue
		var line := UiUtil.stat_line(k, absf(a - b)).substr(1)
		out.append([("▲ +" if a > b else "▼ -") + line, a > b])
	return out
