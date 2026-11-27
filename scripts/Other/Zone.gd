# Zone.gd
extends RefCounted
class_name Zone

enum ZoneType {
	HAND,
	DECK,
	GRAVEYARD,
	ABYSS,
	FRONTLINE,
	RESERVE,
	GOD_SLOT,
	POWER_SLOT
}

enum DeckPlacement { UNKNOWN, SHELVED, PRIMED, REVEALED }

const PrimeCardSoundPlayerScript = preload("res://scripts/audio/PrimeCardSoundPlayer.gd")
const ShelveCardSoundPlayerScript = preload("res://scripts/audio/ShelveCardSoundPlayer.gd")
const ShuffleDeckSoundPlayerScript = preload("res://scripts/audio/ShuffleDeckSoundPlayer.gd")

@export var zone_type: ZoneType
@export var zone_index: int = -1
var cards: Array[Card] = []
var zone_owner: Player
var shuffle_rng: RandomNumberGenerator
# Owner-authoritative knowledge of deck positions. Never treated as public on
# its own: the deck owner always knows their primed/shelved cards, but opponents
# only learn a card's identity when it was publicly known entering the deck.
var _public_deck_placements: Dictionary[Card, DeckPlacement] = {}
# Cards whose identity opponents legitimately know (they saw the card revealed
# or played face-up before it was primed/shelved into this deck).
var _public_identity_cards: Dictionary[Card, bool] = {}
var known_top_card: Card:
	get:
		return get_known_deck_card(0)

func get_deck_placement(card: Card) -> DeckPlacement:
	return _public_deck_placements.get(card, DeckPlacement.UNKNOWN)

func get_known_deck_card(index: int) -> Card:
	if index < 0 or index >= cards.size():
		return null
	var card := cards[index]
	return card if _public_deck_placements.has(card) else null

func get_primed_top_card() -> Card:
	var card := known_top_card
	return card if get_deck_placement(card) == DeckPlacement.PRIMED else null

func is_deck_identity_public(card: Card) -> bool:
	return _public_identity_cards.get(card, false)

func set_deck_identity_public(card: Card, value: bool) -> void:
	if value:
		_public_identity_cards[card] = true
	else:
		_public_identity_cards.erase(card)

## True when a viewer without private access may learn this card's identity:
## it was explicitly revealed, or it entered the deck while publicly known.
func is_deck_card_publicly_known(card: Card) -> bool:
	var placement := get_deck_placement(card)
	if placement == DeckPlacement.UNKNOWN:
		return false
	if placement == DeckPlacement.REVEALED:
		return true
	return is_deck_identity_public(card)

func set_deck_placement(card: Card, placement: DeckPlacement) -> void:
	if placement == DeckPlacement.UNKNOWN:
		_public_deck_placements.erase(card)
		_public_identity_cards.erase(card)
	else:
		_public_deck_placements[card] = placement

func reveal_deck_card(card: Card) -> void:
	if card.current_zone == self:
		set_deck_placement(card, DeckPlacement.REVEALED)
		set_deck_identity_public(card, true)

func clear_deck_knowledge() -> void:
	_public_deck_placements.clear()
	_public_identity_cards.clear()

func get_unordered_deck_cards() -> Array[Card]:
	var unordered := cards.duplicate()
	# A stable order independent of deck position also makes tie breaks safe.
	unordered.sort_custom(func(a: Card, b: Card) -> bool: return a.uid < b.uid)
	return unordered

func shuffle_deck() -> void:
	var gm: GameManager = null
	if zone_owner != null:
		gm = zone_owner.game_manager
	if gm != null:
		if gm.sfx_enabled:
			ShuffleDeckSoundPlayerScript.play_sound()
		gm.note_ui_sound_cue("shuffle_deck")
	# A shuffle is the point where public deck knowledge is lost, so lingering
	# public-reveal statuses on deck cards must not keep identifying them.
	for card in cards:
		if card != null and card.has_status_effect("publicly_revealed"):
			card.remove_status_effects_by_name("publicly_revealed")
	clear_deck_knowledge()
	if shuffle_rng == null:
		cards.shuffle()
	else:
		for index in range(cards.size() - 1, 0, -1):
			var other := shuffle_rng.randi_range(0, index)
			var card := cards[index]
			cards[index] = cards[other]
			cards[other] = card

func prime_card(card: Card, identity_public = null) -> void:
	cards.erase(card)
	add_card(card, DeckPlacement.PRIMED, identity_public)

func shelve_deck_card(card: Card, identity_public = null) -> void:
	cards.erase(card)
	add_card(card, DeckPlacement.SHELVED, identity_public)

func add_card(card: Card, deck_placement: DeckPlacement = DeckPlacement.UNKNOWN, identity_public = null) -> void:
	var gm: GameManager = null
	if zone_owner != null:
		gm = zone_owner.game_manager
	if zone_type == ZoneType.DECK and gm != null:
		match deck_placement:
			DeckPlacement.PRIMED:
				if gm.sfx_enabled:
					PrimeCardSoundPlayerScript.play_sound()
				gm.note_ui_sound_cue("prime_card")
			DeckPlacement.SHELVED:
				if gm.sfx_enabled:
					ShelveCardSoundPlayerScript.play_sound()
				gm.note_ui_sound_cue("shelve_card")
	if zone_type == ZoneType.DECK and deck_placement == DeckPlacement.PRIMED:
		cards.push_front(card)
	else:
		cards.append(card)
	if zone_type == ZoneType.DECK:
		var preserved := is_deck_identity_public(card)
		set_deck_placement(card, deck_placement)
		# Re-placing a card inside the deck keeps any identity the opponents
		# already learned (e.g. shelving a card that was just revealed), unless
		# the caller states otherwise.
		if identity_public is bool:
			set_deck_identity_public(card, identity_public)
		elif deck_placement == DeckPlacement.PRIMED or deck_placement == DeckPlacement.SHELVED:
			set_deck_identity_public(card, preserved)
		else:
			set_deck_identity_public(card, false)
	card.current_zone = self
	if zone_owner != null and is_in_play_zone() \
			and (card.is_god or card.has_type("Active God")):
		zone_owner.has_had_god_in_play = true

func remove_card(card: Card) -> void:
	_public_deck_placements.erase(card)
	_public_identity_cards.erase(card)
	cards.erase(card)
	if card.current_zone == self:
		card.current_zone = null

func get_card_count() -> int:
	return cards.size()

func is_board_zone() -> bool:
	return zone_type in [ZoneType.FRONTLINE, ZoneType.RESERVE]

func is_in_play_zone() -> bool:
	return is_board_zone() or zone_type in [ZoneType.GOD_SLOT, ZoneType.POWER_SLOT]

func get_creature() -> Card:
	for card in cards:
		if card.is_creature_card():
			return card
	return null

func get_equipment() -> Array[Card]:
	var equip_list: Array[Card] = []
	for card in cards:
		if card.card_type == Card.CardType.EQUIPMENT and card.equipped_on == null:
			equip_list.append(card)
	return equip_list
