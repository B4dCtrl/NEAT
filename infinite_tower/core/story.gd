extends RefCounted
## Manga chapters (data/story.json): which ones are unlocked and which are new.
## Chapter 1 is there from the start; the others unlock by reaching a floor for
## the first time or a Torment tier, so the story is told as you climb.

const DataDB = preload("res://core/data_db.gd")
const Torment = preload("res://core/torment.gd")


static func chapters() -> Array:
	return DataDB.table("story")["chapters"]


static func chapter(id: String) -> Dictionary:
	for c in chapters():
		if c["id"] == id:
			return c
	return {}


static func box(state: Dictionary) -> Dictionary:
	if not state.has("manga") or typeof(state["manga"]) != TYPE_DICTIONARY:
		state["manga"] = {}
	var m: Dictionary = state["manga"]
	if not m.has("unlocked"):
		m["unlocked"] = ["c1"]
	if not m.has("read"):
		m["read"] = []
	return m


static func is_unlocked(state: Dictionary, id: String) -> bool:
	return id in box(state)["unlocked"]


static func is_new(state: Dictionary, id: String) -> bool:
	return is_unlocked(state, id) and not id in box(state)["read"]


static func mark_read(state: Dictionary, id: String) -> void:
	var m := box(state)
	if not id in m["read"]:
		m["read"].append(id)


## Checks every locked chapter; returns the ids unlocked just now.
static func check_unlocks(state: Dictionary) -> Array:
	var m := box(state)
	var out := []
	for c in chapters():
		if c["id"] in m["unlocked"]:
			continue
		var u: Dictionary = c["unlock"]
		var ok := false
		match String(u["type"]):
			"start":
				ok = true
			"floor":
				ok = int(state.get("best_floor_ever", 1)) >= int(u["value"])
			"torment":
				ok = Torment.unlocked(state) >= int(u["value"])
		if ok:
			m["unlocked"].append(c["id"])
			out.append(c["id"])
	return out
