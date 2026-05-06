extends RefCounted
class_name PracticeMatchSetup

const DeckBuilderScript = preload("res://scripts/Other/DeckBuilder.gd")
const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")

func build_thor_practice_match(
	game_manager: GameManager,
	player_practice_deck: Dictionary = {},
	thor_practice_deck: Dictionary = {}
) -> Dictionary:
	if game_manager == null:
		return {}

	game_manager.players.clear()
	var player1 := Player.new()
	player1.player_name = "Player 1"
	game_manager.players.append(player1)

	var player2 := Player.new()
	player2.player_name = "Thor"
	game_manager.players.append(player2)

	var player_deck_name := _load_player_practice_deck(player1, player_practice_deck)
	if not _try_load_saved_player_practice_deck(player2, thor_practice_deck):
		_add_practice_god(player2, Thor.new(), game_manager)
		_add_practice_power(player2, 0, CallOfTheValkyrie.new())
		for card in build_thor_practice_deck():
			_add_practice_deck_card(player2, card)

	game_manager.setup_game()
	_apply_opening_state(game_manager, player1, player2)

	return {
		"player1": player1,
		"player2": player2,
		"player_deck_name": player_deck_name,
	}

func build_thor_practice_deck() -> Array[Card]:
	return [
		EnkiLordOfEridu.new(),
		HariiWarrior.new(),
		HariiFransiscan.new(),
		BrownBear.new(),
		VoidShield.new(),
		MeadOfPoetry.new(),
		VisionOfOdin.new(),
		DivineLightning.new(),
		FallOfTheMighty.new(),
		HariiWarrior.new(),
		HariiFransiscan.new(),
		BrownBear.new(),
		EnkiLordOfEridu.new(),
		HariiJarl.new(),
		DivineLightning.new(),
		FallOfTheMighty.new(),
		HariiWarrior.new(),
		HariiFransiscan.new(),
		BrownBear.new(),
		HariiJarl.new(),
		DivineLightning.new(),
		FallOfTheMighty.new(),
		VoidShield.new(),
		VoidShield.new(),
		VisionOfOdin.new(),
		Askelladen.new(),
		Askelladen.new(),
	]

func _apply_opening_state(game_manager: GameManager, player1: Player, player2: Player) -> void:
	for _draw_index in range(5):
		player1.draw_card()
		player2.draw_card()

	player1.spend_mana(player1.mana)
	player2.spend_mana(player2.mana)
	player2.gain_mana(2)
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

func _load_player_practice_deck(player: Player, player_practice_deck: Dictionary) -> String:
	if _try_load_saved_player_practice_deck(player, player_practice_deck):
		var saved_name := str(player_practice_deck.get("name", player_practice_deck.get("deck_name", ""))).strip_edges()
		return saved_name
	_add_practice_god(player, Baldr.new(), null)
	_create_default_player_deck(player)
	return ""

func _try_load_saved_player_practice_deck(player: Player, player_practice_deck: Dictionary) -> bool:
	if player == null or player_practice_deck.is_empty():
		return false
	var saved_counts = player_practice_deck.get("cards", {})
	if not (saved_counts is Dictionary) or (saved_counts as Dictionary).is_empty():
		return false
	var submitted_cards := CardCatalogScript.make_cards_from_counts(saved_counts)
	if submitted_cards.is_empty():
		return false
	var deck_builder := DeckBuilderScript.new()
	return deck_builder.build_deck(player, submitted_cards, player_practice_deck.get("special_setup", {}))

func _add_practice_god(player: Player, god: GodCard, game_manager: GameManager) -> void:
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
	if game_manager != null and god.has_method("on_summon"):
		god.on_summon(game_manager)

func _add_practice_deck_card(player: Player, card: Card) -> void:
	if player == null or card == null:
		return
	card.card_owner = player
	player.deck_zone.add_card(card)

func _add_practice_power(player: Player, slot_index: int, power: PowerCard, unlocked: bool = false) -> void:
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

func _create_default_player_deck(player: Player) -> void:
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
