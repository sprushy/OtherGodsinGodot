extends CreatureCard
class_name ThirdSageEnmedugga

const ART_PATH := "res://images/card_art/creatures/ThirdSageEnmeduggaArt.jpg"
const GOOD_FORTUNE_STATUS := "third_sage_good_fortune"

func _init() -> void:
	super._init()
	card_name = "Third Sage Enmedugga"
	card_types = ["Mer", "Mage", "Priest", "Sage", "Ancient Creature", "Targeting"]
	level = 3
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 21
	strength = 21
	targets = true
	ability_text = "[b]Good Fortune[/b] ([b]Impact[/b]): Choose a Mer Sage. It cannot be targeted by spells or creature abilities for as long as this card remains face-up on the field."
	flavor_text = ""
	culture = "Ancient"
	artist = "Ricardo Zoppello"
	art_path = ART_PATH

func on_impact(game_manager: GameManager) -> void:
	var valid_targets := get_valid_targets(game_manager)
	if valid_targets.is_empty():
		if game_manager != null:
			game_manager.note_player_feedback("%s found no Mer Sage to bless." % card_name)
		return
	var controller := get_controller()
	if game_manager == null or controller == null:
		return
	var target_uids: Array[String] = []
	for target in valid_targets:
		if target != null:
			target_uids.append(target.uid)
	game_manager.decision_requested.emit(controller, "third_sage_enmedugga_impact", {
		"source_uid": uid,
		"target_uids": target_uids,
		"queue_with_priority": true,
		"event_name": "third_sage_enmedugga_impact",
	})

func get_valid_targets(game_manager: GameManager) -> Array[Card]:
	var valid_targets: Array[Card] = []
	var controller := get_controller()
	if controller == null:
		return valid_targets
	for player in _get_all_players(controller, game_manager):
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if _is_valid_good_fortune_target(card):
					valid_targets.append(card)
	if _is_valid_good_fortune_target(self) and self not in valid_targets:
		valid_targets.append(self)
	return valid_targets

func resolve_good_fortune_impact(game_manager: GameManager, target: Card) -> String:
	var valid_targets := get_valid_targets(game_manager)
	if target == null or target not in valid_targets:
		return "%s found no valid Mer Sage to bless." % card_name
	_clear_existing_good_fortune_marks(game_manager)
	target.add_status_effect(
		GOOD_FORTUNE_STATUS,
		"Good Fortune",
		self,
		get_controller(),
		{
			"ward_kind": "spells",
			"source_board_entry_order": board_entry_order,
		}
	)
	target.add_status_effect(
		GOOD_FORTUNE_STATUS,
		"Good Fortune",
		self,
		get_controller(),
		{
			"ward_kind": "creature_abilities",
			"source_board_entry_order": board_entry_order,
		}
	)
	return "%s grants Good Fortune to %s while it remains face-up on the field." % [
		card_name,
		target.get_target_log_display_name(game_manager.get_feedback_viewer()) if game_manager != null else target.card_name
	]

func _clear_existing_good_fortune_marks(game_manager: GameManager) -> void:
	for player in _get_all_players(get_controller(), game_manager):
		for zone in _get_all_player_zones(player):
			for card in zone.cards:
				if card != null:
					card.remove_status_effects_from_source_card(self, GOOD_FORTUNE_STATUS)

func _is_valid_good_fortune_target(card: Card) -> bool:
	return card != null \
		and card.card_type == Card.CardType.CREATURE \
		and card.current_zone != null \
		and card.current_zone.is_board_zone() \
		and card.has_type("Mer") \
		and card.has_type("Sage") \
		and not card.is_face_down \
		and not card.is_stealth

func _get_all_players(controller: Player, game_manager: GameManager = null) -> Array[Player]:
	var players: Array[Player] = []
	if game_manager != null and not game_manager.players.is_empty():
		for player in game_manager.players:
			if player != null and player not in players:
				players.append(player)
	if controller != null and controller not in players:
		players.append(controller)
	return players

func _get_all_player_zones(player: Player) -> Array[Zone]:
	if player == null:
		return []
	return [player.hand_zone, player.deck_zone, player.graveyard_zone, player.abyss_zone, player.god_zone] \
		+ player.power_zones \
		+ player.frontline_zones \
		+ player.reserve_zones
