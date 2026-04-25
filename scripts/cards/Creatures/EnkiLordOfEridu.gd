extends CreatureCard
class_name EnkiLordOfEridu

func _init() -> void:
	super._init()
	card_name = "Enki, Lord of Eridu"
	card_types = ["Divine Manifestation", "Mer", "Mage", "Priest", "Sage", "Ancient Creature"]
	level = 6
	mana_cost = 8
	sacrifice_cost = 0
	speed = 1
	resilience = 36
	strength = 32
	ability_text = "Class Immunity (Passive): Friendly Mages are immune to hexes."
	flavor_text = ""
	culture = "Ancient"
	art_path = "res://images/card_art/creatures/enki_lord_of_eridu - Copy.jpg"
	artist = "Ricarrdo Zoppello"

func protects_from_hex(target: Card) -> bool:
	if hex_protection_is_suppressed_raw():
		return false
	if target == null:
		return false
	return (
		target.card_type == Card.CardType.CREATURE
		and target.get_controller() == get_controller()
		and target.has_type("Mage")
	)

func hex_protection_is_suppressed_raw() -> bool:
	if is_enslaved() or is_muted:
		return true
	for status in active_statuses:
		if status.get("name", "") == "petrified":
			return true
	for status in active_statuses:
		if status.get("name", "") != Card.ABILITY_NEGATED_STATUS:
			continue
		var source_card := status.get("source_card", null) as Card
		if source_card == null:
			return true
		var immunity_tag := source_card.get_ability_immunity_tag() if source_card.has_method("get_ability_immunity_tag") else ""
		if immunity_tag != "hexes":
			return true
	return false
