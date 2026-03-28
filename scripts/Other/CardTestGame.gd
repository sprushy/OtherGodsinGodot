extends CombatMockGame
class_name CardTestGame

var _test_turn_owner: Player = null
var _test_turn_opponent: Player = null

# Override start_game to set up a focused test board.
# Update this whenever a new card ability is coded.
func start_game() -> void:
	await super.start_game()
	_setup_test_board()

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
	var ready_turn := maxi(0, game_manager.turn_number - 1)
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

func _setup_test_board() -> void:
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
	game_manager._temporary_summon_cost_modifiers.clear()

	_add_test_god(player1, Freyja.new())
	_add_test_god(player2, Baldr.new())

	var tian_dragon := SoldierOfTheBlackEmperor.new()
	var friendly_guard := Enkidu.new()
	var doomed_scout := BlessedKnights.new()
	var axe_guard := Berserker.new()
	var fallen_einherjar := AgainWalker.new()
	var fourth_sage_script = load("res://scripts/cards/Creatures/FourthSageEnmegalamma.gd")

	_add_test_hand_card(player1, FiresOfJudgment.new())
	_add_test_hand_card(player1, FoolishOptimism.new())
	_add_test_hand_card(player1, FirstSageAdapa.new())
	_add_test_hand_card(player1, Fenrir.new())
	if fourth_sage_script != null:
		_add_test_hand_card(player1, fourth_sage_script.new())
	_add_test_hand_card(player1, Earthquake.new())
	_add_test_hand_card(player1, FallOfTheMighty.new())

	_add_test_power(player1, 0, FireAndGold.new(), false)
	_add_test_power(player1, 1, CallOfTheValkyrie.new(), true)
	_add_test_power(player2, 0, AncientWisdom.new(), true)

	_place_test_board_card(player1, player1.frontline_zones[0], tian_dragon, Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.frontline_zones[1], friendly_guard, Card.CreatureMode.AGGRESSIVE)

	_place_test_board_card(player2, player2.frontline_zones[0], doomed_scout, Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player2, player2.frontline_zones[1], axe_guard, Card.CreatureMode.DEFENSIVE)
	_place_test_board_permanent(player2, player2.reserve_zones[3], EriduCityOfSages.new())
	_equip_test_card(player2, player2.frontline_zones[1], BeardedAxe.new(), axe_guard)
	_add_test_graveyard_card(player1, fallen_einherjar)

	_add_test_deck_card(player1, EnkiLordOfEridu.new())
	_add_test_deck_card(player1, FirstSageAdapa.new())
	if fourth_sage_script != null:
		_add_test_deck_card(player1, fourth_sage_script.new())

	player1.spend_mana(player1.mana)
	player1.gain_mana(10)
	player2.spend_mana(player2.mana)
	player2.gain_mana(10)
	player1.followers = 100
	player2.followers = 100
	player1.followers_changed.emit(player1.followers)
	player2.followers_changed.emit(player2.followers)
	player1.has_summoned_this_turn = false
	player2.has_summoned_this_turn = false

	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.turn_player = player1
	game_manager.feedback_viewer = player1
	player1.is_turn_player = true
	player2.is_turn_player = false
	game_manager.current_phase = GameManager.GamePhase.MAIN
	game_manager.turn_number = 1
	selected_card = null
	selected_attacker = null
	selected_interceptor = null
	_test_turn_owner = player1
	_test_turn_opponent = player2
	hide_turn_choice()
	action_label.text = "Card test ready. Freyja: activate Receiver of the Slain to summon Again-Walker from your graveyard with Call of the Valkyrie already in play reducing the cost. Fire and Gold: unlock your power in slot 1, discard a spare hand card, and destroy the enemy Eridu while Soldier of the Black Emperor is on your frontline. Fires of Judgment: cast from hand to wipe the enemy's face-up Blessed Knights, Berserker, structure, and axe. Foolish Optimism: cast it to force Blessed Knights, the opponent's only level-1 creature, to attack your highest-level creature, Soldier of the Black Emperor. First Sage Adapa: summon it to mute the enemy Ancient Wisdom power. Fenrir: play or use Wolf Master/Devour from Player 1's hand. Fourth Sage Enmegalamma: summon it on a later turn to search your deck for another Mer Sage such as First Sage Adapa or Enki, Lord of Eridu."
	update_ui()
