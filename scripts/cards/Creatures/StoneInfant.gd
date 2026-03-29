extends CreatureCard
class_name StoneInfant

const TOKEN_ART_PATHS := [
	"res://images/card_art/creatures/StoneInfantToken.png",
	"res://images/card_art/creatures/StoneInfantToken2.png",
	"res://images/card_art/creatures/StoneInfantToken3.png",
	"res://images/card_art/creatures/StoneInfantToken4.jpg",
	"res://images/card_art/creatures/StoneInfantToken5.png"
]

static var _next_art_index: int = 0

func _init() -> void:
	super._init()
	card_name = "Stone Infant"
	card_types = ["Token", "Human", "Stone", "Golem"]
	is_token = true
	level = 1
	mana_cost = 0
	speed = 1
	resilience = 17
	strength = 17
	sacrifice_cost = 0
	ability_text = ""
	flavor_text = ""
	art_path = _get_next_token_art_path()
	culture = "Olympic"
	artist = ""

static func _get_next_token_art_path() -> String:
	if TOKEN_ART_PATHS.is_empty():
		return ""
	var token_art_path: String = TOKEN_ART_PATHS[_next_art_index % TOKEN_ART_PATHS.size()]
	_next_art_index += 1
	return token_art_path
