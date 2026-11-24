extends CharmCard
class_name Exorcism

const EFFECT_SOURCE := "Exorcism"
const ART_PATH := "res://images/card_art/charms/Exorcism.jpg"

func _init() -> void:
	super._init()
	card_name = "Exorcism"
	culture = "Ancient"
	card_types = ["Charm", "Healing"]
	if "Targeting" not in card_types:
		card_types.append("Targeting")
	level = 3
	mana_cost = 0
	speed = 3
	targets = true
	ability_text = "Cannot be negated. Choose a friendly creature. Clear all ongoing effects except its own, negate ongoing effects until the end of your next turn, and destroy any attached sources."
	artist = "Riccardo Zoppello"
	art_path = ART_PATH

func can_be_negated(_action: CardAction = null) -> bool:
	return false

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	if game_manager == null or card_owner == null:
		return valid_targets
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		var creature := zone.get_creature()
		if is_valid_target(creature):
			valid_targets.append(creature)
	return valid_targets

func is_valid_target(target: Card) -> bool:
	return target != null \
		and target.card_type == Card.CardType.CREATURE \
		and not target.is_god \
		and target.current_zone != null \
		and target.current_zone.is_board_zone() \
		and target.get_controller() == card_owner

func resolve(game_manager: GameManager, target = null) -> void:
	if not is_valid_target(target):
		print(card_name + " requires a friendly creature.")
		return
	if game_manager == null:
		return

	target.remove_status_effects_from_source_card(self, Card.EXTERNAL_EFFECT_NEGATION_STATUS)
	var cleared_entries: Array = target.clear_external_ongoing_effects()
	var expires_turn := _get_protection_expiry_turn(game_manager)
	target.add_status_effect(
		Card.EXTERNAL_EFFECT_NEGATION_STATUS,
		EFFECT_SOURCE,
		self,
		card_owner,
		{
			"expires_turn": expires_turn,
			"allow_while_negated": true,
		}
	)

	var destroyed_cards := _destroy_attached_sources(game_manager, target)
	var viewer: Player = game_manager.get_feedback_viewer()
	var target_name: String = target.get_target_log_display_name(viewer)
	var feedback: String = "%s exorcised %s, clearing all ongoing effects and negating new ones until the end of your next turn." % [card_name, target_name]
	var cleared_labels := _get_cleared_effect_labels(cleared_entries)
	if not cleared_labels.is_empty():
		feedback += " Cleared: " + ", ".join(cleared_labels) + "."
	if not destroyed_cards.is_empty():
		var names: Array[String] = []
		for destroyed_card in destroyed_cards:
			if destroyed_card != null:
				names.append(game_manager.get_resolved_destruction_log_name(destroyed_card, viewer, destroyed_card.card_name))
		if not names.is_empty():
			feedback += " Destroyed: " + ", ".join(names) + "."
	game_manager.note_player_feedback(feedback)
	print(feedback)

func _get_cleared_effect_labels(entries: Array) -> Array[String]:
	var labels: Array[String] = []
	var seen_status_names := {}
	for entry_value in entries:
		var entry := entry_value as Dictionary
		if entry.is_empty():
			continue
		if entry.has("name"):
			var status_name := str(entry.get("name", ""))
			if status_name == "" or seen_status_names.has(status_name):
				continue
			seen_status_names[status_name] = true
			labels.append(status_name.capitalize())
			continue
		var stat_parts: Array[String] = []
		var str_change := int(entry.get("str", 0))
		var res_change := int(entry.get("res", 0))
		var spd_change := int(entry.get("spd", 0))
		var lvl_change := int(entry.get("lvl", 0))
		if str_change != 0:
			stat_parts.append("%+d STR" % str_change)
		if res_change != 0:
			stat_parts.append("%+d RES" % res_change)
		if spd_change != 0:
			stat_parts.append("%+d SPD" % spd_change)
		if lvl_change != 0:
			stat_parts.append("%+d LVL" % lvl_change)
		if not stat_parts.is_empty():
			var stat_label := " ".join(stat_parts)
			if stat_label not in labels:
				labels.append(stat_label)
	return labels

func _get_protection_expiry_turn(game_manager: GameManager) -> int:
	if game_manager == null:
		return 0
	if card_owner != null and game_manager.current_player == card_owner:
		return game_manager.turn_number + 2
	return game_manager.turn_number + 1

# Ongoing effects are the enemy hexes still attached to the creature. Queued
# one-shot actions (Dalkhu Break-style reveals, resolving spells) are not
# ongoing effects, so they stay on the stack untouched.
func _destroy_attached_sources(game_manager: GameManager, target: Card) -> Array[Card]:
	var destroyed: Array[Card] = []
	if game_manager == null:
		return destroyed
	var opponent := game_manager.get_opponent(card_owner)
	if opponent == null:
		return destroyed
	var target_uid := str(target.uid).strip_edges()

	for zone in opponent.frontline_zones + opponent.reserve_zones + opponent.power_zones:
		for card in zone.cards.duplicate():
			if not (card is PermanentHexCard):
				continue
			var attached_hex := card as PermanentHexCard
			if not _same_card(attached_hex.attached_target, target, target_uid):
				continue
			game_manager.request_send_to_graveyard(attached_hex, func() -> void:
				if game_manager.reached_public_destroyed_destination(attached_hex) and attached_hex not in destroyed:
					destroyed.append(attached_hex)
			, false, true)

	return destroyed

func _same_card(candidate, target: Card, target_uid: String = "") -> bool:
	if not (candidate is Card) or target == null:
		return false
	var candidate_card := candidate as Card
	if candidate_card == target:
		return true
	var resolved_target_uid := target_uid if target_uid != "" else str(target.uid).strip_edges()
	return resolved_target_uid != "" and str(candidate_card.uid).strip_edges() == resolved_target_uid
