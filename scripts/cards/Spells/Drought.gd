extends SpellCard
class_name Drought

func _init() -> void:
	super._init()
	card_name = "Drought"
	culture = "Neutral"
	card_types = ["Spell", "Weather", "Permanent"]
	level = 3
	mana_cost = 0
	speed = 1
	sacrifice_cost = 0
	artist = "User provided"
	art_path = "res://images/card_art/spells/drought.png"
	ability_text = "Destroy any face-up [b]Weather[/b] spells. Spells must be prepared for 1 turn before use while this remains face-up."

func should_go_to_graveyard() -> bool:
	return false

func resolve(game_manager: GameManager, _target = null) -> void:
	if game_manager == null:
		return
	var doomed_cards: Array[Card] = []
	for card in game_manager.get_field_cards():
		if card == null or card == self or not (card is SpellCard):
			continue
		if not card.is_face_down and card.has_type("Weather"):
			doomed_cards.append(card)
	game_manager.request_send_cards_to_graveyard(doomed_cards)
	game_manager.note_player_feedback(card_name + " parches the battlefield.")
