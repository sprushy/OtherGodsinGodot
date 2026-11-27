extends RefCounted

## Shared Necoc Yaotl blood-streak overlay. BoardZoneUI pins these to the
## Tezcatlipoca sacrifice badge to count stored sacrifices; RankBadge reuses
## the same streaks to mark a player's Bo3 series wins while observing.

const TEXTURE := preload("res://images/Bloodstreak.png")
const OFFSETS := [
	{"left": 0.0, "right": 0.0},
	{"left": -16.0, "right": -16.0},
	{"left": 16.0, "right": 16.0},
]

## Adds up to OFFSETS.size() streak children to parent and returns them so
## callers that need to clear them later can free exactly those nodes.
static func attach(parent: Control, streak_count: int) -> Array[TextureRect]:
	var streaks: Array[TextureRect] = []
	if parent == null:
		return streaks
	for i in range(clampi(streak_count, 0, OFFSETS.size())):
		var streak := TextureRect.new()
		streak.texture = TEXTURE
		streak.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		streak.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
		streak.z_index = 2
		streak.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var pos: Dictionary = OFFSETS[i]
		streak.offset_left = float(pos.get("left", 0.0))
		streak.offset_right = float(pos.get("right", 0.0))
		streak.offset_top = 6.0
		streak.offset_bottom = -6.0
		streak.modulate = Color(1.0, 1.0, 1.0, 0.92)
		parent.add_child(streak)
		streaks.append(streak)
	return streaks
