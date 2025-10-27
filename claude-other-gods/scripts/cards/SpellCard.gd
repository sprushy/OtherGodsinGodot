# SpellCard.gd
extends BaseCard
class_name SpellCard

func _init() -> void:
	
	card_type = Card.CardType.SPELL
	speed = 1  # All spells are speed 1 by default

# Override this in specific spell cards to define what the spell does
func resolve(game_manager: GameManager, target = null) -> void:
	push_error("SpellCard.resolve() must be overridden in " + card_name + "!")

# Called when the spell is played
func on_play(game_manager: GameManager, target = null) -> void:
	print("Casting " + card_name + "...")
	resolve(game_manager, target)
	
	# Spell goes to graveyard after resolving (unless overridden)
	if should_go_to_graveyard():
		card_owner.move_card(self, card_owner.graveyard_zone)
		print(card_name + " sent to graveyard")

# Override this if your spell should NOT go to graveyard
func should_go_to_graveyard() -> bool:
	return true

# Spells can only be played on your turn (speed 1)
func can_be_played(game_manager: GameManager, player: Player) -> bool:
	if player != game_manager.current_player:
		print("Spells can only be cast on your turn")
		return false
	return super.can_be_played(game_manager, player)
