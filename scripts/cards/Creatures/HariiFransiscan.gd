extends CreatureCard
class_name HariiFransiscan

func _init() -> void:
	super._init()
	card_name = "Harii Fransiscan"
	card_types = ["Human", "Warrior", "Norse Creature"]
	level = 2
	mana_cost = 0
	speed = 3
	resilience = 5
	strength = 17
	sacrifice_cost = 0
	ability_text = "[b]Relentless Tempo[/b] ([b]Passive[/b]): This creature can take one additional minor action each turn. In practice, it can take two minor actions and a major action, or three minor actions."
	culture = "Norse"
	artist = "Ricardo Zoppello"
	art_path = "res://images/card_art/creatures/HariiFransiscanEdit.png"

func get_max_minor_creature_actions_per_turn() -> int:
	if abilities_suppressed():
		return super.get_max_minor_creature_actions_per_turn()
	return 3

func get_max_minor_creature_actions_before_major() -> int:
	if abilities_suppressed():
		return super.get_max_minor_creature_actions_before_major()
	return 3
