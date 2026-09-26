extends Node
## Autoload "WindowManager": owns the OS window for the two UX modes.
##
## TASKBAR    transparent borderless window resting on the taskbar (or the top
##            edge): only the tower and the HUD text are drawn, the rest of the
##            window lets clicks through to the desktop (mouse passthrough).
##            Always-on-top is optional and the window is *unfocusable*, so it
##            never steals keyboard focus from whatever the user is doing.
## EXPEDITION regular decorated window, centered, focusable (the user asked for it).

signal mode_changed(mode: String)

const EXPEDITION_SIZE := Vector2i(1100, 780)
const EXPEDITION_MIN := Vector2i(960, 700)
const BAR_MIN_WIDTH := 360
const TRANSITION_TIME := 0.16

var mode := "taskbar"
var _bar_offset_x := -1   # horizontal position of a narrower-than-screen bar
var _tween: Tween
var _passthrough := PackedVector2Array()


func _ready() -> void:
	Game.settings_changed.connect(_on_settings_changed)
	get_window().min_size = Vector2i(BAR_MIN_WIDTH, 32)
	_bar_offset_x = int(Game.state["settings"].get("bar_x", -1))
	apply_mode.call_deferred("taskbar", false)


func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func set_mode(new_mode: String) -> void:
	if new_mode == mode:
		return
	apply_mode(new_mode, true)


func toggle_mode() -> void:
	set_mode("expedition" if mode == "taskbar" else "taskbar")


func apply_mode(new_mode: String, animate: bool) -> void:
	mode = new_mode
	var win := get_window()
	var settings: Dictionary = Game.state["settings"]
	if is_headless():
		mode_changed.emit(mode)
		return
	var target: Rect2i
	if mode == "taskbar":
		Engine.max_fps = int(settings.get("fps_taskbar", 30))
		win.min_size = Vector2i(BAR_MIN_WIDTH, 32)
		win.borderless = true
		win.unresizable = true
		win.transparent = true
		win.always_on_top = bool(settings.get("always_on_top", true))
		# Focus safety: the strip is click-through for keyboard focus.
		win.unfocusable = true
		win.mouse_passthrough_polygon = _passthrough
		target = bar_rect()
	else:
		Engine.max_fps = 60
		win.unfocusable = false
		win.mouse_passthrough_polygon = PackedVector2Array()
		win.always_on_top = false
		win.borderless = false
		win.unresizable = false
		win.transparent = false
		target = expedition_rect()
		win.min_size = EXPEDITION_MIN
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if animate:
		var from := Rect2i(win.position, win.size)
		_tween = create_tween()
		_tween.tween_method(func(t: float): _set_rect(_lerp_rect(from, target, t)), 0.0, 1.0, TRANSITION_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	else:
		_set_rect(target)
	if mode == "expedition":
		# The user explicitly clicked: bringing the window forward is expected here.
		win.grab_focus()
	mode_changed.emit(mode)


func bar_rect() -> Rect2i:
	var settings: Dictionary = Game.state["settings"]
	var screen := DisplayServer.screen_get_usable_rect(get_window().current_screen)
	var height := int(settings.get("bar_height", 54))
	var width := int(settings.get("bar_width", 0))
	if width <= 0 or width > screen.size.x:
		width = screen.size.x
	width = maxi(width, BAR_MIN_WIDTH)
	if _bar_offset_x < 0 or _bar_offset_x + width > screen.size.x:
		# Default: bottom-right, next to the system tray, like a desktop pet.
		_bar_offset_x = maxi(0, screen.size.x - width - 24)
	var y := screen.position.y if settings.get("dock", "bottom") == "top" else screen.end.y - height
	return Rect2i(screen.position.x + _bar_offset_x, y, width, height)


func expedition_rect() -> Rect2i:
	var screen := DisplayServer.screen_get_usable_rect(get_window().current_screen)
	var sz := Vector2i(mini(EXPEDITION_SIZE.x, screen.size.x), mini(EXPEDITION_SIZE.y, screen.size.y - 40))
	return Rect2i(screen.position + (screen.size - sz) / 2, sz)


## Slides a narrower bar horizontally along its dock edge (mouse drag).
func nudge_bar(dx: int) -> void:
	if mode != "taskbar" or is_headless():
		return
	var screen := DisplayServer.screen_get_usable_rect(get_window().current_screen)
	var win := get_window()
	_bar_offset_x = clampi(_bar_offset_x + dx, 0, maxi(0, screen.size.x - win.size.x))
	win.position = Vector2i(screen.position.x + _bar_offset_x, win.position.y)
	Game.state["settings"]["bar_x"] = _bar_offset_x


## Region of the taskbar window that captures the mouse; everything else is
## click-through. Called by the taskbar view whenever its layout changes.
func set_passthrough(polygon: PackedVector2Array) -> void:
	_passthrough = polygon
	if mode == "taskbar" and not is_headless():
		get_window().mouse_passthrough_polygon = polygon


func _on_settings_changed() -> void:
	if mode == "taskbar":
		apply_mode("taskbar", false)


func _set_rect(r: Rect2i) -> void:
	var win := get_window()
	win.size = r.size
	win.position = r.position


static func _lerp_rect(a: Rect2i, b: Rect2i, t: float) -> Rect2i:
	return Rect2i(
		Vector2i(Vector2(a.position).lerp(Vector2(b.position), t)),
		Vector2i(Vector2(a.size).lerp(Vector2(b.size), t)))
