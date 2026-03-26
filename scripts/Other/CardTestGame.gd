extends CombatMockGame
class_name CardTestGame

var _test_turn_owner: Player = null
var _test_turn_opponent: Player = null

const TEST_SPELL_SCRIPTS: Array[Script] = [
	preload("res://scripts/cards/Spells/Absence.gd"),
	preload("res://scripts/cards/Spells/ApollyonsDemiurge.gd"),
	preload("res://scripts/cards/Spells/BaneOfTheSvartalfar.gd"),
	preload("res://scripts/cards/Spells/BitMeseri.gd"),
	preload("res://scripts/cards/Spells/BlotSacrifice.gd"),
	preload("res://scripts/cards/Spells/BookOfLife.gd"),
	preload("res://scripts/cards/Spells/CircleofRebirth.gd"),
	preload("res://scripts/cards/Spells/DeucalionsInfants.gd"),
	preload("res://scripts/cards/Spells/FalloftheMighty.gd"),
]

# Override start_game to set up a focused test board.
# Update this whenever a new card ability is coded.
func start_game() -> void:
	await super.start_game()
	_setup_test_board()

func update_ui() -> void:
	_sync_test_priority_control()
	super.update_ui()

func _sync_test_priority_control() -> void:
	if game_manager == null or player1 == null or player2 == null:
		return
	if _test_turn_owner == null:
		_test_turn_owner = game_manager.current_player
		_test_turn_opponent = game_manager.other_player
	if game_manager.action_stack.is_empty():
		if game_manager.current_player != null and game_manager.current_player != _test_turn_owner and game_manager.current_player != game_manager.priority_player:
			_test_turn_owner = game_manager.current_player
			_test_turn_opponent = game_manager.other_player
		game_manager.current_player = _test_turn_owner
		game_manager.other_player = _test_turn_opponent
	else:
		if game_manager.priority_player != null:
			game_manager.current_player = game_manager.priority_player
			game_manager.other_player = game_manager.get_opponent(game_manager.priority_player)
	game_manager.feedback_viewer = _test_turn_owner
	player1.is_turn_player = game_manager.current_player == player1
	player2.is_turn_player = game_manager.current_player == player2

func _add_test_hand_card(player: Player, card: Card) -> void:
	card.card_owner = player
	player.hand_zone.add_card(card)

func _add_all_test_spells_to_hand(player: Player) -> void:
	for spell_script in TEST_SPELL_SCRIPTS:
		_add_test_hand_card(player, spell_script.new())

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
	power.is_face_down = not unlocked
	power.is_publicly_revealed = false
	player.power_zones[slot_index].add_card(power)

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
	game_manager.died_this_turn.clear()
	game_manager.pending_resurrections.clear()
	game_manager.combat_destroy_events_this_turn.clear()
	game_manager.action_stack.clear()
	game_manager.consecutive_passes = 0
	game_manager.priority_player = null

	var p1_cernunnos := Cernunnos.new()
	p1_cernunnos.card_owner = player1
	player1.god_zone.add_card(p1_cernunnos)

	var p2_aphrodite := AphroditeAreia.new()
	p2_aphrodite.card_owner = player2
	player2.god_zone.add_card(p2_aphrodite)

	_add_test_power(player1, 0, CallOfTheValkyrie.new(), true)
	_add_test_power(player1, 1, DivineCaprice.new(), true)

	_add_test_hand_card(player1, Caleuche.new())
	_add_test_hand_card(player1, Capricorn.new())
	_add_test_hand_card(player1, ClayEaters.new())
	_add_test_hand_card(player1, SoldierOfTheBlackEmperor.new())
	_add_test_hand_card(player1, AsagTheDestroyer.new())
	_add_test_hand_card(player1, DivineLightning.new())
	_add_test_hand_card(player1, BlessedKnights.new())
	_add_test_hand_card(player1, Absence.new())

	_add_test_hand_card(player2, DivineLightning.new())
	_add_test_hand_card(player2, DivineLightning.new())
	_add_test_hand_card(player2, BaneOfTheSvartalfar.new())
	_add_test_hand_card(player2, Byggvir.new())
	_add_test_hand_card(player2, BlessedKnights.new())

	_add_all_test_spells_to_hand(player1)
	_add_all_test_spells_to_hand(player2)

	var cernunnos_test_bear := BrownBear.new()
	cernunnos_test_bear.level = 5
	cernunnos_test_bear.culture = "Triskelion"
	cernunnos_test_bear.card_name = "Brown Bear (Level 5 Test)"

	_place_test_board_card(player1, player1.frontline_zones[0], cernunnos_test_bear, Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.frontline_zones[1], Caleuche.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.reserve_zones[0], CombatMech.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player1, player1.reserve_zones[1], WardingStone.new(), Card.CreatureMode.DEFENSIVE)

	_place_test_board_card(player2, player2.frontline_zones[0], EnkiLordOfEridu.new(), Card.CreatureMode.AGGRESSIVE)
	_place_test_board_card(player2, player2.frontline_zones[1], ClayEaters.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_board_card(player2, player2.reserve_zones[0], AncientPyre.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_board_card(player2, player2.reserve_zones[1], DoorwayToTheVoid.new(), Card.CreatureMode.DEFENSIVE)
	_place_test_prepared_card(player2, player2.reserve_zones[2], Banishment.new())

	_add_test_graveyard_card(player1, AgainWalker.new())
	_add_test_graveyard_card(player1, Aurboda.new())
	_add_test_graveyard_card(player1, Askelladen.new())
	_add_test_graveyard_card(player1, RoboticFootsoldier.new())
	_add_test_graveyard_card(player2, MeadOfPoetry.new())

	_add_test_deck_card(player1, ClayEaters.new())
	_add_test_deck_card(player1, DevastatorMech.new())
	_add_test_deck_card(player1, TitanicMech.new())
	_add_test_deck_card(player1, RoboticFootsoldier.new())
	_add_test_deck_card(player1, BrownBear.new())

	_add_test_deck_card(player2, ClayEaters.new())
	_add_test_deck_card(player2, StoneInfant.new())

	player1.spend_mana(player1.mana)
	player1.gain_mana(20)
	player2.spend_mana(player2.mana)
	player2.gain_mana(20)
	player1.followers = 100
	player2.followers = 100
	player1.followers_changed.emit(player1.followers)
	player2.followers_changed.emit(player2.followers)

	game_manager.current_player = player1
	game_manager.other_player = player2
	game_manager.turn_player = player1
	game_manager.feedback_viewer = player1
	player1.is_turn_player = true
	player2.is_turn_player = false
	game_manager.current_phase = GameManager.GamePhase.MAIN
	game_manager.turn_number = 1
	_test_turn_owner = player1
	_test_turn_opponent = player2
	hide_turn_choice()
	action_label.text = "Card test ready: Aphrodite Areia is facing Cernunnos, and Caleuche, Capricorn, Clay-Eaters, Combat Mech, Soldier of the Black Emperor, Call of the Valkyrie with dead Norse Warriors, and Divine Caprice are all live."
	update_ui()
