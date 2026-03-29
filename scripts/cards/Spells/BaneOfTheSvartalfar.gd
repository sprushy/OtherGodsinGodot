extends SpellCard
class_name BaneOfTheSvartalfar

const PETRIFIED_STATUS := "petrified"
const STONE_TYPE := "Stone"

func _init() -> void:
	super._init()
	card_name = "Bane of the Svartalfar"
	culture = "Norse"
	card_types = ["Petrification"]
	level = 1
	mana_cost = 1
	speed = 1
	is_legendary = false
	flavor_text = ""
	ability_text = "Dwarves and face-up creatures under level 3 lose all abilities and become Stone structures."
	artist = "Jessica Kings via TcgMaker"
	art_path = "res://images/card_art/spells/BaneofSvart.png"
	targets = false

func resolve(game_manager: GameManager, _target = null) -> void:
	var petrified_count := 0
	for player in game_manager.players:
		for zone in player.frontline_zones + player.reserve_zones:
			for card in zone.cards:
				if _should_petrify(card):
					_apply_petrification(card, game_manager)
					petrified_count += 1
	print(card_name + " petrified " + str(petrified_count) + " card(s).")

func _should_petrify(card: Card) -> bool:
	if card == null:
		return false
	if card.is_god:
		return false
	if card.card_type != Card.CardType.CREATURE:
		return false
	if card.is_petrified():
		return false
	if card.has_type("Dwarf"):
		return true
	return not card.is_face_down and card.level < 3

func _apply_petrification(card: Card, game_manager: GameManager) -> void:
	card.reveal(game_manager)
	card.card_type = Card.CardType.STRUCTURE
	card.strength = 0
	card.speed = 0
	if not card.has_type(STONE_TYPE):
		card.card_types.append(STONE_TYPE)
	card.add_status_effect(PETRIFIED_STATUS, card_name, self, card_owner)

func can_be_played(game_manager: GameManager, player: Player) -> bool:
	if not super.can_be_played(game_manager, player):
		return false
	for p in game_manager.players:
		for zone in p.frontline_zones + p.reserve_zones:
			for card in zone.cards:
				if _should_petrify(card):
					return true
	print(card_name + " has no valid targets.")
	return false
