extends Control
## Tiny party portraits with HP bars for the taskbar HUD: [ Knight Ranger Arcanist ].

const DataDB = preload("res://core/data_db.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")

var _textures: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	Game.party_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	_textures.clear()
	for hero in Game.state["heroes"]:
		var f := PixelArt.unit_frames(hero["class"], DataDB.classes()[hero["class"]]["sprite"], {}, Game.state["settings"].get("art_style", "mono") == "mono")
		_textures.append(f[0] if not f.is_empty() else null)
	custom_minimum_size = Vector2(maxi(1, _textures.size()) * 17 + 6, 0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var exp = Game.expedition
	var bar_h := 3.0
	var scale := floorf(clampf((size.y - bar_h - 10.0) / 12.0, 1.0, 3.0))
	var cell := 12.0 * scale + 4.0
	var x := 4.0
	for i in _textures.size():
		var tex: Texture2D = _textures[i]
		if i >= Game.state["heroes"].size():
			break
		var ratio := float(Game.state["heroes"][i]["hp_ratio"])
		var mana := float(Game.state["heroes"][i].get("mp_ratio", 1.0))
		var alive := true
		if exp != null and exp.combat != null and exp.phase == "combat" and i < exp.combat.heroes.size():
			ratio = exp.combat.heroes[i].hp_ratio()
			mana = exp.combat.heroes[i].mp_ratio()
			alive = exp.combat.heroes[i].alive
		var y := (size.y - 12.0 * scale - bar_h - 4.0) * 0.5
		if tex != null:
			var h := 12.0 * scale
			var w := minf(cell - 2.0, tex.get_width() * h / tex.get_height())
			draw_texture_rect(tex, Rect2(x + 2.0 + (cell - 4.0 - w) * 0.5, y, w, h), false, Color.WHITE if alive else Color(0.4, 0.4, 0.4, 0.7))
		var by := y + 12.0 * scale + 2.0
		draw_rect(Rect2(x + 2.0, by, cell - 4.0, bar_h), Color(0, 0, 0, 0.6))
		var col := Color("#5fd35f") if ratio > 0.5 else (Color("#ffd23f") if ratio > 0.25 else Color("#ff4f4f"))
		draw_rect(Rect2(x + 2.0, by, (cell - 4.0) * ratio, bar_h), col)
		draw_rect(Rect2(x + 2.0, by + bar_h, cell - 4.0, 2.0), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(x + 2.0, by + bar_h, (cell - 4.0) * mana, 2.0), Color("#5a9cff"))
		x += cell
	custom_minimum_size.x = x + 4.0
