extends RefCounted

const ADDRESS := "OtherGodsGame@gmail.com"
const MAX_MAILTO_LENGTH := 1800

static func open_draft(subject: String, body: String) -> String:
	var draft_url := "mailto:%s?subject=%s" % [ADDRESS, subject.uri_encode()]
	var mail_body := body.replace("\r\n", "\n").replace("\n", "\r\n")
	var full_url := draft_url + "&body=" + mail_body.uri_encode()
	if full_url.length() <= MAX_MAILTO_LENGTH and OS.shell_open(full_url) == OK:
		return "Send the draft from your email app."
	# Some email handlers truncate long mailto URLs. Keep the full body available to paste.
	DisplayServer.clipboard_set(body)
	if OS.shell_open(draft_url) == OK:
		return "Message copied. Paste it into the email draft, then send it."
	return "Message copied. Paste it into an email to %s." % ADDRESS
