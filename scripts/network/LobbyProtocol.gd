extends RefCounted
class_name LobbyProtocol

const PORT: int = 22345
# Plain WebSocket backend, reached through a TLS reverse proxy on public 443.
const WS_PORT: int = 24443
const MATCH_PORT: int = 12345
const PASSWORD_RESET_CODE_LENGTH := 6
const LADDER_PAGE_SIZE := 50

const LOGIN_GUEST := "login_guest"
const LOGIN_ACCOUNT := "login_account"
const REGISTER_ACCOUNT := "register_account"
const CLAIM_LEGACY_ACCOUNT := "claim_legacy_account"
const UPDATE_ACCOUNT_SETTINGS := "update_account_settings"
const REQUEST_PASSWORD_RESET := "request_password_reset"
const RESET_PASSWORD := "reset_password"
const CREATE_ROOM := "create_room"
const LIST_ROOMS := "list_rooms"
const JOIN_ROOM := "join_room"
const REJOIN_ROOM := "rejoin_room"
const OBSERVE_ROOM := "observe_room"
const REQUEST_NEXT := "request_next"
const LEAVE_ROOM := "leave_room"
const SET_READY := "set_ready"
const SELECT_DECK := "select_deck"
const REQUEST_ACCOUNT_DECKS := "request_account_decks"
const SAVE_ACCOUNT_DECK := "save_account_deck"
const DELETE_ACCOUNT_DECK := "delete_account_deck"
const SET_ACCOUNT_PREFERRED_DECK := "set_account_preferred_deck"
const SET_OBSERVER_FRIEND_CARD_VISIBILITY := "set_observer_friend_card_visibility"
const REQUEST_PROFILE_SUMMARY := "request_profile_summary"
const SET_RANK_BADGE := "set_rank_badge"
const REQUEST_BOT_LADDER := "request_bot_ladder"
const REQUEST_BOT_DECK := "request_bot_deck"
const REQUEST_BOT_MATCH_HISTORY := "request_bot_match_history"
const REQUEST_BOT_WORK := "request_bot_work"
const REPORT_BOT_WORK_STARTED := "report_bot_work_started"
const CANCEL_BOT_WORK := "cancel_bot_work"
const SUBMIT_BOT_WORK_RESULT := "submit_bot_work_result"
const REQUEST_FRIENDS := "request_friends"
const SEND_FRIEND_REQUEST := "send_friend_request"
const RESPOND_FRIEND_REQUEST := "respond_friend_request"
const SEND_DECK_TO_FRIEND := "send_deck_to_friend"
const RESPOND_DECK_SHARE := "respond_deck_share"
const REQUEST_RECONNECT_LOBBY := "request_reconnect_lobby"
const REPORT_HOST_VIABILITY := "report_host_viability"
const SUBMIT_ISSUE_REPORT := "submit_issue_report"
const SUBMIT_BOT_PROPOSAL := "submit_bot_proposal"

const HELLO_OK := "hello_ok"
const ROOM_LIST := "room_list"
const ROOM_SNAPSHOT := "room_snapshot"
const ROOM_ERROR := "room_error"
const MATCH_ASSIGNED := "match_assigned"
const REQUEST_NEXT_RECEIVED := "request_next_received"
const REQUEST_NEXT_RESULT := "request_next_result"
const LOBBY_RECONNECT_OK := "lobby_reconnect_ok"
const ACCOUNT_DECK_LIST := "account_deck_list"
const ACCOUNT_DECK_SAVED := "account_deck_saved"
const ACCOUNT_DECK_DELETED := "account_deck_deleted"
const PROFILE_SUMMARY := "profile_summary"
const RANK_BADGE_RESULT := "rank_badge_result"
const BOT_LADDER := "bot_ladder"
const BOT_DECK := "bot_deck"
const BOT_MATCH_HISTORY := "bot_match_history"
const BOT_WORK_ASSIGNMENT := "bot_work_assignment"
const BOT_WORK_RESULT := "bot_work_result"
const FRIENDS_STATE := "friends_state"
const ACCOUNT_SETTINGS_UPDATED := "account_settings_updated"
const PASSWORD_RESET_RESULT := "password_reset_result"
const MATCH_HOST_VIABILITY_REQUEST := "match_host_viability_request"
const ISSUE_REPORT_RESULT := "issue_report_result"
const BOT_PROPOSAL_RESULT := "bot_proposal_result"

static func make_message(message_type: String, payload: Dictionary = {}) -> Dictionary:
	return {
		"type": message_type,
		"payload": payload,
	}

static func get_type(message: Dictionary) -> String:
	return str(message.get("type", ""))

static func get_payload(message: Dictionary) -> Dictionary:
	var payload = message.get("payload", {})
	if payload is Dictionary:
		return payload
	return {}

static func validate_request(message: Dictionary) -> String:
	var message_type := get_type(message)
	var payload := get_payload(message)

	if message_type.is_empty():
		return "Missing lobby message type."

	match message_type:
		REQUEST_PASSWORD_RESET, RESET_PASSWORD:
			var email := str(payload.get("email", "")).strip_edges()
			if email.is_empty() or email.length() > 254:
				return "Enter a valid account email address."
			if message_type == RESET_PASSWORD:
				if not is_valid_password_reset_code(str(payload.get("token", ""))):
					return "Enter the 6-digit recovery code from your email."
				var password := str(payload.get("new_password", ""))
				if password.is_empty() or password.length() > 1024:
					return "Enter a new password (at most 1024 characters)."
		LOGIN_GUEST:
			return "Guest sign-in is no longer supported."
		LOGIN_ACCOUNT, REGISTER_ACCOUNT:
			if str(payload.get("email", "")).strip_edges().is_empty():
				return "Missing email address."
			if str(payload.get("password", "")).strip_edges().is_empty():
				return "Missing password."
			if message_type == REGISTER_ACCOUNT and str(payload.get("username", "")).strip_edges().is_empty():
				return "Missing username."
		CLAIM_LEGACY_ACCOUNT:
			if str(payload.get("username", "")).strip_edges().is_empty():
				return "Missing username."
			if str(payload.get("email", "")).strip_edges().is_empty():
				return "Missing email address."
			if str(payload.get("password", "")).strip_edges().is_empty():
				return "Missing password."
		UPDATE_ACCOUNT_SETTINGS:
			var changing_email := not str(payload.get("new_email", "")).strip_edges().is_empty()
			var changing_password := not str(payload.get("new_password", "")).is_empty()
			if (changing_email or changing_password) and str(payload.get("current_password", "")).is_empty():
				return "Missing current password."
		JOIN_ROOM, REJOIN_ROOM:
			if str(payload.get("room_id", "")).strip_edges().is_empty():
				return "Missing room code."
		OBSERVE_ROOM:
			if str(payload.get("room_id", "")).strip_edges().is_empty():
				return "Missing room code."
		REQUEST_NEXT:
			var match_id = payload.get("match_id", "")
			if not match_id is String or match_id.strip_edges().is_empty() or match_id.length() > 64:
				return "Invalid match id."
		SELECT_DECK:
			var has_deck_id := not str(payload.get("deck_id", "")).strip_edges().is_empty()
			var has_cards := payload.has("cards") and payload.get("cards") is Dictionary
			if not has_deck_id and not has_cards:
				return "Missing saved deck id or deck cards."
			if has_cards and str(payload.get("deck_name", "")).strip_edges().is_empty():
				return "Missing deck name."
			if payload.has("reinforcements") and not (payload.get("reinforcements") is Dictionary):
				return "Invalid Reinforcements."
		SAVE_ACCOUNT_DECK:
			if str(payload.get("deck_name", "")).strip_edges().is_empty():
				return "Missing deck name."
			if not payload.has("cards") or not (payload.get("cards") is Dictionary):
				return "Missing deck cards."
			if payload.has("reinforcements") and not (payload.get("reinforcements") is Dictionary):
				return "Invalid Reinforcements."
		DELETE_ACCOUNT_DECK:
			if str(payload.get("deck_id", "")).strip_edges().is_empty():
				return "Missing deck id."
		SET_ACCOUNT_PREFERRED_DECK:
			if str(payload.get("deck_id", "")).strip_edges().is_empty():
				return "Missing deck id."
		SET_OBSERVER_FRIEND_CARD_VISIBILITY:
			if not payload.has("allow_friend_observers_to_see_cards"):
				return "Missing observe visibility setting."
		SET_RANK_BADGE:
			var league = payload.get("league")
			if payload.get("best_of") not in [1, 3] or not (league is int or league is float) \
					or not payload.get("portrait") is Dictionary:
				return "Invalid rank badge selection."
		SEND_FRIEND_REQUEST:
			if str(payload.get("username", "")).strip_edges().is_empty():
				return "Missing friend username."
		RESPOND_FRIEND_REQUEST:
			if str(payload.get("request_id", "")).strip_edges().is_empty():
				return "Missing friend request id."
			if not payload.has("accept"):
				return "Missing friend request response."
		SEND_DECK_TO_FRIEND:
			if str(payload.get("username", "")).strip_edges().is_empty():
				return "Missing friend username."
			if str(payload.get("deck_name", "")).strip_edges().is_empty():
				return "Missing deck name."
			if not payload.has("cards") or not (payload.get("cards") is Dictionary):
				return "Missing deck cards."
			if payload.has("reinforcements") and not (payload.get("reinforcements") is Dictionary):
				return "Invalid Reinforcements."
		RESPOND_DECK_SHARE:
			if str(payload.get("share_id", "")).strip_edges().is_empty():
				return "Missing deck share id."
			if not payload.has("accept"):
				return "Missing deck share response."
		SET_READY:
			if not payload.has("is_ready"):
				return "Missing ready state."
		CREATE_ROOM:
			if payload.has("best_of"):
				var best_of := int(payload.get("best_of", 1))
				if best_of not in [1, 3]:
					return "Invalid match format."
		REQUEST_RECONNECT_LOBBY:
			if str(payload.get("session_id", "")).strip_edges().is_empty():
				return "Missing session id."
			if str(payload.get("reconnect_token", "")).strip_edges().is_empty():
				return "Missing reconnect token."
		LIST_ROOMS, LEAVE_ROOM, REQUEST_ACCOUNT_DECKS, REQUEST_PROFILE_SUMMARY, REQUEST_FRIENDS:
			pass
		REQUEST_BOT_LADDER:
			if payload.has("request_id"):
				var request_id = payload["request_id"]
				var page = payload.get("page")
				if not request_id is int or not page is int or page < 0 or payload.get("best_of") not in [1, 3]:
					return "Invalid ladder page request."
		REQUEST_BOT_DECK:
			var list_id = payload.get("list_id", "")
			if not list_id is String or list_id.is_empty() or list_id.length() > 64:
				return "Invalid bot list id."
		REQUEST_BOT_MATCH_HISTORY:
			var cursor = payload.get("before_match_id", "")
			if not cursor is String or cursor.length() > 64:
				return "Invalid bot match history cursor."
		REQUEST_BOT_WORK:
			pass
		REPORT_BOT_WORK_STARTED:
			var started_job_id = payload.get("job_id", "")
			if not started_job_id is String or started_job_id.is_empty() or started_job_id.length() > 64:
				return "Invalid bot worker job id."
		CANCEL_BOT_WORK:
			var canceled_job_id = payload.get("job_id", "")
			if not canceled_job_id is String or canceled_job_id.is_empty() or canceled_job_id.length() > 64:
				return "Invalid bot worker job id."
		SUBMIT_BOT_WORK_RESULT:
			var job_id = payload.get("job_id", "")
			var winner = payload.get("winner_index", -1)
			if not job_id is String or job_id.length() > 64 or not winner is int or winner not in [0, 1]:
				return "Invalid bot worker result."
		REPORT_HOST_VIABILITY:
			if not payload.has("viable"):
				return "Missing viability flag."
		SUBMIT_ISSUE_REPORT:
			var expected = payload.get("expected", "")
			var actual = payload.get("actual", "")
			var screenshot_jpeg = payload.get("screenshot_jpeg", "")
			if not expected is String or expected.strip_edges().is_empty() or expected.length() > 1200:
				return "Enter what you expected to happen (at most 1200 characters)."
			if not actual is String or actual.strip_edges().is_empty() or actual.length() > 1200:
				return "Enter what happened (at most 1200 characters)."
			if not screenshot_jpeg is String or screenshot_jpeg.length() > 16000:
				return "The screenshot is too large. Choose a smaller image."
		SUBMIT_BOT_PROPOSAL:
			var strategy = payload.get("strategy", "")
			var deck_code = payload.get("deck_code", "")
			var deck_text = payload.get("deck_text", "")
			if not strategy is String or strategy.strip_edges().is_empty() or strategy.length() > 2000:
				return "Describe the strategy in at most 2000 characters."
			if not deck_code is String or not deck_code.begins_with("OGDECK1:") or deck_code.length() > 12000:
				return "The deck import code is invalid or too large."
			if not deck_text is String or deck_text.strip_edges().is_empty() or deck_text.length() > 12000:
				return "The deck list is invalid or too large."
		_:
			return "Unknown lobby message type: %s" % message_type

	return ""

static func is_valid_password_reset_code(code: String) -> bool:
	if code.length() != PASSWORD_RESET_CODE_LENGTH:
		return false
	for index in range(code.length()):
		var digit := code.unicode_at(index)
		if digit < 48 or digit > 57:
			return false
	return true
