extends Control
## TASKBAR MODE: a transparent window resting on the taskbar. Only the spiral
## tower and a floating HUD are visible; the rest of the window is
## click-through, like a desktop pet.
##   [heroes] F 382 [tower]   <- tiny HUD on the left, only on mouse hover;
##   the window is just wide enough to sit right in the corner of the taskbar.
## Focus safety: nothing here ever grabs keyboard focus or raises the window.
## Notifications are a soft glow plus a line of text, never a popup.

signal expand_requested()
signal close_requested()

const PixelArt = preload("res://scenes/entities/pixel_art.gd")
const UiUtil = preload("res://scenes/ui/ui_util.gd")
const TowerStage = preload("res://scenes/ui/tower_stage.gd")
const Loc = preload("res://core/loc.gd")
const MenuBarScript = preload("res://scenes/ui/menu/menu_bar.gd")
const PanelHost = preload("res://scenes/ui/menu/panel_host.gd")

const NOTIFY_COLORS := {
	"legendary": Color("#ff9d2a"), "relic": Color("#b388ff"), "boss": Color("#ff4f4f"),
	"fall": Color("#c9d1d9"), "milestone": Color("#7fe8ff"), "set": Color("#5fd35f"), "info": Color("#efe9d8"),
}
const DRAG_THRESHOLD := 6.0
const HUD_H := 40.0
## Width of the left HUD column (hero icons + floor).
const HUD_W := 230.0
## Room on the right for big bosses standing on the landing.
const RIGHT_MARGIN := 40.0
## Row of round menu buttons above the hero icons.
const MENU_ROW := 30.0

@onready var stage: Control = %Stage
@onready var hud: HBoxContainer = %Hud
@onready var notify_box: HBoxContainer = %Notify
@onready var floor_label: Label = %FloorLabel
@onready var notify_label: Label = %NotifyLabel
@onready var notify_icon: TextureRect = %NotifyIcon

var _glow_color := Color.TRANSPARENT
var _glow_left := 0.0
var _notify_left := 0.0
var _press_pos := Vector2.ZERO
var _pressing := false
var _dragging := false
var _drag_mouse := Vector2i.ZERO
var _drag_win := Vector2i.ZERO
var _t := 0.0
var _last_size := Vector2.ZERO
var _hud_alpha := 0.0
var _hud_hold := 0.0      # keeps the HUD up for a few seconds after a notification
var _hud_shown := false
var menu_bar: Control
var panels: Control


func _ready() -> void:
	%FloorIcon.visible = false
	notify_label.label_settings = notify_label.label_settings.duplicate()
	floor_label.label_settings = floor_label.label_settings.duplicate()
	Game.notified.connect(_on_notified)
	notify_box.visible = false
	hud.modulate.a = 0.0
	hud.visible = false
	stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panels = PanelHost.new()
	panels.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panels.layout_changed.connect(_on_panels_changed)
	add_child(panels)
	menu_bar = MenuBarScript.new()
	menu_bar.visible = false
	menu_bar.toggled.connect(func(id): panels.toggle(id))
	menu_bar.expand_requested.connect(func(): expand_requested.emit())
	menu_bar.close_requested.connect(func(): close_requested.emit())
	add_child(menu_bar)
	resized.connect(_layout)
	_layout()
	_refresh()


func tower_column_width() -> float:
	return (TowerStage.R_OUT * stage.px + 10.0) * 2.0


## Compact window: the HUD column on the left, the tower on the right edge.
static func window_width(px: float = 2.0) -> int:
	return int(HUD_W + (TowerStage.R_OUT * px + 10.0) * 2.0 + RIGHT_MARGIN)


## The tower + HUD block fills the whole (free-floating) window; the menu
## panels live in windows of their own.
func _base_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)


func _tower_rect() -> Rect2:
	var b := _base_rect()
	return Rect2(b.position.x + HUD_W, b.position.y, b.size.x - HUD_W, b.size.y)


func _hud_rect() -> Rect2:
	var b := _base_rect()
	return Rect2(b.position.x, b.end.y - HUD_H - MENU_ROW, HUD_W, HUD_H + MENU_ROW)


func _layout() -> void:
	var b := _base_rect()
	stage.position = b.position
	stage.size = b.size
	stage.tower_center = HUD_W + tower_column_width() * 0.5
	hud.offset_left = b.position.x + 4.0
	hud.offset_right = b.position.x + HUD_W
	hud.offset_top = b.end.y - size.y - 34.0
	hud.offset_bottom = b.end.y - size.y - 4.0
	notify_box.offset_left = b.position.x + 4.0
	notify_box.offset_right = b.position.x + HUD_W
	notify_box.offset_top = b.end.y - HUD_H - MENU_ROW - 40.0
	notify_box.offset_bottom = b.end.y - HUD_H - MENU_ROW
	menu_bar.position = Vector2(b.position.x + 4.0, b.end.y - HUD_H - MENU_ROW + 2.0)
	menu_bar.size = menu_bar.custom_minimum_size
	_update_passthrough()
	_last_size = size


func _on_panels_changed() -> void:
	menu_bar.open_ids = panels.open_ids()
	menu_bar.queue_redraw()


## Only the tower (and the HUD while it is shown) catch the mouse; the rest of
## the window is click-through. With menu panels open the whole window is live.
func _update_passthrough() -> void:
	var t := _tower_rect()
	var h := _hud_rect()
	var poly: PackedVector2Array
	if _hud_shown:
		poly = PackedVector2Array([
			Vector2(t.position.x, t.position.y), Vector2(t.end.x, t.position.y), Vector2(t.end.x, t.end.y),
			Vector2(h.position.x, h.end.y), Vector2(h.position.x, h.position.y), Vector2(t.position.x, h.position.y)])
	else:
		poly = PackedVector2Array([t.position, Vector2(t.end.x, t.position.y), t.end, Vector2(t.position.x, t.end.y)])
	WindowManager.set_passthrough(poly)


## The HUD strip stays hidden while you work: it fades in when the mouse is over
## the tower (or the HUD itself) and for a moment after an important event.
func _update_hud(delta: float) -> void:
	_hud_hold = maxf(0.0, _hud_hold - delta)
	var local := _mouse_local()
	var over_tower := _tower_rect().has_point(local)
	var over_hud := _hud_shown and _hud_rect().has_point(local)
	var menu_open: bool = not panels.open_ids().is_empty()
	var want := over_tower or over_hud or _hud_hold > 0.0 or _pressing or menu_open
	_hud_alpha = move_toward(_hud_alpha, 1.0 if want else 0.0, delta * (6.0 if want else 2.5))
	hud.modulate.a = _hud_alpha
	notify_box.modulate.a = maxf(_hud_alpha, 1.0 if _notify_left > 0.0 else 0.0)
	var shown := _hud_alpha > 0.01
	if shown != _hud_shown:
		_hud_shown = shown
		hud.visible = shown
		menu_bar.visible = shown
		_update_passthrough()
	menu_bar.modulate.a = _hud_alpha


func _mouse_local() -> Vector2:
	if WindowManager.is_headless():
		return Vector2(-1, -1)
	# Screen-space query: works even while the pointer is over a click-through area.
	return Vector2(DisplayServer.mouse_get_position() - get_window().position)


func _process(delta: float) -> void:
	_t += delta
	panels.set_shown(is_visible_in_tree() and not WindowManager.hidden)
	_update_hud(delta)
	_glow_left = maxf(0.0, _glow_left - delta)
	if _notify_left > 0.0:
		_notify_left -= delta
		if _notify_left <= 0.0:
			notify_box.visible = false
	_refresh()
	queue_redraw()


func _refresh() -> void:
	floor_label.text = Loc.t("hud.floor") % Game.state["floor"]
	# The floor number takes the colour of the danger ahead (green -> red).
	var d: Dictionary = Game.danger_next
	floor_label.label_settings.font_color = Color(d.get("color", "#fff8e0"))


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
	var strip := _hud_rect().grow(-2.0)
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
		if event.pressed and not _tower_rect().has_point(event.position):
			return
		if event.pressed:
			_pressing = true
			_dragging = false
			_press_pos = event.global_position
			_drag_mouse = DisplayServer.mouse_get_position()
			_drag_win = get_window().position
		else:
			if _pressing and not _dragging:
				# Click on the tower: open the menu (Status), or close it.
				if panels.open_ids().is_empty():
					panels.open("status")
				else:
					panels.close_all()
			_pressing = false
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion and _pressing:
		if not _dragging and event.global_position.distance_to(_press_pos) > DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			# Free drag in screen space: anywhere, across monitors.
			WindowManager.move_bar_to(_drag_win + DisplayServer.mouse_get_position() - _drag_mouse)
		accept_event()
