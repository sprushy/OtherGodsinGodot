extends BaseCard
class_name Mummu

var paragon: String = "Paragon of Entropy"

func _init() -> void:
	card_name = "Mummu, The One Who Has Awoken"
	card_type = Card.CardType.CREATURE
	is_god = true
	card_types = ["Artisan", "Wisdom", "Chaos", "Entropy"]
	mana_cost = 0
	strength = 28
	resilience = 32
	speed = 1
	culture = "Ancient"
	flavor_text = "Before the world was shaped, he stirred in the depths."
	ability_text = "Entropic Force (Speed 1, Activate): Return a face-up card you control to your deck. Gain mana equal to that card's level - 1."
	art_path = "res://images/card_art/Mummu.png"
	artist = "Ricarrdo Zoppello"
	name_at_bottom = true

func can_activate(game_manager: GameManager) -> bool:
	# Speed 1: only usable on your own turn
	if card_owner != game_manager.current_player:
		return false
	# Need at least one face-up card you control on the board (excluding self)
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if not card.is_face_down:
				return true
	return false

func activate(game_manager: GameManager, target: Card) -> void:
	if target == null or target.is_face_down or target.card_owner != card_owner:
		print("Entropic Force: invalid target!")
		return
	var mana_gained: int = max(0, target.level - 1)
	print("Entropic Force: returning " + target.card_name + " to deck, gaining " + str(mana_gained) + " mana.")
	card_owner.move_card(target, card_owner.deck_zone)
	card_owner.gain_mana(mana_gained)
