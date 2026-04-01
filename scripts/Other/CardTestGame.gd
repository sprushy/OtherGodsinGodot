extends CombatMockGame
class_name CardTestGame

var _test_turn_owner: Player = null
var _test_turn_opponent: Player = null

func _ready() -> void:
	super._ready()

# Override start_game to set up a focused test board while preserving
# the CombatMockGame interface.
func start_game(
	is_host: bool = false,
	is_client: bool = false,
	server_ip: String = "127.0.0.1",
	server_port: int = 12345,
	match_info: Dictionary = {},
	server_match_session = null
) -> void:
	await super.start_game(is_host, is_client, server_ip, server_port, match_info, server_match_session)
	load_test_scenario_one()

func update_ui() -> void:
	_sync_test_priority_control()
	super.update_ui()
	if turn_label != null and player1 != null and player2 != null:
		turn_label.text += " | P1 Mana %d | P2 Mana %d" % [player1.mana, player2.mana]

func _sync_test_priority_control() -> void:
	if game_manager == null or player1 == null or player2 == null:
		return
	if game_manager.current_player != null:
		_test_turn_owner = game_manager.current_player
		_test_turn_opponent = game_manager.other_player
	elif _test_turn_owner == null:
		_test_turn_owner = player1
		_test_turn_opponent = player2

	var viewer := _test_turn_owner
	if not game_manager.action_stack.is_empty() and game_manager.priority_player != null:
		viewer = game_manager.priority_player
	game_manager.feedback_viewer = viewer

	var turn_owner := game_manager.turn_player if game_manager.turn_player != null else game_manager.current_player
	player1.is_turn_player = turn_owner == player1
	player2.is_turn_player = turn_owner == player2

func _add_test_hand_card(player: Player, card: Card) -> void:
	card.card_owner = player
	player.hand_zone.add_card(card)

func _add_test_deck_card(player: Player, card: Card) -> void:
	card.card_owner = player
	player.deck_zone.add_card(card)

func _add_test_graveyard_card(player: Player, card: Card) -> void:
	card.card_owner = player
	player.graveyard_zone.add_card(card)

func _add_test_power(player: Player, slot_index: int, power: PowerCard, unlocked: bool = false) -> void:
	if player == null or power == null:
		return
	if slot_index < 0 or slot_index >= player.power_zones.size():
		return
	power.card_owner = player
	power.is_publicly_revealed = false
	power.is_muted = false
	power.mute_turns_remaining = 0
	if unlocked:
		power.is_face_down = false
	else:
		power.relock()
	player.power_zones[slot_index].add_card(power)
	if unlocked:
		power.on_unlock(game_manager)

func _add_test_god(player: Player, god: GodCard) -> void:
	if player == null or god == null:
		return
	god.card_owner = player
	god.is_face_down = false
	god.is_stealth = false
	god.is_muted = false
	god.mute_turns_remaining = 0
	god.reset_creature_action_state()
	god.summoned_this_turn = false
	god.wake_up()
	player.god_zone.add_card(god)
	if god.has_method("on_summon"):
		god.on_summon(game_manager)

func _place_test_board_card(player: Player, zone: Zone, card: Card, mode: Card.CreatureMode = Card.CreatureMode.AGGRESSIVE) -> void:
	if player == null or zone == null or card == null:
		return
	card.card_owner = player
	card.creature_mode = mode
	card.reset_creature_action_state()
	card.summoned_this_turn = false
	card.is_face_down = false
	card.is_stealth = false
	card.wake_up()
	zone.add_card(card)
	if game_manager != null and game_manager.has_method("_apply_god_passives_to_card"):
		game_manager._apply_god_passives_to_card(player, card)

func _place_test_hidden_creature(player: Player, zone: Zone, card: Card) -> void:
	_place_test_board_card(player, zone, card, Card.CreatureMode.DEFENSIVE)
	card.is_face_down = true
	card.is_stealth = true

func _place_test_board_permanent(player: Player, zone: Zone, card: Card) -> void:
	if player == null or zone == null or card == null:
		return
	card.card_owner = player
	card.is_face_down = false
	card.is_stealth = false
	zone.add_card(card)

func _equip_test_card(player: Player, zone: Zone, equipment: Card, creature: Card) -> void:
	if player == null or zone == null or equipment == null or creature == null:
		return
	equipment.card_owner = player
	equipment.is_face_down = false
	equipment.is_stealth = false
	zone.add_card(equipment)
	equipment.equip_to(creature)

func _place_test_prepared_card(player: Player, zone: Zone, card: Card) -> void:
	if player == null or zone == null or card == null:
		return
	card.card_owner = player
	card.is_prepared = true
	card.is_face_down = true
	card.is_stealth = false
	zone.add_card(card)
	if game_manager == null:
		return
	var ready_turn: int = maxi(0, game_manager.turn_number - 1)
	if card.card_type == Card.CardType.HEX:
		game_manager.prepared_hexes[card] = ready_turn
	elif card is CharmCard:
		game_manager.prepared_charms[card] = ready_turn

func _clear_zone(zone: Zone) -> void:
	if zone == null:
		return
	for card in zone.cards.duplicate():
		zone.remove_card(card)

func _reset_player_test_state(player: Player) -> void:
	if player == null:
		return
	_clear_zone(player.hand_zone)
	_clear_zone(player.deck_zone)
	_clear_zone(player.graveyard_zone)
	_clear_zone(player.abyss_zone)
	_clear_zone(player.god_zone)
	for zone in player.power_zones:
		_clear_zone(zone)
	for zone in player.frontline_zones:
		_clear_zone(zone)
	for zone in player.reserve_zones:
		_clear_zone(zone)

func _reset_test_match_state() -> void:
	_reset_player_test_state(player1)
	_reset_player_test_state(player2)
	game_manager.prepared_hexes.clear()
	game_manager.prepared_charms.clear()
	game_manager.attack_restrictions.clear()
	game_manager.died_this_turn.clear()
	game_manager.pending_resurrections.clear()
	game_manager.combat_destroy_events_this_turn.clear()
	game_manager.action_stack.clear()
	game_manager.consecutive_passes = 0
	game_manager.priority_player = null
	game_manager.turn_player = null
	game_manager.turn_number = 0
	game_manager._upkeep_started_turn = -1
	game_manager._upkeep_resolved_turn = -1
	game_manager._temporary_summon_cost_modifiers.clear()
	selected_card = null
	selected_attacker = null
	selected_interceptor = null

func _setup_test_board() -> void:
	load_test_scenario_one()

func load_test_scenario_one() -> void:
	_reset_test_match_state()
	_add_test_god(player1, Hermes.new())
	_add_test_god(player2, Thor.new())
	_add_test_power(player1, 0, KurnugiaTheBeginningOfTheEnd.new(), true)

	var enkidu := Enkidu.new()
	var frontline_enki := EnkiLordOfEridu.new()
	var en_hedu_anna := EnHeduAnna.new()
	var kur_jara := KurJara.new()
	_place_test_board_card(player1, player1.frontline_zones[0], enkidu, Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.frontline_zones[1], frontline_enki, Card.CreatureMode.DEFENSIVE)
	_place_test_board_card(player1, player1.reserve_zones[0], en_hedu_anna, Card.CreatureMode.DEFENSIVE)
	_place_test_board_card(player1, player1.reserve_zones[1], kur_jara, Card.CreatureMode.AGGRESSIVE)

	_add_test_hand_card(player1, Lailoken.new())
	_add_test_hand_card(player1, HeroicStand.new())

	var graveyard_enki := EnkiLordOfEridu.new()
	_add_test_graveyard_card(player1, graveyard_enki)

	var enemy_brown_bear := BrownBear.new()
	_place_test_board_card(player2, player2.frontline_zones[0], enemy_brown_bear, Card.CreatureMode.DEFENSIVE)
	_place_test_prepared_card(player2, player2.reserve_zones[0], Exorcism.new())
	_add_test_hand_card(player2, FallOfTheMighty.new())
	_add_test_hand_card(player2, FallOfTheMighty.new())
	_add_test_hand_card(player2, VoidShield.new())

	_add_test_deck_card(player2, BrownBear.new())
	_add_test_deck_card(player2, Berserker.new())

	player1.spend_mana(player1.mana)
	player1.gain_mana(4)
	player2.spend_mana(player2.mana)
	player2.gain_mana(4)
	player1.followers = 100
	player2.followers = 100
	player1.followers_changed.emit(player1.followers)
	player2.followers_changed.emit(player2.followers)
	player1.has_summoned_this_turn = false
	player2.has_summoned_this_turn = false

	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.feedback_viewer = player1
	player1.is_turn_player = true
	player2.is_turn_player = false
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	_test_turn_owner = player1
	_test_turn_opponent = player2
	game_manager.start_turn()
	game_manager.record_interception(en_hedu_anna)
	game_manager.record_interception(en_hedu_anna)
	_open_upkeep_choice_window()
	action_label.text = (
		"Scenario 1: Lailoken, Heroic Stand, Kurnugia, and Kur-Jara. Choose Draw Card or Gain 4 Mana first.  |  "
		+ "Hand - Heroic Stand is already live because En-hedu-anna counts as having intercepted twice this turn.  |  "
		+ "Hand - Lailoken can reveal into any open lane and drain the prepared enemy Exorcism in reserve.  |  "
		+ "Power - Kurnugia is unlocked and ready to shelter your Ancient Humans or Mer when they are destroyed or voided.  |  "
		+ "Opponent - Thor starts with two Fall of the Mighty and a Void Shield in hand for repeated destroy and protection tests.  |  "
		+ "Board - Enki, Lord of Eridu is on your frontline as a live Mer target for Kurnugia, and another copy is in your graveyard as a Tree of Life target.  |  "
		+ "Follow-up - activate Kur-Jara, then end your turns twice to resurrect Kur-Jara and Enki while Kurnugia shelters En-hedu-anna and Enkidu from the level-cost destruction."
	)
	update_ui()
