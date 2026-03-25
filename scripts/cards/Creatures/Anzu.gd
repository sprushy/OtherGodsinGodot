extends CreatureCard
class_name Anzu

func _init() -> void:
	super._init()  # â† MUST call this first to initialize Card properties
	
	card_name = "AnzÃ»"
	card_types = ["Divine Manifestation", "Demon", "Animal", "Avian", "Aerial", "Ancient Creature"]
	level = 4
	mana_cost = 2
	sacrifice_cost = 0
	speed = 3
	resilience = 13
	strength = 24
	flavor_text = "The Divine Bird AnzÃ» is master of thunderstorms and the southern wind; he breathes both fire and water."
	culture = "Ancient"
	art_path = "res://images/card_art/creatures/anzu ai.png"
	artist = "Lorinda Tomko"
