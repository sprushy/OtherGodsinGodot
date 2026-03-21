@tool
extends Control

var status_label: Label
var log_display: TextEdit

func _ready() -> void:
	status_label = $VBoxContainer/StatusPanel/StatusLabel
	log_display  = $VBoxContainer/LogPanel/LogDisplay

func update_status(text: String) -> void:
	if status_label:
		status_label.text = "Status: " + text

func add_log(msg: String) -> void:
	if log_display:
		log_display.text += "[%s] %s\n" % [Time.get_datetime_string_from_system(), msg]
		log_display.scroll_vertical = log_display.get_line_count()
