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
	ability_text = "Destroy all structures on the field."

func resolve(game_manager: GameManager, target = null) -> void:
	if game_manager == null:
		return
	var structures: Array[Card] = []
	for player: Player in game_manager.players:
		for zone: Zone in player.frontline_zones + player.reserve_zones:
			for card: Card in zone.cards:
				if card.card_type == Card.CardType.STRUCTURE:
					structures.append(card)
	if structures.is_empty():
		print("Earthquake found no structures to destroy.")
		return
	for structure in structures:
		game_manager.request_send_to_graveyard(structure, Callable(), false, true)
	print("Earthquake destroys all structures on the field.")
