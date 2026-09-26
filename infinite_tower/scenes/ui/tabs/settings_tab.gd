extends MarginContainer
## Audio, window behaviour, notifications, hotkeys and save management.

const SaveSystem = preload("res://core/save_system.gd")
const StoryText = preload("res://scenes/ui/story_text.gd")

## Single-column layout for the narrow menu panel.
var compact := false
var _controls := {}
var _reset_confirm: ConfirmationDialog


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 1 if compact else 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	_section(grid, "Taskbar window")
	_option(grid, "art_style", "Art style", [["1-bit (monochrome)", "mono"], ["Color (biome palettes)", "color"]])
	_check(grid, "always_on_top", "Always on top")
	_option(grid, "dock", "Dock position", [["Bottom of screen", "bottom"], ["Top of screen", "top"]])
	_slider(grid, "bar_height", "Window height", 110, 260, 10)
	_slider(grid, "bar_opacity", "HUD backdrop opacity", 0.0, 1.0, 0.05)
	_option(grid, "fps_taskbar", "Taskbar FPS (battery)", [["15", 15], ["30", 30], ["60", 60]])

	_section(grid, "Notifications")
	_check(grid, "notify_glow", "Glow on rare events (never steals focus)")
	_check(grid, "show_damage_numbers", "Damage numbers in Expedition view")

	_section(grid, "Audio")
	_slider(grid, "master_volume", "Master volume", 0.0, 1.0, 0.05)
	_slider(grid, "music_volume", "Music", 0.0, 1.0, 0.05)
	_slider(grid, "sfx_volume", "Sound effects", 0.0, 1.0, 0.05)

	_section(grid, "Loot")
	_check(grid, "auto_equip", "Auto-equip upgrades")
	_check(grid, "auto_train", "Auto-train with spare gold")
	_check(grid, "auto_skills", "Auto-spend skill points")

	_section(grid, "Hotkeys")
	_info(grid, "Tab / F1", "Toggle Taskbar / Expedition")
	_info(grid, "Esc", "Back to Taskbar")
	_info(grid, "Click on the tower", "Open / close the menu (drag to slide it along the taskbar)")
	_info(grid, "Close (X)", "Hides in the system tray; the climb continues")

	_section(grid, "Story")
	var intro := Button.new()
	intro.text = StoryText.ui("replay_intro")
	intro.focus_mode = Control.FOCUS_NONE
	intro.pressed.connect(func(): Game.story_requested.emit("intro"))
	grid.add_child(intro)
	var guide := Button.new()
	guide.text = StoryText.ui("how_to_play")
	guide.focus_mode = Control.FOCUS_NONE
	guide.pressed.connect(func(): Game.story_requested.emit("tutorial"))
	grid.add_child(guide)

	_section(grid, "Save")
	var save_now := Button.new()
	save_now.text = "Save now"
	save_now.focus_mode = Control.FOCUS_NONE
	save_now.pressed.connect(func(): Game.save())
	grid.add_child(save_now)
	var open_dir := Button.new()
	open_dir.text = "Open save folder"
	open_dir.focus_mode = Control.FOCUS_NONE
	open_dir.pressed.connect(func(): OS.shell_open(ProjectSettings.globalize_path("user://")))
	grid.add_child(open_dir)
	var reset := Button.new()
	reset.text = "Reset progress..."
	reset.focus_mode = Control.FOCUS_NONE
	reset.add_theme_color_override("font_color", Color("#ff6b6b"))
	reset.pressed.connect(func(): _reset_confirm.popup_centered())
	grid.add_child(reset)
	var quit := Button.new()
	quit.text = "Quit game"
	quit.focus_mode = Control.FOCUS_NONE
	quit.tooltip_text = "Saves and closes Stairborn completely"
	quit.pressed.connect(func(): Game.save(); get_tree().quit())
	grid.add_child(quit)
	_reset_confirm = ConfirmationDialog.new()
	_reset_confirm.dialog_text = "Delete the save and start a brand new expedition?\nThis cannot be undone."
	_reset_confirm.confirmed.connect(func(): Game.reset_save())
	add_child(_reset_confirm)

	visibility_changed.connect(_sync)
	Game.settings_changed.connect(_sync)


func _section(grid: GridContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color("#f2c14e"))
	grid.add_child(l)
	if not compact:
		grid.add_child(Control.new())


func _label(grid: GridContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	if compact:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", Color("#b39c7c"))
	grid.add_child(l)


func _info(grid: GridContainer, key: String, text: String) -> void:
	_label(grid, key)
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color("#9a96a8"))
	if compact:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	grid.add_child(l)


func _check(grid: GridContainer, key: String, text: String) -> void:
	_label(grid, text)
	var c := CheckBox.new()
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(on): Game.set_setting(key, on))
	grid.add_child(c)
	_controls[key] = c


func _option(grid: GridContainer, key: String, text: String, options: Array) -> void:
	_label(grid, text)
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	for opt in options:
		o.add_item(str(opt[0]))
		o.set_item_metadata(o.item_count - 1, opt[1])
	o.item_selected.connect(func(idx): Game.set_setting(key, o.get_item_metadata(idx)))
	grid.add_child(o)
	_controls[key] = o


func _slider(grid: GridContainer, key: String, text: String, lo: float, hi: float, step: float) -> void:
	_label(grid, text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(0 if compact else 220, 0)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_NONE
	# Apply on release so the window is not resized on every drag tick.
	s.drag_ended.connect(func(_changed): Game.set_setting(key, int(s.value) if step >= 1.0 else s.value))
	grid.add_child(s)
	_controls[key] = s


func _sync() -> void:
	if not is_visible_in_tree():
		return
	var settings: Dictionary = Game.state["settings"]
	for key in _controls:
		var c = _controls[key]
		var v = settings.get(key)
		if c is CheckBox:
			c.set_pressed_no_signal(bool(v))
		elif c is OptionButton:
			for i in c.item_count:
				if str(c.get_item_metadata(i)) == str(v):
					c.select(i)
		elif c is HSlider:
			c.set_value_no_signal(float(v))
