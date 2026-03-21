@tool
extends EditorPlugin

const SERVER_PORT := 6400
const MCP_PATH := "/mcp"

var _server: TCPServer = null
var _peers: Array[StreamPeerTCP] = []
var _bufs: Array[PackedByteArray] = []
var _states: Array[Dictionary] = []
var _command_handler = null
var _panel = null

func _enter_tree() -> void:
	_command_handler = preload("res://addons/godot_mcp/command_handler.gd").new()
	_command_handler.set_editor_plugin(self)

	_server = TCPServer.new()
	var err := _server.listen(SERVER_PORT)
	if err != OK:
		push_error("MCP: failed to listen on port %d" % SERVER_PORT)
		return

	print("MCP server listening on port %d" % SERVER_PORT)
	_panel = preload("res://addons/godot_mcp/ui/mcp_panel.tscn").instantiate()
	add_control_to_bottom_panel(_panel, "MCP")
	_panel.update_status("Running on port %d" % SERVER_PORT)

func _exit_tree() -> void:
	if _server:
		_server.stop()
		_server = null
	for p in _peers:
		p.disconnect_from_host()
	_peers.clear()
	_bufs.clear()
	_states.clear()
	if _panel and is_instance_valid(_panel):
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
		_panel = null

func _process(_delta: float) -> void:
	if not _server:
		return

	while _server.is_connection_available():
		var p := _server.take_connection()
		if p:
			_peers.append(p)
			_bufs.append(PackedByteArray())
			_states.append({"headers_done": false, "method": "", "path": "", "content_length": 0})

	var i := 0
	while i < _peers.size():
		var peer := _peers[i]
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_peers.remove_at(i)
			_bufs.remove_at(i)
			_states.remove_at(i)
			continue

		var avail := peer.get_available_bytes()
		if avail > 0:
			var rd := peer.get_data(avail)
			if rd[0] == OK:
				_bufs[i].append_array(rd[1])

		_try_process(i)
		i += 1

func _try_process(i: int) -> void:
	var state := _states[i]

	if not state["headers_done"]:
		var raw := _bufs[i].get_string_from_utf8()
		var sep := raw.find("\r\n\r\n")
		if sep == -1:
			return

		var header_text := raw.substr(0, sep)
		var lines := header_text.split("\r\n")
		var req_line := lines[0].split(" ")
		if req_line.size() >= 2:
			state["method"] = req_line[0]
			state["path"]   = req_line[1]

		for j in range(1, lines.size()):
			var colon := lines[j].find(":")
			if colon > 0:
				var k := lines[j].substr(0, colon).strip_edges().to_lower()
				var v := lines[j].substr(colon + 1).strip_edges()
				state[k] = v

		state["content_length"] = int(state.get("content-length", "0"))
		state["headers_done"]   = true
		_bufs[i] = _bufs[i].slice(sep + 4)

	var clen: int = state["content_length"]
	if _bufs[i].size() < clen:
		return

	var body := _bufs[i].slice(0, clen).get_string_from_utf8()
	_bufs[i] = _bufs[i].slice(clen)

	var method: String = state["method"]
	var path:   String = state["path"]
	state["headers_done"]   = false
	state["method"]         = ""
	state["path"]           = ""
	state["content_length"] = 0
	state.erase("content-length")

	_handle_http(_peers[i], method, path, body)

func _handle_http(peer: StreamPeerTCP, method: String, path: String, body: String) -> void:
	if method == "OPTIONS":
		_http(peer, 204, "", "")
		return

	if path != MCP_PATH:
		_http(peer, 404, "application/json", '{"error":"not found"}')
		return

	if method != "POST":
		_http(peer, 405, "application/json", '{"error":"method not allowed"}')
		return

	var json := JSON.new()
	if json.parse(body) != OK:
		_rpc_error(peer, null, -32700, "Parse error")
		return

	var req = json.get_data()
	if typeof(req) != TYPE_DICTIONARY:
		_rpc_error(peer, null, -32600, "Invalid Request")
		return

	# Notifications have no "id" field — acknowledge with 204 and no body
	if not (req as Dictionary).has("id"):
		_http(peer, 204, "", "")
		return

	var id = (req as Dictionary).get("id")
	var rpc_method: String = (req as Dictionary).get("method", "")
	var params = (req as Dictionary).get("params", {})
	if typeof(params) != TYPE_DICTIONARY:
		params = {}

	if rpc_method == "initialize":
		_rpc_result(peer, id, {
			"protocolVersion": "2024-11-05",
			"capabilities": {"tools": {}},
			"serverInfo": {"name": "godot-mcp", "version": "2.0.0"}
		})
	elif rpc_method == "ping":
		_rpc_result(peer, id, {})
	elif rpc_method == "tools/list":
		_rpc_result(peer, id, {"tools": _command_handler.get_tool_list()})
	elif rpc_method == "tools/call":
		var tool_name: String = (params as Dictionary).get("name", "")
		var raw_args = (params as Dictionary).get("arguments", {})
		var tool_args: Dictionary = raw_args if typeof(raw_args) == TYPE_DICTIONARY else {}
		var tool_result: Dictionary = _command_handler.call_tool(tool_name, tool_args)
		_rpc_result(peer, id, tool_result)
	else:
		_rpc_error(peer, id, -32601, "Method not found: " + rpc_method)

func _rpc_result(peer: StreamPeerTCP, id: Variant, result: Dictionary) -> void:
	var resp := {"jsonrpc": "2.0", "id": id, "result": result}
	_http(peer, 200, "application/json", JSON.stringify(resp))

func _rpc_error(peer: StreamPeerTCP, id: Variant, code: int, message: String) -> void:
	var resp := {"jsonrpc": "2.0", "id": id, "error": {"code": code, "message": message}}
	_http(peer, 200, "application/json", JSON.stringify(resp))

func _http(peer: StreamPeerTCP, status: int, content_type: String, body: String) -> void:
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	var body_bytes := body.to_utf8_buffer()
	var status_texts := {200: "OK", 204: "No Content", 404: "Not Found", 405: "Method Not Allowed"}
	var status_text: String = status_texts[status] if status_texts.has(status) else "OK"

	var head := "HTTP/1.1 %d %s\r\n" % [status, status_text]
	head += "Access-Control-Allow-Origin: *\r\n"
	head += "Access-Control-Allow-Methods: POST, OPTIONS\r\n"
	head += "Access-Control-Allow-Headers: Content-Type\r\n"
	head += "Content-Length: %d\r\n" % body_bytes.size()
	if content_type != "":
		head += "Content-Type: %s\r\n" % content_type
	head += "\r\n"

	peer.put_data(head.to_utf8_buffer())
	if body_bytes.size() > 0:
		peer.put_data(body_bytes)
