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

var item = null              # Dictionary or null
var hero_idx := -1
var slot_name := ""          # equipment slot this cell represents ("" for bag cells)
var is_selected := false
var _hover := false


func setup(item_: Variant, hero_idx_: int, slot_name_: String, cell: float = 48.0) -> void:
	item = item_
	hero_idx = hero_idx_
	slot_name = slot_name_
	custom_minimum_size = Vector2(cell, cell)
	tooltip_text = PartyTab.item_tooltip(item) if item != null else (slot_name.capitalize() + " (empty)" if slot_name != "" else "")
	mouse_filter = Control.MOUSE_FILTER_STOP
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
			draw_rect(Rect2(size.x - 9, 3, 6, 6), Color("#5fd35f"))
	elif slot_name != "":
		# Faded silhouette of what goes here.
		var ghost := PixelArt.frames("item_" + slot_name if slot_name != "weapon" else "item_sword", {}, true)
		if not ghost.is_empty():
			draw_texture_rect(ghost[0], r.grow(-size.x * 0.2), false, Color(1, 1, 1, 0.18))
	draw_rect(r, border, false, 3.0 if is_selected else 1.5)


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
