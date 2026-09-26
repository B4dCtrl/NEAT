extends Control
## Renders the Infinite Tower: a cylindrical tower with a HELICAL staircase
## wound around it. The party stays near the front of the tower and the tower
## ROTATES as they climb (one full turn per floor), in the spirit of a
## 1-bit "infinitely spiralling tower". Works at any size; the taskbar version
## has a transparent background so only the tower floats over the desktop.
## Purely a view of Game.expedition, it never mutates the simulation.
##
## Path parameter t is measured in revolutions: floor f spans t in [f, f+1).
## The first STAIR_FRAC of each turn is steps, the rest is a flat landing where
## fights happen.

const DataDB = preload("res://core/data_db.gd")
const TowerGen = preload("res://core/tower_generator.gd")
const HeroSprite = preload("res://scenes/entities/hero_sprite.tscn")
const EnemySprite = preload("res://scenes/entities/enemy_sprite.tscn")
const UiNum = preload("res://scenes/ui/ui_util.gd")
const PixelArt = preload("res://scenes/entities/pixel_art.gd")
const CombatFx = preload("res://scenes/ui/combat_fx.gd")

## Size of one art pixel on screen.
@export var px := 2.0
@export var transparent_bg := true
@export var show_numbers := false
## Where the party's feet sit vertically (fraction of the stage height).
@export var feet_y := 0.74
## Horizontal position of the tower axis in pixels (<0 = centered).
@export var tower_center := -1.0

const STEPS := 16
const STAIR_FRAC := 0.72                # share of a turn that is stairs
const R_TOWER := 30.0                   # tower radius (art pixels)
const R_OUT := 46.0                     # outer edge of the steps
const R_WALK := 39.0                    # where feet land
const PITCH := 30.0                     # height gained per turn (= per floor)
const TILT := 0.22                      # camera looks slightly down
const SLOT := 0.045                     # spacing unit, in turns
const HERO_SLOT := 0.06                 # spacing between heroes
const ENEMY_START := 0.115              # first enemy, ahead of the party anchor
const ENEMY_SLOT := 0.05
const FIGHT_CENTER := 0.1               # the camera frames party + enemies around here
const BOSS_SCALE := 1.35
const BRICK_H := 6.0
const BRICKS_PER_TURN := 14

const MONO := {
	"ink": Color("#16151a"), "paper": Color("#efe9d8"), "mid": Color("#a39d90"),
	"back": Color("#6f6a61"), "back_riser": Color("#45423d"), "sky": Color("#101014"),
}

var hero_sprites: Array = []
var enemy_sprites: Array = []
var _combat_id := 0
var _cam_t := 0.0          # which part of the tower faces the viewer
var _cam_h := 0.0          # camera height
var _fall := 0.0
var _floaters: Array = []
var _drops: Array = []     # {tex, color, age, t, rank}
var _fx := CombatFx.new()
var _fx_layer: Node2D
var _pal := {}
var _pal_key := ""
var _time := 0.0
var _tower_tex: ImageTexture
var _tower_tex_key := ""


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	_rebuild_heroes()
	_snap_camera()
	# Effects and floating text are drawn on a layer above every sprite.
	_fx_layer = Node2D.new()
	_fx_layer.z_index = 10
	_fx_layer.draw.connect(_draw_fx_layer)
	add_child(_fx_layer)
	Game.settings_changed.connect(_on_style_changed)
	Game.loot_dropped.connect(_on_loot)
	Game.party_changed.connect(_rebuild_heroes)


func is_mono() -> bool:
	return Game.state["settings"].get("art_style", "mono") == "mono"


func _on_style_changed() -> void:
	_pal_key = ""
	_rebuild_heroes()
	_combat_id = -1


func _rebuild_heroes() -> void:
	var classes := DataDB.classes()
	while hero_sprites.size() < Game.state["heroes"].size():
		var sp = HeroSprite.instantiate()
		add_child(sp)
		hero_sprites.append(sp)
	while hero_sprites.size() > Game.state["heroes"].size():
		hero_sprites.pop_back().queue_free()
	for i in hero_sprites.size():
		var hero: Dictionary = Game.state["heroes"][i]
		hero_sprites[i].configure(classes[hero["class"]]["sprite"], {}, px, false, is_mono(), hero["class"])
		hero_sprites[i].unit_uid = "h%d" % i


# ------------------------------------------------------------------ geometry

static func rest_t(floor_num: int) -> float:
	return floor_num + STAIR_FRAC + (1.0 - STAIR_FRAC) * 0.22


## Height of the walking surface at t (stepped on the stairs).
static func ground_h(t: float) -> float:
	var k := floorf(t)
	var l := t - k
	if l < STAIR_FRAC:
		return k * PITCH + minf(floorf(l / STAIR_FRAC * STEPS) + 1.0, STEPS) * PITCH / STEPS
	return (k + 1.0) * PITCH


static func smooth_h(t: float) -> float:
	var k := floorf(t)
	var l := t - k
	if l < STAIR_FRAC:
		return k * PITCH + l / STAIR_FRAC * PITCH
	return (k + 1.0) * PITCH


func axis_x() -> float:
	return tower_center if tower_center >= 0.0 else size.x * 0.5


## Screen position (x, y) and depth z (1 = facing the viewer, -1 = behind).
func project(t: float, r: float, h: float) -> Vector3:
	var a := (t - _cam_t) * TAU
	var z := cos(a)
	var base := feet_y * size.y - R_WALK * TILT * px
	var sh := _fx.shake_offset()
	return Vector3(axis_x() + r * sin(a) * px + sh.x, base - (h - _cam_h) * px + z * r * TILT * px + sh.y, z)


func party_t() -> float:
	var exp = Game.expedition
	var f := int(Game.state["floor"])
	if exp.phase == "walk":
		return lerpf(rest_t(f - 1), rest_t(f), exp.walk_progress())
	if _is_falling(exp) and not exp.last_fall.is_empty():
		# Fall Back: the party tumbles down the helix to the bonfire.
		var k: float = 1.0 - exp.phase_left / maxf(exp.phase_total, 0.001)
		k = k * k * (3.0 - 2.0 * k)
		return lerpf(rest_t(int(exp.last_fall["from"])), rest_t(int(exp.last_fall["to"])), k)
	return rest_t(f)


func _is_falling(exp) -> bool:
	return exp.phase == "pause" and exp.after_pause == "walk"


## The camera frames the whole fight when there is one.
func _target_cam_t() -> float:
	var exp = Game.expedition
	if exp.phase in ["combat", "intro"] or (exp.phase == "pause" and exp.after_pause == "next_floor"):
		return rest_t(int(Game.state["floor"])) + FIGHT_CENTER
	return party_t()


func _snap_camera() -> void:
	_cam_t = _target_cam_t()
	_cam_h = smooth_h(party_t())


# ------------------------------------------------------------------ update

func _process(delta: float) -> void:
	if Game.expedition == null:
		return
	_time += delta
	var exp = Game.expedition
	_update_palette()

	_fall = 1.0 if _is_falling(exp) else 0.0

	var target_t := _target_cam_t()
	var target_h := smooth_h(party_t())
	if absf(target_t - _cam_t) > 40.0:
		_snap_camera()
	# During a Fall Back the camera rides along the tumbling party.
	var rate := 12.0 if _fall > 0.0 else (2.5 if absf(target_t - _cam_t) > 1.0 else 8.0)
	_cam_t = lerpf(_cam_t, target_t, minf(1.0, delta * rate))
	_cam_h = lerpf(_cam_h, target_h, minf(1.0, delta * rate))

	_sync_enemies(exp)
	_place_heroes(exp)
	_place_enemies(exp)
	_consume_combat_events()
	for d in _drops:
		d["age"] += delta
	_drops = _drops.filter(func(d): return d["age"] < DROP_LIFE)
	_fx.update(delta)
	_fx_layer.queue_redraw()
	for f in _floaters:
		f["t"] += delta
	_floaters = _floaters.filter(func(f): return f["t"] < 1.1)
	queue_redraw()


func _update_palette() -> void:
	var biome := TowerGen.biome_for(int(Game.state["floor"]))
	var key: String = ("mono" if is_mono() else biome["id"]) + str(size.x) + str(px)
	if key == _pal_key:
		return
	_pal_key = key
	if is_mono():
		_pal = MONO.duplicate()
	else:
		var c: Dictionary = biome["colors"]
		_pal = {
			"ink": Color("#121117"), "paper": Color.html(c["step_edge"]), "mid": Color.html(c["step"]),
			"back": Color.html(c["wall"]), "back_riser": Color.html(c["wall_dark"]), "sky": Color.html(c["sky"]),
			"tower": Color.html(c["wall"]).lightened(0.25),
		}
	_build_tower_texture()


## Pre-shades the cylinder once (light from the upper left, ordered dithering),
## so per-frame drawing is just a tiled texture plus rotating brick joints.
func _build_tower_texture() -> void:
	var w := int(R_TOWER * 2.0 * px)
	var cell := int(maxf(1.0, px))
	var h := 4 * cell
	var img := Image.create(maxi(w, 1), h, false, Image.FORMAT_RGBA8)
	var bayer := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	var light: Color = _pal.get("tower", _pal["paper"])
	var dark: Color = _pal["ink"]
	var mid: Color = _pal["mid"]
	for x in w:
		var nx := (x + 0.5) / w * 2.0 - 1.0
		var lambert := clampf(-0.55 * nx + 0.85 * sqrt(maxf(0.0, 1.0 - nx * nx)), 0.0, 1.0)
		var edge := x < cell or x >= w - cell
		for y in h:
			var bx := int(x / cell) % 4
			var by := int(y / cell) % 4
			var threshold: float = (bayer[by * 4 + bx] + 0.5) / 16.0
			var col: Color
			if edge:
				col = dark
			elif lambert > threshold + 0.25:
				col = light
			elif lambert > threshold - 0.2:
				col = mid
			else:
				col = dark
			img.set_pixel(x, y, col)
	_tower_tex = ImageTexture.create_from_image(img)


func _hero_order() -> Array:
	# Back-row heroes walk behind, front-row heroes lead the climb.
	var heroes: Array = Game.state["heroes"]
	var idx := range(mini(heroes.size(), hero_sprites.size()))
	idx.sort_custom(func(a, b):
		var ra := 1 if heroes[a]["row"] == "front" else 0
		var rb := 1 if heroes[b]["row"] == "front" else 0
		return ra < rb if ra != rb else a > b)
	return idx


func _place_heroes(exp) -> void:
	var base_t := party_t()
	var order := _hero_order()
	var walking: bool = exp.phase == "walk"
	var centre := (order.size() - 1) * 0.5
	for slot in order.size():
		var i: int = order[slot]
		var sp = hero_sprites[i]
		var t := base_t + (slot - centre) * HERO_SLOT
		var p := project(t, R_WALK, ground_h(t))
		var pos := Vector2(p.x, p.y)
		if _fall > 0.0:
			# Tumbling: little hops as they roll down the steps.
			pos.y -= absf(sin(_time * 14.0 + slot)) * 3.0 * px
		sp.position = pos.round()
		sp.visible = p.z > 0.05
		sp.walking = walking or _fall > 0.0
		sp.modulate.a = 1.0
		var u = exp.combat.heroes[i] if exp.combat != null and exp.phase == "combat" and i < exp.combat.heroes.size() else null
		if u != null:
			sp.hp_ratio = u.hp_ratio()
			sp.set_dead(not u.alive)
		else:
			sp.hp_ratio = float(Game.state["heroes"][i]["hp_ratio"])
			sp.set_dead(false)


func _sync_enemies(exp) -> void:
	var c = exp.combat
	var cid: int = c.get_instance_id() if c != null else 0
	if cid != _combat_id:
		_combat_id = cid
		for sp in enemy_sprites:
			sp.queue_free()
		enemy_sprites.clear()
	if c == null:
		return
	# Also picks up minions summoned mid-fight.
	while enemy_sprites.size() < c.enemies.size():
		var u = c.enemies[enemy_sprites.size()]
		var def := DataDB.unit_def(u.def_id)
		var sp = EnemySprite.instantiate()
		var scale: float = (BOSS_SCALE if u.is_boss else 1.0) * u.scale
		sp.configure(def["sprite"], def.get("palette", {}), px * scale, true, is_mono(), def.get("art", u.def_id), float(def.get("hue", -1.0)))
		sp.unit_uid = u.uid
		if u.affix_name != "":
			sp.set_meta("elite", true)
		add_child(sp)
		enemy_sprites.append(sp)


func _place_enemies(exp) -> void:
	var c = exp.combat
	if c == null:
		return
	var land := rest_t(int(Game.state["floor"]))
	var extra := 0.0
	var slot := 0
	for i in enemy_sprites.size():
		var sp = enemy_sprites[i]
		var u = c.enemies[i]
		var t: float
		if not u.alive and sp.has_meta("t"):
			t = sp.get_meta("t")    # the fallen stay where they fell
		elif u.is_boss:
			t = land + ENEMY_START + ENEMY_SLOT * 0.8
			extra = ENEMY_SLOT * 1.2
		else:
			t = land + ENEMY_START + extra + slot * ENEMY_SLOT
			slot += 1
		sp.set_meta("t", t)
		if not sp.has_meta("born"):
			sp.set_meta("born", c.time)
		# Enemies (and summoned minions) come round the tower as they appear.
		var intro := clampf((c.time - float(sp.get_meta("born"))) * 3.0, 0.0, 1.0) if exp.phase == "combat" else 1.0
		t += (1.0 - intro) * 0.12
		var p := project(t, R_WALK, ground_h(t))
		sp.position = Vector2(p.x, p.y).round()
		sp.visible = p.z > 0.05
		sp.hp_ratio = u.hp_ratio()
		sp.set_dead(not u.alive)
		sp.walking = false


func _sprite_for(uid: String):
	if uid.begins_with("h"):
		return hero_sprites[int(uid.substr(1))]
	var i := int(uid.substr(1))
	return enemy_sprites[i] if i < enemy_sprites.size() else null


func _center(sp) -> Vector2:
	return sp.position - Vector2(0, sp.size_px().y * 0.5)


func _consume_combat_events() -> void:
	# Two stages exist (taskbar + expedition); only the visible one reacts.
	if not is_visible_in_tree():
		return
	var numbers: bool = show_numbers and Game.state["settings"].get("show_damage_numbers", true)
	var c = Game.expedition.combat
	for ev in Game.combat_events:
		var src = _sprite_for(ev.get("src", "")) if ev.get("src", "") != "" else null
		var su = c.unit_by_uid(ev["src"]) if c != null and ev.get("src", "") != "" else null
		match ev["t"]:
			"hit":
				var dst = _sprite_for(ev["dst"])
				if dst == null:
					continue
				var b := _center(dst)
				var a := _center(src) if src != null else b
				dst.hurt()
				var tag: String = ev["tag"]
				if tag == "" and src != null and su != null:
					src.lunge()
					_attack_fx(su, a, b)
				elif tag == "splash":
					_fx.spawn("burst", a, b, Color("#ff9d4a"), 0.6, 0.25)
				elif tag == "chain":
					_fx.spawn("lightning", a, b, Color.WHITE, 1.0, 0.25)
				elif tag == "thorns":
					_fx.spawn("claw", a, b, Color("#5fd35f"), 0.7, 0.25)
				elif tag == "bomb":
					_fx.spawn("burst", a, b, Color("#ff6a1a"), 1.6, 0.45, 0.3)
					_fx.burst_particles(b, Color("#ffb13d"), 10, 60.0 * px, 1.0, 40.0 * px)
				elif tag == "burn" and randf() < 0.25:
					_fx.burst_particles(b, Color("#ff6a1a"), 2, 12.0 * px, 0.8, -20.0 * px, 0.4)
				_fx.spawn("spark", b, b, Color("#fff1a8") if ev["crit"] else Color.WHITE, 0.8, 0.18)
				if ev["crit"]:
					_fx.spawn("crit", b, b, Color("#ffd23f"), 1.0, 0.35)
					_fx.add_shake(0.35)
					_float_text(dst, "CRIT!", Color("#ffd23f"), true, true)
				if numbers:
					_float_at(dst, UiNum.num(ev["dmg"]), Color("#ffd23f") if ev["crit"] else Color.WHITE, ev["crit"])
				Game.sfx_requested.emit("crit" if ev["crit"] else ("hit" if tag == "" else ""))
			"miss":
				var dst = _sprite_for(ev["dst"])
				if dst != null:
					dst.dodge()
					_fx.spawn("whoosh", _center(dst), _center(dst), Color("#c9d1d9"), 1.0, 0.3)
					_float_text(dst, "MISS", Color("#9aa4b2"), false, true)
				Game.sfx_requested.emit("miss")
			"skill":
				if src != null:
					_skill_fx(ev, src, su)
					_float_at(src, ev["name"], Color("#7fe0ff"), true)
			"summon":
				if src != null:
					_fx.burst_particles(_center(src), Color("#6a5a8a"), 14, 30.0 * px, 1.4, -10.0 * px, 0.7)
				Game.sfx_requested.emit("summon")
			"potion":
				if src != null:
					_fx.spawn("heal", _center(src), _center(src), Color.WHITE, 1.0, 0.8)
					_float_text(src, "+HP", Color("#5fd35f"), true, true)
				Game.sfx_requested.emit("potion")
			"bomb":
				var target := _enemy_center()
				if src != null:
					_fx.spawn("bomb", _center(src), target, Color.WHITE, 1.0, 0.35)
				_fx.add_shake(0.5)
				Game.sfx_requested.emit("bomb")
			"death":
				if src != null:
					_fx.burst_particles(_center(src), Color("#d8d2c4"), 12, 35.0 * px, 1.2, 30.0 * px, 0.6)
				Game.sfx_requested.emit("death")
			"revive":
				if src != null:
					_fx.spawn("burst", _center(src), _center(src), Color("#ff9d2a"), 2.0, 0.6)
					_float_at(src, "REVIVE", Color("#ff9d2a"), true)
			"enrage":
				if src != null:
					_fx.spawn("aura", _center(src), _center(src), Color("#ff3030"), 1.4, 0.9)
					_float_at(src, "ENRAGE", Color("#ff4f4f"), true)
				Game.sfx_requested.emit("enrage")


## Basic attack visuals depend on who swings: arrows, fireballs, orbs or blades.
func _attack_fx(u, a: Vector2, b: Vector2) -> void:
	if u.side == 0:
		match u.def_id:
			"ranger":
				_fx.spawn("arrow", a, b, Color.WHITE, 1.0, 0.16)
			"arcanist":
				_fx.spawn("bolt", a, b, Color("#ff7a1a"), 1.0, 0.22)
				_fx.spawn("burst", b, b, Color("#ff9d4a"), 0.8, 0.25, 0.2)
			_:
				_fx.spawn("slash", a, b, Color("#f2f5ff"), 1.0, 0.2)
	elif u.damage_type == "magic":
		_fx.spawn("bolt", a, b, Color("#b35cff"), 0.9, 0.24)
	else:
		_fx.spawn("claw", a, b, Color("#ff6b6b"), 1.0, 0.22)


func _enemy_center() -> Vector2:
	var pts := []
	for sp in enemy_sprites:
		if sp.visible and not sp.dead:
			pts.append(_center(sp))
	if pts.is_empty():
		return size * 0.5
	var sum := Vector2.ZERO
	for p in pts:
		sum += p
	return sum / pts.size()


func _party_center() -> Vector2:
	var sum := Vector2.ZERO
	for sp in hero_sprites:
		sum += _center(sp)
	return sum / maxf(1.0, hero_sprites.size())


func _skill_fx(ev: Dictionary, src, su) -> void:
	var at := _center(src)
	match ev.get("kind", ""):
		"party_shield":
			_fx.spawn("dome", at, _party_center(), Color("#7fe0ff"), 1.3, 1.4)
			Game.sfx_requested.emit("shield")
		"multi_shot":
			_fx.spawn("rain", at, _enemy_center(), Color.WHITE, 1.0, 0.7)
			Game.sfx_requested.emit("volley")
		"meteor":
			_fx.spawn("meteor", at, _enemy_center(), Color.WHITE, 1.2, 0.5)
			_fx.spawn("burst", at, _enemy_center(), Color("#ff6a1a"), 2.2, 0.5, 0.35)
			_fx.burst_particles(_enemy_center(), Color("#ffb13d"), 16, 70.0 * px, 1.2, 60.0 * px, 0.8)
			_fx.add_shake(0.6)
			Game.sfx_requested.emit("meteor")
		"self_heal", "heal":
			_fx.spawn("heal", at, at, Color.WHITE, 1.2, 1.0)
			Game.sfx_requested.emit("heal")
		"slam":
			_fx.spawn("shockwave", at, at, Color("#e8d7b0"), 1.0, 0.6)
			_fx.add_shake(0.7)
			Game.sfx_requested.emit("slam")
		"drain":
			for h in hero_sprites:
				_fx.spawn("drain", _center(h), at, Color("#b35cff"), 1.0, 0.7)
			Game.sfx_requested.emit("drain")
		"shield":
			_fx.spawn("hexshield", at, at, Color("#8fd6ff"), 1.3, 1.2)
			Game.sfx_requested.emit("shield")
		"frenzy":
			_fx.spawn("aura", at, at, Color("#ff5a2a"), 1.4, 1.0)
			Game.sfx_requested.emit("enrage")
		"strike":
			var target := _enemy_center()
			var dst = _sprite_for(ev.get("dst", ""))
			if dst != null:
				target = _center(dst)
			match String(ev.get("id", "")):
				"piercing_shot":
					_fx.spawn("arrow", at, target, Color.WHITE, 1.8, 0.14)
					_fx.spawn("burst", target, target, Color("#e0e6ee"), 1.4, 0.3, 0.14)
				"firebolt":
					_fx.spawn("bolt", at, target, Color("#ff5a1a"), 1.8, 0.2)
					_fx.spawn("burst", target, target, Color("#ff9d4a"), 1.6, 0.35, 0.2)
				_:
					_fx.spawn("slash", at, target, Color("#fff2b0"), 1.8, 0.3)
					_fx.spawn("crit", target, target, Color("#ffd23f"), 0.9, 0.3, 0.1)
			_fx.add_shake(0.35)
			Game.sfx_requested.emit("crit")
		"party_heal":
			for h in hero_sprites:
				_fx.spawn("heal", _center(h), _center(h), Color.WHITE, 1.1, 1.0)
			_fx.spawn("aura", _party_center(), _party_center(), Color("#5fd35f"), 1.6, 0.9)
			Game.sfx_requested.emit("heal")
		"war_cry":
			for h in hero_sprites:
				_fx.spawn("aura", _center(h), _center(h), Color("#ffb13d"), 1.2, 0.9)
			_fx.spawn("shockwave", at, at, Color("#ffd23f"), 0.8, 0.5)
			Game.sfx_requested.emit("enrage")


## Short floating word ("MISS", "CRIT!") shown even in the small taskbar tower.
func _float_text(sp, text: String, color: Color, big: bool, always: bool) -> void:
	var top: Vector2 = sp.position - Vector2(0, sp.size_px().y)
	_floaters.append({"pos": top + Vector2(randf_range(-4, 4), -4), "text": text, "color": color, "t": 0.0, "big": big, "always": always})


## Flickering pixel campfire on every bonfire landing in view.
func _draw_bonfires() -> void:
	var every := int(DataDB.floor_rules()["archetypes"].get("bonfire_every", 10))
	var k0 := int(floorf(_cam_t)) - 3
	for k in range(k0, k0 + 7):
		if k < 1 or not TowerGen.is_bonfire(k):
			continue
		var t := rest_t(k) + FIGHT_CENTER
		var p := project(t, R_WALK, ground_h(t))
		if p.z < 0.2 or p.y < -20 or p.y > size.y + 20:
			continue
		var base := Vector2(p.x, p.y)
		var ink: Color = _pal["ink"]
		# Logs
		draw_rect(Rect2(base + Vector2(-5, -2) * px, Vector2(10, 2) * px), ink)
		draw_rect(Rect2(base + Vector2(-3, -3) * px, Vector2(6, 1) * px), _pal["mid"])
		# Flames: three flickering layers.
		var fl := [Color("#ff6a1a"), Color("#ffb13d"), Color("#fff1a8")]
		if is_mono():
			fl = [ink, _pal["mid"], _pal["paper"]]
		for layer in 3:
			var h := (7.0 - layer * 2.0 + sin(_time * 9.0 + layer * 1.7) * 1.2) * px
			var w := (6.0 - layer * 1.6) * px
			var c: Color = fl[layer]
			var pts := PackedVector2Array([base + Vector2(-w * 0.5, -2 * px), base + Vector2(w * 0.5, -2 * px),
				base + Vector2(sin(_time * 7.0 + layer) * px, -2 * px - h)])
			draw_colored_polygon(pts, c)
		if not is_mono():
			var glow := Color(1.0, 0.6, 0.2, 0.12 + 0.05 * sin(_time * 5.0))
			draw_circle(base + Vector2(0, -4) * px, 12.0 * px, glow)
		if k == int(Game.state.get("checkpoint", 1)):
			var font := get_theme_default_font()
			var fs := int(maxf(8.0, px * 3.5))
			draw_string_outline(font, base + Vector2(-30, 6 * px), "checkpoint", HORIZONTAL_ALIGNMENT_CENTER, 60, fs, 3, ink)
			draw_string(font, base + Vector2(-30, 6 * px), "checkpoint", HORIZONTAL_ALIGNMENT_CENTER, 60, fs, Color("#ffb13d"))


const DROP_LIFE := 2.6


## Loot pops out where the enemies stood, lands on the step glowing in its
## rarity colour, then flies to the party.
func _on_loot(drop: Dictionary) -> void:
	var tex: Texture2D
	var color: Color
	var rank := 0
	if drop.has("relic"):
		tex = PixelArt.icon("relic")
		color = UiNum.rarity_color("relic")
		rank = 6
	elif drop.has("consumable"):
		var cdef: Dictionary = DataDB.items()["consumables"].get(drop["consumable"], {})
		tex = PixelArt.frames(cdef.get("icon", "cons_potion"))[0]
		color = Color("#5fd35f")
		rank = 1
	else:
		tex = PixelArt.item_icon(drop, is_mono())
		color = UiNum.rarity_color(drop["rarity"])
		rank = DataDB.rarity_order(drop["rarity"])
	var land := rest_t(int(Game.state["floor"]))
	var n := _drops.size()
	_drops.append({"tex": tex, "color": color, "age": -0.2 * n, "t": land + ENEMY_START + ENEMY_SLOT * 0.5 * (n % 4), "rank": rank})


func _draw_drops() -> void:
	var party := project(party_t(), R_WALK, ground_h(party_t()))
	for d in _drops:
		var age: float = d["age"]
		if age < 0.0 or d["tex"] == null:
			continue
		var p := project(d["t"], R_WALK, ground_h(d["t"]))
		if p.z < 0.05:
			continue
		var pos := Vector2(p.x, p.y)
		var hop := 0.0
		if age < 0.5:
			hop = sin(age / 0.5 * PI) * 10.0 * px
		elif age > 1.6:
			var k := clampf((age - 1.6) / 0.8, 0.0, 1.0)
			pos = pos.lerp(Vector2(party.x, party.y), k * k)
			hop = sin(k * PI) * 8.0 * px
		pos.y -= hop
		var alpha := clampf((DROP_LIFE - age) / 0.3, 0.0, 1.0)
		var col: Color = d["color"]
		var tex: Texture2D = d["tex"]
		var sz := Vector2(8.0, 8.0) * px
		var center := pos - Vector2(0, sz.y * 0.6)
		if d["rank"] >= 4:
			# Legendary+ : spinning light rays.
			for i in 6:
				var a := _time * 2.0 + i * TAU / 6.0
				var ray := col
				ray.a = 0.35 * alpha
				draw_line(center, center + Vector2(cos(a), sin(a)) * 11.0 * px, ray, px)
		var glow := col
		glow.a = (0.25 + 0.15 * sin(_time * 8.0)) * alpha
		draw_circle(center, 6.0 * px, glow)
		draw_texture_rect(tex, Rect2(center - sz * 0.5, sz), false, Color(1, 1, 1, alpha))


func _float_at(sp, text: String, color: Color, big: bool) -> void:
	# The tiny taskbar tower stays clean: numbers and names only in the big view.
	if not show_numbers:
		return
	var top: Vector2 = sp.position - Vector2(0, sp.size_px().y)
	_floaters.append({"pos": top + Vector2(randf_range(-4, 4), 0), "text": text, "color": color, "t": 0.0, "big": big})


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if _pal.is_empty():
		return
	if not transparent_bg:
		draw_rect(Rect2(Vector2.ZERO, size), _pal["sky"])
		_draw_stars()
	var segs := _visible_segments()
	var back := []
	var front := []
	for s in segs:
		(front if s["z"] >= 0.0 else back).append(s)
	back.sort_custom(func(a, b): return a["z"] < b["z"])
	front.sort_custom(func(a, b): return a["z"] < b["z"])
	for s in back:
		_draw_segment(s, false)
	_draw_tower()
	for s in front:
		_draw_segment(s, true)
	_draw_bonfires()
	_draw_drops()


func _draw_stars() -> void:
	var c: Color = _pal["paper"]
	for i in 40:
		var sx := fposmod(i * 97.13 + _cam_t * 30.0, size.x)
		var sy := fposmod(i * 53.71 + _cam_h * px * 0.3, size.y)
		c.a = 0.25 + 0.2 * sin(_time * 1.5 + i)
		draw_rect(Rect2(sx, sy, px * 0.5, px * 0.5), c)


## Step and landing wedges in view, each {t0, t1, h, z, stair}.
func _visible_segments() -> Array:
	var out := []
	var k0 := int(floorf(_cam_t)) - 4
	for k in range(k0, k0 + 9):
		if k < 0:
			continue
		var dt := STAIR_FRAC / STEPS
		for i in STEPS:
			var t0 := k + i * dt
			_add_segment(out, t0, t0 + dt, k * PITCH + (i + 1) * PITCH / STEPS, true)
		var land_parts := 6
		var lt := (1.0 - STAIR_FRAC) / land_parts
		for i in land_parts:
			var t0 := k + STAIR_FRAC + i * lt
			_add_segment(out, t0, t0 + lt, (k + 1) * PITCH, false)
	return out


func _add_segment(out: Array, t0: float, t1: float, h: float, stair: bool) -> void:
	var mid := project((t0 + t1) * 0.5, R_OUT, h)
	if mid.y < -PITCH * px or mid.y > size.y + PITCH * px:
		return
	out.append({"t0": t0, "t1": t1, "h": h, "z": mid.z, "stair": stair})


func _draw_segment(s: Dictionary, is_front: bool) -> void:
	var t0: float = s["t0"]
	var t1: float = s["t1"]
	var h: float = s["h"]
	var thick := PITCH / STEPS * 1.6
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var under := PackedVector2Array()
	var n := 3
	for j in n + 1:
		var t := lerpf(t0, t1, float(j) / n)
		var o := project(t, R_OUT, h)
		var ii := project(t, R_TOWER, h)
		var u := project(t, R_OUT, h - thick)
		outer.append(Vector2(o.x, o.y))
		inner.append(Vector2(ii.x, ii.y))
		under.append(Vector2(u.x, u.y))
	var tread := PackedVector2Array(outer)
	for j in range(inner.size() - 1, -1, -1):
		tread.append(inner[j])
	var riser := PackedVector2Array(outer)
	for j in range(under.size() - 1, -1, -1):
		riser.append(under[j])
	var ink: Color = _pal["ink"]
	var line_w := maxf(1.0, px * 0.5)
	if is_front:
		_poly(riser, _pal["mid"])
		_poly(tread, _pal["paper"])
		draw_polyline(outer, ink, line_w)
		draw_polyline(under, ink, line_w)
		draw_line(outer[0], under[0], ink, line_w)
	else:
		_poly(riser, _pal["back_riser"])
		_poly(tread, _pal["back"])
		draw_polyline(outer, ink, line_w)


func _poly(points: PackedVector2Array, color: Color) -> void:
	if points.size() >= 3 and Geometry2D.triangulate_polygon(points).size() > 0:
		draw_colored_polygon(points, color)


func _draw_tower() -> void:
	var cx := axis_x()
	var half := R_TOWER * px
	var rect := Rect2(cx - half, 0, half * 2.0, size.y)
	if _tower_tex != null:
		draw_texture_rect(_tower_tex, rect, true)
	var ink: Color = _pal["ink"]
	ink.a = 0.45
	var line_w := maxf(1.0, px * 0.5)
	# Brick courses scroll with height; joints move sideways as the tower turns.
	var bh := BRICK_H * px
	var y0 := fposmod(feet_y * size.y + _cam_h * px, bh) - bh
	var row := int(floorf((feet_y * size.y + _cam_h * px) / bh))
	var y := y0
	while y < size.y:
		draw_line(Vector2(cx - half, y), Vector2(cx + half, y), ink, line_w)
		var shift := 0.5 if (row & 1) == 0 else 0.0
		for j in BRICKS_PER_TURN:
			var a := ((j + shift) / BRICKS_PER_TURN - fposmod(_cam_t, 1.0)) * TAU
			if cos(a) > 0.15:
				var x := cx + sin(a) * half
				draw_line(Vector2(x, y), Vector2(x, y + bh), ink, line_w)
		y += bh
		row -= 1
	# Arrow slits: one per floor, halfway round from the landing.
	var k0 := int(floorf(_cam_t)) - 3
	var slit: Color = _pal["ink"]
	for k in range(k0, k0 + 7):
		for off in [0.45, 0.95]:
			var p := project(k + off, R_TOWER, k * PITCH + PITCH * 0.55)
			if p.z > 0.25 and p.y > -10 and p.y < size.y + 10:
				var w := 2.5 * px * p.z
				draw_rect(Rect2(p.x - w * 0.5, p.y - 5.0 * px, w, 5.0 * px), slit)
				draw_rect(Rect2(p.x - w * 0.5, p.y - 5.0 * px - px * 0.8, w, px * 0.8), slit)


func _draw_fx_layer() -> void:
	_fx.draw(_fx_layer, px)
	_draw_floaters(_fx_layer)


func _draw_floaters(ci: CanvasItem) -> void:
	var font := get_theme_default_font()
	for f in _floaters:
		var t: float = f["t"]
		var c: Color = f["color"]
		c.a = 1.0 - t / 1.1
		var fs := int(maxf(9.0, px * (5.0 if f["big"] else 4.0)))
		var p: Vector2 = f["pos"] - Vector2(0, t * 10.0 * px)
		ci.draw_string_outline(font, p + Vector2(-60, 0), f["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, fs, 3, Color(0, 0, 0, c.a))
		ci.draw_string(font, p + Vector2(-60, 0), f["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, fs, c)
