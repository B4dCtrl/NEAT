extends Control
## "How to play": a short paged guide shown after the intro (and from Settings).

signal finished()

const StoryText = preload("res://scenes/ui/story_text.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")
const DataDB = preload("res://core/data_db.gd")

## One illustration per page: [sprite ids...] drawn above the text.
const ART := [
	["stairborn"], ["icon_skull", "stairborn"], ["knight", "ranger", "arcanist"],
	["item_sword", "item_helm", "item_ring"], ["icon_market", "icon_soul"], ["icon_floor"],
]

var _page := 0
var _title: Label
var _body: Label
var _art: HBoxContainer
var _dots: Label
var _back: Button
var _next: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 380)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var head := Label.new()
	head.text = StoryText.ui("how_to_play")
	head.add_theme_color_override("font_color", Color("#9a96a8"))
	v.add_child(head)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color("#f2c14e"))
	v.add_child(_title)
	_art = HBoxContainer.new()
	_art.alignment = BoxContainer.ALIGNMENT_CENTER
	_art.custom_minimum_size = Vector2(0, 90)
	_art.add_theme_constant_override("separation", 18)
	v.add_child(_art)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(580, 110)
	_body.add_theme_font_size_override("font_size", 16)
	v.add_child(_body)
	var nav := HBoxContainer.new()
	v.add_child(nav)
	_back = Button.new()
	_back.text = StoryText.ui("back")
	_back.focus_mode = Control.FOCUS_NONE
	_back.pressed.connect(func(): _show(_page - 1))
	nav.add_child(_back)
	_dots = Label.new()
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav.add_child(_dots)
	_next = Button.new()
	_next.focus_mode = Control.FOCUS_NONE
	_next.pressed.connect(func():
		if _page + 1 < StoryText.tutorial().size():
			_show(_page + 1)
		else:
			finished.emit())
	nav.add_child(_next)


func start() -> void:
	_show(0)


func _show(page: int) -> void:
	var pages := StoryText.tutorial()
	_page = clampi(page, 0, pages.size() - 1)
	_title.text = pages[_page][0]
	_body.text = pages[_page][1]
	_back.disabled = _page == 0
	_next.text = StoryText.ui("done") if _page == pages.size() - 1 else StoryText.ui("next") + " ▶"
	var dots := ""
	for i in pages.size():
		dots += ("●" if i == _page else "○") + " "
	_dots.text = dots
	for c in _art.get_children():
		c.queue_free()
	for id in ART[_page]:
		var frames: Array
		if DataDB.classes().has(id):
			frames = PixelArt.unit_frames(id, DataDB.classes()[id]["sprite"], {}, false)
		else:
			frames = PixelArt.frames(id)
		if frames.is_empty():
			continue
		var r := TextureRect.new()
		r.texture = frames[0]
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.custom_minimum_size = Vector2(80, 80)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_art.add_child(r)
