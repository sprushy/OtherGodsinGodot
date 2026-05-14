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
	ability_text = "[b]Restless Tempo[/b]: Has an additional minor action per turn. Attacking does not exhaust minor actions."
	culture = "Norse"
	artist = "Ricardo Zoppello"
	art_path = "res://images/card_art/creatures/HariiFransiscanEdit.png"

func get_max_minor_creature_actions_per_turn() -> int:
	if abilities_suppressed():
		return super.get_max_minor_creature_actions_per_turn()
	return super.get_max_minor_creature_actions_per_turn() + 1

func get_max_minor_creature_actions_before_major() -> int:
	if abilities_suppressed():
		return super.get_max_minor_creature_actions_before_major()
	return get_max_minor_creature_actions_per_turn()

func can_take_minor_creature_action_after_major() -> bool:
	if abilities_suppressed():
		return super.can_take_minor_creature_action_after_major()
	return true

func does_attack_exhaust_minor_creature_actions() -> bool:
	if abilities_suppressed():
		return super.does_attack_exhaust_minor_creature_actions()
	return false
