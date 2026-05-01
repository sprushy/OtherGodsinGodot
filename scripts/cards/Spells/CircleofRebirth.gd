# cards/spells/CircleOfRebirth.gd
extends SpellCard
class_name CircleOfRebirth

func _init() -> void:
	super._init()
	card_name = "Circle of Rebirth"
	
	var types: Array[String] = ["Resurrection", "Nature", "Life"]
	card_types = types
	
	level = 4
	mana_cost = 1
	is_legendary = true
	speed = 1
	flavor_text = "Resurrect all animals and plants which were destroyed this turn."
	culture = "Triskelion"
	art_path = "res://images/card_art/spells/Circle of Rebirth cut.png"
	ability_text = "Resurrect all Animal and Plant creatures destroyed this turn."

func resolve(game_manager: GameManager, _target = null) -> void:
	# Collect Animal/Plant creatures that died this turn (from either player).
	var to_resurrect: Array[Card] = []
	for card in game_manager.died_this_turn:
		if card.card_type == Card.CardType.CREATURE:
			if card.has_type("Animal") or card.has_type("Plant"):
				to_resurrect.append(card)

	for card in to_resurrect:
		var zone := _find_resurrection_zone(card)
		if zone:
			card.card_owner.move_card(card, zone)
			card.has_acted_this_turn = false
			card.is_stealth = false
			card.is_face_down = false
			print("Circle of Rebirth: restored %s to %s[%d]" % [
				card.card_name, zone.zone_type, zone.zone_index])
		else:
			print("Circle of Rebirth: no empty zone for %s" % card.card_name)

# Returns the best available zone for this card, preferring its last position
# and falling back to adjacent slots in expanding rings, then the other row.
func _find_resurrection_zone(card: Card) -> Zone:
	var owner_player: Player = card.card_owner
	var last_type: int = card.last_board_zone_type
	var center: int  = card.last_board_zone_index

	var primary: Array[Zone]
	var secondary: Array[Zone]
	if last_type == Zone.ZoneType.RESERVE:
		primary   = owner_player.reserve_zones
		secondary = owner_player.frontline_zones
	else:
		primary   = owner_player.frontline_zones
		secondary = owner_player.reserve_zones

	for zone in _zones_by_distance(primary, center):
		if zone.cards.size() == 0:
			return zone
	for zone in _zones_by_distance(secondary, center):
		if zone.cards.size() == 0:
			return zone
	return null

# Returns the zones in `row` ordered by distance from `center`.
static func _zones_by_distance(row: Array[Zone], center: int) -> Array[Zone]:
	var result: Array[Zone] = []
	result.append(row[center])
	for dist in range(1, row.size()):
		var lo := center - dist
		var hi := center + dist
		if lo >= 0:
			result.append(row[lo])
		if hi < row.size():
			result.append(row[hi])
	return result
