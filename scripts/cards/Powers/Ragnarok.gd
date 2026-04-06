extends PowerCard
class_name Ragnarok

const UNLOCK_COST := 9
const HAND_LIMIT := 5
const ART_PATH := "res://images/card_art/powers/RagnarokEdit.png"

func _init() -> void:
	super._init()
	card_name = "Ragnarok"
	culture = "Norse"
	level = 0
	mana_cost = UNLOCK_COST
	is_legendary = true
	card_types = ["Power", "Legendary Destruction", "Universal"]
	targets = false
	ability_text = "[b]Unlock[/b] (9): [b]Activate[/b] - Destroy all creatures on the field; then each player with more than 5 cards discards down to 5. You cannot attack this turn."
	artist = "Riccardo Zoppello"
	art_path = ART_PATH

func can_activate(game_manager: GameManager) -> bool:
	return super.can_activate(game_manager)

func activate(game_manager: GameManager, _target: Card = null) -> void:
	if not can_activate(game_manager):
		return
	if game_manager == null:
		return

	var doomed_cards := _get_field_cards(game_manager)
	var destroyed_count := 0
	for doomed_card in doomed_cards:
		if game_manager.request_send_to_graveyard(doomed_card, Callable(), false, true):
			destroyed_count += 1

	var discarded_count := 0
	var interaction_host := game_manager.get_interaction_host()
	if interaction_host != null and interaction_host.has_method("_resolve_ragnarok_post_destroy"):
		interaction_host.call("_resolve_ragnarok_post_destroy", self, destroyed_count, HAND_LIMIT)
		return

	for player in game_manager.players:
		discarded_count += _discard_down_to_limit(player, HAND_LIMIT)
	_finish_resolution(game_manager, destroyed_count, discarded_count)

func _get_field_cards(game_manager: GameManager) -> Array[Card]:
	var field_cards: Array[Card] = []
	if game_manager == null:
		return field_cards
	for player in game_manager.players:
		var zones: Array[Zone] = []
		zones.append_array(player.frontline_zones)
		zones.append_array(player.reserve_zones)
		for zone in zones:
			if zone == null:
				continue
			for card in zone.cards:
				if card != null:
					field_cards.append(card)
	return field_cards

func _discard_down_to_limit(player: Player, limit: int) -> int:
	if player == null or player.hand_zone == null:
		return 0
	var discarded := 0
	while player.hand_zone.get_card_count() > limit:
		var discard_card: Card = player.hand_zone.cards.back()
		if discard_card == null:
			break
		player.discard_card(discard_card)
		discarded += 1
	return discarded

func _finish_resolution(game_manager: GameManager, destroyed_count: int, discarded_count: int) -> void:
	if game_manager == null:
		return
	if card_owner != null:
		game_manager.apply_attack_restriction(card_owner, 1)

	var feedback := "%s destroyed %d field card(s), discarded %d hand card(s), and prevents %s from attacking this turn." % [
		card_name,
		destroyed_count,
		discarded_count,
		card_owner.player_name if card_owner != null else "its controller"
	]
	game_manager.note_player_feedback(feedback)
	print(feedback)

func would_destroy_creature_of_player(game_manager: GameManager, protected_player: Player, _chosen_target = null) -> bool:
	if game_manager == null or protected_player == null:
		return false
	for doomed_card in _get_field_cards(game_manager):
		if doomed_card != null and doomed_card.card_type == Card.CardType.CREATURE and doomed_card.get_controller() == protected_player:
			return true
	return false
