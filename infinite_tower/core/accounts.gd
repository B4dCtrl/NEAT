extends RefCounted
## Local player accounts: a login screen like Steam's, before the game starts.
## Each account has its own save file, encrypted with a key derived from the
## password, so another person on the same computer cannot load (or edit) it.
## Passwords are never stored: only a salted, iterated SHA-256 hash.
##
## These accounts live on this computer only. Online accounts need a server;
## when the game ships on Steam, the Steam login can take this role.

const REGISTRY := "user://accounts.json"
const SAVE_DIR := "user://accounts"
const ITERATIONS := 4000
const NAME_MIN := 3
const NAME_MAX := 16
const PASSWORD_MIN := 6


static func _load() -> Dictionary:
	if not FileAccess.file_exists(REGISTRY):
		return {"users": {}, "remember": {}}
	var f := FileAccess.open(REGISTRY, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"users": {}, "remember": {}}
	if not parsed.has("users"):
		parsed["users"] = {}
	if not parsed.has("remember"):
		parsed["remember"] = {}
	return parsed


static func _store(reg: Dictionary) -> void:
	var f := FileAccess.open(REGISTRY, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(reg, "\t"))


## Account names are case-insensitive ("Ozan" and "ozan" are the same player).
static func normalize(user: String) -> String:
	return user.strip_edges().to_lower()


## "" when fine, otherwise the problem in plain words.
static func check_name(user: String) -> String:
	var n := user.strip_edges()
	if n.length() < NAME_MIN or n.length() > NAME_MAX:
		return "name_length"
	var re := RegEx.new()
	re.compile("^[A-Za-z0-9_]+$")
	if re.search(n) == null:
		return "name_chars"
	return ""


static func check_password(password: String) -> String:
	return "password_length" if password.length() < PASSWORD_MIN else ""


static func exists(user: String) -> bool:
	return _load()["users"].has(normalize(user))


static func _random_hex(bytes: int) -> String:
	var crypto := Crypto.new()
	return crypto.generate_random_bytes(bytes).hex_encode()


## Iterated, salted SHA-256 (a light PBKDF2): slow enough to make guessing
## costly, fast enough for a login screen.
static func _derive(password: String, salt: String, iterations: int = ITERATIONS) -> String:
	var data := (salt + ":" + password).to_utf8_buffer()
	for i in iterations:
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(data)
		ctx.update(salt.to_utf8_buffer())
		data = ctx.finish()
	return data.hex_encode()


## Creates the account. Returns "" on success or an error code.
static func register(user: String, password: String) -> String:
	var err := check_name(user)
	if err == "":
		err = check_password(password)
	if err != "":
		return err
	var reg := _load()
	var key := normalize(user)
	if reg["users"].has(key):
		return "name_taken"
	var salt := _random_hex(16)
	var key_salt := _random_hex(16)
	reg["users"][key] = {
		"display": user.strip_edges(),
		"salt": salt,
		"hash": _derive(password, salt),
		"key_salt": key_salt,
		"file": "%s/%s.dat" % [SAVE_DIR, _random_hex(8)],
		"created": int(Time.get_unix_time_from_system()),
	}
	_store(reg)
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	return ""


## True when the password matches.
static func verify(user: String, password: String) -> bool:
	var rec: Dictionary = _load()["users"].get(normalize(user), {})
	if rec.is_empty():
		return false
	return _derive(password, rec["salt"]) == rec["hash"]


## The key that encrypts this account's save (derived from the password,
## with its own salt, so it is not the stored hash).
static func save_key(user: String, password: String) -> String:
	var rec: Dictionary = _load()["users"].get(normalize(user), {})
	return _derive(password, rec.get("key_salt", ""), 64) if not rec.is_empty() else ""


static func save_path(user: String) -> String:
	var rec: Dictionary = _load()["users"].get(normalize(user), {})
	return rec.get("file", "")


static func display_name(user: String) -> String:
	return _load()["users"].get(normalize(user), {}).get("display", user)


static func last_user() -> String:
	return String(_load().get("last_user", ""))


static func set_last_user(user: String) -> void:
	var reg := _load()
	reg["last_user"] = user.strip_edges()
	_store(reg)


## "Remember me": keeps the save key on this computer so the next launch logs
## straight in (like Steam's saved login). Forgotten on logout.
static func remember(user: String, key: String) -> void:
	var reg := _load()
	reg["remember"] = {"user": normalize(user), "key": key}
	_store(reg)


static func forget() -> void:
	var reg := _load()
	reg["remember"] = {}
	_store(reg)


## {user, key} of the remembered login, or {}.
static func remembered() -> Dictionary:
	var r: Dictionary = _load().get("remember", {})
	if r.has("user") and r.has("key") and exists(r["user"]):
		return r
	return {}


## Deletes an account and its save (used by tests and "delete account").
static func delete_account(user: String) -> void:
	var reg := _load()
	var key := normalize(user)
	var rec: Dictionary = reg["users"].get(key, {})
	if rec.is_empty():
		return
	for suffix in ["", ".bak", ".tmp"]:
		var p: String = String(rec["file"]).get_basename() + (".dat" if suffix == "" else suffix)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	reg["users"].erase(key)
	if reg.get("remember", {}).get("user", "") == key:
		reg["remember"] = {}
	_store(reg)
