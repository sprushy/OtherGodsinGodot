extends GodCard
class_name Mummu

var paragon: String = "Paragon of Entropy"

func _init() -> void:
	super._init()
	card_name = "Mummu, The One Who Has Awoken"
	card_types = ["Artisan", "Wisdom", "Chaos", "Entropy"]
	mana_cost = 0
	culture = "Ancient"
	flavor_text = "Before the world was shaped, he stirred in the depths."
	ability_text = "Entropic Force (Speed 1, Activate): [b]Shelve[/b] a face-up card you control to the bottom of your deck. Gain mana equal to that card's level - 1."
	art_path = "res://images/card_art/gods/Mummu.png"
	artist = "Ricarrdo Zoppello"
	name_at_bottom = true

func can_activate(game_manager: GameManager) -> bool:
	# Speed 1: only usable on your own turn
	if is_muted:
		return false
	if card_owner != game_manager.current_player:
		return false
	# Need at least one face-up card you control on the board (excluding self)
	for zone in card_owner.frontline_zones + card_owner.reserve_zones:
		for card in zone.cards:
			if not card.is_face_down:
				return true
	return false

func is_valid_activation_target(target: Card) -> bool:
	return target != null and not target.is_face_down and target.get_controller() == card_owner

func activate(game_manager: GameManager, target: Card) -> void:
	if not is_valid_activation_target(target):
		print("Entropic Force: invalid target!")
		return
	if game_manager != null and game_manager.is_immune_to_source(target, self):
		print("Entropic Force fizzles - " + target.card_name + " is immune to powers.")
		return
	var mana_gained: int = max(0, target.level - 1)
	print("Entropic Force: returning " + target.card_name + " to deck, gaining " + str(mana_gained) + " mana.")
	game_manager.send_to_deck_bottom_with_hook(target)
	card_owner.gain_mana(mana_gained)

func on_turn_end(game_manager: GameManager) -> void:
	super.on_turn_end(game_manager)
