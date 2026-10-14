extends SceneTree

const AccountStoreScript = preload("res://scripts/server/AccountStore.gd")
const LobbyServerScript = preload("res://scripts/server/LobbyServer.gd")
const LobbyProtocolScript = preload("res://scripts/network/LobbyProtocol.gd")
const LobbyClientScript = preload("res://scripts/client/LobbyClient.gd")

class TestStore extends AccountStoreScript:
	var storage_path: String
	var fail_save: bool = false
	func _get_storage_path() -> String:
		return storage_path
	func _save() -> bool:
		return false if fail_save else super._save()

class FakeMailer extends Node:
	var configured: bool = true
	var queue_ok: bool = true
	var deliveries: Array[Dictionary] = []
	func is_configured() -> bool:
		return configured
	func send_recovery_email(email: String, token: String, completion: Callable) -> bool:
		if not queue_ok:
			return false
		deliveries.append({"email": email, "token": token, "completion": completion})
		return true

class TestServer extends LobbyServerScript:
	var responses: Array[Dictionary] = []
	func _ready() -> void:
		pass
	func _send_to_peer(_peer_id: int, message_type: String, payload: Dictionary) -> void:
		responses.append({"type": message_type, "payload": payload.duplicate(true)})

class TestClient extends LobbyClientScript:
	var requests: Array[Dictionary] = []
	func _ensure_network_manager() -> void:
		pass
	func _start_next_transport_attempt() -> Error:
		return OK
	func _send_request(message_type: String, payload: Dictionary = {}) -> void:
		requests.append({"type": message_type, "payload": payload.duplicate(true)})
	func _arm_auth_response_timeout() -> void:
		pass

var _failures: int = 0
var _checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)

func _run() -> void:
	var store := TestStore.new()
	var test_dir := "user://password_recovery_tests_%d" % Time.get_ticks_usec()
	store.storage_path = test_dir.path_join("accounts.json")
	var registration := store.register_account("recovery@example.com", "original-password", "RecoveryTest")
	_check(bool(registration.get("success", false)), "Register isolated test account")
	var account_id := str(registration.get("account", {}).get("account_id", ""))
	if account_id.is_empty():
		quit(1)
		return
	_check(store.create_password_reset("missing@example.com").is_empty(), "Unknown email cannot obtain a token")
	var first := store.create_password_reset(" RECOVERY@example.com ")
	var token := str(first.get("token", ""))
	_check(token.length() == 64, "Generate a full cryptographic recovery code")
	_check(store.create_password_reset("recovery@example.com").is_empty(), "Email request cooldown is enforced")
	var persisted_text := FileAccess.get_file_as_string(store.storage_path)
	_check(not persisted_text.contains(token), "Storage contains no plaintext recovery token")
	_check(not str(store.get_account(account_id)).contains("password_reset"), "Public account payload has no recovery metadata")
	_check(not bool(store.reset_password("missing@example.com", token, "new-password").get("success")), "A token cannot reset a different email")
	_check(not bool(store.reset_password("recovery@example.com", "0".repeat(64), "new-password").get("success")), "Incorrect token is rejected")
	_check(not bool(store.reset_password("recovery@example.com", token, "short").get("success")), "Weak password rejected without consuming code")
	store.fail_save = true
	_check(not bool(store.reset_password("recovery@example.com", token, "new-password").get("success")), "Save failure does not report reset success")
	_check(str(store._accounts_by_id[account_id].get("password_reset_hash", "")) == token.sha256_text(), "Save failure restores recovery code")
	store.fail_save = false
	var reloaded := TestStore.new()
	reloaded.storage_path = store.storage_path
	_check(bool(reloaded.reset_password("recovery@example.com", token, "new-password").get("success")), "Pending recovery survives restart")
	_check(not bool(reloaded.reset_password("recovery@example.com", token, "second-password").get("success")), "Recovery code cannot be replayed")
	_check(not bool(reloaded.login_account("recovery@example.com", "original-password").get("success")), "Old password fails after reset")
	_check(bool(reloaded.login_account("recovery@example.com", "new-password").get("success")), "New password signs into existing account")
	store = reloaded
	store._accounts_by_id[account_id]["password_reset_requested_unix"] = 0
	var expired := store.create_password_reset("recovery@example.com")
	store._accounts_by_id[account_id]["password_reset_expires_unix"] = 1
	_check(not bool(store.reset_password("recovery@example.com", str(expired.get("token", "")), "expired-password").get("success")), "Expired recovery code fails")
	store._accounts_by_id[account_id]["password_reset_requested_unix"] = 0
	var replacement := store.create_password_reset("recovery@example.com")
	store.cancel_password_reset(account_id, str(expired.get("token", "")))
	_check(str(store._accounts_by_id[account_id].get("password_reset_hash", "")) == str(replacement.get("token", "")).sha256_text(), "A late failed-delivery callback cannot cancel a newer code")
	_check(not bool(store.reset_password("recovery@example.com", str(expired.get("token", "")), "expired-password").get("success")), "Replacement invalidates earlier code")
	_check(bool(store.update_account_settings(account_id, "new-password", "changed@example.com").get("success")), "Email can be changed with current password")
	_check(not bool(store.reset_password("changed@example.com", str(replacement.get("token", "")), "wrong-password").get("success")), "Email change invalidates pending code")
	store._accounts_by_id[account_id]["password_reset_requested_unix"] = 0
	store.fail_save = true
	_check(store.create_password_reset("changed@example.com").is_empty(), "Failed issuance save returns no recovery credential")
	_check(not store._accounts_by_id[account_id].has("password_reset_hash"), "Failed issuance save restores previous state")
	store.fail_save = false
	var server := TestServer.new()
	server.account_store = store
	var mailer := FakeMailer.new()
	server.recovery_mailer = mailer
	get_root().add_child(server)
	server.add_child(mailer)
	mailer.configured = false
	server._handle_password_recovery(1, {"email": "changed@example.com"}, false)
	_check(server.responses.back()["type"] == LobbyProtocolScript.ROOM_ERROR and mailer.deliveries.is_empty(), "Unconfigured provider reports unavailable and sends nothing")
	mailer.configured = true
	server.allow_insecure_account_auth = true
	server._handle_password_recovery(2, {"email": "changed@example.com"}, false)
	_check(server.responses.back()["type"] == LobbyProtocolScript.ROOM_ERROR and mailer.deliveries.is_empty(), "Insecure auth override does not enable remote recovery")
	server._handle_password_recovery(1, {"email": "changed@example.com"}, false)
	var known_response: Dictionary = server.responses.back()
	server._handle_password_recovery(1, {"email": "absent@example.com"}, false)
	_check(server.responses.back() == known_response, "Known and unknown email acknowledgements are identical")
	_check(mailer.deliveries.size() == 1 and mailer.deliveries[0]["email"] == "changed@example.com", "Email is sent to stored address only")
	var delivered_token := str(mailer.deliveries[0]["token"])
	_check(not str(server.responses).contains(delivered_token), "Recovery responses never disclose code")
	mailer.deliveries[0]["completion"].call(false)
	_check(not bool(store.reset_password("changed@example.com", delivered_token, "failed-mail-password").get("success")), "Failed delivery invalidates code")
	store._accounts_by_id[account_id]["password_reset_requested_unix"] = 0
	mailer.queue_ok = false
	server._handle_password_recovery(1, {"email": "changed@example.com"}, false)
	_check(not store._accounts_by_id[account_id].has("password_reset_hash"), "Queue failure cancels code")
	mailer.queue_ok = true
	store._accounts_by_id[account_id]["password_reset_requested_unix"] = 0
	server._handle_password_recovery(1, {"email": "changed@example.com"}, false)
	server.sessions_by_id["old_session"] = {"account_id": account_id, "reconnect_token": "old_token", "peer_id": 0, "connected": false}
	server._handle_password_recovery(1, {"email": "changed@example.com", "token": mailer.deliveries.back()["token"], "new_password": "final-password"}, true)
	_check(bool(server.responses.back()["payload"].get("success")), "Server confirms successful reset")
	_check(str(server.sessions_by_id["old_session"]["reconnect_token"]).is_empty(), "Old lobby reconnect credentials revoked")
	var after_reset := TestStore.new()
	after_reset.storage_path = store.storage_path
	_check(not bool(after_reset.reset_password("changed@example.com", str(mailer.deliveries.back()["token"]), "replay-password").get("success")), "Consumed code remains invalid after restart")
	for index in range(30):
		server._handle_password_recovery(1, {"email": "absent@example.com"}, false)
	_check(server.responses.back()["type"] == LobbyProtocolScript.ROOM_ERROR, "Recovery budget applies across all emails")
	_check(not LobbyProtocolScript.validate_request(LobbyProtocolScript.make_message(LobbyProtocolScript.RESET_PASSWORD, {"email": "changed@example.com", "token": token, "new_password": "x".repeat(1025)})).is_empty(), "Protocol rejects oversized reset password")
	var client := TestClient.new()
	client.network_manager = Node.new()
	_check(client.connect_to_server("ws://remote.example", "changed@example.com", "", "", 22345, "", "request_password_reset") == ERR_UNAVAILABLE, "Client refuses unencrypted public recovery")
	_check(client.connect_to_server("wss://remote.example", "changed@example.com", "", "", 22345, "", "request_password_reset") == OK, "Client accepts secure public recovery")
	client._send_initial_auth_request()
	_check(client.requests.back()["type"] == LobbyProtocolScript.REQUEST_PASSWORD_RESET and not client.requests.back()["payload"].has("password"), "Recovery request requires no old password")
	client.connect_to_server("wss://remote.example", "changed@example.com", "", "", 22345, "", "reset_password", "new-password", "", false, token)
	client._send_initial_auth_request()
	_check(client.requests.back()["type"] == LobbyProtocolScript.RESET_PASSWORD and client.requests.back()["payload"]["token"] == token, "Client submits email code and new password through recovery protocol")
	client.lobby_event(LobbyProtocolScript.make_message(LobbyProtocolScript.PASSWORD_RESET_RESULT, {"completed": true, "success": true, "message": "Done"}))
	_check(client._pending_password.is_empty() and client._pending_recovery_token.is_empty(), "Recovery result clears in-memory client credentials")
	client.network_manager.free()
	client.free()
	server.free()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store.storage_path + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_dir))
	print("Password recovery checks: %s (%d checks)" % ["PASS" if _failures == 0 else "FAIL (%d)" % _failures, _checks])
	quit(0 if _failures == 0 else 1)
