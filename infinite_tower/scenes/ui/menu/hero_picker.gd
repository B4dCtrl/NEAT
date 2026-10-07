extends HBoxContainer
## Row of framed hero portraits (with level) used at the top of the menu
## panels. Empty party slots show a "+" that mints a new hero.

signal picked(index: int)

const DataDB = preload("res://core/data_db.gd")
const Heroes = preload("res://core/heroes.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")
const UiUtil = preload("res://scenes/ui/ui_util.gd")
const Ornate = preload("res://scenes/ui/menu/ornate.gd")
const IconTile = preload("res://scenes/ui/menu/icon_tile.gd")

var selected := 0
var show_mint := false
## Optional per-hero badge text (e.g. free talent points).
var badge: Callable
var _sig := ""


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	Game.party_changed.connect(rebuild)
	rebuild()


## Rebuilds only when levels, badges or gold for minting changed.
func refresh() -> void:
	if _signature() != _sig:
		rebuild()


func _signature() -> String:
	var parts := [Game.state["heroes"].size()]
	for h in Game.state["heroes"]:
		parts.append([h["id"], h["level"], str(badge.call(h)) if badge.is_valid() else ""])
	if show_mint:
		parts.append(Heroes.can_mint(Game.state))
	return str(parts)


func rebuild() -> void:
	_sig = _signature()
	for c in get_children():
		c.queue_free()
	var heroes: Array = Game.state["heroes"]
	selected = clampi(selected, 0, heroes.size() - 1)
	for i in heroes.size():
		var h: Dictionary = heroes[i]
		var t = IconTile.new()
		t.custom_minimum_size = Vector2(38, 50)
		t.texture = PixelArt.unit_frames(h["class"], DataDB.classes()[h["class"]]["sprite"], {}, false)[0]
		t.fill = Color("#2e1f19")
		t.rim = UiUtil.rarity_color(h.get("rarity", "common")).darkened(0.2)
		t.highlight = i == selected
		t.rank_text = "Lv%d" % int(h["level"])
		var extra := ""
		if badge.is_valid():
			extra = str(badge.call(h))
		t.available = extra != ""
		t.tooltip_text = "%s · %s%s" % [h["name"], DataDB.classes()[h["class"]]["name"], ("\n" + extra) if extra != "" else ""]
		t.pressed.connect(func(): select(i))
		add_child(t)
	if show_mint:
		for i in range(heroes.size(), Heroes.party_slots()):
			var t = IconTile.new()
			t.custom_minimum_size = Vector2(38, 50)
			t.glyph = "cross"
			t.fill = Color("#241813")
			t.rim = Ornate.GOLD_LO
			var cost := Heroes.mint_cost(Game.state)
			t.rank_text = UiUtil.num(cost)
			t.dim = not Heroes.can_mint(Game.state)
			t.tooltip_text = "Empty slot: mint a new hero for %s gold\n(random class, name and rarity)%s" % [UiUtil.num(cost), ("\n" + Heroes.mint_blocker(Game.state)) if not Heroes.can_mint(Game.state) else ""]
			t.pressed.connect(func(): Game.mint_hero())
			add_child(t)


func select(i: int, notify: bool = true) -> void:
	selected = i
	for j in get_child_count():
		var c = get_child(j)
		c.highlight = j == i
		c.queue_redraw()
	if notify:
		picked.emit(i)
