extends SpellCard
class_name Famine

const ART_PATH := "res://images/card_art/spells/famine.jpg"

func _init() -> void:
	super._init()
	card_name = "Famine"
	card_types = ["Legendary Destruction", "Creature"]
	level = 4
	mana_cost = 1
	speed = 1
	is_legendary = true
	sacrifice_cost = 0
	flavor_text = ""
	culture = "Neutral"
	artist = "Lorinda Tomko"
	art_path = ART_PATH
	ability_text = "Reveal all face-down creatures. Destroy all non-machine, non-spirit creatures on the field."

func resolve(game_manager: GameManager, _target = null) -> void:
	if game_manager == null:
		return

	var all_creatures: Array[Card] = []
	var revealed_count := 0
	for player: Player in game_manager.players:
		for zone: Zone in player.frontline_zones + player.reserve_zones:
			for card: Card in zone.cards:
				if card.card_type != Card.CardType.CREATURE:
					continue
				all_creatures.append(card)
				if card.is_face_down:
					card.reveal(game_manager)
					revealed_count += 1

	var doomed_creatures: Array[Card] = []
	for creature in all_creatures:
		if _should_destroy(creature):
			doomed_creatures.append(creature)

	if doomed_creatures.is_empty() and revealed_count == 0:
		print(card_name + " found no creatures to destroy.")
		return

	for creature in doomed_creatures:
		game_manager.request_send_to_graveyard(creature, Callable(), false, true)

	print(card_name + " revealed " + str(revealed_count) + " face-down creature(s) and destroyed " + str(doomed_creatures.size()) + " creature(s).")

func can_be_played(game_manager: GameManager, player: Player) -> bool:
	if not super.can_be_played(game_manager, player):
		return false
	for p: Player in game_manager.players:
		for zone: Zone in p.frontline_zones + p.reserve_zones:
			for card: Card in zone.cards:
				if card.card_type == Card.CardType.CREATURE and (card.is_face_down or _should_destroy(card)):
					return true
	print(card_name + " has no valid targets.")
	return false

func _should_destroy(card: Card) -> bool:
	if card == null:
		return false
	if card.card_type != Card.CardType.CREATURE:
		return false
	if card.has_type("Machine") or card.has_type("Spirit"):
		return false
	return true
