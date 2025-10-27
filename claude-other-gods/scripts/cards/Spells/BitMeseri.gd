# cards/spells/BitMeseri.gd (The fix is in the resolve function)
extends SpellCard
class_name BitMeseri

var target_card: Card = null

func _init() -> void:
	super._init()
	card_name = "BitMeseri"
	
	var types: Array[String] = ["Void", "Physical"]
	card_types = types
	
	level = 2
	mana_cost = 3
	speed = 1
	is_legendary = false
	flavor_text = "Cast into the depths of the abyss, never to return."
	culture = "Ancient"

func resolve(game_manager: GameManager, target = null) -> void:
	if target == null:
		print("BitMeseri requires a target!")
		return
	
	if not (target is Card):
		print("BitMeseri can only target cards!")
		return
	
	var target_card_typed: Card = target as Card
	
	# Check if target is a creature or structure
	if target_card_typed.card_type != Card.CardType.CREATURE and target_card_typed.card_type != Card.CardType.STRUCTURE:
		print("BitMeseri can only target creatures or structures!")
		return
	
	print("BitMeseri voids " + target_card_typed.card_name + "!")
	
	# --- FIX: Use the GameManager's hook function for banishment ---
	# This ensures WardingStone.on_removed() is executed before removal.
	game_manager.banish_card_with_hook(target_card_typed)
	
	print(target_card_typed.card_name + " has been cast into the abyss!")

# Override can_be_played to require a valid target
func can_be_played(game_manager: GameManager, player: Player) -> bool:
	if not super.can_be_played(game_manager, player):
		return false
	
	# Check if there are any valid targets on the board
	for p in [game_manager.current_player, game_manager.other_player]:
		for zone in p.frontline_zones + p.reserve_zones:
			for card in zone.cards:
				if card.card_type == Card.CardType.CREATURE or card.card_type == Card.CardType.STRUCTURE:
					return true
	
	print("BitMeseri has no valid targets!")
	return false
