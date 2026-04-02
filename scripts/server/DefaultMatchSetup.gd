extends RefCounted
class_name DefaultMatchSetup

const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")
const DeckBuilderScript = preload("res://scripts/Other/DeckBuilder.gd")

var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

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

	for _i in range(5):
		player1.draw_card()
		player2.draw_card()

	_apply_random_first_player_bonus(game_manager)
	game_manager.feedback_viewer = player1
	return {
		"player1": player1,
		"player2": player2,
	}

func build_empty_match_shell(game_manager: GameManager, player_count: int = 2) -> Dictionary:
	if game_manager == null or player_count <= 0:
		return {}

	var players: Array[Player] = []
	for player_index in range(player_count):
		var player := Player.new()
		player.player_name = "Player %d" % [player_index + 1]
		game_manager.players.append(player)
		players.append(player)

	game_manager.setup_game()
	if not players.is_empty():
		game_manager.feedback_viewer = players[0]

	return {
		"player1": players[0] if players.size() > 0 else null,
		"player2": players[1] if players.size() > 1 else null,
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
	_apply_seeded_first_player_bonus(game_manager, _get_session_first_player_index(game_manager, match_session))
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
	for _draw_index in range(5):
		for player in players:
			if player != null:
				player.draw_card()

func _apply_random_first_player_bonus(game_manager: GameManager) -> void:
	if game_manager == null or game_manager.players.size() < 2:
		return
	var first_player_index: int = _rng.randi_range(0, game_manager.players.size() - 1)
	_apply_seeded_first_player_bonus(game_manager, first_player_index)

func _apply_seeded_first_player_bonus(game_manager: GameManager, first_player_index: int) -> void:
	if game_manager == null or game_manager.players.size() < 2:
		return
	var resolved_first_player_index := first_player_index
	if resolved_first_player_index < 0 or resolved_first_player_index >= game_manager.players.size():
		resolved_first_player_index = 0
	var first_player: Player = game_manager.players[resolved_first_player_index]
	var second_player_index := (resolved_first_player_index + 1) % game_manager.players.size()
	var second_player: Player = game_manager.players[second_player_index]
	for player in game_manager.players:
		if player != null:
			player.is_turn_player = false
	game_manager.current_player = first_player
	game_manager.other_player = second_player
	game_manager.turn_player = first_player
	first_player.is_turn_player = true
	second_player.is_turn_player = false
	second_player.gain_mana(2)

func _get_session_first_player_index(game_manager: GameManager, match_session) -> int:
	if game_manager == null or match_session == null or game_manager.players.is_empty():
		return 0
	var seed_text := "%s|%s" % [
		str(match_session.match_id).strip_edges(),
		str(match_session.room_id).strip_edges(),
	]
	if seed_text.strip_edges().is_empty():
		return _rng.randi_range(0, game_manager.players.size() - 1)
	var accumulator: int = 0
	for char_index in range(seed_text.length()):
		accumulator = int((accumulator * 131 + seed_text.unicode_at(char_index)) % 2147483647)
	return accumulator % game_manager.players.size()

func _get_session_deck_submission(match_session, session_id: String) -> Dictionary:
	if session_id.is_empty() or match_session == null:
		return {}
	var submission = match_session.player_decks_by_session.get(session_id, {})
	if submission is Dictionary:
		return (submission as Dictionary).duplicate(true)
	return {}
