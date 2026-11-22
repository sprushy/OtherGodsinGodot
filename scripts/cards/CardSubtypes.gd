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

