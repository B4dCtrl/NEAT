extends VBoxContainer
## SKILLS: the hero's active job skills. They are learned and levelled up in
## TALENTS with skill points, then AUTO-CAST in every fight while there is
## mana. Shows level, cost, live cooldowns and an auto-cast on/off switch.

const DataDB = preload("res://core/data_db.gd")
const Heroes = preload("res://core/heroes.gd")
const Ornate = preload("res://scenes/ui/menu/ornate.gd")
const IconTile = preload("res://scenes/ui/menu/icon_tile.gd")
const HeroPicker = preload("res://scenes/ui/menu/hero_picker.gd")
const Loc = preload("res://core/loc.gd")

const CLASS_COLORS := {"stairborn": Color("#6a2c24"), "knight": Color("#24456e"), "ranger": Color("#2d5a2a"), "arcanist": Color("#4a2a6e")}

var host
var hero_idx := 0
var _picker
var _list: VBoxContainer
var _cards: Array = []   # [{id, tile, toggle, meta, desc}]
var _built_for := ""
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
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var hint := Ornate.small_label(Loc.t("Learn and level skills in TALENTS (1 point per level). Learned skills auto-cast when there is mana; switch one off to save mana."), Ornate.TEXT_DIM, 11)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(200, 0)
	add_child(hint)
	Game.state_changed.connect(func(): _dirty = true)
	Game.party_changed.connect(func(): _picker.rebuild(); _built_for = ""; _dirty = true)


func _hero() -> Dictionary:
	return Game.state["heroes"][clampi(hero_idx, 0, Game.state["heroes"].size() - 1)]


func _build() -> void:
	for c in _list.get_children():
		c.queue_free()
	_cards.clear()
	var hero := _hero()
	_built_for = String(hero["id"])
	var nodes := DataDB.skill_nodes(hero["class"])
	for id in Heroes.class_skills(hero["class"]):
		var n: Dictionary = nodes[id]
		var panel := PanelContainer.new()
		_list.add_child(panel)
		var h := HBoxContainer.new()
		panel.add_child(h)
		var tile = IconTile.new()
		tile.custom_minimum_size = Vector2(44, 44)
		tile.glyph = n.get("icon", "star")
		tile.fill = CLASS_COLORS.get(hero["class"], Color("#5a2a24"))
		h.add_child(tile)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 1)
		h.add_child(v)
		v.add_child(Ornate.header_label(n["name"]))
		var meta := Ornate.small_label("", Ornate.TEXT_DIM, 11)
		meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		meta.custom_minimum_size = Vector2(150, 0)
		v.add_child(meta)
		var desc := Ornate.small_label("", Ornate.TEXT, 11)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(150, 0)
		v.add_child(desc)
		var toggle := Button.new()
		toggle.focus_mode = Control.FOCUS_NONE
		toggle.custom_minimum_size = Vector2(46, 0)
		toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var sid: String = id
		toggle.pressed.connect(func(): Game.toggle_active_skill(hero_idx, sid); _dirty = true)
		h.add_child(toggle)
		_cards.append({"id": id, "tile": tile, "toggle": toggle, "meta": meta, "desc": desc})


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	if _dirty:
		_dirty = false
		hero_idx = clampi(hero_idx, 0, Game.state["heroes"].size() - 1)
		if _picker.selected != hero_idx:
			_picker.select(hero_idx, false)
		_picker.refresh()
		if _built_for != String(_hero()["id"]):
			_build()
		_refresh()
	_update_cooldowns()


func _refresh() -> void:
	var hero := _hero()
	var nodes := DataDB.skill_nodes(hero["class"])
	for c in _cards:
		var id: String = c["id"]
		var rank := Heroes.skill_rank(hero, id)
		var learned := rank > 0
		var on := Heroes.active_skill_enabled(hero, id)
		c["tile"].locked = not learned
		c["tile"].dim = learned and not on
		c["tile"].rank_text = ""
		c["tile"].queue_redraw()
		c["desc"].text = Heroes.describe(id, maxi(rank, 1)).get_slice(" · ", 0)
		if learned:
			var sk := Heroes.skill_at_rank(id, rank)
			c["meta"].text = Loc.t("Lv %d/%d · %d mana · %ss cooldown") % [rank, int(nodes[id]["max"]), int(sk["mana"]), String.num(float(sk["cooldown"]), 0)]
		else:
			var reqs := []
			for req in nodes[id]["requires"]:
				reqs.append("%s %d" % [nodes[req]["name"], nodes[id]["requires"][req]])
			c["meta"].text = Loc.t("Not learned") + (Loc.t(" · needs ") + ", ".join(reqs) if not reqs.is_empty() else Loc.t(" · learn it in TALENTS"))
		c["toggle"].disabled = not learned
		c["toggle"].text = "ON" if on and learned else (Loc.t("OFF") if learned else "—")
		c["toggle"].tooltip_text = Loc.t("Auto-cast on/off")
		c["toggle"].add_theme_color_override("font_color", Ornate.GOOD if on and learned else Ornate.TEXT_DIM)


## Live cooldown sweep and "out of mana" dimming while the party fights.
func _update_cooldowns() -> void:
	var exp = Game.expedition
	var unit = null
	if exp != null and exp.combat != null and exp.phase == "combat" and hero_idx < exp.combat.heroes.size():
		unit = exp.combat.heroes[hero_idx]
	for c in _cards:
		var cd := 0.0
		var cost := 0.0
		if unit != null and unit.alive:
			for i in unit.skills.size():
				if unit.skills[i].get("id", "") == c["id"]:
					cd = clampf(unit.skill_cds[i] / maxf(0.1, float(unit.skills[i]["cooldown"])), 0.0, 1.0)
					cost = float(unit.skills[i].get("mana", 0))
		var dry: bool = unit != null and unit.alive and cost > 0.0 and unit.mana < cost
		if dry != c["tile"].dim and Heroes.active_skill_enabled(_hero(), c["id"]) and Heroes.skill_rank(_hero(), c["id"]) > 0:
			c["tile"].dim = dry
			c["tile"].queue_redraw()
		if absf(cd - c["tile"].cooldown) > 0.001:
			c["tile"].cooldown = cd
			c["tile"].queue_redraw()
