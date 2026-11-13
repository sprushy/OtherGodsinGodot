extends RefCounted

const BOT_FEEDBACK := "Notice a way for a bot to improve its play? Submit a report through the main menu and I will try to improve it. There are many cards so there should be many ways!"

const GENERAL: Array[String] = [
	# Turns and resources.
	"Followers are your life total. Reduce your opponent's Followers to 0 to win.",
	"Both players start with 100 Followers and a five-card hand.",
	"Going second gives you 2 extra mana at the start of the game.",

	"At Upkeep, you can choose between gaining 4 mana and drawing a card.",
	"You gain 1 mana for free after the first turn of the game if your god is alive.",

	"Keep some mana available if you plan to play a response on your opponent's turn.",
	"If you end your turn with more than seven cards in hand, you'll have to discard down to seven.",

	# Creatures, lanes, and combat.
	"You get summon one creature and build one structure per turn normally.",
	"Creatures can act on the turn they enter. All attacks are blocked on the very first turn of the game.",
	"Summon your attackers before the first attack resolves. Creatures summoned afterward have to wait until next turn to attack.",
	"Creatures normally get one Minor Action and one Major Action each turn. A normal summon spends the Minor Action.",
	"Moving to an adjacent empty slot or changing stance usually costs a Minor Action.",
	"Attacking usually costs a Major Action. Some activated abilities also spend that action.",
	"Stealth is face-down Defensive stance. A normal Stealth summon spends both of the Creature's actions for the turn.",
	"Attack with eligible Aggressive Creatures in your Frontline.",
	"Each lane pairs a Frontline slot with the Reserve slot behind it. Position affects movement, Equipment, and card effects.",

	"Check for interceptors before attacking. An eligible interceptor may step in and take the attack in place of the original target.",
	"An interceptor needs to be at least as fast as the incoming attack.",
	"A Defensive Creature in your Frontline can intercept attacks aimed at your Reserve as well as your Followers.",

	"Reach lets a Creature intercept for more rows.",
	"Aggressive Creatures defend with Strength. An even Strength matchup destroys both Creatures.",
	"Defensive Creatures defend with Resilience. If the attacker's Strength equals the defender's Resilience, both survive.",
	"If your attacker falls short of a Defensive Creature's Resilience, you lose Followers and the defender gains them.",
	"Attack the enemy God to damage their Followers.",


	# Card types and timing.
	"Hexes must be prepared face down for one turn.",
	"Charms can be prepared face-down or play directly from your hand on your turn.",
	"Prepared cards occupy board slots. Leave room for the Creatures you plan to summon or move.",

	"Powers start face-down. Pay their unlock cost to gain access to their effects.",
	"Some Gods use Champion's Call to summon their matching Active God shelving cards from hand to help pay the cost.",
	"God Death costs you 7 Followers at Upkeep and blocks your Powers until you have a face-up, awake God again.",
	"Equipment can boost a Creature's stats or give it new abilities.",
	"A Creature can often spend a Minor Action to pick up friendly Equipment within reach.",
	"An enemy Creature may be able to spend a Major Action to steal or destroy your unequipped Equipment.",
	"Structures stay on the board and can be attacked. You can play one Structure from hand each turn.",
	"Check the full cost before committing. Some cards also require a discard, sacrifice, or other payment.",
	"Priority gives you a chance to respond before an action resolves.",
	"When both players pass Priority in a row, the most recent action on the stack resolves first.",
	"Responses need at least Speed 2 and must be as fast as the action they answer.",
	"Passing Priority can save your best response for a more important threat.",

	# Zones, keywords, and card text.
	"Destroyed cards usually go to the Graveyard. Void sends cards to the Abyss.",
	"Resurrect brings a destroyed card from the Graveyard back to the field.",
	"Shelving puts a card on the bottom of its owner's deck. Milling sends cards from the top of a deck to the Graveyard.",
	"Impact triggers when a card enters the field from your hand. Universal Impact also works from other zones.",
	"Perish triggers when a card goes from the field to the Graveyard, including when you sacrifice it.",
	"Slay triggers when a card destroys a Creature in combat. Fatality triggers when the card itself is destroyed in combat.",
	"Sleep prevents a Creature from acting or intercepting. Wake removes Sleep.",
	"A muted Power can't be unlocked or activated until the mute expires.",
	"Dodge protects a Creature from attacks by slower Creatures.",
	"Incorporeal Creatures can only fight with Spirits or Mages.",
	"Immortal prevents destruction. Check the card text when choosing how to deal with one.",
	"Relock turns a Power face-down again. Reveal effects can trigger when a hidden card turns face-up.",
	"Convert moves Followers from your opponent to you.",
	"Enslave takes control of an opposing Creature.",
	"Card subtypes matter. A bonus for Warriors only helps cards with the Warrior subtype.",

	"Card text can override a general rule. Check the card for exceptions before committing to a play.",
	"Card details explain keywords and show which effects are modifying a Creature's stats.",

	# Deck building and multiplayer.
	"A multiplayer deck needs exactly one God, up to three Powers, and at least 40 regular cards.",
	"Choose Powers that match your God's culture or are Neutral, and check your God for any additional deck restrictions.",
	"You can usually run up to three copies of a regular card. Each Legendary is limited to one copy.",
	"Your main deck can include one Legendary for every ten regular cards.",
	"Reinforcements let you swap cards between games in a best-of-three match.",
	"With 40 regular cards and three Powers, your deck can have up to 14 Reinforcements.",

	"Bo1 and Bo3 have separate ranked ladders. A best-of-three series counts as one ranked match.",

	"Watch a live match to see how other players spend mana, time their responses, and defend their Followers.",
	"If you lose connection, look for the rejoin option in Multiplayer to get back into your active match.",
]

const MOUSE_AND_KEYBOARD: Array[String] = [
	"Did you know you can right-click while dragging a Creature from your hand to summon it in Defensive stance?",
	"Press S while dragging a Creature from your hand to summon it in Stealth.",
	"Right-click or press S while dragging a Spell or Charm to switch between playing it and preparing it face-down.",
	"Drag an eligible attacker to the enemy card or God you want to attack.",
	"Right-click a Creature on the board to see its available actions.",
	"Click the Priority seal or press Space to pass Priority.",
	"Hold Ctrl for temporary Full Control over Priority. Press Ctrl+Shift to toggle it on or off.",
]

const TAP: Array[String] = [
	"Tap a card in your hand, then tap Play Options to see how you can play it.",
	"When the board zooms in for a play, tap Switch Side to view the other side of the board.",
	"Tap Main View to return to the full board after focusing on a card.",
]
