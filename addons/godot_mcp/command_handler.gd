@tool
extends RefCounted

var editor_plugin: EditorPlugin = null

func set_editor_plugin(plugin: EditorPlugin) -> void:
	editor_plugin = plugin

func _ei():
	return editor_plugin.get_editor_interface()

# ── Tool registry ────────────────────────────────────────────────────────────

func get_tool_list() -> Array:
	return [
		{
			"name": "get_scene_tree",
			"description": "Return the full node hierarchy of the currently open scene as JSON.",
			"inputSchema": {"type": "object", "properties": {}, "required": []}
		},
		{
			"name": "get_node_properties",
			"description": "Return the editable properties of a node in the current scene.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Scene-relative path, e.g. 'Player/Sprite2D'"}
				},
				"required": ["node_path"]
			}
		},
		{
			"name": "set_node_property",
			"description": "Set a property on a node in the current scene.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string"},
					"property":  {"type": "string"},
					"value":     {"description": "JSON-serialisable value to assign"}
				},
				"required": ["node_path", "property", "value"]
			}
		},
		{
			"name": "get_script",
			"description": "Read a GDScript (or any text file) from the project. Use res:// paths.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "res:// path to the file"}
				},
				"required": ["path"]
			}
		},
		{
			"name": "update_script",
			"description": "Write (overwrite) a script or text file in the project. Triggers a filesystem rescan.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path":    {"type": "string", "description": "res:// path to write"},
					"content": {"type": "string", "description": "Full new file content"}
				},
				"required": ["path", "content"]
			}
		},
		{
			"name": "list_files",
			"description": "List files (and optionally subdirectories) in a project folder.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path":      {"type": "string",  "description": "res:// directory (default: res://)"},
					"recursive": {"type": "boolean", "description": "Recurse into subdirectories (default: false)"}
				},
				"required": []
			}
		},
		{
			"name": "get_selected_nodes",
			"description": "Return the nodes currently selected in the Godot editor scene tree.",
			"inputSchema": {"type": "object", "properties": {}, "required": []}
		},
		{
			"name": "create_node",
			"description": "Create a new node as a child of an existing node in the open scene.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"parent_path": {"type": "string", "description": "Path to the parent node (empty string = scene root)"},
					"type":        {"type": "string", "description": "Godot class name, e.g. 'Node2D', 'Label', 'Area2D'"},
					"name":        {"type": "string", "description": "Name for the new node"}
				},
				"required": ["type", "name"]
			}
		},
		{
			"name": "delete_node",
			"description": "Remove a node (and all its children) from the current scene.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Scene-relative path to the node"}
				},
				"required": ["node_path"]
			}
		},
		{
			"name": "play_scene",
			"description": "Start playing the current scene in the Godot editor.",
			"inputSchema": {"type": "object", "properties": {}, "required": []}
		},
		{
			"name": "stop_scene",
			"description": "Stop the scene currently playing in the Godot editor.",
			"inputSchema": {"type": "object", "properties": {}, "required": []}
		},
		{
			"name": "save_scene",
			"description": "Save the currently open scene to disk.",
			"inputSchema": {"type": "object", "properties": {}, "required": []}
		},
		{
			"name": "open_scene",
			"description": "Open a scene file in the Godot editor.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "res:// path to the .tscn or .scn file"}
				},
				"required": ["path"]
			}
		},
	]

# ── Dispatcher ───────────────────────────────────────────────────────────────

func call_tool(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name == "get_scene_tree":      return _get_scene_tree()
	if tool_name == "get_node_properties": return _get_node_properties(args.get("node_path", ""))
	if tool_name == "set_node_property":   return _set_node_property(args.get("node_path", ""), args.get("property", ""), args.get("value"))
	if tool_name == "get_script":          return _get_script(args.get("path", ""))
	if tool_name == "update_script":       return _update_script(args.get("path", ""), args.get("content", ""))
	if tool_name == "list_files":          return _list_files(args.get("path", "res://"), args.get("recursive", false))
	if tool_name == "get_selected_nodes":  return _get_selected_nodes()
	if tool_name == "create_node":         return _create_node(args.get("parent_path", ""), args.get("type", "Node"), args.get("name", "NewNode"))
	if tool_name == "delete_node":         return _delete_node(args.get("node_path", ""))
	if tool_name == "play_scene":          return _play_scene()
	if tool_name == "stop_scene":          return _stop_scene()
	if tool_name == "save_scene":          return _save_scene()
	if tool_name == "open_scene":          return _open_scene(args.get("path", ""))
	return _err("Unknown tool: " + tool_name)

# ── Helpers ──────────────────────────────────────────────────────────────────

func _ok(text: String) -> Dictionary:
	return {"content": [{"type": "text", "text": text}], "isError": false}

func _err(text: String) -> Dictionary:
	return {"content": [{"type": "text", "text": text}], "isError": true}

func _scene_root() -> Node:
	return _ei().get_edited_scene_root()

func _resolve_node(node_path: String) -> Node:
	var root := _scene_root()
	if root == null:
		return null
	if node_path == "" or node_path == "." or node_path == root.name:
		return root
	return root.get_node_or_null(node_path)

# ── Tool implementations ─────────────────────────────────────────────────────

func _get_scene_tree() -> Dictionary:
	var root := _scene_root()
	if root == null:
		return _err("No scene is currently open in the editor.")
	return _ok(JSON.stringify(_node_to_dict(root), "\t"))

func _node_to_dict(node: Node) -> Dictionary:
	var d := {
		"name":     node.name,
		"type":     node.get_class(),
		"path":     str(node.get_path()),
		"children": []
	}
	for child in node.get_children():
		d["children"].append(_node_to_dict(child))
	return d

func _get_node_properties(node_path: String) -> Dictionary:
	var node := _resolve_node(node_path)
	if node == null:
		return _err("Node not found: '%s'" % node_path)
	var props := {}
	for prop in node.get_property_list():
		if prop["usage"] & PROPERTY_USAGE_EDITOR:
			var val = node.get(prop["name"])
			if val != null:
				props[prop["name"]] = str(val)
	return _ok(JSON.stringify(props, "\t"))

func _set_node_property(node_path: String, property: String, value) -> Dictionary:
	var node := _resolve_node(node_path)
	if node == null:
		return _err("Node not found: '%s'" % node_path)
	if not property in node:
		return _err("Property '%s' not found on node '%s'" % [property, node_path])
	node.set(property, value)
	return _ok("Set %s.%s = %s" % [node_path, property, str(value)])

func _get_script(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _err("File not found: " + path)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _err("Cannot open file for reading: " + path)
	var content := f.get_as_text()
	f.close()
	return _ok(content)

func _update_script(path: String, content: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return _err("Cannot open file for writing: " + path)
	f.store_string(content)
	f.close()
	_ei().get_resource_filesystem().scan()
	return _ok("Written: " + path)

func _list_files(path: String, recursive: bool) -> Dictionary:
	var files: Array = []
	_collect_files(path.rstrip("/"), files, recursive)
	if files.is_empty():
		return _ok("(no files found in " + path + ")")
	return _ok("\n".join(files))

func _collect_files(path: String, files: Array, recursive: bool) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not fname.begins_with("."):
			var full := path + "/" + fname
			if dir.current_is_dir():
				files.append(full + "/")
				if recursive:
					_collect_files(full, files, true)
			else:
				files.append(full)
		fname = dir.get_next()
	dir.list_dir_end()

func _get_selected_nodes() -> Dictionary:
	var selection := _ei().get_selection()
	var nodes := selection.get_selected_nodes()
	var result: Array = []
	for node in nodes:
		result.append({
			"name": node.name,
			"type": node.get_class(),
			"path": str(node.get_path())
		})
	if result.is_empty():
		return _ok("No nodes selected.")
	return _ok(JSON.stringify(result, "\t"))

func _create_node(parent_path: String, node_type: String, node_name: String) -> Dictionary:
	var root := _scene_root()
	if root == null:
		return _err("No scene open.")
	var parent: Node
	if parent_path == "" or parent_path == ".":
		parent = root
	else:
		parent = root.get_node_or_null(parent_path)
		if parent == null:
			return _err("Parent node not found: " + parent_path)
	if not ClassDB.class_exists(node_type):
		return _err("Unknown node type: " + node_type)
	var node: Node = ClassDB.instantiate(node_type)
	node.name = node_name
	parent.add_child(node)
	node.set_owner(root)
	return _ok("Created %s '%s' under '%s'" % [node_type, node_name, str(parent.get_path())])

func _delete_node(node_path: String) -> Dictionary:
	var node := _resolve_node(node_path)
	if node == null:
		return _err("Node not found: " + node_path)
	if node == _scene_root():
		return _err("Cannot delete the scene root.")
	node.queue_free()
	return _ok("Deleted: " + node_path)

func _play_scene() -> Dictionary:
	_ei().play_current_scene()
	return _ok("Scene started.")

func _stop_scene() -> Dictionary:
	_ei().stop_playing_scene()
	return _ok("Scene stopped.")

func _save_scene() -> Dictionary:
	_ei().save_scene()
	return _ok("Scene saved.")

func _open_scene(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _err("Scene file not found: " + path)
	_ei().open_scene_from_path(path)
	return _ok("Opened: " + path)
