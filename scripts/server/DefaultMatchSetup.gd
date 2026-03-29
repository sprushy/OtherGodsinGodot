extends RefCounted
class_name DefaultMatchSetup

const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")
const DeckBuilderScript = preload("res://scripts/Other/DeckBuilder.gd")

## Shared debug-match bootstrap used by both the visible game scene and
## the dedicated headless match server. Keeping this in one place avoids
## the two authority paths drifting apart.

func build_default_match(game_manager: GameManager) -> Dictionary:
	var player1 := Player.new()
	player1.player_name = "Player 1"
	game_manager.players.append(player1)

	var player2 := Player.new()
	player2.player_name = "Player 2"
	game_manager.players.append(player2)

	_create_deck(player1)
	_create_deck(player2)

	var baldr := Baldr.new()
	baldr.card_owner = player1
	player1.god_zone.add_card(baldr)

	var mummu := Mummu.new()
	mummu.card_owner = player2
	player2.god_zone.add_card(mummu)

	game_manager.setup_game()

	var ananke := AnankesBinding.new()
	ananke.card_owner = player1
	ananke.is_face_down = false
	player1.power_zones[0].add_card(ananke)

	var axe1 := BeardedAxe.new()
	axe1.card_owner = player1
	player1.reserve_zones[3].add_card(axe1)

	var axe2 := BeardedAxe.new()
	axe2.card_owner = player2
	player2.reserve_zones[3].add_card(axe2)

	player1.gain_mana(20)
	player2.gain_mana(20)

	for _i in range(5):
		player1.draw_card()
		player2.draw_card()

	game_manager.feedback_viewer = player1
	return {
		"player1": player1,
		"player2": player2,
	}

func build_match_from_session_decks(game_manager: GameManager, match_session) -> Dictionary:
	if game_manager == null or match_session == null:
		return {}
	if match_session.player_session_ids.size() < 2:
		return {}

	var players: Array[Player] = []
	for player_index in range(match_session.player_session_ids.size()):
		var player := Player.new()
		player.player_name = "Player %d" % [player_index + 1]
		game_manager.players.append(player)
		players.append(player)

	var deck_builder = DeckBuilderScript.new()
	for player_index in range(players.size()):
		var session_id := str(match_session.player_session_ids[player_index]).strip_edges()
		var submission := _get_session_deck_submission(match_session, session_id)
		if submission.is_empty():
			return {}
		var submitted_cards: Array[Card] = CardCatalogScript.make_cards_from_counts(submission.get("cards", {}))
		if submitted_cards.is_empty():
			return {}
		if not deck_builder.build_deck(players[player_index], submitted_cards):
			return {}

	game_manager.setup_game()
	_apply_standard_opening(players)
	game_manager.feedback_viewer = players[0]
	return {
		"player1": players[0],
		"player2": players[1],
	}

func _create_deck(player: Player) -> void:
	var deck: Array[Card] = []

	deck.append(_own(Alu.new(), player))
	deck.append(_own(AsagTheDestroyer.new(), player))
	deck.append(_own(BrownBear.new(), player))
	deck.append(_own(AgainWalker.new(), player))
	deck.append(_own(Anzu.new(), player))
	deck.append(_own(Berserker.new(), player))
	deck.append(_own(Beyla.new(), player))
	deck.append(_own(BlessedKnights.new(), player))

	deck.append(_own(BitMeseri.new(), player))
	deck.append(_own(BitMeseri.new(), player))
	deck.append(_own(FallOfTheMighty.new(), player))
	deck.append(_own(CircleOfRebirth.new(), player))
	deck.append(_own(Absence.new(), player))
	deck.append(_own(Absence.new(), player))
	deck.append(_own(BlotSacrifice.new(), player))
	deck.append(_own(BlotSacrifice.new(), player))
	deck.append(_own(ApollyonsDemiurge.new(), player))

	deck.append(_own(WardingStone.new(), player))
	deck.append(_own(WardingStone.new(), player))

	deck.append(_own(VoidShield.new(), player))
	deck.append(_own(VoidShield.new(), player))

	deck.append(_own(BeardedAxe.new(), player))
	deck.append(_own(BeardedAxe.new(), player))

	deck.shuffle()
	for card in deck:
		player.deck_zone.add_card(card)

func _own(card: Card, player: Player) -> Card:
	card.card_owner = player
	return card

func _apply_standard_opening(players: Array[Player]) -> void:
	for player in players:
		if player == null:
			continue
		player.gain_mana(20)
	for _draw_index in range(5):
		for player in players:
			if player != null:
				player.draw_card()

func _get_session_deck_submission(match_session, session_id: String) -> Dictionary:
	if session_id.is_empty() or match_session == null:
		return {}
	var submission = match_session.player_decks_by_session.get(session_id, {})
	if submission is Dictionary:
		return (submission as Dictionary).duplicate(true)
	return {}
