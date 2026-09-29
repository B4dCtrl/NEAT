extends Control
## Opens the menu panels as their own floating OS windows (up to MAX_OPEN).
## They first appear next to the tower; drag one by its title to move it
## anywhere, even to another monitor. Positions are remembered per panel.

signal layout_changed()

const GamePanel = preload("res://scenes/ui/menu/game_panel.gd")
const Ornate = preload("res://scenes/ui/menu/ornate.gd")
const StatusPage = preload("res://scenes/ui/menu/pages/status_page.gd")
const TalentsPage = preload("res://scenes/ui/menu/pages/talents_page.gd")
const SkillsPage = preload("res://scenes/ui/menu/pages/skills_page.gd")
const InventoryPage = preload("res://scenes/ui/menu/pages/inventory_page.gd")
const HeroesPage = preload("res://scenes/ui/menu/pages/heroes_page.gd")
const SoulsPage = preload("res://scenes/ui/menu/pages/souls_page.gd")
const QuestsPage = preload("res://scenes/ui/menu/pages/quests_page.gd")
const Loc = preload("res://core/loc.gd")
const SettingsTab = preload("res://scenes/ui/tabs/settings_tab.gd")

const MAX_OPEN := 3
const GAP := 6.0
const PANEL_H := 420.0
const ORDER := ["status", "heroes", "talents", "skills", "inventory", "quests", "souls", "settings"]
const WIDTHS := {"status": 300.0, "heroes": 320.0, "talents": 300.0, "skills": 300.0, "inventory": 360.0, "quests": 300.0, "souls": 320.0, "settings": 320.0}

## Hero shown by the hero-centric pages; shared so switching tabs keeps it.
var hero_idx := 0
## Docked on the top of the screen: panels hang below the tower instead.
var flip := false
var _open: Array = []   # panel ids, oldest first
var _panels := {}       # id -> GamePanel
var _windows := {}      # id -> Window hosting that panel
var _shown := true


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
	var sz := Vector2(WIDTHS[id], PANEL_H)
	p.setup(id, Loc.t("panel." + id), _make_page(id), sz)
	p.close_requested.connect(close)
	p.dragged.connect(_on_panel_dragged)
	var w := Window.new()
	w.title = "Stairborn · " + Loc.t("panel." + id).capitalize()
	w.borderless = true
	w.transparent = true
	w.transparent_bg = true
	w.unresizable = true
	w.always_on_top = bool(Game.state["settings"].get("always_on_top", true))
	w.size = Vector2i(sz)
	w.theme = Ornate.theme()
	w.visible = false
	w.add_child(p)
	add_child(w)
	_panels[id] = p
	_windows[id] = w
	_open.append(id)
	w.position = _start_position(id)
	w.visible = _shown
	layout_changed.emit()


func close(id: String) -> void:
	if not is_open(id):
		return
	_open.erase(id)
	var w = _windows[id]
	_panels.erase(id)
	_windows.erase(id)
	w.queue_free()
	layout_changed.emit()


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
		"heroes":
			page = HeroesPage.new()
		"souls":
			page = SoulsPage.new()
		"quests":
			page = QuestsPage.new()
		_:
			page = SettingsTab.new()
			page.compact = true
	if "host" in page:
		page.host = self
	return page


## Where a panel opens: where the player last left it, else beside the
## tower window (above it, or below when the tower sits near the top).
func _start_position(id: String) -> Vector2i:
	var saved = Game.state["settings"].get("panel_pos", {}).get(id, null)
	if saved is Array and saved.size() == 2:
		var r := Rect2i(Vector2i(int(saved[0]), int(saved[1])), Vector2i(int(WIDTHS[id]), int(PANEL_H)))
		for i in DisplayServer.get_screen_count():
			if DisplayServer.screen_get_usable_rect(i).intersection(r).size.x >= 80:
				return r.position
	var main := get_window()
	var screen := DisplayServer.screen_get_usable_rect(main.current_screen)
	# First panel: right edge on the tower's right edge. Later ones open next
	# to the panels already on screen, keeping the menu order left to right.
	var x: float = float(main.position.x + main.size.x) - float(WIDTHS[id])
	var mine := ORDER.find(id)
	var left_edge := INF
	var right_edge := -INF
	for other in _windows:
		if other == id:
			continue
		var w: Window = _windows[other]
		if ORDER.find(other) < mine:
			right_edge = maxf(right_edge, float(w.position.x + w.size.x))
		else:
			left_edge = minf(left_edge, float(w.position.x))
	if right_edge > -INF:
		x = right_edge + GAP
	elif left_edge < INF:
		x = left_edge - GAP - float(WIDTHS[id])
	# No room on the right: open left of everything instead of overlapping.
	var screen_r := DisplayServer.screen_get_usable_rect(main.current_screen)
	if x + float(WIDTHS[id]) > float(screen_r.end.x):
		var leftmost := float(main.position.x + main.size.x)
		for other in _windows:
			if other != id:
				leftmost = minf(leftmost, float(_windows[other].position.x))
		x = leftmost - GAP - float(WIDTHS[id])
	var y := main.position.y - int(PANEL_H) - int(GAP)
	for other in _windows:
		if other != id:
			y = _windows[other].position.y
			break
	if y < screen.position.y:
		y = main.position.y + main.size.y + int(GAP)
	var px := clampi(int(x), screen.position.x, screen.end.x - int(WIDTHS[id]))
	var py := clampi(y, screen.position.y, screen.end.y - int(PANEL_H))
	return Vector2i(px, py)


func _on_panel_dragged(id: String, pos: Vector2i) -> void:
	if not _windows.has(id):
		return
	_windows[id].position = pos
	var saved: Dictionary = Game.state["settings"].get("panel_pos", {})
	saved[id] = [pos.x, pos.y]
	Game.state["settings"]["panel_pos"] = saved


func window_of(id: String) -> Window:
	return _windows.get(id)


## Panels follow the tower: hidden in Expedition mode and in the tray.
func set_shown(on: bool) -> void:
	if on == _shown:
		return
	_shown = on
	for id in _windows:
		_windows[id].visible = on


## Pages call this so every hero-centric page follows the same hero.
func select_hero(i: int) -> void:
	hero_idx = i
	for id in _panels:
		var page = _panels[id].page
		if "hero_idx" in page and page.hero_idx != i:
			page.hero_idx = i
			if page.has_method("mark_dirty"):
				page.mark_dirty()
