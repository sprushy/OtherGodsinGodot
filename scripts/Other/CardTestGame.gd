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

	var p1_askelladen := Askelladen.new()
	p1_askelladen.card_owner = player1
	p1_askelladen.creature_mode = Card.CreatureMode.ATTACK
	player1.frontline_zones[3].add_card(p1_askelladen)

	var p2_askelladen := Askelladen.new()
	p2_askelladen.card_owner = player2
	p2_askelladen.creature_mode = Card.CreatureMode.ATTACK
	player2.frontline_zones[3].add_card(p2_askelladen)

	var p1_mead := BerserkerMead.new()
	p1_mead.card_owner = player1
	player1.power_zones[0].add_card(p1_mead)

	var p1_breidablik := Breidablik.new()
	p1_breidablik.card_owner = player1
	player1.power_zones[1].add_card(p1_breidablik)

	var p1_banishment := Banishment.new()
	p1_banishment.card_owner = player1
	p1_banishment.is_prepared = true
	p1_banishment.is_face_down = true
	player1.reserve_zones[0].add_card(p1_banishment)
	game_manager.prepared_hexes[p1_banishment] = 0

	var p2_banishment := Banishment.new()
	p2_banishment.card_owner = player2
	p2_banishment.is_prepared = true
	p2_banishment.is_face_down = true
	player2.reserve_zones[0].add_card(p2_banishment)
	game_manager.prepared_hexes[p2_banishment] = 0

	var p2_demiurge := ApollyonsDemiurge.new()
	_add_test_hand_card(player2, p2_demiurge)

	var p1_bit_meseri := BitMeseri.new()
	_add_test_hand_card(player1, p1_bit_meseri)

	var p1_warding_stone := WardingStone.new()
	_add_test_hand_card(player1, p1_warding_stone)

	var p1_blot_sacrifice := BlotSacrifice.new()
	_add_test_hand_card(player1, p1_blot_sacrifice)

	var p1_enki := EnkiLordOfEridu.new()
	_add_test_hand_card(player1, p1_enki)

	var p1_hand_askelladen := Askelladen.new()
	_add_test_hand_card(player1, p1_hand_askelladen)

	var p1_byggvir := Byggvir.new()
	_add_test_hand_card(player1, p1_byggvir)

	var p1_mead_of_poetry := MeadOfPoetry.new()
	_add_test_hand_card(player1, p1_mead_of_poetry)

	for i in range(2):
		var p2_absence := Absence.new()
		_add_test_hand_card(player2, p2_absence)

	var p2_bit_meseri := BitMeseri.new()
	_add_test_hand_card(player2, p2_bit_meseri)

	var p2_warding_stone := WardingStone.new()
	_add_test_hand_card(player2, p2_warding_stone)

	var p2_asag_hand := AsagTheDestroyer.new()
	_add_test_hand_card(player2, p2_asag_hand)

	var p2_blessed_knights := BlessedKnights.new()
	_add_test_hand_card(player2, p2_blessed_knights)

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
