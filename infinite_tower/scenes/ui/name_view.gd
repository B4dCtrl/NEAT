extends Control
## Shown once after the comic: the story is called Stairborn, but every player
## names THEIR Stairborn. Renameable later in the HEROES panel.

signal finished()

const Ornate = preload("res://scenes/ui/menu/ornate.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")
const Heroes = preload("res://core/heroes.gd")
const Loc = preload("res://core/loc.gd")

var _edit: LineEdit
var _title: Label
var _ok: Button
var _hint: Label


func _ready() -> void:
	theme = Ornate.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("#0d0b10")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)
	var hero := TextureRect.new()
	hero.texture = PixelArt.unit_frames("stairborn", "stairborn", {}, false)[0]
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hero.custom_minimum_size = Vector2(0, 110)
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	col.add_child(hero)
	_title = Ornate.header_label("")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	_hint = Ornate.small_label("", Ornate.TEXT_DIM, 12)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(320, 0)
	col.add_child(_hint)
	_edit = LineEdit.new()
	_edit.max_length = 16
	_edit.custom_minimum_size = Vector2(260, 0)
	_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_edit.text_submitted.connect(func(_s): _confirm())
	col.add_child(_edit)
	_ok = Button.new()
	_ok.focus_mode = Control.FOCUS_NONE
	_ok.pressed.connect(_confirm)
	col.add_child(_ok)
	Game.language_changed.connect(_texts)
	_texts()


func _texts() -> void:
	_title.text = Loc.t("name.title")
	_hint.text = Loc.t("name.hint")
	_ok.text = Loc.t("name.ok")
	_edit.placeholder_text = Loc.t("name.placeholder")


func start() -> void:
	_edit.text = ""
	_edit.grab_focus.call_deferred()


func _confirm() -> void:
	var nm := Heroes.clean_name(_edit.text)
	if nm == "":
		nm = Loc.t("name.default")
	Game.rename_hero(Game.state["heroes"][0]["id"], nm)
	Game.state["named"] = true
	finished.emit()
