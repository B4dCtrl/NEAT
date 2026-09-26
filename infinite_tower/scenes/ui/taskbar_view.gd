extends Control
## TASKBAR MODE: a transparent window resting on the taskbar. Only the spiral
## tower and a floating HUD are visible; the rest of the window is
## click-through, like a desktop pet.
##   [tower]  [party] FLOOR 382  Slime  18.2k  [»]   <- HUD only on mouse hover
## Focus safety: nothing here ever grabs keyboard focus or raises the window.
## Notifications are a soft glow plus a line of text, never a popup.

signal expand_requested()

const PixelArt = preload("res://scenes/entities/pixel_art.gd")
const UiUtil = preload("res://scenes/ui/ui_util.gd")
const TowerStage = preload("res://scenes/ui/tower_stage.gd")

const NOTIFY_COLORS := {
	"legendary": Color("#ff9d2a"), "relic": Color("#b388ff"), "boss": Color("#ff4f4f"),
	"fall": Color("#c9d1d9"), "milestone": Color("#7fe8ff"), "set": Color("#5fd35f"), "info": Color("#efe9d8"),
}
const DRAG_THRESHOLD := 6.0
const HUD_H := 40.0

@onready var stage: Control = %Stage
@onready var hud: HBoxContainer = %Hud
@onready var notify_box: HBoxContainer = %Notify
@onready var floor_label: Label = %FloorLabel
@onready var enemy_label: Label = %EnemyLabel
@onready var gold_label: Label = %GoldLabel
@onready var notify_label: Label = %NotifyLabel
@onready var notify_icon: TextureRect = %NotifyIcon
@onready var expand_button: Button = %ExpandButton

var _glow_color := Color.TRANSPARENT
var _glow_left := 0.0
var _notify_left := 0.0
var _press_pos := Vector2.ZERO
var _pressing := false
var _dragging := false
var _t := 0.0
var _last_size := Vector2.ZERO
var _hud_alpha := 0.0
var _hud_hold := 0.0      # keeps the HUD up for a few seconds after a notification
var _hud_shown := false


func _ready() -> void:
	%FloorIcon.texture = PixelArt.icon("floor")
	%EnemyIcon.texture = PixelArt.icon("skull")
	%GoldIcon.texture = PixelArt.icon("coin")
	notify_label.label_settings = notify_label.label_settings.duplicate()
	expand_button.pressed.connect(func(): expand_requested.emit())
	Game.notified.connect(_on_notified)
	notify_box.visible = false
	hud.modulate.a = 0.0
	hud.visible = false
	resized.connect(_layout)
	_layout()
	_refresh()


func tower_column_width() -> float:
	return (TowerStage.R_OUT * stage.px + 10.0) * 2.0


## Tower on the left, HUD to its right along the bottom edge.
func _layout() -> void:
	var col := tower_column_width()
	stage.tower_center = col * 0.5
	hud.offset_left = col
	notify_box.offset_left = col
	notify_box.offset_top = size.y - HUD_H - 26.0
	notify_box.offset_bottom = size.y - HUD_H
	_update_passthrough()
	_last_size = size


## Only the tower (and the HUD while it is shown) catch the mouse; the rest of
## the window is click-through.
func _update_passthrough() -> void:
	var col := tower_column_width()
	var poly: PackedVector2Array
	if _hud_shown:
		poly = PackedVector2Array([
			Vector2(0, 0), Vector2(col, 0), Vector2(col, size.y - HUD_H),
			Vector2(size.x, size.y - HUD_H), Vector2(size.x, size.y), Vector2(0, size.y)])
	else:
		poly = PackedVector2Array([Vector2(0, 0), Vector2(col, 0), Vector2(col, size.y), Vector2(0, size.y)])
	WindowManager.set_passthrough(poly)


## The HUD strip stays hidden while you work: it fades in when the mouse is over
## the tower (or the HUD itself) and for a moment after an important event.
func _update_hud(delta: float) -> void:
	_hud_hold = maxf(0.0, _hud_hold - delta)
	var local := _mouse_local()
	var col := tower_column_width()
	var over_tower := Rect2(0, 0, col, size.y).has_point(local)
	var over_hud := _hud_shown and Rect2(col, size.y - HUD_H, size.x - col, HUD_H).has_point(local)
	var want := over_tower or over_hud or _hud_hold > 0.0 or _pressing
	_hud_alpha = move_toward(_hud_alpha, 1.0 if want else 0.0, delta * (6.0 if want else 2.5))
	hud.modulate.a = _hud_alpha
	notify_box.modulate.a = maxf(_hud_alpha, 1.0 if _notify_left > 0.0 else 0.0)
	var shown := _hud_alpha > 0.01
	if shown != _hud_shown:
		_hud_shown = shown
		hud.visible = shown
		_update_passthrough()


func _mouse_local() -> Vector2:
	if WindowManager.is_headless():
		return Vector2(-1, -1)
	# Screen-space query: works even while the pointer is over a click-through area.
	return Vector2(DisplayServer.mouse_get_position() - get_window().position)


func _process(delta: float) -> void:
	_t += delta
	_update_hud(delta)
	_glow_left = maxf(0.0, _glow_left - delta)
	if _notify_left > 0.0:
		_notify_left -= delta
		if _notify_left <= 0.0:
			notify_box.visible = false
	_refresh()
	queue_redraw()


func _refresh() -> void:
	floor_label.text = "FLOOR %d" % Game.state["floor"]
	enemy_label.text = Game.current_enemy_name()
	gold_label.text = UiUtil.num(Game.state["gold"])


func _on_notified(kind: String, text: String) -> void:
	if not Game.state["settings"].get("notify_glow", true) and kind != "relic":
		return
	_glow_color = NOTIFY_COLORS.get(kind, Color.WHITE)
	_glow_left = 6.0 if kind in ["relic", "legendary", "boss"] else 3.0
	notify_label.text = text
	notify_label.label_settings.font_color = _glow_color
	var icon_id := "relic" if kind in ["relic", "set"] else ("sword" if kind == "legendary" else ("skull" if kind == "boss" else "crystal"))
	notify_icon.texture = PixelArt.icon(icon_id)
	_notify_left = 8.0
	notify_box.visible = true
	if kind in ["relic", "legendary", "boss", "milestone"]:
		_hud_hold = 4.0


func _draw() -> void:
	var col := tower_column_width()
	var strip := Rect2(col - 4.0, size.y - HUD_H, size.x - col + 4.0, HUD_H)
	var opacity := float(Game.state["settings"].get("bar_opacity", 0.0)) * _hud_alpha
	if opacity > 0.0:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.06, 0.09, opacity)
		sb.set_corner_radius_all(8)
		draw_style_box(sb, strip)
	if _glow_left > 0.0 and _hud_alpha > 0.01:
		# Soft pulsing halo around the tower top: visible, never intrusive.
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		var c := _glow_color
		c.a = clampf(_glow_left / 2.0, 0.0, 1.0) * (0.35 + 0.35 * pulse) * _hud_alpha
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(c.r, c.g, c.b, c.a * 0.25)
		sb.border_color = c
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		draw_style_box(sb, strip)


# Click expands, drag slides the window along the taskbar.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_dragging = false
			_press_pos = event.global_position
		else:
			if _pressing and not _dragging:
				expand_requested.emit()
			_pressing = false
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion and _pressing:
		if not _dragging and event.global_position.distance_to(_press_pos) > DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			WindowManager.nudge_bar(int(event.relative.x))
		accept_event()
