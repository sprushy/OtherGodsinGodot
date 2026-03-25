extends CombatMockGame
class_name CardTestGame

# Override start_game to set up a focused test board.
# Update this whenever a new card ability is coded.
func start_game() -> void:
	await super.start_game()
	_setup_test_board()

func _add_test_hand_card(player: Player, card: Card) -> void:
	card.card_owner = player
	if player.hand_zone.get_card_count() >= Player.MAX_HAND_SIZE:
		var displaced := player.hand_zone.cards[0]
		player.move_card(displaced, player.graveyard_zone)
	player.hand_zone.add_card(card)

func _add_test_deck_card(player: Player, card: Card) -> void:
	card.card_owner = player
	player.deck_zone.add_card(card)

func _add_test_graveyard_card(player: Player, card: Card) -> void:
	card.card_owner = player
	player.graveyard_zone.add_card(card)

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

	var p1_cernunnos := Cernunnos.new()
	p1_cernunnos.card_owner = player1
	player1.god_zone.add_card(p1_cernunnos)

	var p2_dellingr := DellingrTheDayspring.new()
	p2_dellingr.card_owner = player2
	player2.god_zone.add_card(p2_dellingr)

	var p1_clay_eaters := ClayEaters.new()
	_add_test_hand_card(player1, p1_clay_eaters)

	var p1_deucalions_infants := DeucalionsInfants.new()
	_add_test_hand_card(player1, p1_deucalions_infants)

	var p1_warding_stone_hand := WardingStone.new()
	_add_test_hand_card(player1, p1_warding_stone_hand)

	var p1_blot_sacrifice := BlotSacrifice.new()
	_add_test_hand_card(player1, p1_blot_sacrifice)

	var p2_blessed_knights := BlessedKnights.new()
	_add_test_hand_card(player2, p2_blessed_knights)

	var p2_absence := Absence.new()
	_add_test_hand_card(player2, p2_absence)

	var p1_stone_infant := StoneInfant.new()
	p1_stone_infant.card_owner = player1
	p1_stone_infant.creature_mode = Card.CreatureMode.DEFENSIVE
	player1.frontline_zones[0].add_card(p1_stone_infant)

	var p1_warding_stone_board := WardingStone.new()
	p1_warding_stone_board.card_owner = player1
	player1.reserve_zones[0].add_card(p1_warding_stone_board)

	var p1_askelladen := Askelladen.new()
	p1_askelladen.card_owner = player1
	p1_askelladen.creature_mode = Card.CreatureMode.AGGRESSIVE
	player1.frontline_zones[2].add_card(p1_askelladen)

	var p2_anointing_statue := AnointingStatue.new()
	p2_anointing_statue.card_owner = player2
	player2.reserve_zones[0].add_card(p2_anointing_statue)

	var p2_stone_infant := StoneInfant.new()
	p2_stone_infant.card_owner = player2
	p2_stone_infant.creature_mode = Card.CreatureMode.DEFENSIVE
	player2.reserve_zones[1].add_card(p2_stone_infant)

	var p2_askelladen := Askelladen.new()
	p2_askelladen.card_owner = player2
	p2_askelladen.creature_mode = Card.CreatureMode.AGGRESSIVE
	player2.frontline_zones[2].add_card(p2_askelladen)

	_add_test_graveyard_card(player1, Askelladen.new())
	_add_test_graveyard_card(player1, AgainWalker.new())
	_add_test_graveyard_card(player1, Aurboda.new())

	for player in [player1, player2]:
		for i in range(3):
			var demiurge := ApollyonsDemiurge.new()
			_add_test_deck_card(player, demiurge)
		_add_test_deck_card(player, Alu.new())
		_add_test_deck_card(player, Asakku.new())
		_add_test_deck_card(player, AsagTheDestroyer.new())
		_add_test_deck_card(player, Anzu.new())

	player1.spend_mana(player1.mana)
	player1.gain_mana(20)
	player2.spend_mana(player2.mana)
	player2.gain_mana(20)

	game_manager.turn_number = 1
	update_ui()
