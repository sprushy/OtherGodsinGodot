extends CharmCard
class_name CompelledByTheSecretName

const ART_PATH := "res://images/card_art/charms/CompelledByTheSecretName.png"

func _init() -> void:
	super._init()
	card_name = "Compelled by the Secret Name"
	culture = "Ancient"
	card_types = ["Charm", "Wisdom"]
	level = 2
	mana_cost = 0
	speed = 2
	targets = false
	is_legendary = false
	flavor_text = ""
	ability_text = "Declare the name of any card that could appear in a main deck. If your opponent has any copies of the declared card in their hand, they discard all of them."
	artist = "User-provided"
	art_path = ART_PATH

# The declaration is public information, so MatchManager validates the command's
# "named_card_name" and passes the canonical name through the resolve target.
func resolve(game_manager: GameManager, target = null) -> void:
	if game_manager == null or card_owner == null:
		return
	var declared_name := _extract_declared_name(target)
	if not is_valid_declared_name(declared_name):
		game_manager.note_player_feedback(card_name + " fizzles: declare the name of a card that could appear in a main deck.")
		return
	var canonical_name := get_canonical_declared_name(declared_name)
	var opponent := game_manager.get_opponent(card_owner)
	if opponent == null:
		return
	var discarded := _discard_hand_copies(opponent, canonical_name)
	if discarded.is_empty():
		game_manager.note_player_feedback("%s: %s declared \"%s\". It was not in %s's hand." % [
			card_name,
			card_owner.player_name,
			canonical_name,
			opponent.player_name,
		])
	else:
		game_manager.note_player_feedback("%s: %s declared \"%s\". %s discarded %d %s." % [
			card_name,
			card_owner.player_name,
			canonical_name,
			opponent.player_name,
			discarded.size(),
			"copy" if discarded.size() == 1 else "copies",
		])

func _discard_hand_copies(hand_player: Player, declared_name: String) -> Array[Card]:
	var discarded: Array[Card] = []
	if hand_player == null or hand_player.hand_zone == null:
		return discarded
	var declared_key := CardCatalog.to_lookup_key(declared_name)
	for hand_card in hand_player.hand_zone.cards.duplicate():
		if not _matches_declared_name(hand_card, declared_key):
			continue
		hand_player.discard_card(hand_card)
		discarded.append(hand_card)
	return discarded

func _matches_declared_name(card: Card, declared_key: String) -> bool:
	if card == null or declared_key == "":
		return false
	if CardCatalog.to_lookup_key(card.card_name) == declared_key:
		return true
	if card.has_method("get_normalized_card_name") \
			and CardCatalog.to_lookup_key(str(card.get_normalized_card_name())) == declared_key:
		return true
	if card.has_method("get_ascii_card_name") \
			and CardCatalog.to_lookup_key(str(card.get_ascii_card_name())) == declared_key:
		return true
	return false

func _extract_declared_name(target) -> String:
	if target is String:
		return str(target).strip_edges()
	if target is Dictionary:
		var target_dict := target as Dictionary
		return str(target_dict.get("named_card_name", target_dict.get("declared_card_name", ""))).strip_edges()
	if target is Card:
		return str((target as Card).card_name).strip_edges()
	return ""

static func get_declared_name_options() -> Array[String]:
	var unique_names: Dictionary = {}
	for template in CardCatalog.get_cached_card_templates():
		if not is_declared_name_template_valid(template):
			continue
		unique_names[str(template.card_name)] = true
	var options: Array[String] = []
	for option_name in unique_names.keys():
		options.append(str(option_name))
	options.sort()
	return options

static func is_valid_declared_name(candidate: String) -> bool:
	var template := CardCatalog.instantiate_card_by_name(candidate)
	return is_declared_name_template_valid(template)

static func get_canonical_declared_name(candidate: String) -> String:
	var template := CardCatalog.instantiate_card_by_name(candidate)
	if template != null:
		return str(template.card_name)
	return str(candidate).strip_edges()

static func is_declared_name_template_valid(template: Card) -> bool:
	return template != null \
		and not template.is_god \
		and not template.is_power \
		and not template.is_single_player_card \
		and not template.is_token \
		and not template.card_types.has("Token")
