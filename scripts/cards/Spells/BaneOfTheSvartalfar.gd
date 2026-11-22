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
	mana_cost = 0
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
	return not card.is_face_down and card.get_effective_level() < 3

func _apply_petrification(card: Card, game_manager: GameManager) -> void:
	var was_hidden := card.is_face_down or card.is_stealth
	var original_card_type := card.card_type
	var original_strength := card.strength
	var original_speed := card.speed
	var original_card_types := card.card_types.duplicate()
	card.reveal(game_manager)
	if was_hidden and game_manager != null and game_manager.has_method("notify_card_revealed_by_effect"):
		game_manager.notify_card_revealed_by_effect(card, self)
	card.card_type = Card.CardType.STRUCTURE
	card.strength = 0
	card.speed = 0
	if not card.has_type(STONE_TYPE):
		card.card_types.append(STONE_TYPE)
	card.add_status_effect(
		PETRIFIED_STATUS,
		card_name,
		self,
		card_owner,
		{
			"restore_base_state_on_remove": true,
			"original_card_type": original_card_type,
			"original_strength": original_strength,
			"original_speed": original_speed,
			"original_card_types": original_card_types,
		}
	)

func can_be_played(game_manager: GameManager, player: Player) -> bool:
	return super.can_be_played(game_manager, player)
