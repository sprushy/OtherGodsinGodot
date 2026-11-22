extends CreatureCard
class_name TheChainedGhostOfAthens

func _init() -> void:
	super._init()
	card_name = "The Chained Ghost of Athens"
	card_types = ["Spirit", "Ghost"]
	level = 2
	mana_cost = 0
	sacrifice_cost = 0
	strength = 15
	resilience = 15
	speed = 1
	incorporeal = true
	ability_text = "[b]Incorporeal[/b] ([b]Passive[/b]): Only Spirits or Mages can [b]Engage[/b] The Chained Ghost of Athens. The Chained Ghost of Athens can only [b]Engage[/b] Spirits or Mages. Sleep Immunity.\n[b]Clanking Chains[/b] ([b]Passive[/b]): While The Chained Ghost of Athens is face-up on the field, your opponent cannot activate creature abilities."
	culture = "Olympic"
	art_path = "res://images/card_art/creatures/the_chained_ghost_of_athens.png"

func is_activation_lock_active() -> bool:
	return not (is_face_down or is_prepared or abilities_suppressed())
