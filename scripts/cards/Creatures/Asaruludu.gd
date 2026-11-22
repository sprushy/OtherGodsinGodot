extends CreatureCard
class_name Asaruludu

func _init() -> void:
	super._init()
	card_name = "Asaruludu"
	card_types = ["Divine Manifestation", "Giant"]
	level = 4
	mana_cost = 3
	sacrifice_cost = 0
	speed = 1
	resilience = 25
	strength = 28
	ability_text = "Guardian ([b]Passive[/b]): Opposing effects can't target Allied Ancient creatures on your turn or during combat."
	flavor_text = ""
	culture = "Ancient"
	art_path = "res://images/card_art/creatures/AsaruluduAI5.png"
