extends RefCounted
## Upgrade hints: is an item in the bag (or on sale) better than what a hero
## wears now? "Better" is the real power rating of the hero (stats, crit, dodge,
## set bonuses...) with the item swapped in, not just a bigger number on the item.

const StatCalc = preload("res://core/stat_calculator.gd")
const Inventory = preload("res://core/inventory.gd")
const Loot = preload("res://core/loot_calculator.gd")
const Loc = preload("res://core/loc.gd")

## Below +0.5% of power the difference is noise, not an upgrade.
const MIN_GAIN := 0.005


## {hero_index: gain} for every hero that can use `item` and would improve
## (0.12 = +12% power). `mods` is an optional cached StatCalc.party_mods().
static func gains(state: Dictionary, item: Dictionary, mods: Dictionary = {}) -> Dictionary:
	if mods.is_empty():
		mods = StatCalc.party_mods(state)
	var out := {}
	var heroes: Array = state["heroes"]
	for i in heroes.size():
		var g := gain_for(state, i, item, mods)
		if g > MIN_GAIN:
			out[i] = g
	return out


## Relative power change if hero `i` wore `item` (-1 when the class cannot use it).
static func gain_for(state: Dictionary, i: int, item: Dictionary, mods: Dictionary = {}) -> float:
	var hero: Dictionary = state["heroes"][i]
	if not Loot.can_equip(item, hero["class"]):
		return -1.0
	if mods.is_empty():
		mods = StatCalc.party_mods(state)
	var now := StatCalc.power_rating(StatCalc.hero_stats(state, hero, mods))
	return Inventory.power_with(state, hero, item["slot"], item, mods) / maxf(now, 0.001) - 1.0


## Looks at the whole bag once. Returns
##   items:    {uid: {"gains": {hero: gain}, "top_for": [hero, ...]}} for every
##             item that improves somebody; top_for lists the heroes for whom
##             it is the best bag choice for that slot (those are the ones to
##             highlight: one glowing item per slot, not twenty);
##   per_hero: [number of top upgrades waiting for each hero];
##   total:    how many bag items are the best choice for at least one hero.
static func scan(state: Dictionary) -> Dictionary:
	var mods := StatCalc.party_mods(state)
	var heroes: Array = state["heroes"]
	var base := []
	for h in heroes:
		base.append(maxf(StatCalc.power_rating(StatCalc.hero_stats(state, h, mods)), 0.001))
	var items := {}
	var top := {}    # "hero|slot" -> {uid, gain}
	for it in state["inventory"]:
		var g := {}
		for i in heroes.size():
			if not Loot.can_equip(it, heroes[i]["class"]):
				continue
			var gain: float = Inventory.power_with(state, heroes[i], it["slot"], it, mods) / base[i] - 1.0
			if gain > MIN_GAIN:
				g[i] = gain
				var key := "%d|%s" % [i, it["slot"]]
				if not top.has(key) or gain > float(top[key]["gain"]):
					top[key] = {"uid": int(it["uid"]), "gain": gain}
		if not g.is_empty():
			items[int(it["uid"])] = {"gains": g, "top_for": []}
	var per_hero := []
	per_hero.resize(heroes.size())
	per_hero.fill(0)
	var winners := {}
	for key in top:
		var uid: int = top[key]["uid"]
		var hero_i := int(String(key).get_slice("|", 0))
		items[uid]["top_for"].append(hero_i)
		per_hero[hero_i] += 1
		winners[uid] = true
	return {"items": items, "per_hero": per_hero, "total": winners.size()}


## Tooltip lines: who would gain how much, and compared to what they wear.
## Empty when nobody improves.
static func hint_lines(state: Dictionary, item: Dictionary, found: Dictionary = {}) -> Array:
	var g: Dictionary = found if not found.is_empty() else gains(state, item)
	if g.is_empty():
		return []
	var ids := g.keys()
	ids.sort_custom(func(a, b): return g[a] > g[b])
	var lines := []
	for n in mini(ids.size(), 3):
		var i: int = ids[n]
		var hero: Dictionary = state["heroes"][i]
		var worn = hero["equipment"].get(item["slot"])
		var pct := String.num(g[i] * 100.0, 1 if g[i] < 0.1 else 0)
		if worn == null:
			lines.append(Loc.t("▲ +%s%% power for %s (empty slot)") % [pct, hero["name"]])
		else:
			lines.append(Loc.t("▲ +%s%% power for %s (vs. %s)") % [pct, hero["name"], worn["name"]])
	return lines
