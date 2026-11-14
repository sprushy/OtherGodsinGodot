extends RefCounted

const CardCatalogScript = preload("res://scripts/cards/CardCatalog.gd")
const RankedProgressionScript = preload("res://scripts/server/RankedProgression.gd")
const DEFAULT_PORTRAITS := [
	"Wolf Cub", "Minotaur Footsoldier", "Berserker", "En-hedu-anna",
	"Nergal Lion", "Enki, Lord of Eridu", "Freyja",
]
const MAX_ZOOM := 3.0

static var _cards_by_league: Dictionary = {}

static func league_for_rank(rank_name: String) -> int:
	return RankedProgressionScript.LEAGUES.find(rank_name.get_slice(" ", 0))

static func get_cards(league: int) -> Dictionary:
	if league < 0 or league >= DEFAULT_PORTRAITS.size():
		return {}
	if not _cards_by_league.has(league):
		var cards := {}
		for card in CardCatalogScript.get_cached_card_templates():
			var card_league := -1
			if card is GodCard or card is ActiveGodCard:
				card_league = RankedProgressionScript.DIVINE
			elif card is CreatureCard and card.level >= 1 and card.level <= RankedProgressionScript.DIVINE:
				card_league = card.level - 1
			if card_league == league and not card.art_path.is_empty():
				cards[card.card_name] = card
		_cards_by_league[league] = cards
	return _cards_by_league[league]

static func portrait_from_deck(league: int, cards: Dictionary, reinforcements: Dictionary = {}) -> Dictionary:
	var owned_cards := {}
	for card_name in cards:
		owned_cards[str(card_name)] = int(cards[card_name])
	for card_name in reinforcements:
		owned_cards[str(card_name)] = int(owned_cards.get(str(card_name), 0)) + int(reinforcements[card_name])
	var eligible_names: Array[String] = []
	for card_name in get_cards(league).keys():
		if int(owned_cards.get(str(card_name), 0)) > 0:
			eligible_names.append(str(card_name))
	if eligible_names.is_empty():
		return {}
	eligible_names.sort()
	return validate_portrait(league, {"card": eligible_names[0]})

static func art_paths(card: Card) -> Array[String]:
	var paths := card.get_art_variant_paths()
	if card.art_path not in paths:
		paths.push_front(card.art_path)
	return paths

static func validate_portrait(league: int, portrait: Dictionary) -> Dictionary:
	var card_name = portrait.get("card", "")
	if not card_name is String:
		return {}
	var card: Card = get_cards(league).get(card_name)
	if card == null:
		return {}
	var art = portrait.get("art", 0)
	var x = portrait.get("x", 0.5)
	var y = portrait.get("y", 0.5)
	var zoom = portrait.get("zoom", 1.0)
	if not _is_number(art) or art < 0 or art >= art_paths(card).size() or art != floorf(art):
		return {}
	if not _is_number(x) or x < 0.0 or x > 1.0 or not _is_number(y) or y < 0.0 or y > 1.0:
		return {}
	if not _is_number(zoom) or zoom < 1.0 or zoom > MAX_ZOOM:
		return {}
	return {"card": card_name, "art": int(art), "x": float(x), "y": float(y), "zoom": float(zoom)}

static func resolve_portrait(league: int, portrait: Dictionary) -> Dictionary:
	var validated := validate_portrait(league, portrait)
	if validated.is_empty() and league >= 0 and league < DEFAULT_PORTRAITS.size():
		return validate_portrait(league, {"card": DEFAULT_PORTRAITS[league]})
	return validated

static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
