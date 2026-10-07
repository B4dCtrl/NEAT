extends SceneTree
## Renders a unit through its animation states (idle, walk, attack, miss, hit,
## cast, death) into one strip PNG, to check every unit animates.
##   godot --path . --rendering-driver opengl3 -s res://tools/anim_strip.gd -- <out.png> [hero|enemy id ...]
const DataDB = preload("res://core/data_db.gd")
const UnitSprite = preload("res://scenes/entities/unit_sprite.gd")
const STATES := ["idle", "walk", "attack", "miss", "hit", "cast", "death1", "death2", "death3"]


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var ids: Array = args.slice(1)
	var rows := []
	for id in ids:
		var is_hero: bool = DataDB.classes().has(id)
		var def: Dictionary = DataDB.classes()[id] if is_hero else (DataDB.enemies() if DataDB.enemies().has(id) else DataDB.bosses())[id]
		var row := []
		for st in STATES:
			var vp := SubViewport.new()
			vp.size = Vector2i(120, 110)
			vp.transparent_bg = false
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(vp)
			var bg := ColorRect.new()
			bg.color = Color("#1a1824")
			bg.size = Vector2(120, 110)
			vp.add_child(bg)
			var sp: Node2D = UnitSprite.new()
			vp.add_child(sp)
			sp.position = Vector2(60, 96)
			sp.configure(def["sprite"], def.get("palette", {}), 3.0, not is_hero, false, String(def.get("art", id)), float(def.get("hue", -1.0)), def.get("fx", []))
			match st:
				"walk": sp.walking = true
				"attack": sp.lunge()
				"miss": sp.dodge()
				"hit": sp.hurt()
				"cast": sp.cast(Color("#7fe0ff"))
				"death1", "death2", "death3": sp.set_dead(true)
			var steps: int = {"attack": 3, "miss": 3, "hit": 1, "cast": 5, "death1": 4, "death2": 7, "death3": 10, "walk": 4, "idle": 2}[st]
			for i in steps:
				sp._process(0.05)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			row.append(img)
			vp.queue_free()
		rows.append(row)
	var w := 120 * STATES.size()
	var sheet := Image.create(w, 110 * rows.size(), false, Image.FORMAT_RGBA8)
	for r in rows.size():
		for c in rows[r].size():
			var im: Image = rows[r][c]
			im.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(im, Rect2i(0, 0, 120, 110), Vector2i(c * 120, r * 110))
	sheet.save_png(out)
	print("wrote ", out)
	quit()
