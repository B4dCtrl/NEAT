extends Control
## Renders the Infinite Staircase. Works at any size: a 54px taskbar strip or the
## big expedition header. Purely a view of Game.expedition, never mutates it.
##
## World layout: every floor is a flight of stairs followed by a flat landing.
## The camera follows the party along the diagonal, so the tower scrolls down-left
## while the heroes climb; fights happen on the landing, which stays readable
## even in a very thin window.

const DataDB = preload("res://core/data_db.gd")
const TowerGen = preload("res://core/tower_generator.gd")
const HeroSprite = preload("res://scenes/entities/hero_sprite.tscn")
const EnemySprite = preload("res://scenes/entities/enemy_sprite.tscn")
const UiNum = preload("res://scenes/ui/ui_util.gd")

## World units -> screen pixels.
@export var px := 2.0
## Where the party anchor sits, as a fraction of the stage size.
@export var anchor := Vector2(0.3, 0.8)
@export var show_numbers := false

const STEP_RUN := 6.0
const STEP_RISE := 2.0
const STEPS := 8
const FLIGHT := STEP_RUN * STEPS            # horizontal length of a flight
const RISE := STEP_RISE * STEPS             # height gained per floor
const LANDING := 72.0
const PERIOD := FLIGHT + LANDING
const REST := 22.0                           # party anchor offset into the landing
const HERO_GAP := 12.0
const BOSS_SCALE := 1.4

var hero_sprites: Array = []
var enemy_sprites: Array = []
var _combat_id := 0
var _cam_s := 0.0
var _cam_y := 0.0
var _focus := 0.0          # 0 = normal, 1 = boss close-up
var _fall := 0.0
var _floaters: Array = []  # {s, y, text, color, t, big}
var _colors := {}
var _biome_id := ""
var _time := 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	for i in 3:
		var sp = HeroSprite.instantiate()
		add_child(sp)
		hero_sprites.append(sp)
	_rebuild_heroes()
	_snap_camera()


func _rebuild_heroes() -> void:
	var classes := DataDB.classes()
	for i in hero_sprites.size():
		var hero: Dictionary = Game.state["heroes"][i]
		hero_sprites[i].configure(classes[hero["class"]]["sprite"], {}, px, false)
		hero_sprites[i].unit_uid = "h%d" % i


func set_px(value: float) -> void:
	px = value
	_rebuild_heroes()
	for sp in enemy_sprites:
		sp.px_scale = px * (BOSS_SCALE if sp.get_meta("boss", false) else 1.0)


# ------------------------------------------------------------------ geometry

static func rest_s(floor_num: int) -> float:
	return floor_num * PERIOD + FLIGHT + REST


## Height of the walkable surface at world distance s (stepped on flights).
static func ground_y(s: float) -> float:
	var k := floorf(s / PERIOD)
	var local := s - k * PERIOD
	if local < FLIGHT:
		return k * RISE + minf(floorf(local / STEP_RUN) + 1.0, STEPS) * STEP_RISE
	return (k + 1.0) * RISE


## Smooth version used by the camera.
static func smooth_y(s: float) -> float:
	var k := floorf(s / PERIOD)
	var local := s - k * PERIOD
	if local < FLIGHT:
		return k * RISE + local / FLIGHT * RISE
	return (k + 1.0) * RISE


func to_screen(s: float, y: float) -> Vector2:
	var ax := lerpf(anchor.x, 0.42, _focus) * size.x
	return Vector2(ax + (s - _cam_s) * px, anchor.y * size.y - (y - _cam_y) * px)


func party_anchor_s() -> float:
	var exp = Game.expedition
	var f := int(Game.state["floor"])
	if exp.phase == "walk":
		return lerpf(rest_s(f - 1), rest_s(f), exp.walk_progress())
	return rest_s(f)


func _snap_camera() -> void:
	_cam_s = party_anchor_s()
	_cam_y = smooth_y(_cam_s)


# ------------------------------------------------------------------ update

func _process(delta: float) -> void:
	if Game.expedition == null:
		return
	_time += delta
	var exp = Game.expedition
	var info: Dictionary = exp.floor_info
	var biome := TowerGen.biome_for(int(Game.state["floor"]))
	if biome["id"] != _biome_id:
		_biome_id = biome["id"]
		_colors = {}
		for k in biome["colors"]:
			_colors[k] = Color.html(biome["colors"][k])

	var falling: bool = exp.phase == "pause" and exp.after_pause == "walk"
	_fall = minf(_fall + delta * 1.5, 1.0) if falling else 0.0

	var boss_scene: bool = not info.is_empty() and info["type"] == "guardian" and exp.phase in ["intro", "combat"] and int(info["floor"]) == int(Game.state["floor"])
	_focus = move_toward(_focus, 1.0 if boss_scene else 0.0, delta * 2.0)

	var target_s := party_anchor_s()
	if absf(target_s - _cam_s) > PERIOD:
		_snap_camera()
	_cam_s = lerpf(_cam_s, target_s, minf(1.0, delta * 10.0))
	_cam_y = lerpf(_cam_y, smooth_y(_cam_s), minf(1.0, delta * 10.0))

	_sync_enemies(exp)
	_place_heroes(exp)
	_place_enemies(exp)
	_consume_combat_events()
	for f in _floaters:
		f["t"] += delta
	_floaters = _floaters.filter(func(f): return f["t"] < 1.1)
	queue_redraw()


func _hero_order() -> Array:
	# Front row heroes stand at the front (right), back row behind.
	var idx := [0, 1, 2]
	var heroes: Array = Game.state["heroes"]
	idx.sort_custom(func(a, b):
		var ra := 1 if heroes[a]["row"] == "front" else 0
		var rb := 1 if heroes[b]["row"] == "front" else 0
		return ra < rb if ra != rb else a > b)
	return idx


func _place_heroes(exp) -> void:
	var base_s := party_anchor_s()
	var order := _hero_order()
	var walking: bool = exp.phase == "walk"
	for slot in order.size():
		var i: int = order[slot]
		var sp = hero_sprites[i]
		var s := base_s + (slot - 1) * HERO_GAP
		var pos := to_screen(s, ground_y(s))
		if _fall > 0.0:
			pos.y += _fall * _fall * size.y * 1.6
		sp.position = pos.round()
		sp.walking = walking
		sp.modulate.a = 1.0 - _fall
		var u = exp.combat.heroes[i] if exp.combat != null and exp.phase == "combat" else null
		if u != null:
			sp.hp_ratio = u.hp_ratio()
			sp.set_dead(not u.alive)
		else:
			sp.hp_ratio = float(Game.state["heroes"][i]["hp_ratio"])
			sp.set_dead(false)


func _sync_enemies(exp) -> void:
	var c = exp.combat
	var cid: int = c.get_instance_id() if c != null else 0
	if cid == _combat_id:
		return
	_combat_id = cid
	for sp in enemy_sprites:
		sp.queue_free()
	enemy_sprites.clear()
	if c == null:
		return
	for u in c.enemies:
		var def := DataDB.unit_def(u.def_id)
		var sp = EnemySprite.instantiate()
		sp.set_meta("boss", u.is_boss)
		sp.configure(def["sprite"], def.get("palette", {}), px * (BOSS_SCALE if u.is_boss else 1.0), true)
		sp.unit_uid = u.uid
		add_child(sp)
		enemy_sprites.append(sp)


func _place_enemies(exp) -> void:
	var c = exp.combat
	if c == null:
		return
	var land := rest_s(int(Game.state["floor"]))
	var boss_offset := 0.0
	for i in enemy_sprites.size():
		var sp = enemy_sprites[i]
		var u = c.enemies[i]
		var s: float
		if u.is_boss:
			s = land + 34.0
			boss_offset = 10.0
		else:
			s = land + 26.0 + boss_offset + i * 11.0
		# Enemies slide in from the right when the fight starts.
		var intro := clampf(c.time * 3.0, 0.0, 1.0) if exp.phase == "combat" else 1.0
		s += (1.0 - intro) * 30.0
		sp.position = to_screen(s, ground_y(s)).round()
		sp.hp_ratio = u.hp_ratio()
		sp.set_dead(not u.alive)
		sp.walking = false


func _sprite_for(uid: String):
	if uid.begins_with("h"):
		return hero_sprites[int(uid.substr(1))]
	var i := int(uid.substr(1))
	return enemy_sprites[i] if i < enemy_sprites.size() else null


func _consume_combat_events() -> void:
	for ev in Game.combat_events:
		var src = _sprite_for(ev.get("src", "")) if ev.get("src", "") != "" else null
		match ev["t"]:
			"hit":
				var dst = _sprite_for(ev["dst"])
				if dst != null:
					dst.hurt()
					if show_numbers and Game.state["settings"].get("show_damage_numbers", true):
						_float_at(dst, UiNum.num(ev["dmg"]), Color("#ffd23f") if ev["crit"] else Color.WHITE, ev["crit"])
				if src != null and ev["tag"] == "":
					src.lunge()
			"miss":
				var dst = _sprite_for(ev["dst"])
				if dst != null and show_numbers and Game.state["settings"].get("show_damage_numbers", true):
					_float_at(dst, "miss", Color("#9aa4b2"), false)
			"skill":
				if src != null:
					_float_at(src, ev["name"], Color("#7fe0ff"), true)
			"revive":
				if src != null:
					_float_at(src, "REVIVE", Color("#ff9d2a"), true)
			"enrage":
				if src != null:
					_float_at(src, "ENRAGE", Color("#ff4f4f"), true)


func _float_at(sp, text: String, color: Color, big: bool) -> void:
	var top: Vector2 = sp.position - Vector2(0, sp.size_px().y)
	_floaters.append({"pos": top + Vector2(randf_range(-4, 4), 0), "text": text, "color": color, "t": 0.0, "big": big})


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if _colors.is_empty():
		return
	var sky: Color = _colors["sky"]
	var wall: Color = _colors["wall"]
	var wall_dark: Color = _colors["wall_dark"]
	draw_rect(Rect2(Vector2.ZERO, size), sky)
	_draw_bricks(wall, wall_dark)
	_draw_stairs()
	if _focus > 0.0:
		var vignette := Color(0, 0, 0, 0.35 * _focus)
		var w := size.x * 0.18
		draw_rect(Rect2(0, 0, w, size.y), vignette)
		draw_rect(Rect2(size.x - w, 0, w, size.y), vignette)
		var accent: Color = Color("#ff4f4f")
		accent.a = 0.25 * _focus * (0.6 + 0.4 * sin(_time * 4.0))
		draw_rect(Rect2(Vector2.ZERO, size), accent, false, 2.0)
	var font := get_theme_default_font()
	for f in _floaters:
		var t: float = f["t"]
		var c: Color = f["color"]
		c.a = 1.0 - t / 1.1
		var fs := int(maxf(8.0, px * (6.0 if f["big"] else 5.0)))
		var p: Vector2 = f["pos"] - Vector2(0, t * 10.0 * px)
		draw_string_outline(font, p + Vector2(-20, 0), f["text"], HORIZONTAL_ALIGNMENT_CENTER, 40, fs, 2, Color(0, 0, 0, c.a))
		draw_string(font, p + Vector2(-20, 0), f["text"], HORIZONTAL_ALIGNMENT_CENTER, 40, fs, c)


func _draw_bricks(wall: Color, dark: Color) -> void:
	# Tower wall scrolls with the camera (parallax 0.6) so vertical motion reads clearly.
	var bh := 5.0 * px
	var bw := 14.0 * px
	var ox := fposmod(-_cam_s * px * 0.6, bw * 2.0)
	var oy := fposmod(_cam_y * px * 0.6, bh * 2.0)
	var row := -2
	var y := oy - bh * 2.0
	draw_rect(Rect2(Vector2.ZERO, size), dark)
	while y < size.y:
		var shift := (bw * 0.5) if (row & 1) == 0 else 0.0
		var x := ox - bw * 2.0 + shift
		while x < size.x:
			draw_rect(Rect2(x, y, bw - px, bh - px), wall)
			draw_rect(Rect2(x, y + bh - px, bw, px), dark)
			draw_rect(Rect2(x + bw - px, y, px, bh), dark)
			x += bw
		y += bh
		row += 1
	# Arrow slits that glow with the biome accent.
	var accent: Color = _colors["accent"]
	var slit_every := 90.0 * px
	var sx := fposmod(-_cam_s * px * 0.6, slit_every)
	while sx < size.x:
		var sy := fposmod(oy + sx * 0.37, size.y * 0.6) + size.y * 0.05
		draw_rect(Rect2(sx, sy, 2.0 * px, 5.0 * px), _colors["sky"])
		var glow := accent
		glow.a = 0.35 + 0.15 * sin(_time * 2.0 + sx)
		draw_rect(Rect2(sx, sy + 3.0 * px, 2.0 * px, 2.0 * px), glow)
		sx += slit_every


func _draw_stairs() -> void:
	var step_col: Color = _colors["step"]
	var edge: Color = _colors["step_edge"]
	var shade: Color = _colors["wall_dark"].darkened(0.35)
	# The staircase wraps vertically: a flight leaving the top re-enters at the
	# bottom, so even a 1920x54 strip is filled with diagonal flights (the
	# "infinite staircase" loop). Units live near the anchor and never wrap.
	var rise_px := RISE * px
	var wrap_h := ceilf((size.y + rise_px) / rise_px) * rise_px
	var top := size.y - wrap_h
	var depth := STEP_RISE * px * 2.5
	var s_left := _cam_s - (lerpf(anchor.x, 0.42, _focus) * size.x) / px - STEP_RUN
	var s_right := s_left + size.x / px + STEP_RUN * 2.0
	var s := floorf(s_left / STEP_RUN) * STEP_RUN
	var w := STEP_RUN * px + 1.0
	while s < s_right:
		var p := to_screen(s, ground_y(s + 0.01))
		p.y = fposmod(p.y - top, wrap_h) + top
		draw_rect(Rect2(p.x, p.y, w, depth), step_col)
		draw_rect(Rect2(p.x, p.y + depth, w, px), shade)
		draw_rect(Rect2(p.x, p.y, w, px), edge)
		s += STEP_RUN
	# Floor numbers painted under each landing.
	var font := get_theme_default_font()
	var fs := int(maxf(8.0, px * 3.5))
	var label_col := edge
	label_col.a = 0.6
	var k0 := int(floorf(s_left / PERIOD)) - 1
	for k in range(k0, k0 + int(size.x / px / PERIOD) + 3):
		if k < 1:
			continue
		var p := to_screen(k * PERIOD + FLIGHT + LANDING * 0.5, (k + 1) * RISE)
		p.y = fposmod(p.y - top, wrap_h) + top
		if p.x < -40 or p.x > size.x + 40 or p.y + depth + fs > size.y + fs * 0.5:
			continue
		draw_string(font, Vector2(p.x - 20, p.y + depth + fs), str(k), HORIZONTAL_ALIGNMENT_CENTER, 40, fs, label_col)
