extends MarginContainer
## Per-hero skill tree: one point per level, three branches (Might / Guard / Cunning).

const DataDB = preload("res://core/data_db.gd")
const Heroes = preload("res://core/heroes.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")

var hero_idx := 0
var _picker: HBoxContainer
var _points: Label
var _auto: CheckBox
var _columns: HBoxContainer
var _node_buttons := {}
var _dirty := true


func _ready() -> void:
	var v := VBoxContainer.new()
	add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_picker = HBoxContainer.new()
	top.add_child(_picker)
	_points = Label.new()
	_points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_points)
	_auto = CheckBox.new()
	_auto.focus_mode = Control.FOCUS_NONE
	_auto.text = "Auto-spend points"
	_auto.toggled.connect(func(on): Game.set_setting("auto_skills", on))
	top.add_child(_auto)
	var reset := Button.new()
	reset.focus_mode = Control.FOCUS_NONE
	reset.text = "Reset points"
	reset.pressed.connect(func(): Game.reset_skills(hero_idx); _dirty = true)
	top.add_child(reset)

	_columns = HBoxContainer.new()
	_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_columns.add_theme_constant_override("separation", 12)
	v.add_child(_columns)
	var tree: Dictionary = DataDB.table("skills")
	for branch in tree["branches"]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := Label.new()
		title.text = tree["branches"][branch]
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_color_override("font_color", Color("#f2c14e"))
		col.add_child(title)
		var ids := []
		for id in tree["nodes"]:
			if tree["nodes"][id]["branch"] == branch:
				ids.append(id)
		ids.sort_custom(func(a, b): return int(tree["nodes"][a]["row"]) < int(tree["nodes"][b]["row"]))
		for id in ids:
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(0, 58)
			var node_id: String = id
			b.pressed.connect(func(): Game.learn_skill(hero_idx, node_id); _dirty = true)
			col.add_child(b)
			_node_buttons[id] = b
		_columns.add_child(col)

	Game.state_changed.connect(func(): _dirty = true)
	Game.party_changed.connect(func(): hero_idx = 0; _dirty = true)
	visibility_changed.connect(func(): _dirty = true)


func _process(_delta: float) -> void:
	if _dirty and is_visible_in_tree():
		_dirty = false
		_rebuild()


func _rebuild() -> void:
	var heroes: Array = Game.state["heroes"]
	hero_idx = clampi(hero_idx, 0, heroes.size() - 1)
	for c in _picker.get_children():
		c.queue_free()
	for i in heroes.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = i == hero_idx
		var free := Heroes.skill_points_free(heroes[i])
		b.text = heroes[i]["name"] + (" (%d)" % free if free > 0 else "")
		b.icon = PixelArt.unit_frames(heroes[i]["class"], DataDB.classes()[heroes[i]["class"]]["sprite"], {}, false)[0]
		b.pressed.connect(func(): hero_idx = i; _dirty = true)
		_picker.add_child(b)
	var hero: Dictionary = heroes[hero_idx]
	_points.text = "%s · Lv %d · %d / %d points free" % [hero["name"], hero["level"], Heroes.skill_points_free(hero), Heroes.skill_points_total(hero)]
	_auto.set_pressed_no_signal(Game.state["settings"].get("auto_skills", true))
	var nodes := DataDB.skill_nodes()
	for id in _node_buttons:
		var n: Dictionary = nodes[id]
		var rank := Heroes.skill_rank(hero, id)
		var unlocked := Heroes.skill_unlocked(hero, id)
		var reqs := []
		for req in n["requires"]:
			reqs.append("%s %d" % [nodes[req]["name"], n["requires"][req]])
		var b: Button = _node_buttons[id]
		b.text = "%s  [%d/%d]\n%s%s" % [n["name"], rank, n["max"], n["text"], "" if unlocked else "\nRequires " + ", ".join(reqs)]
		b.disabled = not unlocked or rank >= int(n["max"]) or Heroes.skill_points_free(hero) <= 0
		b.modulate = Color(1, 1, 1, 1) if rank > 0 or unlocked else Color(1, 1, 1, 0.6)
