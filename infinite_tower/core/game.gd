extends Node
## Autoload "Game": owns the state, drives the Expedition in real time, turns
## simulation events into signals for the views, autosaves and applies offline
## progress on boot. All player actions go through here.

const DataDB = preload("res://core/data_db.gd")
const GameState = preload("res://core/game_state.gd")
const Expedition = preload("res://core/expedition.gd")
const SaveSystem = preload("res://core/save_system.gd")
const StatCalc = preload("res://core/stat_calculator.gd")
const Inventory = preload("res://core/inventory.gd")
const Progression = preload("res://core/progression.gd")
const PlatformServices = preload("res://core/platform_services.gd")
const Heroes = preload("res://core/heroes.gd")
const Market = preload("res://core/market.gd")
const Forge = preload("res://core/forge.gd")
const UiNum = preload("res://scenes/ui/ui_util.gd")
const Danger = preload("res://core/danger.gd")
const Accounts = preload("res://core/accounts.gd")
const Quests = preload("res://core/quests.gd")
const Loc = preload("res://core/loc.gd")

## kind: "legendary" | "relic" | "boss" | "fall" | "level" | "milestone" | "info"
signal notified(kind: String, text: String)
signal floor_changed(floor_num: int)
signal combat_started()
signal combat_ended(victory: bool)
signal inventory_changed()
signal state_changed()
signal settings_changed()
signal offline_report_ready(report: Dictionary)
## Any loot the party picks up (item dict, or {"relic": id} / {"crystals": n}).
signal loot_dropped(drop: Dictionary)
## The party composition changed (recruit, mint, swap, bench, reset).
signal party_changed()
## Asks the root to show the story window: "intro" or "tutorial".
signal story_requested(what: String)
## Sound cue name for the audio manager (hit, crit, loot, level...).
signal sfx_requested(cue: String)
## A player logged in or out.
signal account_changed()
## The interface language changed (see core/loc.gd).
signal language_changed()

const AUTOSAVE_INTERVAL := 30.0

var state: Dictionary
var expedition: Expedition
var offline_report: Dictionary = {}
var time_scale := 1.0
var _autosave_left := AUTOSAVE_INTERVAL
var _state_changed_left := 0.25
## Combat events of the current frame, consumed by the stages for animation.
var combat_events: Array = []


func _ready() -> void:
	process_priority = -10
	# Nothing is loaded until a player logs in: a blank placeholder state keeps
	# the views happy behind the login screen.
	state = GameState.new_game()
	expedition = Expedition.new(state)
	party_changed.connect(func(): _danger_dirty = true)
	inventory_changed.connect(func(): _danger_dirty = true)
	PlatformServices.init()
	# On Steam the Steam login IS the account; otherwise "remember me" logs in
	# straight away, like a saved Steam login.
	var steam := PlatformServices.steam_user()
	if not steam.is_empty():
		sign_in_steam()
		return
	var r := Accounts.remembered()
	if not r.is_empty():
		_open_account(r["user"], r["key"])


## Logs in with the Steam account running the game (no password screen).
func sign_in_steam() -> bool:
	var steam := PlatformServices.steam_user()
	if steam.is_empty():
		return false
	var key := Accounts.external_login("steam", steam["id"], steam["name"])
	_open_account(key, Accounts.external_save_key("steam", steam["id"]))
	return true


# ------------------------------------------------------------------ accounts

## Logged-in account name ("" = on the login screen).
var account := ""
var _save_key := ""
var _save_path := ""


func logged_in() -> bool:
	return account != ""


## Returns "" on success or an error code (see Accounts.check_*).
func create_account(user: String, password: String, remember_me: bool) -> String:
	var err := Accounts.register(user, password)
	if err != "":
		return err
	return sign_in(user, password, remember_me)


func sign_in(user: String, password: String, remember_me: bool) -> String:
	if not Accounts.exists(user):
		return "no_account"
	if not Accounts.verify(user, password):
		return "wrong_password"
	var key := Accounts.save_key(user, password)
	if remember_me:
		Accounts.remember(user, key)
	else:
		Accounts.forget()
	Accounts.set_last_user(Accounts.display_name(user))
	_open_account(Accounts.normalize(user), key)
	return ""


## Loads (or starts) the account's own save, with offline progress.
func _open_account(user: String, key: String) -> void:
	account = user
	_save_key = key
	_save_path = Accounts.save_path(user)
	offline_report = {}
	state = SaveSystem.load_game(_save_path, _save_key)
	if state.is_empty():
		state = GameState.new_game()
		GameState.add_history(state, "info", "The expedition of %s begins." % Accounts.display_name(user))
	else:
		var away := SaveSystem.offline_seconds(state, int(Time.get_unix_time_from_system()))
		if away >= 60.0:
			offline_report = SaveSystem.simulate_offline(state, away)
			GameState.add_history(state, "offline", "Climbed while away: floor %d -> %d" % [offline_report["floor_start"], offline_report["floor_end"]])
	expedition = Expedition.new(state)
	_danger_dirty = true
	inventory_changed.emit()
	party_changed.emit()
	settings_changed.emit()
	state_changed.emit()
	account_changed.emit()
	save()
	if not offline_report.is_empty():
		call_deferred("emit_signal", "offline_report_ready", offline_report)


func set_language(code: String) -> void:
	if code == Loc.current():
		return
	Loc.set_language(code)
	language_changed.emit()


## Saves and returns to the login screen (also forgets "remember me").
func logout() -> void:
	if not logged_in():
		return
	save()
	Accounts.forget()
	account = ""
	_save_key = ""
	_save_path = ""
	state = GameState.new_game()
	expedition = Expedition.new(state)
	offline_report = {}
	inventory_changed.emit()
	party_changed.emit()
	state_changed.emit()
	account_changed.emit()


## Danger of the next floor and of the next Guardian (see core/danger.gd).
var danger_next := {}
var danger_boss := {}
var _danger_dirty := true
var _danger_wait := 0.0


func _update_danger(delta: float) -> void:
	_danger_wait -= delta
	if not _danger_dirty or _danger_wait > 0.0:
		return
	_danger_dirty = false
	_danger_wait = 2.0
	var f := int(state["floor"])
	danger_next = Danger.assess(state, f + 1)
	var g := Danger.next_guardian(f)
	danger_boss = danger_next if g == f + 1 else Danger.assess(state, g)


func _process(delta: float) -> void:
	if not logged_in():
		return
	_update_danger(delta)
	var dt := delta * time_scale
	# Hourglass of Haste: the climb runs faster for a while (real time).
	var boost: Dictionary = state.get("time_boost", {})
	if float(boost.get("left", 0.0)) > 0.0 and state.get("intro_seen", false):
		boost["left"] = float(boost["left"]) - delta
		dt *= float(boost.get("mult", 1.0))
		if float(boost["left"]) <= 0.0:
			state.erase("time_boost")
			notified.emit("info", Loc.t("toast.hourglass_end"))
	_check_contracts(delta)
	# The climb begins once the Stairborn has been introduced.
	if not state.get("intro_seen", false):
		return
	state["stats"]["play_time"] = float(state["stats"]["play_time"]) + dt
	expedition.advance(dt)
	if expedition.combat != null and not expedition.combat.events.is_empty():
		combat_events = expedition.combat.events.duplicate()
		expedition.combat.events.clear()
	else:
		combat_events = []
	_drain_events()

	_state_changed_left -= delta
	if _state_changed_left <= 0.0:
		_state_changed_left = 0.25
		state_changed.emit()
	_autosave_left -= delta
	if _autosave_left <= 0.0:
		save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save()


func save() -> void:
	_autosave_left = AUTOSAVE_INTERVAL
	if not logged_in():
		return
	expedition.sync_to_state()
	SaveSystem.save_game(state, _save_path, _save_key)


func _drain_events() -> void:
	if expedition.events.is_empty():
		return
	var evs := expedition.events.duplicate()
	expedition.events.clear()
	for ev in evs:
		match ev["type"]:
			"floor":
				_danger_dirty = true
				floor_changed.emit(int(ev["floor"]))
			"combat_start":
				combat_started.emit()
			"combat_end":
				_danger_dirty = true
				combat_ended.emit(ev["victory"])
			"boss":
				var tier_name: String = DataDB.enemy_scaling()["boss_tiers"][ev["tier"]]["name"]
				notified.emit("boss", "%s: %s" % [tier_name, ev["name"]])
			"fall_back":
				var lost := float(ev.get("gold_lost", 0.0))
				notified.emit("fall", "Fell back to floor %d%s" % [ev["to"], ("  (-%s gold)" % UiNum.num(lost)) if lost >= 1.0 else ""])
			"retreat":
				notified.emit("info", "Retreating to rest at the bonfire (floor %d)" % ev["to"])
			"loot":
				var item: Dictionary = ev["item"]
				inventory_changed.emit()
				loot_dropped.emit(item)
				if DataDB.rarity_order(item["rarity"]) >= DataDB.rarity_order("legendary"):
					notified.emit("legendary", item["name"])
				elif item.get("set", "") != "" and DataDB.rarity_order(item["rarity"]) >= DataDB.rarity_order("epic"):
					notified.emit("set", item["name"])
			"relic":
				inventory_changed.emit()
				loot_dropped.emit({"relic": ev["id"]})
				if ev["new"]:
					notified.emit("relic", "+1 Gem: " + DataDB.relics()[ev["id"]]["name"])
			"consumable":
				loot_dropped.emit({"consumable": ev["id"]})
				inventory_changed.emit()
			"milestone":
				PlatformServices.unlock_achievement(ev["achievement"])
				notified.emit("milestone", "%s  +%d Crystals" % [ev["name"], ev["crystals"]])
			"shrine":
				notified.emit("info", ev["name"])
			"vault":
				notified.emit("info", "Treasure Vault!")
			"bonfire":
				notified.emit("info", "Resting at the bonfire")
			"wall_broken":
				notified.emit("info", "Broke through floor %d!" % ev["floor"])
			"level_up":
				sfx_requested.emit("level")
				notified.emit("info", "%s reached a new level!" % ev["name"])


# ---------------------------------------------------------------- queries

func hero_stats(hero_idx: int) -> Dictionary:
	return StatCalc.hero_stats(state, state["heroes"][hero_idx])


func current_enemy_name() -> String:
	var info: Dictionary = expedition.floor_info
	if expedition.phase == "walk" or info.is_empty():
		return "..."
	match info["type"]:
		"shrine":
			return info["shrine"]["name"]
		"vault":
			return "Treasure Vault"
		"bonfire":
			return "Bonfire (camping)" if expedition.is_camping() else "Bonfire"
	if expedition.combat != null:
		for u in expedition.combat.enemies:
			if u.alive:
				return u.name
	if not info["enemies"].is_empty():
		return DataDB.unit_def(info["enemies"][0])["name"]
	return "..."


# ---------------------------------------------------------------- actions

func equip(hero_idx: int, uid: int) -> void:
	if Inventory.equip_uid(state, hero_idx, uid):
		inventory_changed.emit()


func unequip(hero_idx: int, slot: String) -> void:
	Inventory.unequip(state, hero_idx, slot)
	inventory_changed.emit()


func salvage(uid: int) -> void:
	Inventory.salvage(state, uid)
	inventory_changed.emit()


## Merges items of `rarity` and kind `key` ("helm/", "weapon/ranger") into one
## random item of the same kind, one rarity higher.
func merge(rarity: String, key: String) -> Dictionary:
	var item := Forge.merge(state, rarity, key)
	if item.is_empty():
		return {}
	sfx_requested.emit("legendary" if DataDB.rarity_order(item["rarity"]) >= DataDB.rarity_order("legendary") else "loot")
	notified.emit("legendary" if item["rarity"] in ["legendary", "mythic"] else "info", "Merged: %s" % item["name"])
	inventory_changed.emit()
	state_changed.emit()
	return item


## Evolves `count` items of one set into one of the next set (same rarity).
func evolve(rarity: String, set_id: String, key: String) -> Dictionary:
	var item := Forge.evolve(state, rarity, set_id, key)
	if item.is_empty():
		return {}
	sfx_requested.emit("legendary" if DataDB.rarity_order(item["rarity"]) >= DataDB.rarity_order("epic") else "loot")
	notified.emit("legendary" if DataDB.rarity_order(item["rarity"]) >= DataDB.rarity_order("legendary") else "info", "Evolved: %s" % item["name"])
	inventory_changed.emit()
	state_changed.emit()
	return item


func salvage_below(rarity: String) -> void:
	Inventory.salvage_below(state, rarity)
	inventory_changed.emit()


func equip_relic(relic_id: String) -> void:
	if Inventory.equip_relic(state, relic_id):
		inventory_changed.emit()


func unequip_relic(relic_id: String) -> void:
	Inventory.unequip_relic(state, relic_id)
	inventory_changed.emit()


func train(key: String) -> void:
	if Progression.buy_training(state, key):
		state_changed.emit()


func set_row(hero_idx: int, row: String) -> void:
	state["heroes"][hero_idx]["row"] = row
	state_changed.emit()


func buy_ascension_node(node_id: String) -> void:
	if Progression.buy_node(state, node_id):
		state_changed.emit()


func ascend() -> void:
	var souls := Progression.ascend(state)
	if souls > 0:
		expedition = Expedition.new(state)
		notified.emit("milestone", "Ascended! +%d Souls" % souls)
		inventory_changed.emit()
		party_changed.emit()
		state_changed.emit()
		save()


## Uses a consumable now. Potions/bombs act on the current fight (potions heal
## the whole party outside combat); elixirs and scrolls become floor buffs.
func use_consumable(id: String) -> bool:
	var bag: Dictionary = state["consumables"]
	var def: Dictionary = DataDB.items()["consumables"].get(id, {})
	if int(bag.get(id, 0)) <= 0 or def.is_empty():
		return false
	var in_fight: bool = expedition.phase == "combat" and expedition.combat != null
	match def["kind"]:
		"potion":
			if in_fight:
				expedition.combat.supplies["potion"] = int(expedition.combat.supplies.get("potion", 0)) + 1
				if not expedition.combat.use_potion(float(def["value"])):
					expedition.combat.supplies["potion"] -= 1
					return false
				expedition.combat.consumed.erase("potion")
			else:
				for hero in state["heroes"]:
					hero["hp_ratio"] = minf(1.0, float(hero["hp_ratio"]) + float(def["value"]))
		"mana":
			if in_fight:
				expedition.combat.supplies["mana"] = int(expedition.combat.supplies.get("mana", 0)) + 1
				if not expedition.combat.use_mana_potion(float(def["value"])):
					expedition.combat.supplies["mana"] -= 1
					return false
				expedition.combat.consumed.erase("mana")
			else:
				for hero in state["heroes"]:
					hero["mp_ratio"] = minf(1.0, float(hero.get("mp_ratio", 1.0)) + float(def["value"]))
		"bomb":
			if not in_fight:
				notified.emit("info", "Bombs can only be thrown in a fight")
				return false
			expedition.combat.supplies["bomb"] = int(expedition.combat.supplies.get("bomb", 0)) + 1
			expedition.combat.use_bomb(float(def["value"]))
			expedition.combat.consumed.erase("bomb")
		"buff":
			var buffs: Array = state["buffs"]
			for b in buffs:
				if b["id"] == id:
					b["floors_left"] = int(def["floors"])
					bag[id] = int(bag[id]) - 1
					state_changed.emit()
					return true
			buffs.append({"id": id, "name": def["name"], "stats": def["stats"], "floors_left": int(def["floors"])})
		"warp":
			var target := expedition.warp_target()
			if in_fight or target <= int(state["floor"]):
				notified.emit("info", "No higher bonfire to warp to" if not in_fight else "Wait until the fight is over")
				return false
			expedition.warp_to(target)
			notified.emit("milestone", Loc.t("toast.warp") % target)
		"time":
			var boost: Dictionary = state.get("time_boost", {})
			# Stacking an hourglass adds time, the speed stays the same.
			state["time_boost"] = {"mult": float(def["value"]), "left": float(boost.get("left", 0.0)) + float(def["seconds"])}
			notified.emit("milestone", Loc.t("toast.hourglass") % [int(def["value"]), int(float(state["time_boost"]["left"]) / 60.0)])
	bag[id] = int(bag[id]) - 1
	sfx_requested.emit("use")
	state_changed.emit()
	inventory_changed.emit()
	return true


# ------------------------------------------------------------------ contracts & daily

var _contracts_wait := 0.0
var _contracts_ready := 0


## Glows once when a contract becomes claimable (checked twice a second).
func _check_contracts(delta: float) -> void:
	_contracts_wait -= delta
	if _contracts_wait > 0.0:
		return
	_contracts_wait = 0.5
	Quests.ensure(state)
	var ready := 0
	for c in state["contracts"]:
		if Quests.is_done(state, c):
			ready += 1
	if ready > _contracts_ready:
		notified.emit("milestone", Loc.t("toast.contract_done"))
		sfx_requested.emit("fanfare")
	_contracts_ready = ready


func claim_contract(index: int) -> Dictionary:
	var got := Quests.claim(state, index)
	if not got.is_empty():
		notified.emit("milestone", Loc.t("toast.reward") % Quests.reward_text(got, state))
		sfx_requested.emit("loot")
		_contracts_ready = maxi(0, _contracts_ready - 1)
		inventory_changed.emit()
		state_changed.emit()
		save()
	return got


func daily_status() -> Dictionary:
	return Quests.daily_status(state, Quests.today_string())


func claim_daily() -> Dictionary:
	var got := Quests.claim_daily(state, Quests.today_string())
	if not got.is_empty():
		notified.emit("milestone", Loc.t("toast.daily") % [int(state["daily_streak"]), Quests.reward_text(got, state)])
		sfx_requested.emit("fanfare")
		inventory_changed.emit()
		state_changed.emit()
		save()
	return got


func mint_hero() -> void:
	var hero := Heroes.mint(state)
	if not hero.is_empty():
		GameState.add_history(state, "info", "Minted %s the %s [%s]" % [hero["name"], DataDB.classes()[hero["class"]]["name"], hero["rarity"]])
		notified.emit("milestone", "Minted %s the %s" % [hero["name"], DataDB.classes()[hero["class"]]["name"]])
		party_changed.emit()
		state_changed.emit()


func swap_hero(party_idx: int, bench_idx: int) -> void:
	if Heroes.swap(state, party_idx, bench_idx):
		party_changed.emit()


func bench_hero(party_idx: int) -> void:
	if Heroes.bench_hero(state, party_idx):
		party_changed.emit()


func learn_skill(hero_idx: int, node_id: String) -> void:
	if Heroes.learn_skill(state["heroes"][hero_idx], node_id):
		state_changed.emit()


func toggle_active_skill(hero_idx: int, skill_id: String) -> void:
	Heroes.toggle_active_skill(state["heroes"][hero_idx], skill_id)
	state_changed.emit()


func reset_skills(hero_idx: int) -> void:
	Heroes.reset_skills(state["heroes"][hero_idx])
	state_changed.emit()


func market_offers() -> Array:
	Market.ensure_stock(state, int(Time.get_unix_time_from_system()))
	return state["market"]["offers"]


func market_buy(index: int) -> void:
	var had: int = state["heroes"].size() + state["bench"].size()
	if Market.buy(state, index):
		inventory_changed.emit()
		state_changed.emit()
		if state["heroes"].size() + state["bench"].size() != had:
			party_changed.emit()


func market_reroll() -> void:
	if Market.reroll(state, int(Time.get_unix_time_from_system())):
		state_changed.emit()


## "Rest at the bonfire": walk back to the checkpoint now (or right after the
## current fight) to refill HP and mana without losing gold.
func request_retreat() -> void:
	if int(state["floor"]) <= int(state.get("checkpoint", 1)):
		notified.emit("info", "Already at the bonfire")
		return
	if expedition.phase == "combat":
		expedition.retreat_requested = true
		notified.emit("info", "The party will rest at the bonfire after this fight")
	else:
		expedition.retreat_to_bonfire()
	state_changed.emit()


func camp_at_next_bonfire(on: bool) -> void:
	state["settings"]["camp_at_bonfire"] = on
	state_changed.emit()


func leave_camp() -> void:
	expedition.leave_camp()
	state_changed.emit()


func set_setting(key: String, value) -> void:
	state["settings"][key] = value
	settings_changed.emit()


func reset_save() -> void:
	if not logged_in():
		return
	SaveSystem.delete_save(_save_path)
	state = GameState.new_game()
	GameState.add_history(state, "info", "A new expedition begins.")
	expedition = Expedition.new(state)
	inventory_changed.emit()
	party_changed.emit()
	settings_changed.emit()
	state_changed.emit()
	save()


func clear_offline_report() -> void:
	offline_report = {}
