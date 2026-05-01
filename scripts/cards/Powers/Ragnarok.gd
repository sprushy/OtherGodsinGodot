extends PowerCard
class_name Ragnarok

const UNLOCK_COST := 9
const HAND_LIMIT := 5
const ART_PATH := "res://images/card_art/powers/RagnarokEdit.png"

var _has_activated_on_unlock: bool = false

func _init() -> void:
	super._init()
	card_name = "Ragnarok"
	culture = "Norse"
	level = 0
	mana_cost = UNLOCK_COST
	is_legendary = true
	card_types = ["Power", "Legendary Destruction", "Universal"]
	targets = false
	ability_text = "[b]Unlock[/b] (9): Destroy all creatures on the field; then each player with more than 5 cards discards down to 5. You cannot attack this turn. This only happens once."
	artist = "Riccardo Zoppello"
	art_path = ART_PATH

func can_activate(_game_manager: GameManager) -> bool:
	return false

func on_unlock(game_manager: GameManager) -> void:
	if _has_activated_on_unlock:
		return
	_has_activated_on_unlock = true
	if game_manager != null:
		game_manager.run_with_effect_source(
			self,
			func() -> void:
				_resolve_ragnarok(game_manager)
		)

func activate(game_manager: GameManager, _target: Card = null) -> void:
	if game_manager != null:
		game_manager.note_player_feedback(card_name + " has already resolved.")

func _resolve_ragnarok(game_manager: GameManager) -> void:
	if game_manager == null:
		return

	var doomed_cards := _get_field_cards(game_manager)
	var destroyed_count := 0
	for doomed_card in doomed_cards:
		if game_manager.request_send_to_graveyard(doomed_card, Callable(), false, true):
			destroyed_count += 1

	if _begin_pending_discards(game_manager, destroyed_count, HAND_LIMIT):
		return
	var discarded_count := 0
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

func _begin_pending_discards(game_manager: GameManager, destroyed_count: int, hand_limit: int) -> bool:
	if game_manager == null:
		return false
	var pending_indices: Array[int] = []
	for i in range(game_manager.players.size()):
		var player := game_manager.players[i]
		if player != null and player.hand_zone != null and player.hand_zone.get_card_count() > hand_limit:
			pending_indices.append(i)
	if pending_indices.is_empty():
		return false
	set_meta("ragnarok_pending_destroyed_count", destroyed_count)
	set_meta("ragnarok_pending_discarded_count", 0)
	set_meta("ragnarok_pending_hand_limit", maxi(0, hand_limit))
	set_meta("ragnarok_pending_player_indices", pending_indices)
	_emit_next_pending_discard_prompt(game_manager)
	return true

func get_pending_discard_player(game_manager: GameManager) -> Player:
	if game_manager == null:
		return null
	var pending_indices: Array = get_meta("ragnarok_pending_player_indices", [])
	var hand_limit := int(get_meta("ragnarok_pending_hand_limit", HAND_LIMIT))
	while not pending_indices.is_empty():
		var player_index := int(pending_indices[0])
		var player: Player = game_manager.players[player_index] if player_index >= 0 and player_index < game_manager.players.size() else null
		if player != null and player.hand_zone != null and player.hand_zone.get_card_count() > hand_limit:
			set_meta("ragnarok_pending_player_indices", pending_indices)
			return player
		pending_indices.remove_at(0)
	set_meta("ragnarok_pending_player_indices", pending_indices)
	return null

func get_pending_discard_targets(game_manager: GameManager) -> Array[Card]:
	var targets: Array[Card] = []
	var player := get_pending_discard_player(game_manager)
	if player == null or player.hand_zone == null:
		return targets
	for card in player.hand_zone.cards:
		if card != null:
			targets.append(card)
	return targets

func resolve_discard_choice(game_manager: GameManager, chosen_card: Card) -> void:
	var player := get_pending_discard_player(game_manager)
	if player == null or player.hand_zone == null or chosen_card == null or chosen_card.current_zone != player.hand_zone:
		return
	player.discard_card(chosen_card)
	set_meta(
		"ragnarok_pending_discarded_count",
		int(get_meta("ragnarok_pending_discarded_count", 0)) + 1
	)
	_emit_next_pending_discard_prompt(game_manager)

func _emit_next_pending_discard_prompt(game_manager: GameManager) -> void:
	if game_manager == null:
		return
	var player := get_pending_discard_player(game_manager)
	if player == null:
		_finish_pending_discards(game_manager)
		return
	var target_uids: Array[String] = []
	for card in get_pending_discard_targets(game_manager):
		if card != null:
			target_uids.append(card.uid)
	game_manager.decision_requested.emit(player, "ragnarok_discard", {
		"source_uid": uid,
		"target_uids": target_uids,
		"hand_limit": int(get_meta("ragnarok_pending_hand_limit", HAND_LIMIT)),
	})

func _finish_pending_discards(game_manager: GameManager) -> void:
	_finish_resolution(
		game_manager,
		int(get_meta("ragnarok_pending_destroyed_count", 0)),
		int(get_meta("ragnarok_pending_discarded_count", 0))
	)
	_clear_pending_discards()

func _clear_pending_discards() -> void:
	remove_meta("ragnarok_pending_destroyed_count")
	remove_meta("ragnarok_pending_discarded_count")
	remove_meta("ragnarok_pending_hand_limit")
	remove_meta("ragnarok_pending_player_indices")

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
