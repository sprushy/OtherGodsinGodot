extends PanelContainer
class_name ReinforcementDropArea

signal card_dropped(card_name: String, from_zone: String, to_zone: String)

var zone_name: String = ""
var drag_enabled: bool = true

func setup(p_zone_name: String) -> void:
	zone_name = p_zone_name
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.032, 0.042, 0.88)
	style.border_color = Color(0.22, 0.36, 0.52, 0.80) if zone_name == "main" else Color(0.72, 0.54, 0.24, 0.85)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side as Side, 2)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	add_theme_stylebox_override("panel", style)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not drag_enabled:
		return false
	if not (data is Dictionary):
		return false
	var payload := data as Dictionary
	if str(payload.get("type", "")) != "reinforcement_card":
		return false
	if str(payload.get("card_name", "")).strip_edges().is_empty():
		return false
	return str(payload.get("source_zone", "")) != zone_name

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	var payload := data as Dictionary
	card_dropped.emit(
		str(payload.get("card_name", "")),
		str(payload.get("source_zone", "")),
		zone_name
	)
