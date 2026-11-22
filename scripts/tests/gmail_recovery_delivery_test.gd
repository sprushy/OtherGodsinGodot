extends SceneTree

const DeliveryScript = preload("res://scripts/server/GmailRecoveryDelivery.gd")
const MailerScript = preload("res://scripts/server/PasswordRecoveryMailer.gd")

class TestDelivery extends DeliveryScript:
	var commands: Array[String] = []
	var results: Array[bool] = []
	func _process(_delta: float) -> void:
		pass
	func _queue_command(command: String, next_stage: Stage) -> void:
		commands.append(command)
		_stage = next_stage
	func _finish(sent: bool) -> void:
		results.append(sent)
		super._finish(sent)
	func prepare() -> void:
		_sender = "sender@gmail.com"
		_recipient = "player@example.com"
		_password = "abcdefghijklmnop"
		_message = _build_message(_sender, _recipient, "Test recovery body")
		_stage = Stage.GREETING
	func receive(chunk: String) -> void:
		_incoming += chunk
		_consume_replies()

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
	if "--gmail-tls-check" in OS.get_cmdline_user_args():
		var connected: bool = await _check_gmail_tls()
		quit(0 if connected else 1)
		return
	var tls_options := DeliveryScript.create_tls_options()
	_check(tls_options != null and not tls_options.is_unsafe_client(), "Gmail TLS configuration enforces verification")
	_check(tls_options != null and tls_options.get_trusted_ca_chain() != null, "Published Google CA bundle loads successfully")
	var export_config := ConfigFile.new()
	_check(export_config.load("res://export_presets.cfg") == OK, "Export presets load for certificate packaging check")
	for section in export_config.get_sections():
		if export_config.has_section_key(section, "include_filter"):
			_check(str(export_config.get_value(section, "include_filter")).contains("certificates/*.pem"), "Export includes the Gmail CA bundle: " + section)
	_check(DeliveryScript.valid_mailbox("player+test@example.com"), "Normal mailbox accepted")
	_check(not DeliveryScript.valid_mailbox("player@example.com\r\nBcc: victim@example.com"), "Header injection rejected")
	_check(not DeliveryScript.valid_mailbox("player@example.com><victim@example.com"), "SMTP envelope injection rejected")
	_check(not DeliveryScript.valid_mailbox("a@example.com,b@example.com"), "Multiple SMTP recipients rejected")
	_check(not DeliveryScript.valid_app_password("ordinary-password"), "Non-app-password format rejected")
	_check(DeliveryScript.valid_app_password("abcdefghijklmnop"), "Google app-password format accepted")
	var delivery := TestDelivery.new()
	delivery.prepare()
	delivery.receive("220 smtp.gmail.com ready\r")
	_check(delivery.commands.is_empty(), "Fragmented SMTP reply waits for complete line")
	delivery.receive("\n")
	_check(delivery.commands.back() == "EHLO othergods.local\r\n", "Send EHLO after greeting")
	delivery.receive("250-smtp.gmail.com\r\n250-AUTH LOGIN PLAIN\r\n")
	_check(delivery.commands.size() == 1, "Multiline reply waits for final line")
	delivery.receive("250 SIZE 35882577\r\n")
	_check(delivery.commands.back() == "AUTH LOGIN\r\n", "Begin SMTP authentication after EHLO")
	delivery.receive("334 VXNlcm5hbWU6\r\n")
	_check(Marshalls.base64_to_raw(delivery.commands.back().strip_edges()).get_string_from_utf8() == "sender@gmail.com", "Send encoded sender identity")
	delivery.receive("334 UGFzc3dvcmQ6\r\n")
	_check(Marshalls.base64_to_raw(delivery.commands.back().strip_edges()).get_string_from_utf8() == "abcdefghijklmnop", "Send encoded app credential at password challenge")
	_check(delivery._password.is_empty(), "Clear password field after authentication write is queued")
	delivery.receive("235 2.7.0 Accepted\r\n")
	_check(delivery.commands.back() == "MAIL FROM:<sender@gmail.com>\r\n", "Use authenticated Gmail address as envelope sender")
	delivery.receive("250 OK\r\n")
	_check(delivery.commands.back() == "RCPT TO:<player@example.com>\r\n", "Use stored account mailbox as recipient")
	delivery.receive("250 OK\r\n")
	_check(delivery.commands.back() == "DATA\r\n", "Request message transfer")
	delivery.receive("354 Go ahead\r\n")
	_check(delivery.commands.back().contains("Test recovery body") and delivery.commands.back().ends_with("\r\n.\r\n"), "Transfer correctly terminated email")
	_check(delivery.results.is_empty(), "Do not report success before final SMTP acceptance")
	delivery.receive("250 2.0.0 queued\r\n")
	_check(delivery.results == [true], "Successful message acceptance completes once")
	_check(delivery._password.is_empty() and delivery._message.is_empty() and delivery._incoming.is_empty() and delivery._sender.is_empty(), "Completion clears sensitive transaction state")
	delivery.receive("250 duplicate\r\n")
	_check(delivery.results.size() == 1, "Post-completion replies cannot complete again")
	delivery.free()
	var rejected := TestDelivery.new()
	rejected.prepare()
	rejected._stage = DeliveryScript.Stage.PASSWORD
	rejected.receive("535 5.7.8 credentials rejected\r\n")
	_check(rejected.results == [false] and rejected._password.is_empty(), "Authentication failure clears credentials and reports failure")
	rejected.free()
	var oversized := TestDelivery.new()
	oversized.prepare()
	oversized.receive("x".repeat(DeliveryScript.MAX_REPLY_BYTES + 1))
	_check(oversized.results == [false], "Bound incoming SMTP response memory")
	oversized.free()
	var malformed := TestDelivery.new()
	malformed.prepare()
	malformed.receive("220-part one\r\n250 wrong multiline code\r\n")
	_check(malformed.results == [false], "Reject inconsistent multiline response")
	malformed.free()
	var message: String = DeliveryScript._build_message("sender@gmail.com", "player@example.com", ".first\n.\nlast")
	_check(message.contains("\r\n..first\r\n..\r\nlast\r\n"), "SMTP dot-stuffing prevents premature message termination")
	# Test config selection with synthetic credentials; restore the process env.
	var saved_gmail := OS.get_environment("OTHERGODS_GMAIL_ADDRESS")
	var saved_password := OS.get_environment("OTHERGODS_GMAIL_APP_PASSWORD")
	var saved_resend := OS.get_environment("OTHERGODS_RESEND_API_KEY")
	var saved_from := OS.get_environment("OTHERGODS_RECOVERY_EMAIL_FROM")
	OS.set_environment("OTHERGODS_RESEND_API_KEY", "test-key")
	OS.set_environment("OTHERGODS_RECOVERY_EMAIL_FROM", "sender@example.com")
	OS.set_environment("OTHERGODS_GMAIL_ADDRESS", "sender@gmail.com")
	OS.set_environment("OTHERGODS_GMAIL_APP_PASSWORD", "abcd efgh ijkl mnop")
	var mailer := MailerScript.new()
	_check(mailer.is_configured() and mailer._uses_gmail(), "Gmail config selected and grouped app password normalized")
	OS.set_environment("OTHERGODS_GMAIL_APP_PASSWORD", "")
	_check(not mailer.is_configured(), "Incomplete Gmail config cannot silently switch to Resend")
	OS.set_environment("OTHERGODS_GMAIL_ADDRESS", "")
	_check(mailer.is_configured() and not mailer._uses_gmail(), "Resend remains available when Gmail config absent")
	OS.set_environment("OTHERGODS_GMAIL_ADDRESS", saved_gmail)
	OS.set_environment("OTHERGODS_GMAIL_APP_PASSWORD", saved_password)
	OS.set_environment("OTHERGODS_RESEND_API_KEY", saved_resend)
	OS.set_environment("OTHERGODS_RECOVERY_EMAIL_FROM", saved_from)
	mailer.free()
	print("Gmail recovery checks: %s (%d checks)" % ["PASS" if _failures == 0 else "FAIL (%d)" % _failures, _checks])
	quit(0 if _failures == 0 else 1)

func _check_gmail_tls() -> bool:
	# Optional integration check: no login, email, or account credentials.
	var options := DeliveryScript.create_tls_options()
	if options == null:
		return false
	var tcp := StreamPeerTCP.new()
	if tcp.connect_to_host(DeliveryScript.HOST, DeliveryScript.PORT) != OK:
		return false
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		tcp.poll()
		if tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			break
		if tcp.get_status() == StreamPeerTCP.STATUS_ERROR:
			tcp.disconnect_from_host()
			return false
		await process_frame
	var tls := StreamPeerTLS.new()
	if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED or tls.connect_to_stream(tcp, DeliveryScript.HOST, options) != OK:
		tcp.disconnect_from_host()
		return false
	var verified := false
	while Time.get_ticks_msec() < deadline:
		tcp.poll()
		tls.poll()
		if tls.get_status() == StreamPeerTLS.STATUS_CONNECTED:
			verified = true
			break
		if tls.get_status() != StreamPeerTLS.STATUS_HANDSHAKING:
			break
		await process_frame
	tls.disconnect_from_stream()
	tcp.disconnect_from_host()
	print("Gmail verified TLS check: %s (no authentication or email sent)" % ("PASS" if verified else "FAIL"))
	return verified
