extends Node

# One bounded, nonblocking SMTP transaction. Credentials are sent only after
# certificate/hostname verification succeeds for Google's fixed SMTP endpoint.
const HOST := "smtp.gmail.com"
const PORT := 465
const TIMEOUT_SECONDS := 20.0
const MAX_REPLY_BYTES := 16384
enum Stage { TCP, TLS, GREETING, EHLO, AUTH, USERNAME, PASSWORD, MAIL, RECIPIENT, DATA, ACCEPTED, DONE }

signal finished(sent: bool)

var _tcp := StreamPeerTCP.new()
var _tls := StreamPeerTLS.new()
var _stage: Stage = Stage.DONE
var _elapsed: float = 0.0
var _sender: String = ""
var _recipient: String = ""
var _password: String = ""
var _message: String = ""
var _outgoing := PackedByteArray()
var _incoming: String = ""
var _reply_code: int = 0
var _reply_bytes: int = 0

static func valid_mailbox(email: String) -> bool:
	if email.length() > 254 or email.find("@") <= 0 or email.find("@") != email.rfind("@"):
		return false
	var domain := email.get_slice("@", 1)
	if domain.find(".") <= 0 or domain.ends_with("."):
		return false
	for index in range(email.length()):
		var codepoint := email.unicode_at(index)
		if codepoint <= 32 or codepoint >= 127 or "<>[](),;:\\\"".contains(email.substr(index, 1)):
			return false
	return true

static func valid_app_password(password: String) -> bool:
	if password.length() != 16:
		return false
	for index in range(password.length()):
		var codepoint := password.unicode_at(index)
		if not ((codepoint >= 97 and codepoint <= 122) or (codepoint >= 65 and codepoint <= 90) or (codepoint >= 48 and codepoint <= 57)):
			return false
	return true

func begin(sender: String, app_password: String, recipient: String, text: String) -> Error:
	if _stage != Stage.DONE:
		return ERR_BUSY
	if not valid_mailbox(sender) or not valid_mailbox(recipient) or not valid_app_password(app_password):
		return ERR_INVALID_PARAMETER
	_sender = sender
	_recipient = recipient
	_password = app_password
	_message = _build_message(sender, recipient, text)
	_elapsed = 0.0
	_incoming = ""
	_outgoing.clear()
	_reply_code = 0
	_reply_bytes = 0
	var error := _tcp.connect_to_host(HOST, PORT)
	if error != OK:
		_clear_secrets()
		return error
	_stage = Stage.TCP
	set_process(true)
	return OK

func _process(delta: float) -> void:
	if _stage == Stage.DONE:
		return
	_elapsed += delta
	if _elapsed >= TIMEOUT_SECONDS:
		_finish(false)
		return
	_tcp.poll()
	if _tcp.get_status() == StreamPeerTCP.STATUS_ERROR or _tcp.get_status() == StreamPeerTCP.STATUS_NONE:
		_finish(false)
		return
	if _stage == Stage.TCP:
		if _tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			if _tls.connect_to_stream(_tcp, HOST, TLSOptions.client()) != OK:
				_finish(false)
				return
			_stage = Stage.TLS
		return
	_tls.poll()
	var status := _tls.get_status()
	if status == StreamPeerTLS.STATUS_HANDSHAKING:
		return
	if status != StreamPeerTLS.STATUS_CONNECTED:
		_finish(false)
		return
	if _stage == Stage.TLS:
		_stage = Stage.GREETING
	if not _outgoing.is_empty():
		var write_result := _tls.put_partial_data(_outgoing)
		if int(write_result[0]) != OK:
			_finish(false)
			return
		_outgoing = _outgoing.slice(int(write_result[1]))
		if not _outgoing.is_empty():
			return
	var available := _tls.get_available_bytes()
	if available > 0:
		var read_result := _tls.get_partial_data(mini(available, MAX_REPLY_BYTES))
		if int(read_result[0]) != OK:
			_finish(false)
			return
		_incoming += (read_result[1] as PackedByteArray).get_string_from_ascii()
	_consume_replies()

func _consume_replies() -> void:
	while _stage != Stage.DONE and _outgoing.is_empty():
		if _incoming.length() + _reply_bytes > MAX_REPLY_BYTES:
			_finish(false)
			return
		var line_end := _incoming.find("\r\n")
		if line_end < 0:
			return
		var line := _incoming.substr(0, line_end)
		_incoming = _incoming.substr(line_end + 2)
		_reply_bytes += line.length() + 2
		if line.length() < 3 or not line.substr(0, 3).is_valid_int():
			_finish(false)
			return
		var code := int(line.substr(0, 3))
		if code < 100 or code > 599 or (_reply_code != 0 and code != _reply_code):
			_finish(false)
			return
		_reply_code = code
		if line.length() > 3 and line.substr(3, 1) == "-":
			continue
		if line.length() > 3 and line.substr(3, 1) != " ":
			_finish(false)
			return
		_reply_code = 0
		_reply_bytes = 0
		_on_reply(code)

func _on_reply(code: int) -> void:
	match _stage:
		Stage.GREETING:
			if code == 220:
				_queue_command("EHLO othergods.local\r\n", Stage.EHLO)
				return
		Stage.EHLO:
			if code == 250:
				_queue_command("AUTH LOGIN\r\n", Stage.AUTH)
				return
		Stage.AUTH:
			if code == 334:
				_queue_command(Marshalls.raw_to_base64(_sender.to_utf8_buffer()) + "\r\n", Stage.USERNAME)
				return
		Stage.USERNAME:
			if code == 334:
				_queue_command(Marshalls.raw_to_base64(_password.to_utf8_buffer()) + "\r\n", Stage.PASSWORD)
				_password = ""
				return
		Stage.PASSWORD:
			if code == 235:
				_queue_command("MAIL FROM:<%s>\r\n" % _sender, Stage.MAIL)
				return
		Stage.MAIL:
			if code == 250:
				_queue_command("RCPT TO:<%s>\r\n" % _recipient, Stage.RECIPIENT)
				return
		Stage.RECIPIENT:
			if code in [250, 251]:
				_queue_command("DATA\r\n", Stage.DATA)
				return
		Stage.DATA:
			if code == 354:
				_queue_command(_message, Stage.ACCEPTED)
				_message = ""
				return
		Stage.ACCEPTED:
			if code == 250:
				_finish(true)
				return
	# SMTP replies can echo mailbox addresses or credentials; never log them.
	push_warning("Gmail recovery email rejected (SMTP status %d)." % code)
	_finish(false)

func _queue_command(command: String, next_stage: Stage) -> void:
	_outgoing = command.to_utf8_buffer()
	_stage = next_stage

static func _build_message(sender: String, recipient: String, text: String) -> String:
	var utc := Time.get_datetime_dict_from_system(true)
	var weekdays := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var date := "%s, %02d %s %04d %02d:%02d:%02d +0000" % [
		weekdays[int(utc["weekday"])], int(utc["day"]), months[int(utc["month"]) - 1],
		int(utc["year"]), int(utc["hour"]), int(utc["minute"]), int(utc["second"]),
	]
	var message_id := "%s.%d@%s" % [Crypto.new().generate_random_bytes(16).hex_encode(), Time.get_ticks_usec(), sender.get_slice("@", 1)]
	var body_lines := text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	var body := ""
	for line in body_lines:
		body += ("." if line.begins_with(".") else "") + line + "\r\n"
	return "From: Other Gods <%s>\r\nTo: <%s>\r\nDate: %s\r\nMessage-ID: <%s>\r\nSubject: Reset your Other Gods password\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\nContent-Transfer-Encoding: 8bit\r\n\r\n%s.\r\n" % [sender, recipient, date, message_id, body]

func _clear_secrets() -> void:
	_password = ""
	_message = ""
	_sender = ""
	_recipient = ""
	_incoming = ""
	_outgoing.clear()

func _finish(sent: bool) -> void:
	if _stage == Stage.DONE:
		return
	_stage = Stage.DONE
	set_process(false)
	_tls.disconnect_from_stream()
	_tcp.disconnect_from_host()
	_clear_secrets()
	finished.emit(sent)

func _exit_tree() -> void:
	_tls.disconnect_from_stream()
	_tcp.disconnect_from_host()
	_clear_secrets()
