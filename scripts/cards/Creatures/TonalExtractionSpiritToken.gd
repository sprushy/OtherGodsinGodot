extends CreatureCard
class_name TonalExtractionSpiritToken

func _init() -> void:
	super._init()
	card_name = "Tonal Spirit"
	card_types = ["Token", "Spirit"]
	is_token = true
	level = 1
	mana_cost = 0
	sacrifice_cost = 0
	speed = 1
	resilience = 1
	strength = 1
	ability_text = ""
	flavor_text = ""
	culture = ""
	artist = ""

func configure_from_profile(profile: Dictionary) -> void:
	card_name = str(profile.get("card_name", card_name))
	level = int(profile.get("level", level))
	speed = int(profile.get("speed", speed))
	resilience = int(profile.get("resilience", resilience))
	strength = int(profile.get("strength", strength))
	culture = str(profile.get("culture", culture))
	artist = str(profile.get("artist", artist))
	art_path = str(profile.get("art_path", art_path))
	ability_text = str(profile.get("ability_text", ""))
	flavor_text = str(profile.get("flavor_text", ""))
	var profile_types: Array[String] = []
	for raw_type in profile.get("card_types", []):
		var type_name := str(raw_type).strip_edges()
		if type_name != "" and type_name not in profile_types:
			profile_types.append(type_name)
	for required_type in ["Token", "Spirit"]:
		if required_type not in profile_types:
			profile_types.append(required_type)
	card_types = profile_types
