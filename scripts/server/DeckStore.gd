extends RefCounted
class_name DeckStore

const ServerPathsScript = preload("res://scripts/server/ServerPaths.gd")
const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")
const DEFAULT_DECK_NAME := "Default Deck"

var _decks_by_account_id: Dictionary = {}
var _loaded: bool = false
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

func list_decks(account_id: String) -> Array[Dictionary]:
	_ensure_loaded()
	var resolved_account_id: String = account_id.strip_edges()
	if resolved_account_id.is_empty():
		return []
	var deck_bucket = _decks_by_account_id.get(resolved_account_id, {})
	var decks: Array[Dictionary] = []
	if deck_bucket is Dictionary:
		for raw_deck in (deck_bucket as Dictionary).values():
			if raw_deck is Dictionary:
				decks.append((raw_deck as Dictionary).duplicate(true))
	decks.sort_custom(_sort_decks)
	return decks

func save_deck(account_id: String, deck_name: String, cards: Dictionary, deck_id: String = "") -> Dictionary:
	_ensure_loaded()
	var resolved_account_id: String = account_id.strip_edges()
	if resolved_account_id.is_empty():
		return {"success": false, "message": "Missing account id.", "deck": {}}
	var sanitized_cards: Dictionary = _sanitize_cards(cards)
	if sanitized_cards.is_empty():
		return {"success": false, "message": "Deck did not contain any valid cards.", "deck": {}}

	var deck_bucket: Dictionary = _get_deck_bucket(resolved_account_id)
	var resolved_deck_id: String = deck_id.strip_edges()
	if resolved_deck_id.is_empty() or not deck_bucket.has(resolved_deck_id):
		resolved_deck_id = _generate_id("deck_", 12)

	var clean_name: String = deck_name.strip_edges()
	if clean_name.is_empty():
		clean_name = DEFAULT_DECK_NAME

	var now_unix := int(Time.get_unix_time_from_system())
	var deck_entry: Dictionary = deck_bucket.get(resolved_deck_id, {
		"deck_id": resolved_deck_id,
		"created_unix": now_unix,
	})
	deck_entry["deck_id"] = resolved_deck_id
	deck_entry["name"] = clean_name
	deck_entry["cards"] = sanitized_cards
	if not deck_entry.has("created_unix"):
		deck_entry["created_unix"] = now_unix
	deck_entry["updated_unix"] = now_unix
	deck_bucket[resolved_deck_id] = deck_entry
	_decks_by_account_id[resolved_account_id] = deck_bucket
	_save()
	return {"success": true, "message": "", "deck": deck_entry.duplicate(true)}

func delete_deck(account_id: String, deck_id: String) -> Dictionary:
	_ensure_loaded()
	var resolved_account_id: String = account_id.strip_edges()
	var resolved_deck_id: String = deck_id.strip_edges()
	if resolved_account_id.is_empty() or resolved_deck_id.is_empty():
		return {"success": false, "message": "Missing account deck id.", "deck_id": resolved_deck_id}
	var deck_bucket: Dictionary = _get_deck_bucket(resolved_account_id)
	if not deck_bucket.has(resolved_deck_id):
		return {"success": false, "message": "That saved deck was not found.", "deck_id": resolved_deck_id}
	deck_bucket.erase(resolved_deck_id)
	_decks_by_account_id[resolved_account_id] = deck_bucket
	_save()
	return {"success": true, "message": "", "deck_id": resolved_deck_id}

func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_decks_by_account_id = {}
	var storage_path: String = _get_storage_path()
	if not FileAccess.file_exists(storage_path):
		return
	var file := FileAccess.open(storage_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return
	var root := parsed as Dictionary
	var stored_decks = root.get("decks_by_account_id", {})
	if stored_decks is Dictionary:
		_decks_by_account_id = (stored_decks as Dictionary).duplicate(true)

func _save() -> void:
	var storage_path: String = _get_storage_path()
	var parent_dir := storage_path.get_base_dir()
	if not parent_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(parent_dir)
	var file := FileAccess.open(storage_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"decks_by_account_id": _decks_by_account_id,
	}, "\t"))
	file.flush()
	file.close()

func _sanitize_cards(cards: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	for raw_card_name in cards.keys():
		var requested_name: String = str(raw_card_name).strip_edges()
		var count := int(cards[raw_card_name])
		if requested_name.is_empty() or count <= 0:
			continue
		var template = CardCatalogScript.instantiate_card_by_name(requested_name)
		if template == null:
			continue
		sanitized[str(template.card_name)] = count
	return sanitized

func _get_deck_bucket(account_id: String) -> Dictionary:
	var deck_bucket = _decks_by_account_id.get(account_id, {})
	if deck_bucket is Dictionary:
		return (deck_bucket as Dictionary).duplicate(true)
	return {}

func _get_storage_path() -> String:
	return ServerPathsScript.get_server_data_file_path("account_decks.json")

func _generate_id(prefix: String, length: int) -> String:
	const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var output := prefix
	for _i in length:
		output += CHARS[_rng.randi_range(0, CHARS.length() - 1)]
	return output

func _sort_decks(a: Dictionary, b: Dictionary) -> bool:
	var a_updated := int(a.get("updated_unix", 0))
	var b_updated := int(b.get("updated_unix", 0))
	if a_updated != b_updated:
		return a_updated > b_updated
	return str(a.get("name", "")).to_lower() < str(b.get("name", "")).to_lower()
