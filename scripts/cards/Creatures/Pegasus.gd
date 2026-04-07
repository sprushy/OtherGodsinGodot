extends CreatureCard
class_name Pegasus

const ART_PATH := "res://scripts/cards/Gods/PegasusArt.jpg"
const STEED_SPEED := 5

func _init() -> void:
	super._init()
	card_name = "Pegasus"
	card_types = ["Animal", "Horse", "Aerial", "Steed", "Olympic Creature"]
	level = 5
	mana_cost = 6
	sacrifice_cost = 0
	speed = 5
	resilience = 14
	strength = 17
	ability_text = "[b]Evasive[/b]: Only aerial creatures and archers can engage it.\n[b]Steed[/b]: Once summoned, a human or active god can use Pegasus as equipment that makes its Spd 5 and gains [b]Aerial[/b] and [b]Evasive[/b]."
	flavor_text = ""
	culture = "Olympic"
	artist = ""
	art_path = ART_PATH

func can_be_engaged_by(source: Card) -> bool:
	if is_mounted_as_steed():
		return super.can_be_engaged_by(source)
	if not super.can_be_engaged_by(source):
		return false
	if abilities_suppressed():
		return true
	return source != null \
		and source.is_creature_card() \
		and (source.has_type("Aerial") or source.has_type("Archer"))

func can_be_used_as_steed_by(creature: Card, game_manager: GameManager = null) -> bool:
	if creature == null or game_manager == null:
		return false
	if is_mounted_as_steed():
		return false
	var controller := get_controller()
	if controller == null or creature.get_controller() != controller:
		return false
	if current_zone == null or not current_zone.is_board_zone():
		return false
	if is_face_down or is_stealth or is_prepared:
		return false
	if abilities_suppressed():
		return false
	if not creature.has_type("Human") and not creature.has_type("Active God"):
		return false
	if not creature.can_receive_equipment():
		return false
	return current_zone in game_manager.get_reachable_board_zones(creature)

func mount_to_creature(creature: Card) -> bool:
	if creature == null:
		return false
	card_type = CardType.EQUIPMENT
	if equip_to(creature):
		return true
	card_type = CardType.CREATURE
	return false

func unequip() -> void:
	super.unequip()
	card_type = CardType.CREATURE

func is_mounted_as_steed() -> bool:
	return equipped_on != null or card_type == CardType.EQUIPMENT

func get_speed_override_for_equipped_creature(_creature: Card) -> Variant:
	if not is_mounted_as_steed() or abilities_suppressed():
		return null
	return STEED_SPEED

func grants_evasive_to_equipped_creature(_creature: Card) -> bool:
	return is_mounted_as_steed() and not abilities_suppressed()

func grants_type_to_equipped_creature(_creature: Card, type_name: String) -> bool:
	return type_name == "Aerial" and is_mounted_as_steed() and not abilities_suppressed()
