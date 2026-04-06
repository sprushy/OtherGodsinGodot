extends RefCounted
class_name CardCatalog

const CARDS_DIR := "res://scripts/cards/"
const EXCLUDED_FILENAMES := [
	"BaseCard.gd",
	"card.gd",
	"CardCatalog.gd",
	"CharmCard.gd",
	"CreatureCard.gd",
	"Deck.gd",
	"EquipmentCard.gd",
	"GenericCreature.gd",
	"GodCard.gd",
	"HexCard.gd",
	"PermanentHexCard.gd",
	"PowerCard.gd",
	"SpellCard.gd",
	"StructureCard.gd"
]
const CARD_SCRIPT_PATHS := [
	"res://scripts/cards/Charms/DivineLightning.gd",
	"res://scripts/cards/Charms/Exorcism.gd",
	"res://scripts/cards/Charms/FifaTheMagicalArrow.gd",
	"res://scripts/cards/Charms/GungnirTheSpearOfOdin.gd",
	"res://scripts/cards/Charms/HeavySnow.gd",
	"res://scripts/cards/Charms/HeroicStand.gd",
	"res://scripts/cards/Charms/Hringhorni.gd",
	"res://scripts/cards/Charms/MeadOfPoetry.gd",
	"res://scripts/cards/Charms/NamburbiApotropaeon.gd",
	"res://scripts/cards/Creatures/AgainWalker.gd",
	"res://scripts/cards/Creatures/Alu.gd",
	"res://scripts/cards/Creatures/AnkouServantToTheReaper.gd",
	"res://scripts/cards/Creatures/AnTheBowbender.gd",
	"res://scripts/cards/Creatures/Anzu.gd",
	"res://scripts/cards/Creatures/AsagTheDestroyer.gd",
	"res://scripts/cards/Creatures/Asakku.gd",
	"res://scripts/cards/Creatures/Asaruludu.gd",
	"res://scripts/cards/Creatures/Askelladen.gd",
	"res://scripts/cards/Creatures/Aurboda.gd",
	"res://scripts/cards/Creatures/Berserker.gd",
	"res://scripts/cards/Creatures/Beyla.gd",
	"res://scripts/cards/Creatures/BlessedKnights.gd",
	"res://scripts/cards/Creatures/BrownBear.gd",
	"res://scripts/cards/Creatures/Byggvir.gd",
	"res://scripts/cards/Creatures/Caleuche.gd",
	"res://scripts/cards/Creatures/Capricorn.gd",
	"res://scripts/cards/Creatures/ClayEaters.gd",
	"res://scripts/cards/Creatures/CombatMech.gd",
	"res://scripts/cards/Creatures/DevastatorMech.gd",
	"res://scripts/cards/Creatures/DraugRevenant.gd",
	"res://scripts/cards/Creatures/DurinnSecondborn.gd",
	"res://scripts/cards/Creatures/Edimmu.gd",
	"res://scripts/cards/Creatures/EnHeduAnna.gd",
	"res://scripts/cards/Creatures/Enkidu.gd",
	"res://scripts/cards/Creatures/EnkiLordOfEridu.gd",
	"res://scripts/cards/Creatures/ErlqueensNightingale.gd",
	"res://scripts/cards/Creatures/Fenrir.gd",
	"res://scripts/cards/Creatures/FirstSageAdapa.gd",
	"res://scripts/cards/Creatures/FourthSageEnmegalamma.gd",
	"res://scripts/cards/Creatures/GalaTura.gd",
	"res://scripts/cards/Creatures/Gallu.gd",
	"res://scripts/cards/Creatures/Garm.gd",
	"res://scripts/cards/Creatures/Gawain.gd",
	"res://scripts/cards/Creatures/GiantMasterArchitect.gd",
	"res://scripts/cards/Creatures/GidimEnsi.gd",
	"res://scripts/cards/Creatures/Gilgamesh.gd",
	"res://scripts/cards/Creatures/GududPriest.gd",
	"res://scripts/cards/Creatures/GugalannaBullOfHeaven.gd",
	"res://scripts/cards/Creatures/Gullinbursti.gd",
	"res://scripts/cards/Creatures/HabrokParagonOfHawks.gd",
	"res://scripts/cards/Creatures/HariiFransiscan.gd",
	"res://scripts/cards/Creatures/HariiJarl.gd",
	"res://scripts/cards/Creatures/HariiShaman.gd",
	"res://scripts/cards/Creatures/HariiWarrior.gd",
	"res://scripts/cards/Creatures/Hati.gd",
	"res://scripts/cards/Creatures/HelBlarDraug.gd",
	"res://scripts/cards/Creatures/Hrimgrimmnir.gd",
	"res://scripts/cards/Creatures/Huginn.gd",
	"res://scripts/cards/Creatures/HumbabaTheTerrible.gd",
	"res://scripts/cards/Creatures/HyenaPack.gd",
	"res://scripts/cards/Creatures/Isimud.gd",
	"res://scripts/cards/Creatures/Jiaolong.gd",
	"res://scripts/cards/Creatures/KurJara.gd",
	"res://scripts/cards/Creatures/Lailoken.gd",
	"res://scripts/cards/Creatures/Lamashatu.gd",
	"res://scripts/cards/Creatures/LesserMushussu.gd",
	"res://scripts/cards/Creatures/Lindwyrm.gd",
	"res://scripts/cards/Creatures/LowLightTroll.gd",
	"res://scripts/cards/Creatures/Lugalbanda.gd",
	"res://scripts/cards/Creatures/MalinalxochitlAcolyte.gd",
	"res://scripts/cards/Creatures/MalinalxochitlThrall.gd",
	"res://scripts/cards/Creatures/MasmassuPriest.gd",
	"res://scripts/cards/Creatures/MinotaurFootsoldier.gd",
	"res://scripts/cards/Creatures/Mopsus.gd",
	"res://scripts/cards/Creatures/Muninn.gd",
	"res://scripts/cards/Creatures/NergalLion.gd",
	"res://scripts/cards/Creatures/Nagual.gd",
	"res://scripts/cards/Creatures/Nimue.gd",
	"res://scripts/cards/Creatures/Pegasus.gd",
	"res://scripts/cards/Creatures/PictishBeast.gd",
	"res://scripts/cards/Creatures/Pazuzu.gd",
	"res://scripts/cards/Creatures/RedCap.gd",
	"res://scripts/cards/Creatures/RabidWolf.gd",
	"res://scripts/cards/Creatures/Rabisu.gd",
	"res://scripts/cards/Creatures/RavenStorm.gd",
	"res://scripts/cards/Creatures/RoboticFootsoldier.gd",
	"res://scripts/cards/Creatures/ScorpionManArcher.gd",
	"res://scripts/cards/Creatures/ScorpionManWarrior.gd",
	"res://scripts/cards/Creatures/SevenHeadedSerpent.gd",
	"res://scripts/cards/Creatures/SeventhSageUtuabzu.gd",
	"res://scripts/cards/Creatures/Skoll.gd",
	"res://scripts/cards/Creatures/SoldierOfTheBlackEmperor.gd",
	"res://scripts/cards/Creatures/StoneInfant.gd",
	"res://scripts/cards/Creatures/TitanicMech.gd",
	"res://scripts/cards/Equipment/BeardedAxe.gd",
	"res://scripts/cards/Equipment/DraupnirTheMultiplying.gd",
	"res://scripts/cards/Equipment/Gambanteinn.gd",
	"res://scripts/cards/Equipment/ReedBow.gd",
	"res://scripts/cards/Equipment/SevenLeagueBoots.gd",
	"res://scripts/cards/Equipment/RunicShortsword.gd",
	"res://scripts/cards/Equipment/SharurTheFlyingMace.gd",
	"res://scripts/cards/Gods/AphroditeAreia.gd",
	"res://scripts/cards/Gods/Baldr.gd",
	"res://scripts/cards/Gods/Cernunnos.gd",
	"res://scripts/cards/Gods/DellingrTheDayspring.gd",
	"res://scripts/cards/Gods/Freyja.gd",
	"res://scripts/cards/Gods/GuanYu.gd",
	"res://scripts/cards/Gods/Hermes.gd",
	"res://scripts/cards/Gods/ManannanMacLir.gd",
	"res://scripts/cards/Gods/Mummu.gd",
	"res://scripts/cards/Gods/NuskuFirebearer.gd",
	"res://scripts/cards/Gods/Odin.gd",
	"res://scripts/cards/Gods/Thor.gd",
	"res://scripts/cards/Hexes/Banishment.gd",
	"res://scripts/cards/Hexes/Dromi.gd",
	"res://scripts/cards/Hexes/Gleipnir.gd",
	"res://scripts/cards/Hexes/SepLemutti.gd",
	"res://scripts/cards/Hexes/Sap.gd",
	"res://scripts/cards/Hexes/SapStrength.gd",
	"res://scripts/cards/Hexes/VoidShield.gd",
	"res://scripts/cards/Powers/AcceleratedFate.gd",
	"res://scripts/cards/Powers/ACostToWalkTheWorlds.gd",
	"res://scripts/cards/Powers/AdvancedBuildingTechniques.gd",
	"res://scripts/cards/Powers/AllfathersSacrifice.gd",
	"res://scripts/cards/Powers/AltarOfDreams.gd",
	"res://scripts/cards/Powers/AnankesBinding.gd",
	"res://scripts/cards/Powers/AncientWisdom.gd",
	"res://scripts/cards/Powers/BerserkerMead.gd",
	"res://scripts/cards/Powers/Breidablik.gd",
	"res://scripts/cards/Powers/CallOfTheValkyrie.gd",
	"res://scripts/cards/Powers/NorseBloodlust.gd",
	"res://scripts/cards/Powers/OraclesSight.gd",
	"res://scripts/cards/Powers/Palisade.gd",
	"res://scripts/cards/Powers/Ragnarok.gd",
	"res://scripts/cards/Powers/RallyTheTroops.gd",
	"res://scripts/cards/Powers/SavingGrace.gd",
	"res://scripts/cards/Powers/DivineCaprice.gd",
	"res://scripts/cards/Powers/FeastOfAmbrosiaAndNectar.gd",
	"res://scripts/cards/Powers/FerociousDefence.gd",
	"res://scripts/cards/Powers/FireAndGold.gd",
	"res://scripts/cards/Powers/GiantsDisdain.gd",
	"res://scripts/cards/Powers/HuntingTactics.gd",
	"res://scripts/cards/Powers/ImmortalTechniques.gd",
	"res://scripts/cards/Powers/Kurnugia.gd",
	"res://scripts/cards/Powers/LawsOfCivilization.gd",
	"res://scripts/cards/Powers/MechFactory.gd",
	"res://scripts/cards/Powers/Myrkwood.gd",
	"res://scripts/cards/Spells/Absence.gd",
	"res://scripts/cards/Spells/ApollyonsDemiurge.gd",
	"res://scripts/cards/Spells/BaneOfTheSvartalfar.gd",
	"res://scripts/cards/Spells/BitMeseri.gd",
	"res://scripts/cards/Spells/BlotSacrifice.gd",
	"res://scripts/cards/Spells/BookOfLife.gd",
	"res://scripts/cards/Spells/CircleofRebirth.gd",
	"res://scripts/cards/Spells/DeucalionsInfants.gd",
	"res://scripts/cards/Spells/Earthquake.gd",
	"res://scripts/cards/Spells/FalloftheMighty.gd",
	"res://scripts/cards/Spells/Famine.gd",
	"res://scripts/cards/Spells/FiresOfJudgment.gd",
	"res://scripts/cards/Spells/FoolishOptimism.gd",
	"res://scripts/cards/Spells/KeyOfSolomon.gd",
	"res://scripts/cards/Spells/LightOfMorningsDoors.gd",
	"res://scripts/cards/Spells/OccultSingularity.gd",
	"res://scripts/cards/Spells/RunicSpellbreaker.gd",
	"res://scripts/cards/Structures/AncientPyre.gd",
	"res://scripts/cards/Structures/AnointingStatue.gd",
	"res://scripts/cards/Structures/DoorwayToTheVoid.gd",
	"res://scripts/cards/Structures/E2Abzu.gd",
	"res://scripts/cards/Structures/EriduCityOfSages.gd",
	"res://scripts/cards/Structures/GlitnirThePeaceful.gd",
	"res://scripts/cards/Structures/WardingStone.gd",
]

static var _cached_all_cards: Array[Card] = []

static func make_all_cards() -> Array[Card]:
	if not _cached_all_cards.is_empty():
		var duplicates: Array[Card] = []
		for card in _cached_all_cards:
			duplicates.append(card.duplicate(true))
		return duplicates
	
	var discovered_cards: Array[Card] = []
	_discover_cards_from_registry(discovered_cards)
	
	_cached_all_cards = discovered_cards
	
	# Return duplicates so the caller doesn't modify the cache
	var duplicates: Array[Card] = []
	for card in _cached_all_cards:
		duplicates.append(card.duplicate(true))
	return duplicates

static func _discover_cards_from_registry(out_cards: Array[Card]) -> void:
	for full_path in CARD_SCRIPT_PATHS:
		var script: GDScript = load(full_path)
		if script == null:
			push_warning("CardCatalog: Failed to load card script %s" % full_path)
			continue
		var inst = script.new()
		if inst is Card:
			var is_valid_for_catalog := true
			if inst.is_token or inst.card_types.has("Token"):
				is_valid_for_catalog = false
			elif inst.card_name == "" or inst.card_name == "Unnamed" or inst.card_name == "Card":
				is_valid_for_catalog = false
			if is_valid_for_catalog:
				out_cards.append(inst)
			elif inst is Object and not inst is RefCounted:
				inst.free()
		elif inst is Object and not inst is RefCounted:
			inst.free()

static func instantiate_card_by_name(card_name: String) -> Card:
	var requested_name := str(card_name).strip_edges()
	if requested_name.is_empty():
		return null
	
	# Ensure cache is populated
	if _cached_all_cards.is_empty():
		make_all_cards()
		
	var requested_lookup_key: String = to_lookup_key(requested_name)
	for template in _cached_all_cards:
		if template == null:
			continue
		if _matches_card_name(template, requested_name):
			return template.duplicate(true)
		if requested_lookup_key == to_lookup_key(str(template.card_name)):
			return template.duplicate(true)
		if template.has_method("get_normalized_card_name") and requested_lookup_key == to_lookup_key(str(template.get_normalized_card_name())):
			return template.duplicate(true)
		if template.has_method("get_ascii_card_name") and requested_lookup_key == to_lookup_key(str(template.get_ascii_card_name())):
			return template.duplicate(true)
	return null

static func make_cards_from_counts(card_counts: Dictionary) -> Array[Card]:
	var cards: Array[Card] = []
	for raw_card_name in card_counts.keys():
		var card_name := str(raw_card_name).strip_edges()
		var count := int(card_counts[raw_card_name])
		if card_name.is_empty() or count <= 0:
			continue
		for _copy_index in range(count):
			var card := instantiate_card_by_name(card_name)
			if card != null:
				cards.append(card)
	return cards

static func _matches_card_name(card: Card, requested_name: String) -> bool:
	if card == null:
		return false
	if str(card.card_name) == requested_name:
		return true
	if card.has_method("get_normalized_card_name") and str(card.get_normalized_card_name()) == requested_name:
		return true
	if card.has_method("get_ascii_card_name") and str(card.get_ascii_card_name()) == requested_name:
		return true
	return false

static func to_lookup_key(card_name: String) -> String:
	var normalized_name: String = str(card_name).strip_edges().to_lower()
	var output := ""
	for char_index in range(normalized_name.length()):
		var codepoint := normalized_name.unicode_at(char_index)
		var is_digit := codepoint >= 48 and codepoint <= 57
		var is_upper := codepoint >= 65 and codepoint <= 90
		var is_lower := codepoint >= 97 and codepoint <= 122
		if is_digit or is_upper or is_lower:
			output += normalized_name[char_index]
	return output
