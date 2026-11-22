# GenericCreature.gd
extends CreatureCard
class_name GenericCreature

# This class can be used for 80% of creatures that don't have unique hooks.
# They can be defined purely via Resource properties.

func _init(p_data: Dictionary = {}) -> void:
	super._init()
	if p_data.is_empty():
		return

	card_name = p_data.get("name", "Unnamed")
	var types: Array = p_data.get("types", [])
	card_types = CardSubtypes.without_culture_labels(types)
	level = p_data.get("level", 1)
	mana_cost = p_data.get("mana_cost", 0)
	sacrifice_cost = p_data.get("sacrifice_cost", 0)
	speed = p_data.get("speed", 1)
	resilience = p_data.get("resilience", 1)
	strength = p_data.get("strength", 1)
	flavor_text = p_data.get("flavor", "")
	culture = p_data.get("culture", CardSubtypes.legacy_culture(types, "Ancient"))
	art_path = p_data.get("art", "")
	artist = p_data.get("artist", "")
