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
	var lifesteal := 0.0
	var cleave := 0.0
	var fire_damage_pct := 0.0
	var damage_type := "physical"
	var element := ""
	var pattern := "single"
	var aggro := 1.0
	var row := "front"
	var skills: Array = []      # hero: its class skill; bosses: several
	var skill_cds: Array = []
	var thorns := 0.0           # reflects this share of damage taken
	var regen := 0.0            # max-HP share healed per second
	var berserk := 0.0          # attack-speed multiplier below 50% HP
	var berserked := false
	var haste_time := 0.0
	var haste_mult := 1.0
	var affix_name := ""
	var summoned := false
	var scale := 1.0
	var cdr := 0.0
	var mana := 0.0
	var max_mana := 0.0
	var mana_regen := 0.0
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

	func mp_ratio() -> float:
		return clampf(mana / max_mana, 0.0, 1.0) if max_mana > 0.0 else 1.0


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
## Creates a combat entry for a summoned enemy id (set by the Expedition).
var summon_factory: Callable
## Consumables carried into the fight: {"potion": n, "bomb": n}; `consumed` counts use.
var supplies := {}
var consumed := {}
var auto_supplies := true
var _potion_cd := 0.0
var _bomb_used := false


## hero_entries: [{index, class_def, stats, hp_ratio, row, name}]
## enemy_entries: [{id, def, stats, is_boss}]
func setup(hero_entries: Array, enemy_entries: Array, rng_: RandomNumberGenerator, opts: Dictionary = {}) -> void:
	rng = rng_
	time_limit = float(opts.get("time_limit", 45.0))
	record_events = bool(opts.get("record_events", false))
	party_specials = opts.get("party_specials", [])
	summon_factory = opts.get("summon_factory", Callable())
	supplies = opts.get("supplies", {}).duplicate()
	auto_supplies = bool(opts.get("auto_supplies", true))
	for entry in hero_entries:
		heroes.append(_make_hero(entry))
	var i := 0
	for entry in enemy_entries:
		enemies.append(_make_enemy(entry, i))
		i += 1
	for u in heroes + enemies:
		_init_timers(u)


func _init_timers(u: Unit) -> void:
	u.atk_timer = rng.randf_range(0.15, 0.6) / u.attack_speed
	u.skill_cds.clear()
	for i in u.skills.size():
		# Staggered so multi-skill bosses do not fire everything at once.
		u.skill_cds.append(float(u.skills[i]["cooldown"]) * (0.5 + 0.25 * i) * (1.0 - u.cdr))


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
	u.lifesteal = st.get("lifesteal", 0.0)
	u.cleave = st.get("cleave", 0.0)
	u.damage_type = st["damage_type"]
	u.element = st["element"]
	u.cdr = st.get("cdr", 0.0)
	u.specials = st["specials"]
	u.pattern = cdef["attack_pattern"]
	u.aggro = float(cdef["aggro"])
	u.row = entry.get("row", "front")
	u.skills = entry.get("skills", [cdef["skill"]] if cdef.has("skill") else [])
	u.max_mana = float(st.get("mana", 0.0))
	u.mana = u.max_mana * float(entry.get("mp_ratio", 1.0))
	u.mana_regen = float(st.get("mana_regen", 0.0))
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
	u.skills = def.get("skills", []) if u.is_boss else []
	u.gold = st["gold"]
	u.xp = st["xp"]
	u.affix_name = st.get("affix_name", "")
	if u.affix_name != "":
		u.name = u.affix_name + " " + u.name
	var traits: Dictionary = st.get("traits", {})
	u.lifesteal = float(traits.get("lifesteal", 0.0))
	u.thorns = float(traits.get("thorns", 0.0))
	u.regen = float(traits.get("regen", 0.0))
	u.berserk = float(traits.get("berserk", 0.0))
	if traits.has("opening_shield"):
		u.dr = float(traits["opening_shield"])
		u.dr_time = 4.0
	u.summoned = bool(entry.get("summoned", false))
	u.scale = float(st.get("scale", 1.0))
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
	if u.regen > 0.0 and u.hp < u.max_hp:
		u.hp = minf(u.max_hp, u.hp + u.max_hp * u.regen * TICK)
	if u.haste_time > 0.0:
		u.haste_time -= TICK
		if u.haste_time <= 0.0:
			u.attack_speed /= u.haste_mult
			u.haste_mult = 1.0

	if u.max_mana > 0.0:
		u.mana = minf(u.max_mana, u.mana + u.mana_regen * TICK)
	for i in u.skills.size():
		u.skill_cds[i] = maxf(0.0, u.skill_cds[i] - TICK)
		if u.skill_cds[i] <= 0.0:
			# Heroes pay mana: a ready skill waits until there is enough.
			var cost := float(u.skills[i].get("mana", 0.0)) if u.side == SIDE_HEROES else 0.0
			if cost > u.mana:
				continue
			if not _skill_useful(u, u.skills[i]):
				continue
			u.mana -= cost
			_use_skill(u, u.skills[i])
			u.skill_cds[i] += float(u.skills[i]["cooldown"]) * (1.0 - u.cdr)
			if finished:
				return

	u.atk_timer -= TICK
	if u.atk_timer <= 0.0:
		u.atk_timer += 1.0 / u.attack_speed
		_basic_attack(u)
	if u.side == SIDE_HEROES and u.index == 0:
		_auto_supplies()


func _basic_attack(u: Unit) -> void:
	if u.side == SIDE_HEROES:
		var foes := alive_units(SIDE_ENEMIES)
		if foes.is_empty():
			return
		_hit(u, foes[0], 1.0, u.element, "")
		if u.pattern == "aoe":
			for f in foes.slice(1):
				_hit(u, f, 0.5, u.element, "splash")
		elif u.cleave > 0.0 and foes.size() > 1 and foes[1].alive:
			_hit(u, foes[1], u.cleave, u.element, "splash")
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


## Heroes do not waste mana: heals wait for a wound, attacks for a target.
func _skill_useful(u: Unit, sk: Dictionary) -> bool:
	if u.side != SIDE_HEROES:
		return true
	match sk.get("type", ""):
		"self_heal":
			return u.hp_ratio() < 0.6
		"party_heal":
			for h in alive_units(SIDE_HEROES):
				if h.hp_ratio() < 0.6:
					return true
			return false
		_:
			return not alive_units(SIDE_ENEMIES).is_empty()


## Mana potion: every hero gets `share` of their mana back.
func use_mana_potion(share: float = 0.5) -> bool:
	if int(supplies.get("mana", 0)) <= 0 or finished:
		return false
	supplies["mana"] = int(supplies["mana"]) - 1
	consumed["mana"] = int(consumed.get("mana", 0)) + 1
	for h in alive_units(SIDE_HEROES):
		h.mana = minf(h.max_mana, h.mana + h.max_mana * share)
		_emit({"t": "mana", "src": h.uid})
	return true


func _use_skill(u: Unit, sk: Dictionary) -> void:
	var kind: String = sk.get("type", "")
	match kind:
		"party_shield":
			for h in alive_units(SIDE_HEROES):
				h.dr = float(sk["value"])
				h.dr_time = float(sk["duration"])
			u.taunt_time = float(sk["duration"])
			_emit({"t": "skill", "src": u.uid, "name": sk["name"], "kind": kind})
		"multi_shot":
			if alive_units(SIDE_ENEMIES).is_empty():
				return
			_emit({"t": "skill", "src": u.uid, "name": sk["name"], "kind": kind})
			for i in int(sk["hits"]):
				var foes := alive_units(SIDE_ENEMIES)
				if foes.is_empty():
					break
				_hit(u, foes[rng.randi() % foes.size()], float(sk["mult"]), u.element, "skill")
		"meteor":
			if alive_units(SIDE_ENEMIES).is_empty():
				return
			_emit({"t": "skill", "src": u.uid, "name": sk["name"], "kind": kind})
			for f in alive_units(SIDE_ENEMIES):
				var dealt := _hit(u, f, float(sk["mult"]), "fire", "skill")
				if dealt > 0.0 and f.alive:
					_ignite(u, f, dealt * float(sk["burn"]) / float(sk["duration"]), float(sk["duration"]))
		"self_heal":
			u.hp = minf(u.max_hp, u.hp + u.max_hp * float(sk["value"]))
			_emit({"t": "skill", "src": u.uid, "name": sk["name"], "kind": kind})
		"strike":
			var foes := alive_units(SIDE_ENEMIES)
			if foes.is_empty():
				return
			_emit({"t": "skill", "src": u.uid, "dst": foes[0].uid, "name": sk["name"], "kind": kind, "id": sk.get("id", "")})
			_hit(u, foes[0], float(sk["mult"]), "fire" if sk.get("id", "") == "firebolt" else u.element, "skill")
		"party_heal":
			for h in alive_units(SIDE_HEROES):
				h.hp = minf(h.max_hp, h.hp + h.max_hp * float(sk["value"]))
			_emit({"t": "skill", "src": u.uid, "name": sk["name"], "kind": kind})
		"war_cry":
			# Party-wide haste; refreshing an active cry only extends it.
			for h in alive_units(SIDE_HEROES):
				if h.haste_time <= 0.0:
					h.haste_mult = float(sk["value"])
					h.attack_speed *= h.haste_mult
				h.haste_time = maxf(h.haste_time, float(sk["duration"]))
			_emit({"t": "skill", "src": u.uid, "name": sk["name"], "kind": kind})
		"slam":
			_emit({"t": "skill", "src": u.uid, "name": sk["name"], "kind": kind})
			for h in alive_units(SIDE_HEROES):
				_hit(u, h, float(sk["mult"]), "", "skill")
		"drain":
			_emit({"t": "skill", "src": u.uid, "name": sk["name"], "kind": kind})
			var total := 0.0
			for h in alive_units(SIDE_HEROES):
				total += _hit(u, h, float(sk["mult"]), "", "skill")
			if u.alive:
				u.hp = minf(u.max_hp, u.hp + total * float(sk.get("value", 0.5)))
		"heal":
			u.hp = minf(u.max_hp, u.hp + u.max_hp * float(sk["value"]))
			_emit({"t": "skill", "src": u.uid, "name": sk["name"], "kind": kind})
		"shield":
			u.dr = float(sk["value"])
			u.dr_time = float(sk["duration"])
			_emit({"t": "skill", "src": u.uid, "name": sk["name"], "kind": kind})
		"frenzy":
			if u.haste_time <= 0.0:
				u.haste_mult = float(sk["value"])
				u.attack_speed *= u.haste_mult
			u.haste_time = float(sk["duration"])
			_emit({"t": "skill", "src": u.uid, "name": sk["name"], "kind": kind})
		"summon":
			_summon(u, sk)


## Bosses call reinforcements, up to `max` summoned minions alive at once.
func _summon(u: Unit, sk: Dictionary) -> void:
	if not summon_factory.is_valid():
		return
	var alive_minions := 0
	for e in enemies:
		if e.summoned and e.alive:
			alive_minions += 1
	var room := int(sk.get("max", 4)) - alive_minions
	if room <= 0:
		return
	_emit({"t": "skill", "src": u.uid, "name": sk["name"], "kind": "summon"})
	for i in mini(int(sk.get("count", 1)), room):
		var entry: Dictionary = summon_factory.call(String(sk["unit"]))
		entry["summoned"] = true
		var m := _make_enemy(entry, enemies.size())
		m.gold *= 0.3
		m.xp *= 0.3
		_init_timers(m)
		enemies.append(m)
		_emit({"t": "summon", "src": m.uid, "by": u.uid})


# ------------------------------------------------------------------ supplies

## Drinks a potion: heals the most wounded hero. Returns false if none left.
func use_potion(heal: float = 0.45) -> bool:
	if int(supplies.get("potion", 0)) <= 0 or finished:
		return false
	var target: Unit = null
	for h in alive_units(SIDE_HEROES):
		if target == null or h.hp_ratio() < target.hp_ratio():
			target = h
	if target == null:
		return false
	supplies["potion"] = int(supplies["potion"]) - 1
	consumed["potion"] = int(consumed.get("potion", 0)) + 1
	target.hp = minf(target.max_hp, target.hp + target.max_hp * heal)
	_emit({"t": "potion", "src": target.uid})
	return true


## Throws a fire bomb at every enemy (damage scaled on the party's power).
func use_bomb(mult: float = 3.0) -> bool:
	if int(supplies.get("bomb", 0)) <= 0 or finished or heroes.is_empty():
		return false
	supplies["bomb"] = int(supplies["bomb"]) - 1
	consumed["bomb"] = int(consumed.get("bomb", 0)) + 1
	var thrower: Unit = heroes[0]
	for h in alive_units(SIDE_HEROES):
		if h.power() > thrower.power():
			thrower = h
	_emit({"t": "bomb", "src": thrower.uid})
	for e in alive_units(SIDE_ENEMIES):
		_hit(thrower, e, mult, "fire", "bomb")
	return true


func _auto_supplies() -> void:
	if not auto_supplies:
		return
	_potion_cd -= TICK
	if _potion_cd <= 0.0:
		for h in alive_units(SIDE_HEROES):
			if h.hp_ratio() < 0.3 and use_potion():
				_potion_cd = 2.0
				break
	if _potion_cd <= 0.0:
		for e in alive_units(SIDE_ENEMIES):
			if e.is_boss:
				var dry := 0
				for h in alive_units(SIDE_HEROES):
					if h.max_mana > 0.0 and h.mp_ratio() < 0.15:
						dry += 1
				if dry > 0 and use_mana_potion():
					_potion_cd = 2.0
				break
	if not _bomb_used and time > 1.0:
		for e in alive_units(SIDE_ENEMIES):
			if e.is_boss:
				_bomb_used = use_bomb()
				break


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

	if src.lifesteal > 0.0 and src.alive:
		src.hp = minf(src.max_hp, src.hp + dmg * src.lifesteal)
	if dst.thorns > 0.0 and src.alive and tag != "thorns":
		_apply_damage(dst, src, dmg * dst.thorns, false, "thorns")
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
	if dst.berserk > 0.0 and not dst.berserked and dst.hp < dst.max_hp * 0.5 and dst.hp > 0.0:
		dst.berserked = true
		dst.attack_speed *= dst.berserk
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
