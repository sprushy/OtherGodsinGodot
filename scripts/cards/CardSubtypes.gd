extends RefCounted
class_name CardSubtypes

const PARENTS := {
	"Anguine": ["Animal"],
	"Archer": ["Warrior"],
	"Avian": ["Animal", "Aerial"],
	"Bovine": ["Animal"],
	"Canine": ["Animal"],
	"Elaphine": ["Animal"],
	"Feline": ["Animal"],
	"Hircine": ["Animal"],
	"Horse": ["Animal"],
	"Insect": ["Animal"],
	"Jaguar": ["Feline"],
	"Knight": ["Warrior"],
	"Lupine": ["Animal"],
	"Porcine": ["Animal"],
	"Raven": ["Avian"],
	"Simian": ["Animal"],
	"Taurine": ["Animal"],
	"Ursine": ["Animal"],
}

# Card classes and rules markers stay with a card when its subtypes change.
const FIXED_TYPES := [
	"Active God", "Charm", "Creature", "Equipment", "God", "Hex", "Legendary",
	"Magic", "Magical", "Permanent", "Physical", "Power", "Spell", "Structure",
	"Targeting", "Token",
]

# Older card payloads may still include culture labels in their subtype arrays.
const CULTURE_NAMES := [
	"Ancient", "Atlanitan", "Atlantean", "Atlantian", "Nahuatl", "Nahutl", "Neutral",
	"Norse", "Olympic", "Tian", "Triskelion",
]
const CULTURE_LABEL_CLASSES := ["Charm", "Creature", "Equipment", "God", "Hex", "Power", "Spell", "Structure"]

static func is_culture_label(type_name: String) -> bool:
	var culture_name := type_name.get_slice(" ", 0)
	if culture_name not in CULTURE_NAMES:
		return false
	return type_name == culture_name or type_name.trim_prefix(culture_name + " ") in CULTURE_LABEL_CLASSES

static func without_culture_labels(types: Array) -> Array[String]:
	var subtypes: Array[String] = []
	for raw_type in types:
		var type_name := str(raw_type)
		if not is_culture_label(type_name):
			subtypes.append(type_name)
	return subtypes

static func legacy_culture(types: Array, fallback: String) -> String:
	for raw_type in types:
		var type_name := str(raw_type)
		if is_culture_label(type_name):
			return type_name.get_slice(" ", 0)
	return fallback

static func get_transferable_subtypes(types: Array) -> Array[String]:
	var subtypes: Array[String] = []
	for type_name: String in types:
		for subtype in expand(type_name):
			if subtype not in FIXED_TYPES and not is_culture_label(subtype) and subtype not in subtypes:
				subtypes.append(subtype)
	return subtypes

static func format_typing(types: Array) -> String:
	return " / ".join(types) if not types.is_empty() else "No subtypes"

static func matches(type_name: String, requested_type: String) -> bool:
	if type_name == requested_type:
		return true
	for parent: String in PARENTS.get(type_name, []):
		if matches(parent, requested_type):
			return true
	return false

static func includes(types: Array[String], requested_type: String) -> bool:
	if requested_type in types:
		return true
	for type_name in types:
		if matches(type_name, requested_type):
			return true
	return false

static func expand(type_name: String) -> Array[String]:
	var types: Array[String] = [type_name]
	for parent: String in PARENTS.get(type_name, []):
		for inherited_type in expand(parent):
			if inherited_type not in types:
				types.append(inherited_type)
	return types

