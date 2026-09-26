extends RefCounted
## Pure combat simulation: no nodes, no animation, no wall clock.
## The same engine runs a fight in real time (step() once per TICK) or instantly
## for offline progress (run_to_end()). Given the same RNG state it always
## produces the same result.

const TICK := 0.1

const SIDE_HEROES := 0
const SIDE_ENEMIES := 1


class Unit:
	var uid := ""
	var side := 0
	var def_id := ""
	var name := ""
	var index := 0
	var max_hp := 1.0
	var hp := 1.0
	var attack := 0.0
	var magic_power := 0.0
	var defense := 0.0
	var attack_speed := 1.0
	var crit_chance := 0.0
	var crit_damage := 1.5
	var dodge := 0.0
	var damage_pct := 0.0
	var fire_damage_pct := 0.0
	var damage_type := "physical"
	var element := ""
	var pattern := "single"
	var aggro := 1.0
	var row := "front"
	var skill := {}
	var skill_cd := 0.0
	var cdr := 0.0
	var specials: Array = []
	var atk_timer := 0.0
	var burn_dps := 0.0
	var burn_time := 0.0
	var burn_src = null
	var dr := 0.0
	var dr_time := 0.0
	var taunt_time := 0.0
	var enraged := false
	var is_boss := false
	var alive := true
	var damage_dealt := 0.0
	var gold := 0.0
	var xp := 0.0

	func power() -> float:
		return magic_power if damage_type == "magic" else attack

	func hp_ratio() -> float:
		return clampf(hp / max_hp, 0.0, 1.0)


var rng: RandomNumberGenerator
var heroes: Array = []
var enemies: Array = []
var time := 0.0
var time_limit := 45.0
var finished := false
var victory := false
var record_events := false
var events: Array = []
var party_specials: Array = []
var phoenix_used := false


## hero_entries: [{index, class_def, stats, hp_ratio, row, name}]
## enemy_entries: [{id, def, stats, is_boss}]
func setup(hero_entries: Array, enemy_entries: Array, rng_: RandomNumberGenerator, opts: Dictionary = {}) -> void:
	rng = rng_
	time_limit = float(opts.get("time_limit", 45.0))
	record_events = bool(opts.get("record_events", false))
	party_specials = opts.get("party_specials", [])
	for entry in hero_entries:
		heroes.append(_make_hero(entry))
	var i := 0
	for entry in enemy_entries:
		enemies.append(_make_enemy(entry, i))
		i += 1
	for u in heroes + enemies:
		u.atk_timer = rng.randf_range(0.15, 0.6) / u.attack_speed
		if not u.skill.is_empty():
			u.skill_cd = float(u.skill["cooldown"]) * 0.5 * (1.0 - u.cdr)


func _make_hero(entry: Dictionary) -> Unit:
	var u := Unit.new()
	var st: Dictionary = entry["stats"]
	var cdef: Dictionary = entry["class_def"]
	u.side = SIDE_HEROES
	u.index = int(entry["index"])
	u.uid = "h%d" % u.index
	u.def_id = entry["class_id"]
	u.name = entry["name"]
	u.max_hp = maxf(st["hp"], 1.0)
	u.hp = maxf(u.max_hp * float(entry.get("hp_ratio", 1.0)), 1.0)
	u.attack = st["attack"]
	u.magic_power = st["magic_power"]
	u.defense = st["defense"]
	u.attack_speed = maxf(st["attack_speed"], 0.1)
	u.crit_chance = st["crit_chance"]
	u.crit_damage = st["crit_damage"]
	u.dodge = st["dodge"]
	u.damage_pct = st["damage_pct"]
	u.fire_damage_pct = st["fire_damage_pct"]
	u.damage_type = st["damage_type"]
	u.element = st["element"]
	u.cdr = st.get("cdr", 0.0)
	u.specials = st["specials"]
	u.pattern = cdef["attack_pattern"]
	u.aggro = float(cdef["aggro"])
	u.row = entry.get("row", "front")
	u.skill = cdef.get("skill", {})
	return u


func _make_enemy(entry: Dictionary, idx: int) -> Unit:
	var u := Unit.new()
	var st: Dictionary = entry["stats"]
	var def: Dictionary = entry["def"]
	u.side = SIDE_ENEMIES
	u.index = idx
	u.uid = "e%d" % idx
	u.def_id = entry["id"]
	u.name = def["name"]
	u.max_hp = maxf(st["hp"], 1.0)
	u.hp = u.max_hp
	u.attack = st["attack"]
	u.magic_power = st["magic_power"]
	u.defense = st["defense"]
	u.attack_speed = st["attack_speed"]
	u.crit_chance = st["crit_chance"]
	u.crit_damage = st["crit_damage"]
	u.dodge = st["dodge"]
	u.damage_type = st["damage_type"]
	u.is_boss = bool(entry.get("is_boss", false))
	u.skill = def.get("skill", {}) if u.is_boss else {}
	u.gold = st["gold"]
	u.xp = st["xp"]
	return u


func run_to_end() -> void:
	while not finished:
		step()


func step() -> void:
	if finished:
		return
	time += TICK
	for u in heroes:
		_tick_unit(u)
		if finished:
			return
	for u in enemies:
		_tick_unit(u)
		if finished:
			return
	if time >= time_limit:
		_finish(false)


func alive_units(side: int) -> Array:
	var out := []
	for u in (heroes if side == SIDE_HEROES else enemies):
		if u.alive:
			out.append(u)
	return out


func unit_by_uid(uid: String) -> Unit:
	for u in heroes + enemies:
		if u.uid == uid:
			return u
	return null


func _tick_unit(u: Unit) -> void:
	if not u.alive:
		return
	if u.burn_time > 0.0:
		u.burn_time -= TICK
		_apply_damage(u.burn_src, u, u.burn_dps * TICK, false, "burn")
		if not u.alive or finished:
			return
	if u.dr_time > 0.0:
		u.dr_time -= TICK
		if u.dr_time <= 0.0:
			u.dr = 0.0
	if u.taunt_time > 0.0:
		u.taunt_time -= TICK
	if "regrowth" in u.specials and u.hp < u.max_hp:
		u.hp = minf(u.max_hp, u.hp + u.max_hp * 0.02 * TICK)

	if not u.skill.is_empty():
		u.skill_cd -= TICK
		if u.skill_cd <= 0.0:
			_use_skill(u)
			u.skill_cd += float(u.skill["cooldown"]) * (1.0 - u.cdr)
			if finished:
				return

	u.atk_timer -= TICK
	if u.atk_timer <= 0.0:
		u.atk_timer += 1.0 / u.attack_speed
		_basic_attack(u)


func _basic_attack(u: Unit) -> void:
	if u.side == SIDE_HEROES:
		var foes := alive_units(SIDE_ENEMIES)
		if foes.is_empty():
			return
		_hit(u, foes[0], 1.0, u.element, "")
		if u.pattern == "aoe":
			for f in foes.slice(1):
				_hit(u, f, 0.5, u.element, "splash")
	else:
		var target := _enemy_target()
		if target != null:
			_hit(u, target, 1.0, "", "")


func _enemy_target() -> Unit:
	var candidates := alive_units(SIDE_HEROES)
	if candidates.is_empty():
		return null
	for h in candidates:
		if h.taunt_time > 0.0:
			return h
	var total := 0.0
	for h in candidates:
		total += h.aggro * (1.0 if h.row == "front" else 0.4)
	var roll := rng.randf() * total
	for h in candidates:
		roll -= h.aggro * (1.0 if h.row == "front" else 0.4)
		if roll <= 0.0:
			return h
	return candidates[-1]


func _use_skill(u: Unit) -> void:
	var sk := u.skill
	match sk.get("type", ""):
		"party_shield":
			for h in alive_units(SIDE_HEROES):
				h.dr = float(sk["value"])
				h.dr_time = float(sk["duration"])
			u.taunt_time = float(sk["duration"])
			_emit({"t": "skill", "src": u.uid, "name": sk["name"]})
		"multi_shot":
			if alive_units(SIDE_ENEMIES).is_empty():
				return
			_emit({"t": "skill", "src": u.uid, "name": sk["name"]})
			for i in int(sk["hits"]):
				var foes := alive_units(SIDE_ENEMIES)
				if foes.is_empty():
					break
				_hit(u, foes[rng.randi() % foes.size()], float(sk["mult"]), u.element, "skill")
		"meteor":
			if alive_units(SIDE_ENEMIES).is_empty():
				return
			_emit({"t": "skill", "src": u.uid, "name": sk["name"]})
			for f in alive_units(SIDE_ENEMIES):
				var dealt := _hit(u, f, float(sk["mult"]), "fire", "skill")
				if dealt > 0.0 and f.alive:
					_ignite(u, f, dealt * float(sk["burn"]) / float(sk["duration"]), float(sk["duration"]))
		"slam":
			_emit({"t": "skill", "src": u.uid, "name": sk["name"]})
			for h in alive_units(SIDE_HEROES):
				_hit(u, h, float(sk["mult"]), "", "skill")


## Returns the damage dealt (0 on miss).
func _hit(src: Unit, dst: Unit, mult: float, element: String, tag: String) -> float:
	if not dst.alive or finished:
		return 0.0
	if rng.randf() < dst.dodge:
		_emit({"t": "miss", "src": src.uid, "dst": dst.uid})
		return 0.0
	var raw := src.power() * mult * (1.0 + src.damage_pct)
	if element == "fire":
		raw *= 1.0 + src.fire_damage_pct
	var crit := rng.randf() < src.crit_chance
	if crit:
		raw *= src.crit_damage
	var armor := dst.defense * (0.5 if src.damage_type == "magic" else 1.0)
	var dmg := raw * raw / (raw + armor) if raw > 0.0 else 0.0
	dmg = maxf(1.0, dmg * (1.0 - dst.dr))
	_apply_damage(src, dst, dmg, crit, tag)

	if src.side == SIDE_HEROES:
		if crit and "blood_crown" in party_specials:
			for h in alive_units(SIDE_HEROES):
				h.hp = minf(h.max_hp, h.hp + dmg * 0.05)
			_emit({"t": "heal", "src": src.uid, "amount": dmg * 0.05})
		if "burning_soul" in src.specials and dst.alive:
			_ignite(src, dst, dmg * 0.1, 3.0)
		if crit and tag != "chain" and "chain_lightning" in src.specials:
			var others := alive_units(SIDE_ENEMIES)
			others.erase(dst)
			if not others.is_empty():
				_hit(src, others[rng.randi() % others.size()], mult * 0.6, element, "chain")
	return dmg


func _ignite(src: Unit, dst: Unit, dps: float, duration: float) -> void:
	# Burns do not stack: the strongest one wins and refreshes the timer.
	if dps >= dst.burn_dps or dst.burn_time <= 0.0:
		dst.burn_dps = dps
		dst.burn_src = src
	dst.burn_time = maxf(dst.burn_time, duration)


func _apply_damage(src, dst: Unit, dmg: float, crit: bool, tag: String) -> void:
	if not dst.alive:
		return
	dst.hp -= dmg
	if src != null:
		src.damage_dealt += dmg
	_emit({"t": "hit", "src": src.uid if src != null else "", "dst": dst.uid, "dmg": dmg, "crit": crit, "tag": tag})
	if dst.is_boss and not dst.enraged and dst.hp < dst.max_hp * 0.5 and dst.hp > 0.0:
		dst.enraged = true
		dst.attack_speed *= 1.3
		_emit({"t": "enrage", "src": dst.uid})
	if dst.hp <= 0.0:
		_on_death(dst)


func _on_death(u: Unit) -> void:
	if u.side == SIDE_HEROES and "phoenix_feather" in party_specials and not phoenix_used:
		phoenix_used = true
		u.hp = u.max_hp * 0.4
		u.burn_time = 0.0
		_emit({"t": "revive", "src": u.uid})
		return
	u.hp = 0.0
	u.alive = false
	u.burn_time = 0.0
	_emit({"t": "death", "src": u.uid})
	if alive_units(SIDE_ENEMIES).is_empty():
		_finish(true)
	elif alive_units(SIDE_HEROES).is_empty():
		_finish(false)


func _finish(won: bool) -> void:
	if finished:
		return
	finished = true
	victory = won
	_emit({"t": "end", "victory": won})


func _emit(ev: Dictionary) -> void:
	if record_events:
		events.append(ev)
