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
## The tower window was dragged somewhere else.
signal bar_moved()

const EXPEDITION_SIZE := Vector2i(1100, 780)
const EXPEDITION_MIN := Vector2i(960, 700)
const BAR_MIN_WIDTH := 200
const TaskbarView = preload("res://scenes/ui/taskbar_view.gd")
const TRANSITION_TIME := 0.16

var mode := "taskbar"
var hidden := false
var _tween: Tween
var _passthrough := PackedVector2Array()


func _ready() -> void:
	Game.settings_changed.connect(_on_settings_changed)
	get_window().min_size = Vector2i(BAR_MIN_WIDTH, 32)
	var first := "story" if not Game.state.get("intro_seen", false) or not Game.state.get("tutorial_seen", false) else "taskbar"
	apply_mode.call_deferred(first, false)


func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func set_mode(new_mode: String) -> void:
	if new_mode == mode:
		return
	apply_mode(new_mode, true)


func toggle_mode() -> void:
	if mode == "story":
		return
	set_mode("expedition" if mode == "taskbar" else "taskbar")


## "Closing" minimises the game; it keeps climbing (cheaply) with its tray icon.
## Godot cannot hide the main window itself, so it is minimised instead.
func hide_to_tray() -> void:
	hidden = true
	Engine.max_fps = 5
	if not is_headless():
		get_window().mode = Window.MODE_MINIMIZED


func _process(_delta: float) -> void:
	if is_headless():
		return
	var win_mode := get_window().mode
	# Restored from the OS taskbar instead of the tray icon: resume normally.
	if hidden and win_mode != Window.MODE_MINIMIZED:
		show_from_tray(mode)
	# Minimising the Expedition window shrinks back to the taskbar tower.
	elif not hidden and mode == "expedition" and win_mode == Window.MODE_MINIMIZED:
		get_window().mode = Window.MODE_WINDOWED
		apply_mode("taskbar", false)


func show_from_tray(new_mode: String) -> void:
	hidden = false
	if not is_headless():
		get_window().mode = Window.MODE_WINDOWED
	apply_mode(new_mode, false)


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
		# "expedition" and "story" (comic intro / tutorial) use a regular window.
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


## The tower window floats freely: wherever the player dropped it (any
## monitor), or by default in the bottom-right corner above the taskbar.
func bar_rect() -> Rect2i:
	var settings: Dictionary = Game.state["settings"]
	var size := Vector2i(TaskbarView.window_width(), int(settings.get("bar_height", 150)))
	var saved = settings.get("win_pos", null)
	if saved is Array and saved.size() == 2:
		var r := Rect2i(Vector2i(int(saved[0]), int(saved[1])), size)
		if _on_some_screen(r):
			return r
	var screen := DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen())
	return Rect2i(screen.end - size, size)


## True when enough of the window is on a connected monitor to grab it.
static func _on_some_screen(r: Rect2i) -> bool:
	for i in DisplayServer.get_screen_count():
		var inter := DisplayServer.screen_get_usable_rect(i).intersection(r)
		if inter.size.x >= 60 and inter.size.y >= 40:
			return true
	return false


func expedition_rect() -> Rect2i:
	var screen := DisplayServer.screen_get_usable_rect(get_window().current_screen)
	var sz := Vector2i(mini(EXPEDITION_SIZE.x, screen.size.x), mini(EXPEDITION_SIZE.y, screen.size.y - 40))
	return Rect2i(screen.position + (screen.size - sz) / 2, sz)


## Drag: puts the tower window at `pos` (screen coordinates, any monitor).
func move_bar_to(pos: Vector2i) -> void:
	if mode != "taskbar" or is_headless():
		return
	get_window().position = pos
	Game.state["settings"]["win_pos"] = [pos.x, pos.y]
	bar_moved.emit()


func reset_bar_position() -> void:
	Game.state["settings"].erase("win_pos")
	if mode == "taskbar":
		apply_mode("taskbar", false)
	bar_moved.emit()


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
