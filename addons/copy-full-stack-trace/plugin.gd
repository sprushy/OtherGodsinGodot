## Copy Full Stack Trace
@tool
extends EditorPlugin

const SETUP_RETRY_SECONDS := 0.5
const MAX_SETUP_RETRIES := 40

var _copy_button: Button
var _reason: RichTextLabel
var _threads: OptionButton
var _stack_dump: Tree
var _setup_timer: Timer
var _setup_attempts := 0


func _enter_tree() -> void:
	print("[CopyFullStackTrace] Plugin loaded; locating Stack Trace panel.")
	_setup_timer = Timer.new()
	_setup_timer.wait_time = SETUP_RETRY_SECONDS
	_setup_timer.one_shot = true
	_setup_timer.timeout.connect(_try_setup)
	add_child(_setup_timer)
	_setup_timer.start()


func _exit_tree() -> void:
	if is_instance_valid(_copy_button):
		_copy_button.queue_free()
	_copy_button = null
	_reason = null
	_threads = null
	_stack_dump = null
	_cleanup_setup_timer()


func _try_setup() -> void:
	var controls := _find_stack_trace_controls(EditorInterface.get_base_control())
	if controls.is_empty():
		_setup_attempts += 1
		if _setup_attempts < MAX_SETUP_RETRIES and is_instance_valid(_setup_timer):
			_setup_timer.start()
		else:
			push_warning("[CopyFullStackTrace] Could not find the Stack Trace panel.")
			_cleanup_setup_timer()
		return

	_reason = controls.reason
	_threads = controls.threads
	_stack_dump = controls.stack_dump
	_add_copy_full_button(controls.button_bar)
	print("[CopyFullStackTrace] Copy Full button added to Stack Trace.")
	_cleanup_setup_timer()


func _cleanup_setup_timer() -> void:
	if is_instance_valid(_setup_timer):
		_setup_timer.queue_free()
		_setup_timer = null


func _find_stack_trace_controls(node: Node) -> Dictionary:
	if node is VBoxContainer:
		var top_row: HBoxContainer
		var split: HSplitContainer

		for child in node.get_children():
			if child is HBoxContainer and top_row == null:
				top_row = child
			elif child is HSplitContainer and split == null:
				split = child

		if top_row != null and split != null:
			var reason: RichTextLabel
			var button_bar := top_row
			for child in top_row.get_children():
				if child is RichTextLabel:
					reason = child
				elif child is HBoxContainer:
					button_bar = child

			if reason != null:
				for split_child in split.get_children():
					if split_child is not VBoxContainer:
						continue

					var threads: OptionButton
					var stack_dump: Tree
					for panel_child in split_child.get_children():
						if panel_child is HBoxContainer:
							for row_child in panel_child.get_children():
								if row_child is OptionButton:
									threads = row_child
						elif panel_child is Tree:
							stack_dump = panel_child

					if threads != null and stack_dump != null:
						return {
							"reason": reason,
							"button_bar": button_bar,
							"threads": threads,
							"stack_dump": stack_dump,
						}

	for child in node.get_children():
		var controls := _find_stack_trace_controls(child)
		if not controls.is_empty():
			return controls

	return {}


func _add_copy_full_button(button_bar: HBoxContainer) -> void:
	_copy_button = Button.new()
	_copy_button.text = "Copy Full"
	_copy_button.tooltip_text = "Copy the full stack trace: active error, selected thread, and all frames"
	_copy_button.theme_type_variation = &"FlatButton"
	_copy_button.pressed.connect(_copy_active_trace)

	var theme := EditorInterface.get_editor_theme()
	if theme != null and theme.has_icon(&"ActionCopy", &"EditorIcons"):
		_copy_button.icon = theme.get_icon(&"ActionCopy", &"EditorIcons")

	button_bar.add_child(_copy_button)
	var insert_index := 0
	if _reason.get_parent() == button_bar:
		insert_index = _reason.get_index() + 1
	button_bar.move_child(_copy_button, insert_index)


func _copy_active_trace() -> void:
	if not is_instance_valid(_reason) or not is_instance_valid(_threads) or not is_instance_valid(_stack_dump):
		push_warning("[CopyFullStackTrace] Stack Trace controls are no longer valid.")
		return

	var root := _stack_dump.get_root()
	if root == null or root.get_first_child() == null:
		_flash_button("No Trace")
		return

	var output := PackedStringArray()
	var reason_text := _reason.text.strip_edges()
	if not reason_text.is_empty():
		output.append(reason_text)

	var selected_thread := _threads.get_selected()
	if selected_thread >= 0:
		output.append("Thread: %s" % _threads.get_item_text(selected_thread))

	output.append("")
	output.append("Stack Trace:")

	var frame_count := 0
	var item := root.get_first_child()
	while item != null:
		output.append(_format_stack_frame(item, frame_count))
		frame_count += 1
		item = item.get_next()

	DisplayServer.clipboard_set("\n".join(output))
	_flash_button("Copied %d" % frame_count)


func _format_stack_frame(item: TreeItem, fallback_index: int) -> String:
	var metadata: Variant = item.get_metadata(0)
	if metadata is Dictionary:
		var frame := int(metadata.get("frame", fallback_index))
		var file := str(metadata.get("file", ""))
		var line := int(metadata.get("line", 0))
		var function_name := str(metadata.get("function", ""))
		if function_name.is_empty():
			function_name = "<unknown>"
		return "%d - %s:%d - at function: %s" % [frame, file, line, function_name]

	return item.get_text(0).strip_edges()


func _flash_button(message: String) -> void:
	if not is_instance_valid(_copy_button):
		return

	_copy_button.text = message
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if is_instance_valid(_copy_button):
			_copy_button.text = "Copy Full"
	)
