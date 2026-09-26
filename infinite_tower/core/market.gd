extends RefCounted
## The Tower Market: a stock that rotates every N minutes (same stock for the
## same save and time window), bought with Gold, plus a Crystal exchange for a
## featured Legendary and unowned Relics. Selling = salvage.

const DataDB = preload("res://core/data_db.gd")
const Loot = preload("res://core/loot_calculator.gd")
const Inventory = preload("res://core/inventory.gd")
const GameState = preload("res://core/game_state.gd")
const Heroes = preload("res://core/heroes.gd")

const HERO_RARITY_PRICE := {"common": 1.0, "uncommon": 1.4, "rare": 2.0, "epic": 3.5, "legendary": 6.0}


static func rules() -> Dictionary:
	return DataDB.balance()["market"]


static func rotation_id(now_unix: int) -> int:
	return int(now_unix / (int(rules()["rotation_minutes"]) * 60))


static func seconds_to_rotation(now_unix: int) -> int:
	var period := int(rules()["rotation_minutes"]) * 60
	return period - now_unix % period


## Rebuilds the stock when the rotation window changed. Returns true if it did.
static func ensure_stock(state: Dictionary, now_unix: int) -> bool:
	var rot := rotation_id(now_unix)
	var m: Dictionary = state.get("market", {})
	if int(m.get("rotation", -1)) == rot and int(m.get("floor", -1)) == int(state["max_floor"]) / 10:
		return false
	_generate(state, rot, int(m.get("rerolls", 0)) if int(m.get("rotation", -1)) == rot else 0)
	return true


static func _generate(state: Dictionary, rot: int, rerolls: int) -> void:
	var r := rules()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state["seed"]) * 31 + rot * 7919 + rerolls * 104729
	var floor_num := maxi(1, int(state["max_floor"]))
	var offers := []
	for i in int(r["stock"]):
		var rarity := Loot.roll_rarity(rng, floor_num, r["min_rarity"], float(r["rarity_bonus"]), false)
		var item := Loot.generate_item(rng, state, floor_num, rarity)
		offers.append({"item": item, "price": ceilf(Loot.salvage_value(item) * float(r["gold_price_mult"])), "currency": "gold", "sold": false})
	var featured := Loot.generate_item(rng, state, floor_num, r["featured_rarity"])
	offers.append({"item": featured, "price": int(r["featured_crystals"]), "currency": "crystals", "sold": false})
	for i in int(r.get("hero_offers", 0)):
		var hero := Heroes.generate(state, rng)
		var price := ceilf(Heroes.hire_price(state) * float(HERO_RARITY_PRICE.get(hero["rarity"], 1.0)))
		offers.append({"hero": hero, "price": price, "currency": "gold", "sold": false})
	var relic := Loot.roll_relic(rng, state)
	if relic != "":
		offers.append({"relic": relic, "price": int(r["relic_crystals"]), "currency": "crystals", "sold": false})
	state["market"] = {"rotation": rot, "rerolls": rerolls, "floor": int(state["max_floor"]) / 10, "offers": offers}


static func can_afford(state: Dictionary, offer: Dictionary) -> bool:
	if offer["currency"] == "gold":
		return float(state["gold"]) >= float(offer["price"])
	return int(state["crystals"]) >= int(offer["price"])


static func buy(state: Dictionary, index: int) -> bool:
	var offers: Array = state.get("market", {}).get("offers", [])
	if index < 0 or index >= offers.size():
		return false
	var offer: Dictionary = offers[index]
	if offer["sold"] or not can_afford(state, offer):
		return false
	if offer["currency"] == "gold":
		state["gold"] = float(state["gold"]) - float(offer["price"])
	else:
		state["crystals"] = int(state["crystals"]) - int(offer["price"])
	offer["sold"] = true
	if offer.has("hero"):
		var hero: Dictionary = offer["hero"]
		var where := Heroes.add_hero(state, hero)
		GameState.add_history(state, "info", "%s the %s joined the %s" % [hero["name"], DataDB.classes()[hero["class"]]["name"], where])
	elif offer.has("relic"):
		Inventory.receive_relic(state, offer["relic"])
		GameState.add_history(state, "relic", "Bought relic: %s" % DataDB.relics()[offer["relic"]]["name"])
	else:
		state["inventory"].append(offer["item"])
		GameState.add_history(state, "loot", "Bought %s" % offer["item"]["name"])
	return true


static func reroll(state: Dictionary, now_unix: int) -> bool:
	var cost := int(rules()["reroll_crystals"])
	if int(state["crystals"]) < cost:
		return false
	state["crystals"] = int(state["crystals"]) - cost
	var m: Dictionary = state.get("market", {})
	_generate(state, rotation_id(now_unix), int(m.get("rerolls", 0)) + 1)
	return true
