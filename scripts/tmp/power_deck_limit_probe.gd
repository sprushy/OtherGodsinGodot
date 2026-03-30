extends SceneTree

const CardCatalogScript := preload("res://scripts/cards/CardCatalog.gd")
const DeckValidatorScript := preload("res://scripts/server/DeckValidator.gd")
const DeckBuilderUIScript := preload("res://scripts/ui/DeckBuilderUI.gd")
const PlayerScript := preload("res://scripts/Other/player.gd")

func _assert_state(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _init() -> void:
	var validator = DeckValidatorScript.new()
	var valid_deck := {
		"Baldr": 1,
		"Giant's Disdain": 1,
		"Advanced Building Techniques": 1,
		"Allfather's Sacrifice": 1,
		"Blessed Knights": 3,
		"Brown Bear": 3,
		"Berserker": 3,
		"Again-Walker": 3,
		"Byggvir": 3,
		"BitMeseri": 3,
		"Absence": 3,
		"Warding Stone": 3,
		"Void Shield": 3,
		"Bearded Axe": 3,
		"Blot Sacrifice": 3,
		"Fall of the Mighty": 2,
	}
	var invalid_duplicate_power_deck := valid_deck.duplicate(true)
	invalid_duplicate_power_deck.erase("Advanced Building Techniques")
	invalid_duplicate_power_deck["Giant's Disdain"] = 2

	var valid_result: Dictionary = validator.validate_deck(valid_deck)
	_assert_state(bool(valid_result.get("is_valid", false)), "Unique powers should remain legal.")

	var invalid_result: Dictionary = validator.validate_deck(invalid_duplicate_power_deck)
	_assert_state(not bool(invalid_result.get("is_valid", true)), "Duplicate powers should be rejected.")
	_assert_state(
		str(invalid_result.get("error", "")).contains("copy limit (1)"),
		"Duplicate powers should fail with a copy limit error."
	)

	var player := PlayerScript.new()
	_assert_state(player.validate_deck(_build_deck_array(valid_deck)), "Player.validate_deck should allow unique powers.")
	_assert_state(
		not player.validate_deck(_build_deck_array(invalid_duplicate_power_deck)),
		"Player.validate_deck should reject duplicate powers."
	)

	var deck_builder_ui := DeckBuilderUIScript.new()
	var giant_disdain := _find_template("Giant's Disdain")
	var blessed_knights := _find_template("Blessed Knights")
	_assert_state(deck_builder_ui._max_copies(giant_disdain) == 1, "Deck builder should cap powers at one copy.")
	_assert_state(deck_builder_ui._max_copies(blessed_knights) == 3, "Regular non-legendary cards should still allow three copies.")

	print("power_deck_limit_probe: PASS")
	quit()

func _build_deck_array(deck_list: Dictionary) -> Array[Card]:
	var cards: Array[Card] = []
	for raw_card_name in deck_list.keys():
		var template := _find_template(str(raw_card_name))
		_assert_state(template != null, "Missing card template for %s." % str(raw_card_name))
		var count := int(deck_list[raw_card_name])
		for _copy_index in range(count):
			cards.append(template.duplicate(true))
	return cards

func _find_template(card_name: String) -> Card:
	for card in CardCatalogScript.make_all_cards():
		if card != null and card.card_name == card_name:
			return card
	return null
