extends BaseCard
class_name EquipmentCard

const EQUIPPED_AFFORDANCE_SIZE := Vector2(24, 32)

func _init() -> void:
	super._init()
	card_type = CardType.EQUIPMENT

func create_equipped_affordance(size: Vector2 = EQUIPPED_AFFORDANCE_SIZE) -> Control:
	var affordance := PanelContainer.new()
	affordance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	affordance.custom_minimum_size = size
	affordance.clip_contents = true

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.08, 0.06, 0.96)
	style.border_color = Color(0.96, 0.84, 0.58, 0.95)
	style.shadow_color = Color(0.02, 0.02, 0.02, 0.45)
	style.shadow_size = 4
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
	affordance.add_theme_stylebox_override("panel", style)

	var art := TextureRect.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 1
	art.offset_top = 1
	art.offset_right = -1
	art.offset_bottom = -1

	var texture: Texture2D = null
	if art_path != "":
		texture = load(art_path) as Texture2D
	if texture != null:
		art.texture = texture
		affordance.add_child(art)
		var sheen := ColorRect.new()
		sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sheen.color = Color(1.0, 0.94, 0.82, 0.08)
		sheen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		affordance.add_child(sheen)
	else:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = card_name.left(3).to_upper()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.82))
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		affordance.add_child(label)

	return affordance

# Called when this equipment is attached to a creature
func on_equip(_creature: Card) -> void:
	pass

# Return extra STR when the equipped creature attacks a defensive-stance defender.
# Override in specific equipment cards for conditional bonuses.
func get_bonus_strength_vs_defense(_attacker: Card) -> int:
	return 0
