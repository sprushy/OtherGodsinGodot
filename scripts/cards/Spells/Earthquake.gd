extends SpellCard
class_name Earthquake

func _init() -> void:
	super._init()
	card_name = "Earthquake"
	card_types = ["Legendary Destruction", "Physical", "Structures"]
	level = 4
	mana_cost = 1
	speed = 1
	is_legendary = true
	sacrifice_cost = 0
	flavor_text = ""
	culture = "Neutral"
	artist = "Lorinda Tomko"
	art_path = "res://images/card_art/spells/EarthquakeAIEdit.png"
	ability_text = "Destroy all structures and face-up non-aerial machines on the field."

func resolve(game_manager: GameManager, _target = null) -> void:
	if game_manager == null:
		return
	var doomed_cards: Array[Card] = []
	for player: Player in game_manager.players:
		for zone: Zone in player.frontline_zones + player.reserve_zones:
			for card: Card in zone.cards:
				if _is_doomed_card(card):
					doomed_cards.append(card)
	if doomed_cards.is_empty():
		print("Earthquake found no structures or face-up non-aerial machines to destroy.")
		return
	for doomed_card in doomed_cards:
		game_manager.request_send_to_graveyard(doomed_card, Callable(), false, true)
	print("Earthquake destroys all structures and face-up non-aerial machines on the field.")

func _is_doomed_card(card: Card) -> bool:
	if card == null:
		return false
	if card.is_face_down:
		return false
	if card.card_type == Card.CardType.STRUCTURE:
		return true
	return card.has_type("Machine") and not card.has_type("Aerial") and not card.is_stealth
