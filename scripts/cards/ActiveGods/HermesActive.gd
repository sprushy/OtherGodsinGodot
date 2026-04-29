extends ActiveGodCard
class_name HermesActive

const LINKED_GOD_NAME := "Hermes"
const ART_PATH := "res://images/card_art/gods/HermesEdit.png"

func _init() -> void:
	super._init()
	linked_god_name = LINKED_GOD_NAME
	card_name = "Hermes, Active God"
	card_types = ["Active God", "Divine Manifestation", "God"]
	level = 7
	mana_cost = 10
	speed = 7
	resilience = 18
	strength = 21
	culture = "Olympic"
	flavor_text = "Hermes slips past slower foes before they can even bring a strike to bear."
	ability_text = "[b]Wingfoot[/b] ([b]Passive[/b]): Slower creatures cannot attack Hermes."
	art_path = ART_PATH
	name_at_bottom = true
	artist = "Ricardo Zoppello"

func can_be_engaged_by(source: Card) -> bool:
	if not super.can_be_engaged_by(source):
		return false
	if abilities_suppressed():
		return true
	if current_zone == null or not current_zone.is_board_zone():
		return true
	if is_face_down or is_stealth:
		return true
	if source == null or not source.is_creature_card():
		return true
	return source.get_effective_speed() >= get_effective_speed()
