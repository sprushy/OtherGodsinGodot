extends CreatureCard
class_name Gullinbursti

func _init() -> void:
	super._init()
	card_name = "Gullinbursti"
	card_types = ["Animal", "Porcine", "Norse Creature"]
	level = 4
	mana_cost = 3
	sacrifice_cost = 0
	speed = 4
	resilience = 25
	strength = 24
	ability_text = "[b]Dodge[/b] ([b]Passive[/b]): Cannot be attacked by slower creatures."
	# flavor_text = "Forged by Dwarven smiths for the God Freyr, Gullinbursti can run through air and water and moves faster than any horse."
	flavor_text = ""
	culture = "Norse"
	artist = "Lorinda Tomko"
	art_path = "res://images/card_art/creatures/gullinbursti.png"

func can_be_engaged_by(source: Card) -> bool:
	if not super.can_be_engaged_by(source):
		return false
	if abilities_suppressed():
		return true
	if source == null or not source.is_creature_card():
		return true
	return source.get_effective_speed() >= get_effective_speed()
