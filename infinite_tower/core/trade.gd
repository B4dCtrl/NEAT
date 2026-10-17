extends RefCounted
## TRADE RULES: what may leave the game for the Steam Community Market, and when.
##   - every cosmetic (tower skins, pets, auras): looks only, no power;
##   - Lord's Sigils (the boss key Torment players need);
##   - Legendary gear that was never equipped (equipping binds it).
## Mythic gear and gems stay bound to the account: the very top of the power
## curve cannot be bought. Trading opens after real progress (best floor and
## hours played), which keeps throwaway bot accounts out. Data: platform.json.

const DataDB = preload("res://core/data_db.gd")
const Loc = preload("res://core/loc.gd")


static func rules() -> Dictionary:
	return DataDB.platform().get("trade", {})


static func unlocked(state: Dictionary) -> bool:
	return lock_reason(state) == ""


## "" when trading is open, else what is still missing.
static func lock_reason(state: Dictionary) -> String:
	var r := rules()
	var need_floor := int(r.get("unlock_best_floor", 0))
	var need_hours := float(r.get("unlock_play_hours", 0.0))
	var hours := float(state["stats"].get("play_time", 0.0)) / 3600.0
	var miss := []
	if int(state.get("best_floor_ever", 1)) < need_floor:
		miss.append(Loc.t("reach floor %d") % need_floor)
	if hours < need_hours:
		miss.append(Loc.t("play %d hours (%s h so far)") % [int(need_hours), String.num(hours, 1)])
	return "" if miss.is_empty() else Loc.t("Trading opens when you %s.") % Loc.t(" and ").join(miss)


static func item_tradable(item: Dictionary) -> bool:
	if item.get("bound", false):
		return false
	return String(item.get("rarity", "")) in rules().get("gear_rarities", [])


static func consumable_tradable(id: String) -> bool:
	return id in rules().get("consumables", [])


static func cosmetic_tradable(_id: String) -> bool:
	return bool(rules().get("cosmetics", true))


## One line for tooltips.
static func item_note(item: Dictionary) -> String:
	if item_tradable(item):
		return Loc.t("Tradeable on Steam (while never equipped)")
	if item.get("bound", false):
		return Loc.t("Bound: it was equipped, so it can no longer be traded")
	return Loc.t("Not tradeable (only Legendary gear trades)")
