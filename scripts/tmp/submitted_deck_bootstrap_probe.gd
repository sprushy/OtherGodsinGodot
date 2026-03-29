extends SceneTree

const DefaultMatchSetupScript = preload("res://scripts/server/DefaultMatchSetup.gd")
const MatchSessionScript = preload("res://scripts/server/MatchSession.gd")
const DeckValidatorScript = preload("res://scripts/server/DeckValidator.gd")

func _init() -> void:
	var validator = DeckValidatorScript.new()
	var player_one_deck := {
		"Baldr": 1,
		"Blessed Knights": 3,
		"Brown Bear": 3,
		"Berserker": 3,
		"Again-Walker": 3,
		"Byggvir": 3,
		"Bit Meseri": 3,
		"Absence": 3,
		"Warding Stone": 3,
		"Void Shield": 3,
		"Bearded Axe": 3,
		"Blot Sacrifice": 3,
		"Fall of the Mighty": 2,
	}
	var player_two_deck := {
		"Mummu": 1,
		"Alu": 3,
		"Anzu": 3,
		"Asakku": 3,
		"Asaruludu": 3,
		"Bit Meseri": 3,
		"Absence": 3,
		"Warding Stone": 3,
		"Void Shield": 3,
		"Bearded Axe": 3,
		"Blot Sacrifice": 3,
		"Fall of the Mighty": 3,
		"Asag the Destroyer": 2,
	}
	var player_one_validation: Dictionary = validator.validate_deck(player_one_deck)
	var player_two_validation: Dictionary = validator.validate_deck(player_two_deck)
	if not bool(player_one_validation.get("is_valid", false)):
		_fail("Player one probe deck is invalid: %s" % str(player_one_validation.get("error", "")))
		return
	if not bool(player_two_validation.get("is_valid", false)):
		_fail("Player two probe deck is invalid: %s" % str(player_two_validation.get("error", "")))
		return

	var match_session = MatchSessionScript.new(
		"match_probe",
		"room_probe",
		"127.0.0.1",
		12345,
		["session_a", "session_b"],
		{
			"session_a": {
				"deck_name": "Baldr Probe",
				"cards": player_one_validation.get("cards", {}).duplicate(true),
				"validation": player_one_validation.duplicate(true),
			},
			"session_b": {
				"deck_name": "Mummu Probe",
				"cards": player_two_validation.get("cards", {}).duplicate(true),
				"validation": player_two_validation.duplicate(true),
			},
		}
	)

	var game_manager := GameManager.new()
	var setup = DefaultMatchSetupScript.new()
	var match_players: Dictionary = setup.build_match_from_session_decks(game_manager, match_session)
	var player1: Player = match_players.get("player1", null)
	var player2: Player = match_players.get("player2", null)
	if player1 == null or player2 == null:
		_fail("Submitted deck bootstrap did not return both players.")
		return
	if player1.god_zone.get_card_count() != 1 or player2.god_zone.get_card_count() != 1:
		_fail("Submitted deck bootstrap did not place both gods.")
		return
	if player1.god_zone.cards[0].card_name != "Baldr":
		_fail("Player one god should be Baldr, got %s." % player1.god_zone.cards[0].card_name)
		return
	if player2.god_zone.cards[0].card_name != "Mummu":
		_fail("Player two god should be Mummu, got %s." % player2.god_zone.cards[0].card_name)
		return
	if player1.power_zones[0].get_card_count() != 0:
		_fail("Player one should not receive debug-only powers.")
		return
	if player1.reserve_zones[3].get_card_count() != 0 or player2.reserve_zones[3].get_card_count() != 0:
		_fail("Submitted deck bootstrap should not inject reserve equipment.")
		return
	if player1.hand_zone.get_card_count() != 5 or player2.hand_zone.get_card_count() != 5:
		_fail("Players should open with five cards in hand.")
		return
	if player1.mana != 20 or player2.mana != 20:
		_fail("Players should retain the current 20 mana opening baseline.")
		return
	if player1.deck_zone.get_card_count() != 30:
		_fail("Player one should have 30 remaining deck cards after drawing 5, got %d." % player1.deck_zone.get_card_count())
		return
	if player2.deck_zone.get_card_count() != 30:
		_fail("Player two should have 30 remaining deck cards after drawing 5, got %d." % player2.deck_zone.get_card_count())
		return
	print("PASS:submitted_deck_bootstrap")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	print("FAIL:%s" % message)
	quit(1)
