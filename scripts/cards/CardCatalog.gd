extends RefCounted
class_name CardCatalog

static func make_all_cards() -> Array:
	return [
		Thor.new(), Mummu.new(), AphroditeAreia.new(), Baldr.new(), Cernunnos.new(), DellingrTheDayspring.new(), Freyja.new(), GuanYu.new(),
		AcceleratedFate.new(), ACostToWalkTheWorlds.new(), AdvancedBuildingTechniques.new(), AllfathersSacrifice.new(), AltarOfDreams.new(), AnankesBinding.new(), AncientWisdom.new(), BerserkerMead.new(), Breidablik.new(), CallOfTheValkyrie.new(), DivineCaprice.new(), FeastOfAmbrosiaAndNectar.new(), FerociousDefence.new(), FireAndGold.new(), GiantsDisdain.new(), MechFactory.new(),
		Berserker.new(), Beyla.new(), BlessedKnights.new(), BrownBear.new(), Byggvir.new(), DurinnSecondborn.new(), Fenrir.new(), FirstSageAdapa.new(), load("res://scripts/cards/Creatures/FourthSageEnmegalamma.gd").new(), GiantMasterArchitect.new(), Skoll.new(), AnkouServantToTheReaper.new(), Anzu.new(), AnTheBowbender.new(),
		AsagTheDestroyer.new(), Asakku.new(), Asaruludu.new(), Caleuche.new(), Capricorn.new(), ClayEaters.new(), HabrokParagonOfHawks.new(),
		AgainWalker.new(), Alu.new(), Askelladen.new(), Aurboda.new(), DraugRevenant.new(), DevastatorMech.new(), Edimmu.new(), EnHeduAnna.new(), Enkidu.new(), EnkiLordOfEridu.new(), ErlqueensNightingale.new(), Gallu.new(), GalaTura.new(), GarmWatchdogOfHel.new(), Gawain.new(), GidimEnsi.new(), Gilgamesh.new(), GududPriest.new(), GugalannaBullOfHeaven.new(), Gullinbursti.new(), RoboticFootsoldier.new(), SoldierOfTheBlackEmperor.new(), TitanicMech.new(),
		BitMeseri.new(), CircleOfRebirth.new(), Earthquake.new(), FallOfTheMighty.new(), Famine.new(), FoolishOptimism.new(), preload("res://scripts/cards/Spells/FiresOfJudgment.gd").new(), ApollyonsDemiurge.new(), Absence.new(), BaneOfTheSvartalfar.new(), BlotSacrifice.new(), BookOfLife.new(), DeucalionsInfants.new(), Exorcism.new(), MeadOfPoetry.new(), DivineLightning.new(), FifaTheMagicalArrow.new(), GungnirTheSpearOfOdin.new(),
		BeardedAxe.new(), DraupnirTheMultiplying.new(), Gambanteinn.new(),
		WardingStone.new(), AncientPyre.new(), AnointingStatue.new(), DoorwayToTheVoid.new(), E2Abzu.new(), EriduCityOfSages.new(), GlitnirThePeaceful.new(),
		VoidShield.new(), Banishment.new(), Dromi.new(), Gleipnir.new(),
	]

static func instantiate_card_by_name(card_name: String) -> Card:
	var requested_name := str(card_name).strip_edges()
	if requested_name.is_empty():
		return null
	var requested_lookup_key: String = to_lookup_key(requested_name)
	for template in make_all_cards():
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
