extends RefCounted
class_name FriendStore

const ServerPathsScript = preload("res://scripts/server/ServerPaths.gd")
const JsonStoreScript = preload("res://scripts/server/JsonStore.gd")
const DeckStoreScript = preload("res://scripts/server/DeckStore.gd")
const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")
const TiamatScript = preload("res://scripts/cards/Gods/TiamatThePrimordial.gd")

const FRIEND_REQUEST_COOLDOWN_SECONDS := 10 * 60
const DECK_SHARE_COOLDOWN_SECONDS := 5
const MAX_PENDING_FRIEND_REQUESTS_FROM_ACCOUNT := 8
const MAX_PENDING_DECK_SHARES_FROM_ACCOUNT_TO_RECIPIENT := 3

var _friends_by_account_id: Dictionary = {}
var _friend_requests_by_id: Dictionary = {}
var _deck_shares_by_id: Dictionary = {}
var _loaded: bool = false
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

func get_state(account_id: String, username_by_account_id: Dictionary = {}) -> Dictionary:
	_ensure_loaded()
	var resolved_account_id := account_id.strip_edges()
	if resolved_account_id.is_empty():
		return _empty_state()
	var friends: Array[Dictionary] = []
	for raw_friend_id in _get_friend_lookup(resolved_account_id).keys():
		var friend_id := str(raw_friend_id).strip_edges()
		if friend_id.is_empty():
			continue
		friends.append({
			"account_id": friend_id,
			"username": _get_username(friend_id, username_by_account_id),
		})
	friends.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("username", "")).to_lower() < str(b.get("username", "")).to_lower()
	)

	var incoming_requests: Array[Dictionary] = []
	var outgoing_requests: Array[Dictionary] = []
	for raw_request in _friend_requests_by_id.values():
		if not (raw_request is Dictionary):
			continue
		var request := (raw_request as Dictionary).duplicate(true)
		if str(request.get("status", "pending")) != "pending":
			continue
		var requester_id := str(request.get("requester_account_id", "")).strip_edges()
		var recipient_id := str(request.get("recipient_account_id", "")).strip_edges()
		request["requester_username"] = _get_username(requester_id, username_by_account_id)
		request["recipient_username"] = _get_username(recipient_id, username_by_account_id)
		if recipient_id == resolved_account_id:
			incoming_requests.append(request)
		elif requester_id == resolved_account_id:
			outgoing_requests.append(request)

	var incoming_deck_shares: Array[Dictionary] = []
	var outgoing_deck_shares: Array[Dictionary] = []
	for raw_share in _deck_shares_by_id.values():
		if not (raw_share is Dictionary):
			continue
		var share := (raw_share as Dictionary).duplicate(true)
		if str(share.get("status", "pending")) != "pending":
			continue
		var sender_id := str(share.get("sender_account_id", "")).strip_edges()
		var recipient_id := str(share.get("recipient_account_id", "")).strip_edges()
		share["sender_username"] = _get_username(sender_id, username_by_account_id)
		share["recipient_username"] = _get_username(recipient_id, username_by_account_id)
		if recipient_id == resolved_account_id:
			incoming_deck_shares.append(share)
		elif sender_id == resolved_account_id:
			outgoing_deck_shares.append(share)
	return {
		"friends": friends,
		"incoming_requests": _sort_newest_first(incoming_requests),
		"outgoing_requests": _sort_newest_first(outgoing_requests),
		"incoming_deck_shares": _sort_newest_first(incoming_deck_shares),
		"outgoing_deck_shares": _sort_newest_first(outgoing_deck_shares),
	}

func send_friend_request(
	requester_account_id: String,
	recipient_account_id: String
) -> Dictionary:
	_ensure_loaded()
	var requester_id := requester_account_id.strip_edges()
	var recipient_id := recipient_account_id.strip_edges()
	if requester_id.is_empty() or recipient_id.is_empty():
		return _result(false, "Missing account id.")
	if requester_id == recipient_id:
		return _result(false, "You cannot add yourself.")
	if are_friends(requester_id, recipient_id):
		return _result(false, "You are already friends.")
	if _has_pending_friend_request_between(requester_id, recipient_id):
		return _result(false, "There is already a pending friend request.")
	if _count_pending_friend_requests_from(requester_id) >= MAX_PENDING_FRIEND_REQUESTS_FROM_ACCOUNT:
		return _result(false, "You already have too many pending friend requests.")
	if not _friend_request_cooldown_has_elapsed(requester_id, recipient_id):
		return _result(false, "Wait a few minutes before sending another friend request to that user.")

	var now_unix := int(Time.get_unix_time_from_system())
	var request_id := _generate_id("friend_request_", 12)
	while _friend_requests_by_id.has(request_id):
		request_id = _generate_id("friend_request_", 12)
	var request := {
		"request_id": request_id,
		"requester_account_id": requester_id,
		"recipient_account_id": recipient_id,
		"status": "pending",
		"created_unix": now_unix,
		"updated_unix": now_unix,
	}
	_friend_requests_by_id[request_id] = request
	if not _save():
		_friend_requests_by_id.erase(request_id)
		return _result(false, "Could not save friend request storage.")
	return _result(true, "", request)

func respond_to_friend_request(account_id: String, request_id: String, accept: bool) -> Dictionary:
	_ensure_loaded()
	var resolved_account_id := account_id.strip_edges()
	var resolved_request_id := request_id.strip_edges()
	if resolved_account_id.is_empty() or resolved_request_id.is_empty():
		return _result(false, "Missing friend request.")
	if not _friend_requests_by_id.has(resolved_request_id):
		return _result(false, "That friend request was not found.")
	var request: Dictionary = (_friend_requests_by_id[resolved_request_id] as Dictionary).duplicate(true)
	if str(request.get("status", "pending")) != "pending":
		return _result(false, "That friend request is no longer pending.")
	if str(request.get("recipient_account_id", "")).strip_edges() != resolved_account_id:
		return _result(false, "Only the recipient can respond to this request.")
	var previous_requests_by_id := _friend_requests_by_id.duplicate(true)
	var previous_friends_by_account_id := _friends_by_account_id.duplicate(true)
	request["status"] = "accepted" if accept else "rejected"
	request["updated_unix"] = int(Time.get_unix_time_from_system())
	_friend_requests_by_id[resolved_request_id] = request
	if accept:
		_add_friend_pair(
			str(request.get("requester_account_id", "")).strip_edges(),
			str(request.get("recipient_account_id", "")).strip_edges()
		)
	if not _save():
		_friend_requests_by_id = previous_requests_by_id
		_friends_by_account_id = previous_friends_by_account_id
		return _result(false, "Could not save friend request response.")
	return _result(true, "", request)

func send_deck_share(
	sender_account_id: String,
	recipient_account_id: String,
	deck_name: String,
	cards,
	special_setup = {}
) -> Dictionary:
	_ensure_loaded()
	var sender_id := sender_account_id.strip_edges()
	var recipient_id := recipient_account_id.strip_edges()
	if sender_id.is_empty() or recipient_id.is_empty():
		return _result(false, "Missing account id.")
	if sender_id == recipient_id:
		return _result(false, "Choose a friend instead of yourself.")
	if not are_friends(sender_id, recipient_id):
		return _result(false, "You can only send decks to friends.")
	if _count_pending_deck_shares(sender_id, recipient_id) >= MAX_PENDING_DECK_SHARES_FROM_ACCOUNT_TO_RECIPIENT:
		return _result(false, "That friend already has several pending decks from you.")
	if not _deck_share_cooldown_has_elapsed(sender_id, recipient_id):
		return _result(false, "Wait a few minutes before sending another deck to that friend.")
	var sanitized_cards := _sanitize_cards(cards)
	if sanitized_cards.is_empty():
		return _result(false, "Deck did not contain any valid cards.")
	var clean_name := deck_name.strip_edges()
	if clean_name.is_empty():
		clean_name = DeckStoreScript.DEFAULT_DECK_NAME
	var now_unix := int(Time.get_unix_time_from_system())
	var share_id := _generate_id("deck_share_", 12)
	while _deck_shares_by_id.has(share_id):
		share_id = _generate_id("deck_share_", 12)
	var share := {
		"share_id": share_id,
		"sender_account_id": sender_id,
		"recipient_account_id": recipient_id,
		"status": "pending",
		"deck": {
			"name": clean_name,
			"cards": sanitized_cards,
			"special_setup": _sanitize_special_setup(special_setup),
		},
		"created_unix": now_unix,
		"updated_unix": now_unix,
	}
	_deck_shares_by_id[share_id] = share
	if not _save():
		_deck_shares_by_id.erase(share_id)
		return _result(false, "Could not save deck share storage.")
	return _result(true, "", share)

func respond_to_deck_share(
	account_id: String,
	share_id: String,
	accept: bool,
	deck_store
) -> Dictionary:
	_ensure_loaded()
	var resolved_account_id := account_id.strip_edges()
	var resolved_share_id := share_id.strip_edges()
	if resolved_account_id.is_empty() or resolved_share_id.is_empty():
		return _result(false, "Missing deck share.")
	if not _deck_shares_by_id.has(resolved_share_id):
		return _result(false, "That deck share was not found.")
	var share: Dictionary = (_deck_shares_by_id[resolved_share_id] as Dictionary).duplicate(true)
	if str(share.get("status", "pending")) != "pending":
		return _result(false, "That deck share is no longer pending.")
	if str(share.get("recipient_account_id", "")).strip_edges() != resolved_account_id:
		return _result(false, "Only the recipient can respond to this deck.")
	var saved_deck: Dictionary = {}
	var previous_deck_shares_by_id := _deck_shares_by_id.duplicate(true)
	if accept:
		if deck_store == null:
			return _result(false, "Deck storage is unavailable.")
		var deck = share.get("deck", {})
		if not (deck is Dictionary):
			return _result(false, "That deck share is missing its deck.")
		var save_result: Dictionary = deck_store.save_deck(
			resolved_account_id,
			str((deck as Dictionary).get("name", DeckStoreScript.DEFAULT_DECK_NAME)),
			(deck as Dictionary).get("cards", {}),
			"",
			(deck as Dictionary).get("special_setup", {})
		)
		if not bool(save_result.get("success", false)):
			return save_result
		saved_deck = save_result.get("deck", {})
	share["status"] = "accepted" if accept else "rejected"
	share["updated_unix"] = int(Time.get_unix_time_from_system())
	_deck_shares_by_id[resolved_share_id] = share
	if not _save():
		_deck_shares_by_id = previous_deck_shares_by_id
		if accept and deck_store != null and deck_store.has_method("delete_deck"):
			var saved_deck_id := str(saved_deck.get("deck_id", "")).strip_edges()
			if not saved_deck_id.is_empty():
				deck_store.delete_deck(resolved_account_id, saved_deck_id)
		return _result(false, "Could not save deck share response.")
	return {
		"success": true,
		"message": "",
		"entry": share.duplicate(true),
		"deck": saved_deck.duplicate(true),
	}

func are_friends(first_account_id: String, second_account_id: String) -> bool:
	_ensure_loaded()
	var first_id := first_account_id.strip_edges()
	var second_id := second_account_id.strip_edges()
	if first_id.is_empty() or second_id.is_empty():
		return false
	return bool(_get_friend_lookup(first_id).get(second_id, false))

func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_friends_by_account_id = {}
	_friend_requests_by_id = {}
	_deck_shares_by_id = {}
	var storage_path := _get_storage_path()
	if not FileAccess.file_exists(storage_path):
		return
	var root := JsonStoreScript.load_dictionary(storage_path, {}, "FriendStore")
	if root.is_empty():
		return
	var friends = root.get("friends_by_account_id", {})
	if friends is Dictionary:
		_friends_by_account_id = (friends as Dictionary).duplicate(true)
	var requests = root.get("friend_requests_by_id", {})
	if requests is Dictionary:
		_friend_requests_by_id = (requests as Dictionary).duplicate(true)
	var shares = root.get("deck_shares_by_id", {})
	if shares is Dictionary:
		_deck_shares_by_id = (shares as Dictionary).duplicate(true)

func _save() -> bool:
	var storage_path := _get_storage_path()
	return JsonStoreScript.save_json(storage_path, {
		"friends_by_account_id": _friends_by_account_id,
		"friend_requests_by_id": _friend_requests_by_id,
		"deck_shares_by_id": _deck_shares_by_id,
	}, "FriendStore")

func _empty_state() -> Dictionary:
	return {
		"friends": [],
		"incoming_requests": [],
		"outgoing_requests": [],
		"incoming_deck_shares": [],
		"outgoing_deck_shares": [],
	}

func _result(success: bool, message: String, entry: Dictionary = {}) -> Dictionary:
	return {
		"success": success,
		"message": message,
		"entry": entry.duplicate(true),
	}

func _get_friend_lookup(account_id: String) -> Dictionary:
	var friends = _friends_by_account_id.get(account_id.strip_edges(), {})
	if friends is Dictionary:
		return (friends as Dictionary).duplicate(true)
	return {}

func _add_friend_pair(first_account_id: String, second_account_id: String) -> void:
	var first_id := first_account_id.strip_edges()
	var second_id := second_account_id.strip_edges()
	if first_id.is_empty() or second_id.is_empty():
		return
	var first_friends := _get_friend_lookup(first_id)
	var second_friends := _get_friend_lookup(second_id)
	first_friends[second_id] = true
	second_friends[first_id] = true
	_friends_by_account_id[first_id] = first_friends
	_friends_by_account_id[second_id] = second_friends

func _has_pending_friend_request_between(first_account_id: String, second_account_id: String) -> bool:
	for raw_request in _friend_requests_by_id.values():
		if not (raw_request is Dictionary):
			continue
		var request := raw_request as Dictionary
		if str(request.get("status", "pending")) != "pending":
			continue
		var requester_id := str(request.get("requester_account_id", "")).strip_edges()
		var recipient_id := str(request.get("recipient_account_id", "")).strip_edges()
		if requester_id == first_account_id and recipient_id == second_account_id:
			return true
		if requester_id == second_account_id and recipient_id == first_account_id:
			return true
	return false

func _friend_request_cooldown_has_elapsed(requester_account_id: String, recipient_account_id: String) -> bool:
	var now_unix := int(Time.get_unix_time_from_system())
	for raw_request in _friend_requests_by_id.values():
		if not (raw_request is Dictionary):
			continue
		var request := raw_request as Dictionary
		if str(request.get("requester_account_id", "")).strip_edges() != requester_account_id:
			continue
		if str(request.get("recipient_account_id", "")).strip_edges() != recipient_account_id:
			continue
		var updated_unix := int(request.get("updated_unix", request.get("created_unix", 0)))
		if now_unix - updated_unix < FRIEND_REQUEST_COOLDOWN_SECONDS:
			return false
	return true

func _deck_share_cooldown_has_elapsed(sender_account_id: String, recipient_account_id: String) -> bool:
	var now_unix := int(Time.get_unix_time_from_system())
	for raw_share in _deck_shares_by_id.values():
		if not (raw_share is Dictionary):
			continue
		var share := raw_share as Dictionary
		if str(share.get("sender_account_id", "")).strip_edges() != sender_account_id:
			continue
		if str(share.get("recipient_account_id", "")).strip_edges() != recipient_account_id:
			continue
		var updated_unix := int(share.get("updated_unix", share.get("created_unix", 0)))
		if now_unix - updated_unix < DECK_SHARE_COOLDOWN_SECONDS:
			return false
	return true

func _count_pending_friend_requests_from(account_id: String) -> int:
	var count := 0
	for raw_request in _friend_requests_by_id.values():
		if not (raw_request is Dictionary):
			continue
		var request := raw_request as Dictionary
		if str(request.get("status", "pending")) == "pending" \
				and str(request.get("requester_account_id", "")).strip_edges() == account_id:
			count += 1
	return count

func _count_pending_deck_shares(sender_account_id: String, recipient_account_id: String) -> int:
	var count := 0
	for raw_share in _deck_shares_by_id.values():
		if not (raw_share is Dictionary):
			continue
		var share := raw_share as Dictionary
		if str(share.get("status", "pending")) == "pending" \
				and str(share.get("sender_account_id", "")).strip_edges() == sender_account_id \
				and str(share.get("recipient_account_id", "")).strip_edges() == recipient_account_id:
			count += 1
	return count

func _sanitize_cards(cards) -> Dictionary:
	var sanitized: Dictionary = {}
	if not (cards is Dictionary):
		return sanitized
	for raw_card_name in (cards as Dictionary).keys():
		var requested_name := str(raw_card_name).strip_edges()
		var count := int((cards as Dictionary)[raw_card_name])
		if requested_name.is_empty() or count <= 0:
			continue
		var template = CardCatalogScript.instantiate_card_by_name(requested_name)
		if template == null:
			continue
		sanitized[str(template.card_name)] = count
	return sanitized

func _sanitize_special_setup(special_setup) -> Dictionary:
	if not (special_setup is Dictionary) or (special_setup as Dictionary).is_empty():
		return {}
	return TiamatScript.build_special_setup(
		TiamatScript.get_slot_card_names_from_setup(special_setup as Dictionary)
	)

func _get_username(account_id: String, username_by_account_id: Dictionary) -> String:
	var username := str(username_by_account_id.get(account_id, "")).strip_edges()
	if username.is_empty():
		username = account_id
	return username

func _sort_newest_first(entries: Array[Dictionary]) -> Array[Dictionary]:
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("created_unix", 0)) > int(b.get("created_unix", 0))
	)
	return entries

func _generate_id(prefix: String, length: int) -> String:
	const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var output := prefix
	for _i in range(length):
		output += CHARS[_rng.randi_range(0, CHARS.length() - 1)]
	return output

func _get_storage_path() -> String:
	return ServerPathsScript.get_server_data_file_path("friends.json")
