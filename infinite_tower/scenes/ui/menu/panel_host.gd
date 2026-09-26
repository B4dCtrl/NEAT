extends Control
## Opens the menu panels above the tower (up to MAX_OPEN side by side, newest
## closest to the tower) and tells the taskbar view how much room they need.

signal layout_changed()

const GamePanel = preload("res://scenes/ui/menu/game_panel.gd")
const Ornate = preload("res://scenes/ui/menu/ornate.gd")
const StatusPage = preload("res://scenes/ui/menu/pages/status_page.gd")
const TalentsPage = preload("res://scenes/ui/menu/pages/talents_page.gd")
const SkillsPage = preload("res://scenes/ui/menu/pages/skills_page.gd")
const InventoryPage = preload("res://scenes/ui/menu/pages/inventory_page.gd")
const SettingsTab = preload("res://scenes/ui/tabs/settings_tab.gd")

const MAX_OPEN := 3
const GAP := 6.0
const PANEL_H := 420.0
const ORDER := ["status", "talents", "skills", "inventory", "settings"]
const TITLES := {"status": "STATUS", "talents": "TALENTS", "skills": "SKILLS", "inventory": "INVENTORY", "settings": "SETTINGS"}
const WIDTHS := {"status": 300.0, "talents": 300.0, "skills": 300.0, "inventory": 360.0, "settings": 320.0}

## Hero shown by the hero-centric pages; shared so switching tabs keeps it.
var hero_idx := 0
## Docked on the top of the screen: panels hang below the tower instead.
var flip := false
var _open: Array = []   # panel ids, oldest first
var _panels := {}       # id -> GamePanel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Ornate.theme()


func is_open(id: String) -> bool:
	return id in _open


func open_ids() -> Array:
	return _open.duplicate()


func toggle(id: String) -> void:
	if is_open(id):
		close(id)
	else:
		open(id)


func open(id: String) -> void:
	if is_open(id):
		return
	if _open.size() >= MAX_OPEN:
		close(_open[0])
	var p = GamePanel.new()
	p.setup(id, TITLES[id], _make_page(id), Vector2(WIDTHS[id], PANEL_H))
	p.close_requested.connect(close)
	add_child(p)
	_panels[id] = p
	_open.append(id)
	_layout()


func close(id: String) -> void:
	if not is_open(id):
		return
	_open.erase(id)
	var p = _panels[id]
	_panels.erase(id)
	p.queue_free()
	_layout()


func close_all() -> void:
	for id in _open.duplicate():
		close(id)


func _make_page(id: String) -> Control:
	var page: Control
	match id:
		"status":
			page = StatusPage.new()
		"talents":
			page = TalentsPage.new()
		"skills":
			page = SkillsPage.new()
		"inventory":
			page = InventoryPage.new()
		_:
			page = SettingsTab.new()
			page.compact = true
	if "host" in page:
		page.host = self
	return page


## Room the open panels need (0 when none are open).
func needed_size() -> Vector2:
	if _open.is_empty():
		return Vector2.ZERO
	var w := 0.0
	for id in _open:
		w += WIDTHS[id]
	return Vector2(w + GAP * (_open.size() - 1), PANEL_H + GAP)


## Panels line up right-aligned in menu order, bottoms resting on `bottom`.
func _layout() -> void:
	var ids := ORDER.filter(func(i): return i in _open)
	var x := size.x
	for i in range(ids.size() - 1, -1, -1):
		var p = _panels[ids[i]]
		x -= WIDTHS[ids[i]]
		p.position = Vector2(x, GAP if flip else size.y - PANEL_H)
		x -= GAP
	layout_changed.emit()


func panel_rects() -> Array:
	var out := []
	for id in _open:
		var p = _panels[id]
		out.append(Rect2(p.position + position, p.size))
	return out


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


## Pages call this so every hero-centric page follows the same hero.
func select_hero(i: int) -> void:
	hero_idx = i
	for id in _panels:
		var page = _panels[id].page
		if "hero_idx" in page and page.hero_idx != i:
			page.hero_idx = i
			if page.has_method("mark_dirty"):
				page.mark_dirty()
