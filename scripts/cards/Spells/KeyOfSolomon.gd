extends SpellCard
class_name KeyOfSolomon

const MAX_DEMONS_TO_RETURN := 2
const ART_PATH := "res://images/card_art/spells/SolomonKeyEdit.png"

func _init() -> void:
	super._init()
	card_name = "Key of Solomon"
	culture = "Ancient"
	card_types = ["Ancient", "Recovery"]
	level = 1
	mana_cost = 1
	speed = 1
	is_legendary = false
	ability_text = "[b]Return Grave[/b]/[b]Return Void[/b]: Sacrifice an Animal, add two Demons from your grave or void to your hand."
	artist = "Lorinda Tomko"
	art_path = ART_PATH

func can_be_played(game_manager: GameManager, player: Player) -> bool:
	if not super.can_be_played(game_manager, player):
		return false
	if get_valid_sacrifices().is_empty():
		return false
	if get_valid_demon_targets().is_empty():
		return false
	return true

## Returns friendly Animals on the board that can be sacrificed.
func get_valid_sacrifices() -> Array[Card]:
	var cards: Array[Card] = []
	if card_owner == null:
		return cards
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if card != null \
					and card.card_type == Card.CardType.CREATURE \
					and card.get_controller() == card_owner \
					and card.has_type("Animal") \
					and card.can_be_used_for_creature_sacrifice:
				cards.append(card)
	return cards

## Returns Demon creatures in the owner's graveyard or abyss.
func get_valid_demon_targets() -> Array[Card]:
	var cards: Array[Card] = []
	if card_owner == null:
		return cards
	for card in card_owner.graveyard_zone.cards:
		if card != null and card.card_type == Card.CardType.CREATURE and card.has_type("Demon"):
			cards.append(card)
	for card in card_owner.abyss_zone.cards:
		if card != null and card.card_type == Card.CardType.CREATURE and card.has_type("Demon"):
			cards.append(card)
	return cards

func resolve(game_manager: GameManager, target = null) -> void:
	if game_manager == null or card_owner == null:
		return
	var demons_chosen: Array[Card] = []
	if target is Array:
		for c in target:
			if c is Card:
				demons_chosen.append(c as Card)
	_add_demons_to_hand(game_manager, demons_chosen)

func resolve_from_command(game_manager: GameManager, command: Dictionary) -> void:
	var choice_uids: Array = command.get("choices", [])
	var demons: Array[Card] = []
	for chosen_uid in choice_uids:
		var c := game_manager.get_card_by_uid(chosen_uid as String)
		if c != null:
			demons.append(c)
	_add_demons_to_hand(game_manager, demons)

func _add_demons_to_hand(game_manager: GameManager, chosen_demons: Array[Card]) -> void:
	if game_manager == null or card_owner == null:
		return
	var valid := get_valid_demon_targets()
	var count := 0
	for demon in chosen_demons:
		if count >= MAX_DEMONS_TO_RETURN:
			break
		if demon == null or demon not in valid:
			continue
		card_owner.move_card(demon, card_owner.hand_zone)
		count += 1
	if count == 0:
		game_manager.note_player_feedback("Key of Solomon: no valid Demons found to return.")
	else:
		game_manager.note_player_feedback(
			"Key of Solomon returned %d Demon(s) to hand." % count
		)
