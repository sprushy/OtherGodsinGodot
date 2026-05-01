extends SpellCard
class_name OccultSingularity

const ART_PATH := "res://images/card_art/spells/OccultSingularityEdit.png"

func _init() -> void:
	super._init()
	card_name = "Occult Singularity"
	culture = "Neutral"
	card_types = ["Legendary Destruction", "Occult"]
	level = 4
	mana_cost = 1
	speed = 1
	is_legendary = true
	flavor_text = ""
	ability_text = "Destroy all magical cards on the field."
	artist = ""
	art_path = ART_PATH
	targets = false

func resolve(game_manager: GameManager, _target = null) -> void:
	if game_manager == null:
		return

	var doomed_cards := _get_doomed_cards(game_manager)
	if doomed_cards.is_empty():
		var no_targets_feedback := "%s found no magical cards on the field." % card_name
		game_manager.note_player_feedback(no_targets_feedback)
		print(no_targets_feedback)
		return

	var destroyed_count := 0
	for doomed_card in doomed_cards:
		if game_manager.request_send_to_graveyard(doomed_card, Callable(), false, true):
			destroyed_count += 1

	var feedback := "%s destroyed %d magical card(s) on the field." % [card_name, destroyed_count]
	game_manager.note_player_feedback(feedback)
	print(feedback)

func can_be_played(game_manager: GameManager, player: Player) -> bool:
	if not super.can_be_played(game_manager, player):
		return false
	if _get_doomed_cards(game_manager).is_empty():
		print(card_name + " has no valid targets.")
		return false
	return true

func get_play_failure_reason(game_manager: GameManager, player: Player) -> String:
	var base_reason := super.get_play_failure_reason(game_manager, player)
	if not base_reason.is_empty():
		return base_reason
	if _get_doomed_cards(game_manager).is_empty():
		return card_name + " has no valid targets."
	return ""

func _get_doomed_cards(game_manager: GameManager) -> Array[Card]:
	var doomed_cards: Array[Card] = []
	if game_manager == null:
		return doomed_cards
	for player: Player in game_manager.players:
		for zone: Zone in player.frontline_zones + player.reserve_zones:
			for card: Card in zone.cards:
				if _is_doomed_card(card):
					doomed_cards.append(card)
	return doomed_cards

func _is_doomed_card(card: Card) -> bool:
	return card != null \
		and card.current_zone != null \
		and card.current_zone.is_board_zone() \
		and card.is_magical_card()
