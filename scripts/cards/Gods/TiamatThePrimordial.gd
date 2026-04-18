extends GodCard
class_name TiamatThePrimordial

const TIAMAT_CARD_NAME := "Tiamat, the Primordial"
const TIAMAT_SLOT_KEY := "tiamat_slots"
const MAX_SLOT_LEVEL_TOTAL := 6
const POWER_SLOT_COUNT := 3

func _init() -> void:
	super._init()
	card_name = TIAMAT_CARD_NAME
	card_types = ["Matriarch", "Bi-Aspected", "Chaos", "Sea"]
	mana_cost = 0
	culture = "Ancient"
	flavor_text = "The mother of monsters keeps her broods waiting in the deep."
	ability_text = "Mother of Demons: You may use [b]Brood Slots[/b] instead of powers. Each one may hold different face-up Ancient Demons or Dragons with total levels up to 6.\nMatriarch Rule: Starting on turn 1, you may add one of those cards to your hand instead of drawing."
	art_path = "res://images/card_art/gods/TiamatEdit.png"
	artist = "Riccardo Zoppello"
	name_at_bottom = true

static func is_tiamat_god(card: Card) -> bool:
	return card != null and str(card.card_name).strip_edges() == TIAMAT_CARD_NAME

static func is_valid_slot_creature(card: Card) -> bool:
	if card == null:
		return false
	if card.card_type != Card.CardType.CREATURE:
		return false
	if str(card.culture).strip_edges() != "Ancient":
		return false
	return card.has_type("Demon") or card.has_type("Dragon")

static func sanitize_slot_card_names(raw_slots) -> Array:
	var sanitized: Array = []
	for slot_index in range(POWER_SLOT_COUNT):
		var clean_slot: Array[String] = []
		if raw_slots is Array and slot_index < raw_slots.size():
			var raw_slot = raw_slots[slot_index]
			if raw_slot is Array:
				for raw_card_name in raw_slot:
					var card_name := str(raw_card_name).strip_edges()
					if not card_name.is_empty():
						clean_slot.append(card_name)
		sanitized.append(clean_slot)
	return sanitized

static func get_slot_card_names_from_setup(special_setup: Dictionary) -> Array:
	if special_setup == null or special_setup.is_empty():
		return sanitize_slot_card_names([])
	return sanitize_slot_card_names(special_setup.get(TIAMAT_SLOT_KEY, []))

static func build_special_setup(slot_card_names: Array) -> Dictionary:
	var sanitized_slots := sanitize_slot_card_names(slot_card_names)
	for slot_cards in sanitized_slots:
		if not slot_cards.is_empty():
			return {TIAMAT_SLOT_KEY: sanitized_slots}
	return {}

static func get_available_matriarch_rule_cards(player: Player) -> Array[Card]:
	var available: Array[Card] = []
	if player == null:
		return available
	for zone in player.power_zones:
		for card in zone.cards:
			if is_valid_slot_creature(card):
				available.append(card)
	return available

static func can_offer_matriarch_rule(game_manager: GameManager) -> bool:
	if game_manager == null or game_manager.current_player == null:
		return false
	var player := game_manager.current_player
	if player.god_zone == null or player.god_zone.cards.is_empty():
		return false
	if not is_tiamat_god(player.god_zone.cards[0]):
		return false
	return not get_available_matriarch_rule_cards(player).is_empty()

static func resolve_matriarch_rule(game_manager: GameManager, chosen_card: Card) -> bool:
	if game_manager == null or game_manager.current_player == null or chosen_card == null:
		return false
	var player := game_manager.current_player
	if chosen_card.card_owner != player:
		return false
	if chosen_card.current_zone == null or chosen_card.current_zone not in player.power_zones:
		return false
	if not is_valid_slot_creature(chosen_card):
		return false
	player.move_card(chosen_card, player.hand_zone)
	if chosen_card.current_zone != player.hand_zone:
		return false
	game_manager.note_player_feedback(
		"Matriarch Rule added %s to %s's hand." % [chosen_card.card_name, player.player_name]
	)
	return true
