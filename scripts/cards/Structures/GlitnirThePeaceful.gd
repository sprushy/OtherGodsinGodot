extends StructureCard
class_name GlitnirThePeaceful

const ART_PATH := "res://images/card_art/structures/glitnir_the_peaceful.png"

func _init() -> void:
	super._init()
	card_name = "Glitnir the Peaceful"
	card_types = ["Dwelling", "Hall"]
	level = 1
	mana_cost = 2
	sacrifice_cost = 0
	resilience = 30
	strength = 0
	speed = 0
	ability_text = "All creatures must be summoned in defensive stance."
	flavor_text = ""
	culture = "Norse"
	artist = "Lorinda Tomko"
	art_path = ART_PATH

func forces_defensive_summon() -> bool:
	return true
