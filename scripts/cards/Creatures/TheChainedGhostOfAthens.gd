extends CreatureCard
class_name TheChainedGhostOfAthens

func _init() -> void:
	super._init()
	card_name = "The Chained Ghost of Athens"
	card_types = ["Spirit", "Ghost", "Olympic Creature"]
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	strength = 15
	resilience = 15
	speed = 1
	ability_text = "[b]Clanking Chains[/b] ([b]Passive[/b]): While this card is face-up on the field, your opponent cannot activate creature abilities."
	culture = "Olympic"
	art_path = "res://images/card_art/creatures/the_chained_ghost_of_athens.png"

func is_activation_lock_active() -> bool:
	return not (is_face_down or is_prepared or abilities_suppressed())
