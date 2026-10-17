extends Control
## Row of round gold-rimmed buttons next to the tower: each one toggles a menu
## panel; the last one opens the full Expedition window.

signal toggled(panel_id: String)
signal expand_requested()
signal close_requested()

const Ornate = preload("res://scenes/ui/menu/ornate.gd")
const Glyphs = preload("res://scenes/ui/menu/glyphs.gd")
const Loc = preload("res://core/loc.gd")

const BUTTON := 20.0
const GAP := 2.0
## [id, glyph, tooltip]
const BUTTONS := [
	["status", "helm", "menu.status"],
	["heroes", "banner", "menu.heroes"],
	["talents", "tree", "menu.talents"],
	["skills", "book", "menu.skills"],
	["inventory", "bag", "menu.inventory"],
	["quests", "star", "menu.quests"],
	["collection", "gift", "menu.collection"],
	["manga", "manga", "menu.manga"],
	["souls", "skull", "menu.souls"],
	["settings", "gear", "menu.settings"],
	["expedition", "expand", "menu.expedition"],
	["close", "minimize", "menu.close"],
	["quit", "power", "menu.quit"],
]

var open_ids: Array = []
var _hover := -1
var _t := 0.0


## The Inventory button pulses while the bag holds a better item for somebody.
func _process(delta: float) -> void:
	if Game.logged_in() and int(Game.upgrades()["total"]) > 0:
		_t += delta
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(width(), BUTTON)


static func width() -> float:
	return BUTTONS.size() * BUTTON + (BUTTONS.size() - 1) * GAP


func _button_rect(i: int) -> Rect2:
	return Rect2(i * (BUTTON + GAP), 0, BUTTON, BUTTON)


func _index_at(p: Vector2) -> int:
	for i in BUTTONS.size():
		if _button_rect(i).has_point(p):
			return i
	return -1


func _get_tooltip(at: Vector2) -> String:
	var i := _index_at(at)
	return Loc.t(BUTTONS[i][2]) if i >= 0 else ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var i := _index_at(event.position)
		if i != _hover:
			_hover = i
			tooltip_text = Loc.t(BUTTONS[i][2]) if i >= 0 else ""
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _index_at(event.position)
		if i >= 0:
			var id: String = BUTTONS[i][0]
			if id == "expedition":
				expand_requested.emit()
			elif id == "close":
				close_requested.emit()
			elif id == "manga":
				Game.story_requested.emit("manga")
			elif id == "quit":
				Game.save()
				get_tree().quit()
			else:
				toggled.emit(id)
			Game.sfx_requested.emit("use")
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = -1
		queue_redraw()


func _draw() -> void:
	for i in BUTTONS.size():
		var r := _button_rect(i)
		var c := r.get_center()
		var rad := BUTTON * 0.5
		var on: bool = BUTTONS[i][0] in open_ids
		draw_circle(c + Vector2(1, 2), rad, Color(0, 0, 0, 0.35))
		draw_circle(c, rad, Ornate.OUT)
		draw_circle(c, rad - 2.0, Ornate.GOLD if on or i == _hover else Ornate.GOLD_LO)
		draw_circle(c, rad - 4.0, Color("#8e3328") if on else (Color("#74302a") if i == _hover else Ornate.FRAME))
		draw_circle(c + Vector2(-2, -3), rad - 8.0, Color(1, 1, 1, 0.08))
		var s := BUTTON - 10.0
		draw_texture_rect(Glyphs.texture(BUTTONS[i][1]), Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		if BUTTONS[i][0] == "inventory" and not on and Game.logged_in() and int(Game.upgrades()["total"]) > 0:
			var pulse := 0.5 + 0.5 * sin(_t * 5.0)
			draw_arc(c, rad + 1.0, 0, TAU, 28, Color(0.49, 1.0, 0.54, 0.45 + 0.5 * pulse), 2.0)
			# Little green arrow on the corner.
			var o := c + Vector2(rad * 0.45, -rad * 0.95)
			draw_colored_polygon(PackedVector2Array([o + Vector2(0, -4.5), o + Vector2(4.5, 3.0), o + Vector2(-4.5, 3.0)]), Color(0.04, 0.08, 0.04))
			draw_colored_polygon(PackedVector2Array([o + Vector2(0, -3.2), o + Vector2(3.4, 2.2), o + Vector2(-3.4, 2.2)]), Color(0.49, 1.0, 0.54))
