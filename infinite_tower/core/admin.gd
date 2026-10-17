extends RefCounted
## TEST MODE (the "Stairborn (test mode)" shortcut runs the game with --admin).
##
## For trying things quickly: a panel with time speed, jump to any floor,
## resources, levels, gear, caches, story and Torment. Safety rails:
##   - the test mode has its own accounts and saves (user://test/), so it can
##     never touch a real save, and a normal launch never shows these tools;
##   - every save opened here is marked "test_save": it cannot trade items
##     (core/trade.gd), so nothing made with these tools reaches a market.

const DataDB = preload("res://core/data_db.gd")
const Accounts = preload("res://core/accounts.gd")
const Loot = preload("res://core/loot_calculator.gd")
const Heroes = preload("res://core/heroes.gd")
const Story = preload("res://core/story.gd")
const Cosmetics = preload("res://core/cosmetics.gd")
const TowerGen = preload("res://core/tower_generator.gd")
const Torment = preload("res://core/torment.gd")
const Loc = preload("res://core/loc.gd")

const USER := "teste"
const PASS := "teste-admin"

static var _on := -1


static func enabled() -> bool:
	if _on < 0:
		var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
		_on = 1 if ("--admin" in args or OS.get_environment("STAIRBORN_ADMIN") == "1") else 0
	return _on == 1


## Called first thing at startup: points the accounts at the test folder.
static func prepare() -> void:
	if enabled():
		Accounts.use_test_dir()


## Signs the shared test account in (creating it the first time).
static func auto_login(game) -> void:
	if not Accounts.exists(USER):
		Accounts.register(USER, PASS)
	game.sign_in(USER, PASS, true)


static func _say(game, text: String) -> void:
	game.notified.emit("info", text)


# ------------------------------------------------------------------ time and floors

static func set_speed(game, factor: float) -> void:
	game.time_scale = factor
	_say(game, Loc.t("Speed x%d") % int(factor))


## Moves the party to `floor_num` (rested), counting it as reached.
static func go_to_floor(game, floor_num: int) -> void:
	var s: Dictionary = game.state
	floor_num = maxi(2, floor_num)
	s["max_floor"] = maxi(int(s["max_floor"]), floor_num)
	s["best_floor_ever"] = maxi(int(s["best_floor_ever"]), floor_num)
	game.expedition.warp_to(floor_num - 1)
	s["checkpoint"] = maxi(1, TowerGen.bonfire_below(floor_num))
	Torment.record_best(s)
	Torment.check_unlock(s)
	game.state_changed.emit()
	_say(game, Loc.t("Going to floor %d") % floor_num)


## The next guardian floor (every 10th) above the current one.
static func next_guardian(game) -> void:
	var f := int(game.state["floor"])
	go_to_floor(game, (f / 10 + 1) * 10)


static func heal(game) -> void:
	game.expedition.restore_party()
	game.party_changed.emit()
	_say(game, Loc.t("Party healed"))


# ------------------------------------------------------------------ resources and heroes

static func add_resource(game, kind: String, amount: float) -> void:
	var s: Dictionary = game.state
	s[kind] = float(s[kind]) + amount if kind in ["gold", "souls"] else int(s[kind]) + int(amount)
	game.state_changed.emit()
	_say(game, "+%s %s" % [String.num(amount, 0), Loc.t(kind.capitalize())])


static func level_heroes(game, plus: int, exact: int = 0) -> void:
	for h in game.state["heroes"]:
		h["level"] = exact if exact > 0 else mini(int(h["level"]) + plus, 300)
	game.party_changed.emit()
	game.state_changed.emit()
	_say(game, Loc.t("Heroes leveled up"))


static func free_hero(game) -> void:
	var s: Dictionary = game.state
	s["best_floor_ever"] = maxi(int(s["best_floor_ever"]), Heroes.mint_floor_required(s))
	s["gold"] = float(s["gold"]) + Heroes.mint_cost(s)
	game.mint_hero()


# ------------------------------------------------------------------ gear and items

static func give_items(game, rarity: String, count: int) -> void:
	var s: Dictionary = game.state
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var floor_num := maxi(int(s["best_floor_ever"]), 10)
	var cap := int(DataDB.balance()["inventory_cap"])
	var n := 0
	while n < count and s["inventory"].size() < cap:
		s["inventory"].append(Loot.generate_item(rng, s, floor_num, rarity))
		n += 1
	game.inventory_changed.emit()
	_say(game, Loc.t("%d items added to the bag") % n)


static func fill_bag(game) -> void:
	var s: Dictionary = game.state
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var floor_num := maxi(int(s["best_floor_ever"]), 10)
	var cap := int(DataDB.balance()["inventory_cap"])
	var rarities := ["common", "uncommon", "rare", "epic", "legendary"]
	var i := 0
	while s["inventory"].size() < mini(cap, 40):
		s["inventory"].append(Loot.generate_item(rng, s, floor_num + (i * 3) % 25, rarities[i % rarities.size()]))
		i += 1
	game.inventory_changed.emit()
	_say(game, Loc.t("Bag filled"))


static func give_supplies(game, plus: int) -> void:
	for id in DataDB.items()["consumables"]:
		game.state["consumables"][id] = int(game.state["consumables"].get(id, 0)) + plus
	game.inventory_changed.emit()
	_say(game, Loc.t("Supplies added"))


# ------------------------------------------------------------------ collection and story

static func add_caches(game, n: int) -> void:
	var c := Cosmetics.box(game.state)
	c["caches"] = int(c["caches"]) + n
	game.cosmetics_changed.emit()
	_say(game, Loc.t("+%d caches") % n)


static func add_dust(game, n: int) -> void:
	var c := Cosmetics.box(game.state)
	c["dust"] = int(c["dust"]) + n
	game.cosmetics_changed.emit()
	_say(game, Loc.t("+%d stardust") % n)


static func call_imp(game) -> void:
	game.imp_left = 12.0


static func unlock_manga(game) -> void:
	var box := Story.box(game.state)
	for c in Story.chapters():
		if not c["id"] in box["unlocked"]:
			box["unlocked"].append(c["id"])
	_say(game, Loc.t("All manga chapters unlocked"))


static func set_torment(game, level: int) -> void:
	game.state["torment_unlocked"] = clampi(level, 0, Torment.max_level())
	game.state_changed.emit()
	_say(game, Loc.t("Torment unlocked up to %d") % level)


# ------------------------------------------------------------------ save

static func skip_intro(game) -> void:
	game.state["intro_seen"] = true
	game.state["tutorial_seen"] = true
	game.state["named"] = true
	game.save()
	_say(game, Loc.t("Intro and tutorial skipped"))
