extends Node

# API credentials are read on the server only; never use project settings here.
const API_URL := "https://api.resend.com/emails"
const GmailRecoveryDeliveryScript = preload("res://scripts/server/GmailRecoveryDelivery.gd")
const MAX_PENDING_EMAILS := 4
var _pending_count: int = 0

func is_configured() -> bool:
	if _uses_gmail():
		var sender := OS.get_environment("OTHERGODS_GMAIL_ADDRESS").strip_edges().to_lower()
		return GmailRecoveryDeliveryScript.valid_mailbox(sender) \
			and (sender.ends_with("@gmail.com") or sender.ends_with("@googlemail.com")) \
			and GmailRecoveryDeliveryScript.valid_app_password(_gmail_app_password())
	return not OS.get_environment("OTHERGODS_RESEND_API_KEY").strip_edges().is_empty() \
		and not OS.get_environment("OTHERGODS_RECOVERY_EMAIL_FROM").strip_edges().is_empty()

func send_recovery_email(email: String, token: String, completion: Callable) -> bool:
	if not is_configured() or _pending_count >= MAX_PENDING_EMAILS:
		return false
	if _uses_gmail():
		return _send_gmail(email, token, completion)
	var request := HTTPRequest.new()
	request.timeout = 10.0
	request.body_size_limit = 65536
	add_child(request)
	_pending_count += 1
	request.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		_pending_count -= 1
		request.queue_free()
		var sent := result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300
		if not sent:
			# Provider responses may contain private data; log status codes only.
			push_warning("Password recovery email failed (transport=%d HTTP=%d)." % [result, response_code])
		completion.call(sent)
	)
	var body := JSON.stringify({
		"from": OS.get_environment("OTHERGODS_RECOVERY_EMAIL_FROM").strip_edges(),
		"to": [email],
		"subject": "Reset your Other Gods password",
		"text": _recovery_text(token),
	})
	var error := request.request(API_URL, PackedStringArray([
		"Authorization: Bearer " + OS.get_environment("OTHERGODS_RESEND_API_KEY").strip_edges(),
		"Content-Type: application/json",
	]), HTTPClient.METHOD_POST, body)
	if error != OK:
		_pending_count -= 1
		request.queue_free()
		push_warning("Could not start password recovery email request (%d)." % error)
		return false
	return true

func _uses_gmail() -> bool:
	return not OS.get_environment("OTHERGODS_GMAIL_ADDRESS").strip_edges().is_empty() \
		or not OS.get_environment("OTHERGODS_GMAIL_APP_PASSWORD").strip_edges().is_empty()

func _gmail_app_password() -> String:
	# Google displays app passwords in groups separated by spaces.
	return OS.get_environment("OTHERGODS_GMAIL_APP_PASSWORD").replace(" ", "").strip_edges()

func _send_gmail(email: String, token: String, completion: Callable) -> bool:
	var delivery := GmailRecoveryDeliveryScript.new()
	add_child(delivery)
	delivery.finished.connect(func(sent: bool) -> void:
		_pending_count -= 1
		delivery.queue_free()
		if not sent:
			push_warning("Gmail password recovery delivery failed. Check app-password setup and outbound TCP 465.")
		completion.call(sent)
	)
	var error := delivery.begin(OS.get_environment("OTHERGODS_GMAIL_ADDRESS").strip_edges().to_lower(), _gmail_app_password(), email, _recovery_text(token))
	if error != OK:
		delivery.queue_free()
		push_warning("Could not start Gmail recovery delivery (%d)." % error)
		return false
	_pending_count += 1
	return true

func _recovery_text(token: String) -> String:
	return "A password reset was requested for your Other Gods account.\n\nOpen Other Gods, choose Forgot password?, and paste this recovery code:\n\n%s\n\nThe code expires in 15 minutes and can be used once. Choose a new password in the game. If you did not request this, you can ignore this email; your password has not changed.\n" % token
