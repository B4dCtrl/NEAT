extends RefCounted
## Procedural floor rules. A floor is a pure function of (run seed, floor number):
## the same save always sees the same tower, which keeps offline progress deterministic.

const DataDB = preload("res://core/data_db.gd")


static func floor_rng(run_seed: int, floor_num: int, salt: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed * 1000003 + floor_num * 7919 + salt * 104729
	return rng


static func biome_for(floor_num: int) -> Dictionary:
	var rules := DataDB.floor_rules()
	var biomes: Array = rules["biomes"]
	var span := int(rules["biome_span"])
	var idx := int((max(floor_num, 1) - 1) / span) % biomes.size()
	return biomes[idx]


## "" for a normal floor, otherwise "guardian", "elite" or "lord".
static func is_bonfire(floor_num: int) -> bool:
	var every := int(DataDB.floor_rules()["archetypes"].get("bonfire_every", 10))
	return floor_num % every == 1 or every == 1


## Last bonfire at or below this floor.
static func bonfire_below(floor_num: int) -> int:
	var every := int(DataDB.floor_rules()["archetypes"].get("bonfire_every", 10))
	return maxi(1, floor_num - ((floor_num - 1) % every))


static func boss_tier(floor_num: int) -> String:
	var arch: Dictionary = DataDB.floor_rules()["archetypes"]
	if floor_num % int(arch["lord_every"]) == 0:
		return "lord"
	if floor_num % int(arch["elite_every"]) == 0:
		return "elite"
	if floor_num % int(arch["guardian_every"]) == 0:
		return "guardian"
	return ""


## Describes a floor: {floor, type, biome, tier, enemies, shrine}.
## type is one of "standard", "shrine", "vault", "guardian", "bonfire".
## Bonfires sit on floors 1, 11, 21...: the checkpoint the party returns to.
static func generate(run_seed: int, floor_num: int) -> Dictionary:
	var rules := DataDB.floor_rules()
	var rng := floor_rng(run_seed, floor_num)
	var biome := biome_for(floor_num)
	var info := {
		"floor": floor_num,
		"type": "standard",
		"biome": biome["id"],
		"biome_name": biome["name"],
		"tier": boss_tier(floor_num),
		"enemies": [],
		"shrine": {},
	}
	if is_bonfire(floor_num):
		info["type"] = "bonfire"
		return info
	if info["tier"] != "":
		info["type"] = "guardian"
		var tier_def: Dictionary = DataDB.enemy_scaling()["boss_tiers"][info["tier"]]
		info["enemies"].append(biome["boss"])
		for i in int(tier_def["minions"]):
			info["enemies"].append(biome["enemies"][rng.randi() % biome["enemies"].size()])
		return info

	var arch: Dictionary = rules["archetypes"]
	if floor_num >= int(arch["min_floor_for_events"]):
		var roll := rng.randf()
		if roll < float(arch["shrine_chance"]):
			info["type"] = "shrine"
			info["shrine"] = _pick_shrine(rng)
			return info
		if roll < float(arch["shrine_chance"]) + float(arch["vault_chance"]):
			info["type"] = "vault"
			return info

	var count_rules: Dictionary = rules["enemy_count"]
	var extra := int(floor_num / int(count_rules["extra_every"]))
	var lo := mini(int(count_rules["base_min"]) + extra, int(count_rules["cap"]))
	var hi := mini(int(count_rules["base_max"]) + extra, int(count_rules["cap"]))
	var count := rng.randi_range(lo, hi)
	var pool: Array = biome["enemies"]
	for i in count:
		info["enemies"].append(pool[rng.randi() % pool.size()])
	return info


## Final combat stats of an enemy/boss at a given floor.
static func enemy_stats(unit_id: String, floor_num: int, tier: String = "") -> Dictionary:
	var def := DataDB.unit_def(unit_id)
	var sc := DataDB.enemy_scaling()
	var n := float(max(floor_num, 1) - 1)
	var hp_mult := pow(float(sc["hp_growth"]), n)
	var atk_mult := pow(float(sc["attack_growth"]), n)
	var def_mult := pow(float(sc["defense_growth"]), n)
	var gold_mult := pow(float(sc["gold_growth"]), n)
	var xp_mult := pow(float(sc["xp_growth"]), n)
	if tier != "" and DataDB.bosses().has(unit_id):
		var t: Dictionary = sc["boss_tiers"][tier]
		hp_mult *= float(t["hp_mult"])
		atk_mult *= float(t["attack_mult"])
		gold_mult *= float(t["gold_mult"])
		xp_mult *= float(t["gold_mult"])
	var power := float(def["attack"]) * atk_mult
	return {
		"hp": float(def["hp"]) * hp_mult,
		"attack": power,
		"magic_power": power,
		"defense": float(def["defense"]) * def_mult,
		"attack_speed": float(def["attack_speed"]),
		"crit_chance": float(def.get("crit_chance", 0.0)),
		"crit_damage": 1.5,
		"dodge": float(def.get("dodge", 0.0)),
		"damage_type": def.get("damage_type", "physical"),
		"gold": float(def["gold"]) * gold_mult,
		"xp": float(def["xp"]) * xp_mult,
	}


static func _pick_shrine(rng: RandomNumberGenerator) -> Dictionary:
	var shrines: Array = DataDB.floor_rules()["shrines"]
	var total := 0.0
	for s in shrines:
		total += float(s["weight"])
	var roll := rng.randf() * total
	for s in shrines:
		roll -= float(s["weight"])
		if roll <= 0.0:
			return s
	return shrines[0]
