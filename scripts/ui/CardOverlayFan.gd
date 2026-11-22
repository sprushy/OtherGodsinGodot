extends Control

# Keep small selections centered; scroll large selections rather than hiding
# targets behind a tightly packed hand. Reserve space for rotation and glow.
const EDGE_PADDING := 40.0
const MIN_CARD_STEP := 100.0
const MAX_TILT_DEGREES := 4.0
const ARC_DROP := 10.0

var _items: Array[Control] = []
var _layout_pending := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	resized.connect(refresh_layout)
	refresh_layout()

func add_card(item: Control) -> void:
	_items.append(item)
	add_child(item)
	item.minimum_size_changed.connect(refresh_layout)
	item.mouse_entered.connect(func() -> void:
		item.z_index = 1
		move_child.call_deferred(item, get_child_count() - 1)
	)
	item.mouse_exited.connect(func() -> void:
		item.z_index = 0
		move_child.call_deferred(item, _items.find(item))
	)
	refresh_layout()

func refresh_layout() -> void:
	if _layout_pending or not is_inside_tree():
		return
	_layout_pending = true
	call_deferred("_layout_cards")

func _layout_cards() -> void:
	_layout_pending = false
	var visible_items: Array[Control] = []
	var card_size := Vector2.ZERO
	for item in _items:
		# Use one footprint for the whole collection, including filtered cards.
		card_size = card_size.max(item.get_combined_minimum_size())
		if not item.visible:
			continue
		visible_items.append(item)
	if visible_items.is_empty():
		custom_minimum_size = Vector2.ZERO
		return

	var count := visible_items.size()
	var max_tilt := deg_to_rad(MAX_TILT_DEGREES) if count > 1 else 0.0
	var rotated_height := card_size.y + card_size.x * sin(max_tilt)
	custom_minimum_size = Vector2(
		card_size.x + float(count - 1) * MIN_CARD_STEP + EDGE_PADDING * 2.0,
		rotated_height + ARC_DROP + EDGE_PADDING * 2.0
	)
	var available_width := maxf(size.x, custom_minimum_size.x)
	var available_height := maxf(size.y, custom_minimum_size.y)
	var step := 0.0
	if count > 1:
		step = minf(card_size.x + 12.0, (available_width - card_size.x - EDGE_PADDING * 2.0) / float(count - 1))
	var span := float(count - 1) * step
	for index in range(count):
		var item := visible_items[index]
		item.size = card_size
		item.pivot_offset = item.size * 0.5
		var offset := float(index) / float(count - 1) * 2.0 - 1.0 if count > 1 else 0.0
		item.rotation = offset * max_tilt
		var center := Vector2(
			available_width * 0.5 - span * 0.5 + float(index) * step,
			available_height * 0.5 - ARC_DROP * 0.5 + offset * offset * ARC_DROP
		)
		item.position = center - item.size * 0.5
