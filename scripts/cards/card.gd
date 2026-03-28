# Card.gd
extends Resource
class_name Card

enum CardType { CREATURE, SPELL, EQUIPMENT, STRUCTURE, HEX, POWER, CHARM }
enum CreatureMode { AGGRESSIVE, DEFENSIVE }

@export var card_name: String
@export var card_type: CardType
@export var speed: int = 1
@export var level: int = 1
@export var is_legendary: bool = false
@export var is_god: bool = false
@export var is_power: bool = false
@export var is_token: bool = false
@export var can_be_used_for_creature_sacrifice: bool = true

# Card types (warrior, mage, etc.) - can have multiple
@export var card_types: Array[String] = []

# Lore and background
@export_multiline var flavor_text: String = ""
@export_multiline var ability_text: String = ""
@export var targets: bool = false  # True if this card's effect targets a specific card
@export var culture: String = ""  # e.g., "Sumerian", "Norse", "Egyptian"
@export var art_path: String = ""  # e.g., "res://images/card_art/hexes/VoidShield.jpg"
@export var artist: String = ""
@export var paragon_of_champions: String = ""  # Name of the champion type this god is patron of; empty if not a paragon
@export var name_at_bottom: bool = false  # If true, card name is rendered at the bottom instead of the top
@export var exhausted_art_path: String = ""  # Art to switch to when the card's effect is exhausted
@export var ability_immunity_tag: String = ""

signal art_updated(new_path: String)

const CARD_NAME_MOJIBAKE_FIXES := {
	"AurboÃƒÂ°a": "Aurboða",
	"AurboÃ°a": "Aurboða"
}

const CARD_NAME_ASCII_FALLBACKS := {
	"À": "A", "Á": "A", "Â": "A", "Ã": "A", "Ä": "A", "Å": "A",
	"Æ": "Ae", "Ç": "C", "È": "E", "É": "E", "Ê": "E", "Ë": "E",
	"Ì": "I", "Í": "I", "Î": "I", "Ï": "I", "Ð": "D", "Ñ": "N",
	"Ò": "O", "Ó": "O", "Ô": "O", "Õ": "O", "Ö": "O", "Ø": "O",
	"Ù": "U", "Ú": "U", "Û": "U", "Ü": "U", "Ý": "Y", "Þ": "Th",
	"ß": "ss",
	"à": "a", "á": "a", "â": "a", "ã": "a", "ä": "a", "å": "a",
	"æ": "ae", "ç": "c", "è": "e", "é": "e", "ê": "e", "ë": "e",
	"ì": "i", "í": "i", "î": "i", "ï": "i", "ð": "d", "ñ": "n",
	"ò": "o", "ó": "o", "ô": "o", "õ": "o", "ö": "o", "ø": "o",
	"ù": "u", "ú": "u", "û": "u", "ü": "u", "ý": "y", "þ": "th",
	"ÿ": "y", "Œ": "Oe", "œ": "oe", "Š": "S", "š": "s", "Ž": "Z",
	"ž": "z", "Ł": "L", "ł": "l"
}

func switch_to_exhausted_art() -> void:
	if exhausted_art_path != "":
		art_path = exhausted_art_path
		art_updated.emit(art_path)

# Costs
@export var mana_cost: int = 0
@export var discard_cost: int = 0  # Number of cards to discard
@export var sacrifice_cost: int = 0  # Number of creatures to sacrifice from board
@export var banish_cost: int = 0  # Number of cards to banish
@export var shelve_cost: int = 0  # Number of cards to shelve (return to bottom of deck)

# Creature stats
@export var strength: int = 0
@export var resilience: int = 0
@export var creature_mode: CreatureMode = CreatureMode.DEFENSIVE

# Equipment modifiers
@export var strength_modifier: int = 0
@export var resilience_modifier: int = 0
@export var speed_modifier: int = 0

# Card state - Changed "owner" to "card_owner" to avoid Godot reserved word
var card_owner: Player
var current_zone: Zone
var is_prepared: bool = false
# Tracks the last board position so Circle of Rebirth can auto-resurrect.
var last_board_zone_type: int = -1   # Zone.ZoneType value; -1 = never placed
var last_board_zone_index: int = Player.BOARD_LANE_COUNT / 2   # default centre column
var is_face_down: bool = false
var is_stealth: bool = false
var has_acted_this_turn: bool = false
var has_moved_this_turn: bool = false
var has_attacked_this_turn: bool = false
var creature_major_action_used: bool = false
var creature_minor_actions_used: int = 0
var is_sleeping: bool = false
var sleeping_from: Card = null
var equipped_on: Card = null
var equipment: Array[Card] = []
var summoned_this_turn: bool = false
var board_entry_order: int = -1
var is_used: bool = false          # for single-use activatable abilities on powers
var is_muted: bool = false
var mute_turns_remaining: int = 0
var _mute_applied_owner_turn_number: int = -1

# Runtime stat buffs: Array of {source: String, str: int, res: int, spd: int}
var active_buffs: Array[Dictionary] = []
var active_statuses: Array[Dictionary] = []
var _was_muted_last_check: bool = false
var _pending_chosen_discards: Array[Card] = []

const EXTERNAL_EFFECT_NEGATION_STATUS := "external_effect_negation"
const COST_KIND_POWER_UNLOCK := "power_unlock"
const COST_KIND_POWER_ACTIVATION := "power_activation"
const COST_KIND_CREATURE_SUMMON := "creature_summon"

func get_controller() -> Player:
	if current_zone != null and current_zone.is_board_zone() and current_zone.zone_owner != null:
		return current_zone.zone_owner
	return card_owner

func get_normalized_card_name() -> String:
	return card_name

func get_ascii_card_name() -> String:
	var normalized := get_normalized_card_name()
	var fallback := ""
	for i in normalized.length():
		var codepoint := normalized.unicode_at(i)
		if codepoint >= 32 and codepoint <= 126:
			fallback += normalized[i]
		else:
			fallback += _get_ascii_fallback_for_codepoint(codepoint)
	return fallback

func _get_ascii_fallback_for_codepoint(codepoint: int) -> String:
	match codepoint:
		192, 193, 194, 195, 196, 197:
			return "A"
		198:
			return "Ae"
		199:
			return "C"
		200, 201, 202, 203:
			return "E"
		204, 205, 206, 207:
			return "I"
		208:
			return "D"
		209:
			return "N"
		210, 211, 212, 213, 214, 216:
			return "O"
		217, 218, 219, 220:
			return "U"
		221:
			return "Y"
		222:
			return "Th"
		223:
			return "ss"
		224, 225, 226, 227, 228, 229:
			return "a"
		230:
			return "ae"
		231:
			return "c"
		232, 233, 234, 235:
			return "e"
		236, 237, 238, 239:
			return "i"
		240:
			return "d"
		241:
			return "n"
		242, 243, 244, 245, 246, 248:
			return "o"
		249, 250, 251, 252:
			return "u"
		253, 255:
			return "y"
		254:
			return "th"
		338:
			return "Oe"
		339:
			return "oe"
		352:
			return "S"
		353:
			return "s"
		381:
			return "Z"
		382:
			return "z"
		321:
			return "L"
		322:
			return "l"
		_:
			return "?"

func get_display_name(prefer_ascii: bool = false, font: Font = null) -> String:
	var normalized := get_normalized_card_name()
	if prefer_ascii:
		return get_ascii_card_name()
	if font != null:
		for i in normalized.length():
			if not font.has_char(normalized.unicode_at(i)):
				return get_ascii_card_name()
	return normalized

func get_display_name_for_control(control: Control = null, prefer_ascii: bool = false) -> String:
	if control == null:
		return get_display_name(prefer_ascii)
	return get_display_name(prefer_ascii, control.get_theme_font("font"))

func is_hidden_from_viewer(viewer: Player = null) -> bool:
	if viewer == null:
		return false
	var controller := get_controller()
	var publicly_revealed_power := self is PowerCard and (self as PowerCard).is_publicly_revealed
	var hidden_face_down := (is_face_down or is_prepared) and not publicly_revealed_power
	return (is_stealth or hidden_face_down) \
		and controller != null \
		and controller != viewer \
		and not is_temporarily_revealed()

func get_log_display_name(
	viewer: Player = null,
	hidden_fallback: String = "Hidden card",
	prefer_ascii: bool = false,
	font: Font = null
) -> String:
	if is_hidden_from_viewer(viewer):
		return hidden_fallback
	return get_display_name(prefer_ascii, font)

func get_hidden_log_position_label() -> String:
	var zone := current_zone
	if zone == null:
		return "a hidden card"
	var controller := get_controller()
	if controller == null:
		controller = card_owner
	var owner_prefix := controller.player_name + "'s " if controller != null and controller.player_name != "" else ""
	match zone.zone_type:
		Zone.ZoneType.FRONTLINE:
			return owner_prefix + "Front Line position " + str(zone.zone_index + 1)
		Zone.ZoneType.RESERVE:
			return owner_prefix + "Reserve Line position " + str(zone.zone_index + 1)
		Zone.ZoneType.POWER_SLOT:
			return owner_prefix + "Power slot " + str(zone.zone_index + 1)
		Zone.ZoneType.GOD_SLOT:
			return owner_prefix + "God slot"
	return owner_prefix + "position " + str(zone.zone_index + 1)

func get_target_log_display_name(viewer: Player = null) -> String:
	if current_zone != null and current_zone.zone_type in [Zone.ZoneType.GRAVEYARD, Zone.ZoneType.ABYSS]:
		return get_display_name()
	if is_hidden_from_viewer(viewer):
		return get_hidden_log_position_label()
	return get_display_name()

func is_enslaved() -> bool:
	var controller := get_controller()
	return controller != null and card_owner != null and controller != card_owner

func has_status_effect(status_name: String) -> bool:
	for status in _get_effective_statuses():
		if status.get("name", "") == status_name:
			return true
	return false

func get_status_effect(status_name: String) -> Dictionary:
	for status in _get_effective_statuses():
		if status.get("name", "") == status_name:
			return status
	return {}

func is_petrified() -> bool:
	return has_status_effect("petrified")

func is_temporarily_revealed() -> bool:
	return has_status_effect("temporarily_revealed")

func temporarily_reveal_until_end_of_turn(
	current_turn: int,
	source: String,
	source_card: Card = null,
	source_owner: Player = null,
	game_manager: GameManager = null
) -> void:
	var was_visible: bool = is_temporarily_revealed()
	if self is PowerCard and (self as PowerCard).is_publicly_revealed:
		was_visible = true
	var was_hidden: bool = (is_face_down or is_stealth) and not was_visible
	remove_status_effects_by_name("temporarily_revealed")
	add_status_effect(
		"temporarily_revealed",
		source,
		source_card,
		source_owner,
		{"expires_turn": current_turn}
	)
	if was_hidden and game_manager != null:
		on_reveal(game_manager)

func is_activation_locked(game_manager: GameManager = null) -> bool:
	if not has_status_effect("activation_locked"):
		return false
	if game_manager == null:
		return true
	for status in _get_effective_statuses():
		if status.get("name", "") != "activation_locked":
			continue
		var expires_turn = status.get("expires_turn", null)
		if expires_turn == null:
			return true
		return int(expires_turn) >= game_manager.turn_number
	return false

func lock_activation_until_end_of_turn(
	current_turn: int,
	source: String,
	source_card: Card = null,
	source_owner: Player = null
) -> void:
	remove_status_effects_by_name("activation_locked")
	add_status_effect(
		"activation_locked",
		source,
		source_card,
		source_owner,
		{"expires_turn": current_turn}
	)

func is_silenced() -> bool:
	return is_muted and mute_turns_remaining < 0

func abilities_suppressed() -> bool:
	return is_enslaved() or is_petrified() or is_muted

func get_effective_speed() -> int:
	var base_speed = speed
	if is_stealth:
		base_speed -= 1
	for equip in equipment:
		base_speed += equip.speed_modifier
	for buff in _get_effective_buffs():
		base_speed += buff.get("spd", 0)
	return max(1, base_speed)

func get_effective_strength() -> int:
	var total = strength
	for equip in equipment:
		total += equip.strength_modifier
	for buff in _get_effective_buffs():
		total += buff.get("str", 0)
	return total

func get_effective_resilience() -> int:
	var total = resilience
	for equip in equipment:
		total += equip.resilience_modifier
	for buff in _get_effective_buffs():
		total += buff.get("res", 0)
	return total

# Returns a human-readable breakdown of all active buffs for a stat ("str", "res", "spd")
func get_buff_tooltip(stat: String) -> String:
	var lines: Array[String] = []
	for buff in _get_effective_buffs():
		var v: int = buff.get(stat, 0)
		if v != 0:
			lines.append(("+%d" % v if v > 0 else "%d" % v) + " from " + buff.get("source", "?"))
	return "\n".join(lines)

# Returns a full breakdown including equipment modifiers and buffs, e.g. "21 +5 Bearded Axe"
# Returns empty string if no modifiers are active.
func get_full_stat_breakdown(stat: String) -> String:
	var base: int
	match stat:
		"str": base = strength
		"res": base = resilience
		"spd": base = speed
		_: return ""
	var lines: Array[String] = []
	for equip in equipment:
		var v: int
		match stat:
			"str": v = equip.strength_modifier
			"res": v = equip.resilience_modifier
			"spd": v = equip.speed_modifier
			_: v = 0
		if v != 0:
			lines.append(("+%d" % v if v > 0 else "%d" % v) + " " + equip.card_name)
	for buff in _get_effective_buffs():
		var v: int = buff.get(stat, 0)
		if v != 0:
			lines.append(("+%d" % v if v > 0 else "%d" % v) + " from " + buff.get("source", "?"))
	if lines.is_empty():
		return ""
	return str(base) + " " + " ".join(lines)

func get_effect_summary_lines() -> Array[String]:
	var lines: Array[String] = []
	for buff in _get_effective_buffs():
		var parts: Array[String] = []
		var str_change: int = buff.get("str", 0)
		var res_change: int = buff.get("res", 0)
		var spd_change: int = buff.get("spd", 0)
		if str_change != 0:
			parts.append(("STR %+d" % str_change))
		if res_change != 0:
			parts.append(("RES %+d" % res_change))
		if spd_change != 0:
			parts.append(("SPD %+d" % spd_change))
		if parts.size() == 0:
			continue
		lines.append(", ".join(parts) + " from " + str(buff.get("source", "?")))

	for status in _get_effective_statuses():
		var raw_status_name := str(status.get("name", "Status"))
		if raw_status_name == "blessed_ward":
			var ward_kind := str(status.get("ward_kind", "")).replace("_", " ")
			lines.append("Blessed Ward vs " + ward_kind.capitalize() + " from " + str(status.get("source", "?")))
			continue
		if raw_status_name == "cannot_attack":
			lines.append("Cannot attack from " + str(status.get("source", "?")))
			continue
		if raw_status_name == "temporarily_revealed":
			lines.append("Revealed until end of turn by " + str(status.get("source", "?")))
			continue
		if raw_status_name == "activation_locked":
			lines.append("Cannot activate this turn from " + str(status.get("source", "?")))
			continue
		var status_name := raw_status_name.capitalize()
		lines.append(status_name + " from " + str(status.get("source", "?")))

	return lines

func get_equipment_modifier_summary_parts() -> Array[String]:
	var parts: Array[String] = []
	if strength_modifier != 0:
		parts.append("STR %+d" % strength_modifier)
	if resilience_modifier != 0:
		parts.append("RES %+d" % resilience_modifier)
	if speed_modifier != 0:
		parts.append("SPD %+d" % speed_modifier)
	return parts

func get_equipment_summary_label() -> String:
	var parts := get_equipment_modifier_summary_parts()
	if parts.is_empty():
		return card_name
	return "%s (%s)" % [card_name, ", ".join(parts)]

func get_inline_ability_summary() -> String:
	var summary := ability_text.strip_edges().replace("\n", " ")
	while summary.contains("  "):
		summary = summary.replace("  ", " ")
	return summary

func get_adjusted_mana_cost(
	base_cost: int,
	cost_kind: String,
	game_manager: GameManager = null,
	metadata: Dictionary = {}
) -> int:
	if game_manager == null:
		return maxi(0, base_cost)
	return maxi(0, base_cost + game_manager.get_total_cost_adjustment(self, base_cost, cost_kind, metadata))

func get_cost_adjustment_lines(
	base_cost: int,
	cost_kind: String,
	game_manager: GameManager = null,
	metadata: Dictionary = {}
) -> Array[String]:
	var lines: Array[String] = []
	if game_manager == null:
		return lines
	for entry in game_manager.get_cost_adjustment_entries(self, base_cost, cost_kind, metadata):
		var delta := int(entry.get("delta", 0))
		if delta == 0:
			continue
		lines.append(("%+d" % delta) + " from " + str(entry.get("source", "?")))
	return lines

func get_cost_adjustment_entries(
	_target_card: Card,
	_base_cost: int,
	_cost_kind: String,
	_game_manager: GameManager,
	_metadata: Dictionary = {}
) -> Array[Dictionary]:
	return []

func claim_cost_adjustment(
	_target_card: Card,
	_base_cost: int,
	_cost_kind: String,
	_game_manager: GameManager,
	_metadata: Dictionary = {}
) -> bool:
	return false

func get_hover_detail_lines(_viewer: Player = null) -> Array[String]:
	return []

func get_equipment_summary_lines() -> Array[String]:
	var lines: Array[String] = []
	for equip in equipment:
		if equip == null:
			continue
		var line := equip.get_equipment_summary_label()
		var effect_lines := equip.get_effect_summary_lines()
		if effect_lines.is_empty():
			var ability_summary := equip.get_inline_ability_summary()
			if ability_summary != "":
				effect_lines.append(ability_summary)
		if effect_lines.is_empty():
			lines.append(line)
		else:
			lines.append(line + ": " + " | ".join(effect_lines))
	return lines

func clear_buffs_from(source: String) -> void:
	active_buffs = active_buffs.filter(func(b): return b.get("source", "") != source)

func remove_buffs_from_source_card(source_card: Card, effect_type: String = "") -> void:
	active_buffs = active_buffs.filter(func(b):
		var same_source: bool = b.get("source_card", null) == source_card
		var same_effect_type: bool = effect_type == "" or b.get("effect_type", "") == effect_type
		return not (same_source and same_effect_type)
	)

func add_buff(
	source: String,
	str_bonus: int,
	res_bonus: int,
	spd_bonus: int,
	source_card: Card = null,
	source_owner: Player = null,
	effect_type: String = "buff",
	extra_metadata: Dictionary = {}
) -> void:
	var buff := {
		"source": source,
		"str": str_bonus,
		"res": res_bonus,
		"spd": spd_bonus,
		"source_card": source_card,
		"source_owner": source_owner,
		"effect_type": effect_type,
	}
	for key in extra_metadata.keys():
		buff[key] = extra_metadata[key]
	active_buffs.append(buff)

func add_status_effect(
	status_name: String,
	source: String,
	source_card: Card = null,
	source_owner: Player = null,
	extra_metadata: Dictionary = {}
) -> void:
	var status := {
		"name": status_name,
		"source": source,
		"source_card": source_card,
		"source_owner": source_owner,
	}
	for key in extra_metadata.keys():
		status[key] = extra_metadata[key]
	active_statuses.append(status)
	_sync_status_flags()

func remove_status_effects_by_name(status_name: String) -> void:
	active_statuses = active_statuses.filter(func(s): return s.get("name", "") != status_name)
	_sync_status_flags()

func remove_status_effects_from_source_card(source_card: Card, status_name: String = "") -> void:
	active_statuses = active_statuses.filter(func(s):
		var same_source: bool = s.get("source_card", null) == source_card
		var same_status: bool = status_name == "" or s.get("name", "") == status_name
		return not (same_source and same_status)
	)
	_sync_status_flags()

func remove_expired_buffs(current_turn: int) -> void:
	active_buffs = active_buffs.filter(func(b):
		var expires_turn = b.get("expires_turn", null)
		if expires_turn == null:
			return true
		return int(expires_turn) > current_turn
	)

func remove_expired_statuses(current_turn: int) -> void:
	active_statuses = active_statuses.filter(func(s):
		var expires_turn = s.get("expires_turn", null)
		if expires_turn == null:
			return true
		return int(expires_turn) > current_turn
	)
	_sync_status_flags()

func remove_effects_expiring_after_combat() -> void:
	active_buffs = active_buffs.filter(func(b): return b.get("expires_after_combat", false) != true)
	active_statuses = active_statuses.filter(func(s): return s.get("expires_after_combat", false) != true)
	_sync_status_flags()

func has_effects_from_player(player: Player) -> bool:
	for buff in active_buffs:
		if buff.get("source_owner", null) == player:
			return true
	for status in active_statuses:
		if status.get("source_owner", null) == player:
			return true
	return false

func remove_effects_from_player(player: Player) -> void:
	active_buffs = active_buffs.filter(func(b): return b.get("source_owner", null) != player)
	active_statuses = active_statuses.filter(func(s): return s.get("source_owner", null) != player)
	_sync_status_flags()

func apply_sleep(source_card: Card) -> void:
	remove_status_effects_by_name("sleep")
	add_status_effect("sleep", source_card.card_name if source_card != null else "Sleep", source_card, source_card.card_owner if source_card != null else null)

func wake_up() -> void:
	remove_status_effects_by_name("sleep")

func clear_all_effects() -> void:
	active_buffs.clear()
	active_statuses.clear()
	_sync_status_flags()

func _sync_status_flags() -> void:
	var sleep_status: Dictionary = {}
	for status in _get_effective_statuses():
		if status.get("name", "") == "sleep":
			sleep_status = status
			break
	is_sleeping = not sleep_status.is_empty()
	sleeping_from = sleep_status.get("source_card", null) if is_sleeping else null

func can_respond_to(other_card: Card) -> bool:
	return get_effective_speed() >= 2 and get_effective_speed() >= other_card.get_effective_speed()

func is_permanent() -> bool:
	return has_type("Permanent") or card_type in [CardType.CREATURE, CardType.EQUIPMENT, CardType.STRUCTURE, CardType.POWER]

func goes_to_graveyard_after_use() -> bool:
	return not is_permanent() and card_type in [CardType.SPELL, CardType.HEX, CardType.CHARM]

func get_ability_immunity_tag() -> String:
	if ability_immunity_tag != "":
		return ability_immunity_tag
	if is_god:
		return "powers"
	match card_type:
		CardType.CREATURE:
			return "creature_abilities"
		CardType.POWER:
			return "powers"
		CardType.HEX:
			return "hexes"
	return ""

func can_be_negated(_action: CardAction = null) -> bool:
	return true

func negates_external_effects() -> bool:
	for status in active_statuses:
		if status.get("name", "") == EXTERNAL_EFFECT_NEGATION_STATUS:
			return true
	return false

func _get_effective_buffs() -> Array[Dictionary]:
	if not negates_external_effects():
		return active_buffs
	var filtered: Array[Dictionary] = []
	for buff in active_buffs:
		if not _is_external_effect_entry(buff):
			filtered.append(buff)
	return filtered

func _get_effective_statuses() -> Array[Dictionary]:
	if not negates_external_effects():
		return active_statuses
	var filtered: Array[Dictionary] = []
	for status in active_statuses:
		if not _is_external_effect_entry(status):
			filtered.append(status)
	return filtered

func _is_external_effect_entry(entry: Dictionary) -> bool:
	if entry.get("allow_while_negated", false) == true:
		return false
	return entry.get("source_card", null) != self

func mute_for_turns(turns: int, game_manager: GameManager = null) -> void:
	var was_muted := is_muted
	is_muted = turns > 0
	mute_turns_remaining = max(0, turns)
	_mute_applied_owner_turn_number = -1
	if game_manager != null and game_manager.current_player == card_owner:
		_mute_applied_owner_turn_number = game_manager.turn_number
	_process_mute_state_change(game_manager, was_muted)

func mute_permanently(game_manager: GameManager = null) -> void:
	var was_muted := is_muted
	is_muted = true
	mute_turns_remaining = -1
	_mute_applied_owner_turn_number = -1
	_process_mute_state_change(game_manager, was_muted)

func on_turn_end(game_manager: GameManager) -> void:
	var was_muted := is_muted
	if not is_muted:
		return
	if mute_turns_remaining < 0:
		return
	if game_manager != null and game_manager.current_player == card_owner and game_manager.turn_number == _mute_applied_owner_turn_number:
		return
	if mute_turns_remaining > 0:
		mute_turns_remaining -= 1
	if mute_turns_remaining <= 0:
		is_muted = false
		mute_turns_remaining = 0
		_mute_applied_owner_turn_number = -1
	_process_mute_state_change(game_manager, was_muted)

# Called for all board/god/power permanents whenever any player's turn begins.
# Use this for effects keyed to "a turn started", not specifically "your turn started".
func on_global_turn_start(_game_manager: GameManager, _starting_player: Player) -> void:
	pass

# Called for all board/god/power permanents whenever any player's turn ends.
# Use this for effects keyed to "end of turn" regardless of controller.
func on_global_turn_end(_game_manager: GameManager, _ending_player: Player) -> void:
	pass

func _process_mute_state_change(game_manager: GameManager, was_muted: bool) -> void:
	if was_muted == is_muted:
		return
	_was_muted_last_check = is_muted
	if is_muted:
		on_muted(game_manager)
	else:
		on_unmuted(game_manager)

func on_muted(_game_manager: GameManager) -> void:
	pass

func on_unmuted(_game_manager: GameManager) -> void:
	pass

func on_reveal(_game_manager: GameManager) -> void:
	pass

func reveal(game_manager: GameManager = null) -> void:
	var was_hidden: bool = is_face_down or is_stealth
	is_face_down = false
	is_stealth = false
	# Reveal triggers whenever a card becomes visible from a hidden state,
	# even if that same card was revealed earlier and later became hidden again.
	if was_hidden and game_manager != null:
		on_reveal(game_manager)

func has_type(type_name: String) -> bool:
	if type_name == "Physical":
		return is_physical_card()
	if type_name == "Magic" or type_name == "Magical":
		return is_magical_card()
	return type_name in card_types

func get_intercept_reach_bonus() -> int:
	if card_type != CardType.CREATURE or ability_text == "":
		return 0
	var normalized := " " + ability_text.to_lower() + " "
	for token in ["[b]", "[/b]", "\n", "\t", ",", ".", ":", ";", "!", "?", "(", ")", "[", "]"]:
		normalized = normalized.replace(token, " ")
	if normalized.contains(" reach +1 "):
		return 1
	if normalized.contains(" reach "):
		return 1
	return 0

func is_physical_card() -> bool:
	return card_type in [CardType.CREATURE, CardType.STRUCTURE, CardType.EQUIPMENT]

func is_magical_card() -> bool:
	return card_type in [CardType.SPELL, CardType.HEX, CardType.CHARM]

func equip_to(creature: Card) -> bool:
	if card_type != CardType.EQUIPMENT or creature.card_type != CardType.CREATURE:
		return false
	
	if equipped_on:
		equipped_on.equipment.erase(self)
	
	equipped_on = creature
	creature.equipment.append(self)
	return true

func unequip() -> void:
	if equipped_on:
		equipped_on.equipment.erase(self)
		equipped_on = null

func reveal_from_stealth(game_manager: GameManager = null) -> void:
	if is_stealth:
		reveal(game_manager)

func reset_creature_action_state() -> void:
	has_acted_this_turn = false
	has_moved_this_turn = false
	has_attacked_this_turn = false
	creature_major_action_used = false
	creature_minor_actions_used = 0

func can_take_major_creature_action() -> bool:
	return not creature_major_action_used and creature_minor_actions_used < 2

func can_take_minor_creature_action() -> bool:
	return not creature_major_action_used and creature_minor_actions_used < 2

func spend_major_creature_action() -> void:
	creature_major_action_used = true
	has_acted_this_turn = true

func spend_minor_creature_action(marked_as_move: bool = false) -> void:
	creature_minor_actions_used += 1
	if marked_as_move:
		has_moved_this_turn = true
	if creature_minor_actions_used >= 2:
		has_acted_this_turn = true

func mark_attacked_this_turn() -> void:
	has_attacked_this_turn = true

func can_prepare(game_manager: GameManager, player: Player) -> bool:
	if game_manager == null or player == null:
		return false
	if card_owner != null and card_owner != player:
		return false
	if player != game_manager.current_player:
		return false
	if player.hand_zone == null or current_zone != player.hand_zone:
		return false
	return can_pay_costs(player)

func can_pay_costs(player: Player) -> bool:
	return can_pay_costs_with_mana_cost(player, mana_cost)

func can_pay_costs_with_mana_cost(player: Player, mana_required: int) -> bool:
	# Check if player can afford all costs
	if player.mana < mana_required:
		return false
	if player.hand_zone.get_card_count() < discard_cost:
		return false
	if player.hand_zone.get_card_count() < shelve_cost:
		return false
	
	# Count creatures on board for sacrifice costs.
	var creature_count = 0
	for zone in player.frontline_zones + player.reserve_zones:
		for card in zone.cards:
			if card.card_type == CardType.CREATURE and card.can_be_used_for_creature_sacrifice:
				creature_count += 1
	if creature_count < sacrifice_cost:
		return false
	
	# Check cards available to banish (hand + board)
	var banishable = player.hand_zone.get_card_count()
	for zone in player.frontline_zones + player.reserve_zones:
		banishable += zone.get_card_count()
	if banishable < banish_cost:
		return false
	
	return true

func requires_chosen_hand_discards() -> bool:
	return discard_cost > 0

func get_valid_play_discards(player: Player) -> Array[Card]:
	var choices: Array[Card] = []
	if player == null or player.hand_zone == null:
		return choices
	for card in player.hand_zone.cards:
		if card != null and card != self:
			choices.append(card)
	return choices

func set_pending_chosen_discards(cards: Array[Card]) -> void:
	_pending_chosen_discards = cards.duplicate()

func clear_pending_chosen_discards() -> void:
	_pending_chosen_discards.clear()

func has_pending_chosen_discards_for_cost() -> bool:
	if discard_cost <= 0:
		return true
	if _pending_chosen_discards.size() < discard_cost:
		return false
	for i in range(discard_cost):
		var card := _pending_chosen_discards[i]
		if card == null or card == self or card.current_zone != card_owner.hand_zone:
			return false
	return true

func pay_costs(player: Player, game_manager: GameManager = null) -> bool:
	return pay_costs_with_mana_cost(player, mana_cost, game_manager)

func pay_costs_with_mana_cost(player: Player, mana_required: int, game_manager: GameManager = null) -> bool:
	if not can_pay_costs_with_mana_cost(player, mana_required):
		return false
	
	# Pay mana cost
	if mana_required > 0:
		player.spend_mana(mana_required)
	
	# Pay discard cost
	for i in range(discard_cost):
		if _pending_chosen_discards.size() > i:
			var chosen_discard := _pending_chosen_discards[i]
			if chosen_discard != null and chosen_discard.current_zone == player.hand_zone and chosen_discard != self:
				player.discard_card(chosen_discard)
				continue
		if player.hand_zone.get_card_count() > 0:
			var card_to_discard = player.hand_zone.cards[0]
			if card_to_discard == self and player.hand_zone.get_card_count() > 1:
				card_to_discard = player.hand_zone.cards[1]
			if card_to_discard != self:
				player.discard_card(card_to_discard)

	clear_pending_chosen_discards()
	
	# Pay sacrifice cost.
	if sacrifice_cost > 0:
		for i in range(sacrifice_cost):
			var creature_found = false
			for zone in player.frontline_zones + player.reserve_zones:
				if creature_found:
					break
				for card in zone.cards:
					if card.card_type == CardType.CREATURE and card.can_be_used_for_creature_sacrifice:
						if game_manager != null:
							game_manager._send_to_graveyard_with_hook(card, false, false)
						else:
							player.move_card(card, player.graveyard_zone)
						if card.has_method("on_sacrificed_for_summon") and not card.abilities_suppressed():
							card.on_sacrificed_for_summon(game_manager, self)
						creature_found = true
						break
	
	# Pay shelve cost
	for i in range(shelve_cost):
		if player.hand_zone.get_card_count() > 0:
			var card_to_shelve = player.hand_zone.cards[0]
			player.shelve_card(card_to_shelve)
	
	# Pay banish cost
	for i in range(banish_cost):
		var card_found = false
		# Try hand first
		if player.hand_zone.get_card_count() > 0:
			var card_to_banish = player.hand_zone.cards[0]
			player.banish_card(card_to_banish)
			card_found = true
		# Then board
		if not card_found:
			for zone in player.frontline_zones + player.reserve_zones:
				if zone.get_card_count() > 0:
					var card_to_banish = zone.cards[0]
					if game_manager != null:
						game_manager._send_to_abyss_with_hook(card_to_banish)
					else:
						player.banish_card(card_to_banish)
					break
	
	return true
