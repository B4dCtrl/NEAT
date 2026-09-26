extends RefCounted
## Thin seam for store integrations (Steamworks via GodotSteam, etc.).
## The game only talks to this file; swapping the backend never touches gameplay.
## Without a backend every call is a harmless no-op.

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
