extends Control
## One square item cell: equipment slot (hero_idx >= 0) or bag cell (hero_idx = -1).
## Supports click, double click and drag & drop:
##   bag -> equipment slot : equip        equipment slot -> bag : unequip
##   bag -> another hero's slot works too (class restrictions are checked).

signal selected(slot)
signal activated(slot)

const DataDB = preload("res://core/data_db.gd")
const Loot = preload("res://core/loot_calculator.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")
const UiUtil = preload("res://scenes/ui/ui_util.gd")
const PartyTab = preload("res://scenes/ui/tabs/party_tab.gd")
const Loc = preload("res://core/loc.gd")
const Upgrades = preload("res://core/upgrades.gd")

const GLOW_ME := Color("#7dff8a")      # best choice for the hero being viewed
const GLOW_OTHER := Color("#7fc4ff")   # best choice for another hero of the party

var item = null              # Dictionary or null
var hero_idx := -1
var slot_name := ""          # equipment slot this cell represents ("" for bag cells)
var is_selected := false
## 0 = nothing to say, 1 = an upgrade for another hero, 2 = an upgrade for the
## hero being viewed (or for anyone, in the market).
var upgrade := 0
var _hover := false
var _t := 0.0


## `viewing_hero` turns on the upgrade hints for a bag / shop cell: the index of
## the hero whose gear is on screen, or -1 for "any hero" (the shop). Equipped
## cells (and the default, -2) show no hints.
func setup(item_: Variant, hero_idx_: int, slot_name_: String, cell: float = 48.0, viewing_hero: int = -2) -> void:
	item = item_
	hero_idx = hero_idx_
	slot_name = slot_name_
	custom_minimum_size = Vector2(cell, cell)
	var hints := []
	upgrade = 0
	if item != null and viewing_hero > -2 and hero_idx_ < 0 and slot_name_ == "":
		hints = _upgrade_hints(viewing_hero)
	tooltip_text = PartyTab.item_tooltip(item, hints) if item != null else (Loc.t("%s (empty)") % Loc.t(slot_name.capitalize()) if slot_name != "" else "")
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_process(upgrade > 0)
	queue_redraw()


## Fills `upgrade` and returns the tooltip lines saying who gains what.
func _upgrade_hints(viewing_hero: int) -> Array:
	var scan: Dictionary = Game.upgrades()["items"]
	var uid := int(item["uid"])
	if scan.has(uid):
		var info: Dictionary = scan[uid]
		if viewing_hero in info["top_for"]:
			upgrade = 2
		elif not info["top_for"].is_empty():
			upgrade = 1
		return Upgrades.hint_lines(Game.state, item, info["gains"])
	if viewing_hero == -1:
		# Not in the bag (a shop offer): work it out directly.
		var g := Upgrades.gains(Game.state, item)
		if not g.is_empty():
			upgrade = 2
			return Upgrades.hint_lines(Game.state, item, g)
	return []


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hover = true
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover = false
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			activated.emit(self)
		else:
			selected.emit(self)


func _mono() -> bool:
	return Game.state["settings"].get("art_style", "mono") == "mono"


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var border := Color("#3a3752")
	if item != null:
		border = UiUtil.rarity_color(item["rarity"])
	var bg := Color("#12111a")
	if _hover:
		bg = bg.lightened(0.08)
	draw_rect(r, bg)
	if item != null:
		var tint := border
		tint.a = 0.14
		draw_rect(r.grow(-2), tint)
		var tex := PixelArt.item_icon(item, _mono())
		if tex != null:
			var pad := size.x * 0.14
			draw_texture_rect(tex, r.grow(-pad), false)
		if item.get("set", "") != "":
			draw_rect(Rect2(size.x - 9, 3, 6, 6), Color(DataDB.sets()[item["set"]]["art"]["accent"]) if DataDB.sets().has(item["set"]) else Color("#5fd35f"))
	elif slot_name != "":
		# Faded silhouette of what goes here.
		var ghost := PixelArt.frames({"weapon": "iron_sword"}.get(slot_name, "wayfarer_" + slot_name), {}, true)
		if not ghost.is_empty():
			draw_texture_rect(ghost[0], r.grow(-size.x * 0.2), false, Color(1, 1, 1, 0.18))
	draw_rect(r, border, false, 3.0 if is_selected else 1.5)
	if upgrade > 0 and item != null:
		_draw_upgrade(r)


## A pulsing green frame, a light sweep and an arrow: "this beats what you wear".
func _draw_upgrade(r: Rect2) -> void:
	var col := GLOW_ME if upgrade == 2 else GLOW_OTHER
	var pulse := 0.5 + 0.5 * sin(_t * 4.2)
	# Inside the rarity border, so the item's rarity colour stays readable.
	for k in 3:
		var a := (0.75 - k * 0.2) * (0.45 + 0.55 * pulse)
		draw_rect(r.grow(-2.4 - k * 1.3), Color(col.r, col.g, col.b, a), false, 1.5)
	var tint := col
	tint.a = 0.07 + 0.07 * pulse
	draw_rect(r.grow(-2), tint)
	if upgrade == 2:
		# A diagonal sheen sweeps across every couple of seconds.
		var sweep := fposmod(_t * 0.55, 2.4) - 0.7
		if sweep > -0.3 and sweep < 1.3:
			var c := sweep * (size.x + size.y)
			var w := size.x * 0.16
			var band := PackedVector2Array([Vector2(c - w, 0), Vector2(c + w, 0), Vector2(c + w - size.y, size.y), Vector2(c - w - size.y, size.y)])
			draw_colored_polygon(band, Color(1, 1, 1, 0.3))
	# Arrow badge, top-left.
	var s := maxf(7.0, size.x * 0.2)
	var o := Vector2(3, 3)
	var tri := PackedVector2Array([o + Vector2(s * 0.5, 0), o + Vector2(s, s), o + Vector2(0, s)])
	var bg := PackedVector2Array([tri[0] + Vector2(0, -1.5), tri[1] + Vector2(1.5, 1.2), tri[2] + Vector2(-1.5, 1.2)])
	draw_colored_polygon(bg, Color(0.04, 0.08, 0.04, 0.95))
	draw_colored_polygon(tri, col)


# ------------------------------------------------------------ drag & drop

func _get_drag_data(_pos: Vector2) -> Variant:
	if item == null:
		return null
	var preview := TextureRect.new()
	preview.texture = PixelArt.item_icon(item, _mono())
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.custom_minimum_size = Vector2(40, 40)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return {"stairborn_item": item, "from_hero": hero_idx, "from_slot": slot_name}


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("stairborn_item"):
		return false
	var it: Dictionary = data["stairborn_item"]
	if slot_name != "" and hero_idx >= 0:
		return it["slot"] == slot_name and Loot.can_equip(it, Game.state["heroes"][hero_idx]["class"]) and data["from_hero"] != hero_idx
	# Bag cell: accepts items coming off a hero.
	return int(data["from_hero"]) >= 0


func _drop_data(_pos: Vector2, data: Variant) -> void:
	var it: Dictionary = data["stairborn_item"]
	var from_hero := int(data["from_hero"])
	if slot_name != "" and hero_idx >= 0:
		if from_hero >= 0:
			Game.unequip(from_hero, data["from_slot"])
		Game.equip(hero_idx, int(it["uid"]))
	elif from_hero >= 0:
		Game.unequip(from_hero, data["from_slot"])
