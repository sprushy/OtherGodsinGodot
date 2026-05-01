extends PowerCard
class_name AllfathersSacrifice

const UNLOCK_COST := 5
const FOLLOWER_COST := 12
const ART_PATH := "res://images/card_art/powers/allfathers_sacrifice.jpg"

func _init() -> void:
	super._init()
	card_name = "Allfather's Sacrifice"
	mana_cost = UNLOCK_COST
	card_types = ["Searching", "Spells"]
	culture = "Norse"
	ability_text = "[b]Unlock[/b] (5): Searching - Spells - Lose 12 followers. [b]Search[/b] a spell. [b]Prime[/b] it."
	art_path = ART_PATH

func can_activate(game_manager: GameManager) -> bool:
	return not is_face_down \
		and not is_activation_locked(game_manager) \
		and card_owner == game_manager.current_player \
		and card_owner.followers >= FOLLOWER_COST \
		and not get_spell_cards_in_deck().is_empty()

func get_activation_failure_reason(game_manager: GameManager) -> String:
	var base_reason := super.get_activation_failure_reason(game_manager)
	if game_manager == null:
		return base_reason
	if card_owner == null or card_owner.followers < FOLLOWER_COST:
		return card_name + " needs " + str(FOLLOWER_COST) + " followers."
	if get_spell_cards_in_deck().is_empty():
		return card_name + " could not find a spell in your deck."
	return base_reason

func get_spell_cards_in_deck() -> Array[Card]:
	var spells: Array[Card] = []
	for card in card_owner.deck_zone.cards:
		if card.card_type == Card.CardType.SPELL:
			spells.append(card)
	return spells

func activate(game_manager: GameManager, target: Card = null) -> void:
	if not can_activate(game_manager):
		if game_manager != null:
			game_manager.note_player_feedback(get_activation_failure_reason(game_manager))
		return
	var player := card_owner
	if target == null or target.card_type != Card.CardType.SPELL or target.current_zone != player.deck_zone:
		print(card_name + ": Invalid spell choice.")
		return
	if not player.deck_zone.cards.has(target):
		print(card_name + ": Chosen spell is no longer in deck.")
		return

	player.lose_followers(FOLLOWER_COST)
	player.deck_zone.cards.erase(target)
	player.deck_zone.cards.shuffle()
	player.deck_zone.cards.insert(0, target)
	print(card_name + ": Shuffled deck, moved " + target.card_name + " to the top.")
