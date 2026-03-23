extends PowerCard
class_name AllfathersSacrifice

const UNLOCK_COST := 5
const FOLLOWER_COST := 12

func _init() -> void:
	super._init()
	card_name = "Allfather's Sacrifice"
	mana_cost = UNLOCK_COST
	
	# Type reference
	card_types = ["Searching", "Spells"]
	
	# Culture reference
	culture = "Norse"
	
	ability_text = "Unlock (5): Searching – Spells — Lose 12 followers. Move one spell from your deck to the top of your deck."
	art_path = "res://images/card_art/allfathers_sacrifice.png"


func can_activate(game_manager: GameManager) -> bool:
	return not is_face_down \
		and card_owner == game_manager.current_player \
		and card_owner.followers >= FOLLOWER_COST


func activate(game_manager: GameManager, _target: Card = null) -> void:
	var player = card_owner
	
	player.lose_followers(FOLLOWER_COST)
	
	# Find a spell in the deck (you'll likely want to replace with player choice)
	var spell_card := null
	for card in player.deck:
		if "Spells" in card.card_types:
			spell_card = card
			break
	
	if spell_card:
		player.deck.erase(spell_card)
		player.deck.push_front(spell_card)
		print(card_name + ": Moved " + spell_card.card_name + " to the top of the deck.")
	else:
		print(card_name + ": No spell found in deck.")
