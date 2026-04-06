extends CreatureCard
class_name RabidWolf

const ART_PATH := "res://scripts/cards/Creatures/RabidWolfEdit2.png"
const DISEASE_SOURCE := "Rabid Wolf Disease"
const DISEASE_EFFECT_TYPE := "rabid_wolf_disease"

func _init() -> void:
	super._init()
	card_name = "Rabid Wolf"
	card_types = ["Animal", "Lupine", "Norse Creature"]
	level = 3
	mana_cost = 0
	sacrifice_cost = 0
	speed = 2
	resilience = 8
	strength = 19
	ability_text = "[b]Disease[/b] ([b]Passive[/b]): Creatures that survive combat with this creature lose Str equal to this creature's Str. If this reduces a creature's Str below 0, destroy that creature."
	flavor_text = ""
	culture = "Norse"
	artist = "Daniel Dee"
	art_path = ART_PATH

func on_after_combat(game_manager: GameManager, opposing_card: Card) -> void:
	if game_manager == null or opposing_card == null:
		return
	if abilities_suppressed():
		return
	if current_zone == null or not current_zone.is_board_zone():
		return
	if opposing_card.card_type != Card.CardType.CREATURE:
		return
	if opposing_card.current_zone == null or not opposing_card.current_zone.is_board_zone():
		return
	if opposing_card.get_controller() == get_controller():
		return
	if game_manager.is_immune_to_source(opposing_card, self):
		return

	var str_loss := get_effective_strength()
	if str_loss <= 0:
		return

	opposing_card.add_buff(
		DISEASE_SOURCE,
		-str_loss,
		0,
		0,
		self,
		card_owner,
		DISEASE_EFFECT_TYPE
	)

	var target_name := opposing_card.get_target_log_display_name(game_manager.get_feedback_viewer())
	game_manager.note_player_feedback(
		"%s infects %s for %d Str after combat." % [
			card_name,
			target_name,
			str_loss
		]
	)

	if _get_uncapped_strength(opposing_card) < 0:
		game_manager.note_player_feedback("%s is destroyed by %s." % [target_name, DISEASE_SOURCE])
		game_manager.request_send_to_graveyard(opposing_card, Callable(), false, true)

func _get_uncapped_strength(card: Card) -> int:
	if card == null:
		return 0
	var total := card.strength
	for equip in card.equipment:
		total += equip.strength_modifier
	for buff in card._get_effective_buffs():
		total += int(buff.get("str", 0))
	return total
