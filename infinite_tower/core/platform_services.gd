extends RefCounted
## Thin seam for store integrations (Steamworks via GodotSteam, etc.).
## The game only talks to this file; swapping the backend never touches gameplay.
## Without a backend every call is a harmless no-op.

const DataDB = preload("res://core/data_db.gd")
const Loc = preload("res://core/loc.gd")

static var _steam = null


static func init() -> void:
	# GodotSteam registers a "Steam" singleton when its GDExtension is installed.
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")
		var result = _steam.call("steamInitEx", false)
		print("PlatformServices: Steam init -> ", result)


static func unlock_achievement(api_name: String) -> void:
	if _steam != null:
		_steam.call("setAchievement", api_name)
		_steam.call("storeStats")
	else:
		print("PlatformServices: achievement unlocked (no backend): ", api_name)


static func is_available() -> bool:
	return _steam != null


## Set by tests to pretend a Steam user is logged in.
static var _fake_user := {}


## The Steam account running the game: {id, name}, or {} outside Steam.
## On Steam this replaces the local login screen: the Steam login is the identity.
static func steam_user() -> Dictionary:
	if not _fake_user.is_empty():
		return _fake_user
	if _steam == null:
		return {}
	var id := str(_steam.call("getSteamID"))
	if id == "" or id == "0":
		return {}
	return {"id": id, "name": str(_steam.call("getPersonaName"))}


# ------------------------------------------------------------------ Steam Inventory / Market
# Items flagged as tradable (Legendary+ gear, relics) are mirrored as Steam
# Inventory item definitions (see tools/export_steam_itemdefs.gd), which is what
# lets them appear on the Steam Community Market once the app is live.

static func app_id() -> int:
	return int(DataDB.platform().get("steam_app_id", 0))


static func market_url() -> String:
	if app_id() <= 0:
		return "https://steamcommunity.com/market/"
	return String(DataDB.platform()["steam_market_url"]) % app_id()


## Opens the Steam Community Market in the Steam overlay (or the browser).
static func open_market() -> void:
	if _steam != null:
		_steam.call("activateGameOverlayToWebPage", market_url())
	else:
		OS.shell_open(market_url())


## Asks Steam for the player's inventory (async; GodotSteam emits inventory_result_ready).
static func request_inventory() -> bool:
	if _steam == null:
		return false
	return bool(_steam.call("getAllItems"))


## Playtime drop: Steam decides whether the player earned an item for time played.
static func trigger_playtime_drop() -> bool:
	if _steam == null:
		return false
	var itemdef := int(DataDB.platform()["steam_inventory"]["playtime_drop_itemdef"])
	return bool(_steam.call("triggerItemDrop", itemdef))


static func status_text() -> String:
	if _steam != null:
		return Loc.t("Steam connected (app %d)") % app_id()
	if app_id() <= 0:
		return Loc.t("Steam not configured: set steam_app_id in data/platform.json and install GodotSteam")
	return Loc.t("Steam not running: start Steam to trade on the Community Market")
