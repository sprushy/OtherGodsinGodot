# Bot Strategy Baseline And Card Comprehension

This document is the reference for improving the practice/ranked bots (`scripts/bots/ThorPracticeBot.gd`, `scripts/bots/BotCardStrategy.gd`, `scripts/bots/BotCardPromptPolicy.gd`). It has two halves:

1. A **strategy baseline**: the decision layers a strong Other Gods player runs every turn, mapped against what the bot does today, with the gaps called out.
2. A **card comprehension pass**: category-by-category and card-by-card notes on how each card should be used profitably, what the bot currently understands, and the concrete heuristic that would close the gap.

No code changes are included here; this is the planning baseline those changes should follow.

---

## 1. How The Bot Works Today

`ThorPracticeBot` is an event-driven state machine (signals → `_run_step`) with a single scalar economy. Everything is compared in points:

- `CARD_VALUE = 5000` — one card.
- `MANA_VALUE = 1000` per mana, with a saturation curve (`BotCardStrategy._mana_saturation_ceiling`) so mana past everything the deck can still pay for decays toward a floor; unbounded sinks (Ancient Pyre, Mana Guard) raise the floor.
- Followers are worth ~200/point above 50, ~350 between 25–50, ~600 below 25 (`_score_follower_loss`), lethal/lethal-prevention is `±CARD_VALUE * 20..30`.
- A card on board is worth `CARD_VALUE + projected_score/2`, discounted by disables (`_debilitation_discount`).

The turn flow:

1. **Upkeep** (`_choose_upkeep_option`): mana vs. draw, compared via best-affordable-creature lines, expected deck draw value (the bot knows its own deck composition), and god-specific overrides (Hermes lethal, Tonal Extraction, manifestation, Aphrodite).
2. **Main phase** (`_take_main_phase_action`): a cascade of plan generators — combat plan, Hermes/shift plans, removal setups, paired removals, power activations, summons (with attack-setup composition), manifestations, unlocks, defensive stance, equipment pickup, united front — sorted by score with lethal always winning.
3. **Combat model** (`_plan_combat`): BFS over attack sequences with dedup keys and `0.75^depth` discounting. Each attack candidate carries a base outcome plus every legal interceptor reply plus known prepared responses (`_get_known_attack_response_cards` models enemy The Inferno / Void Shield / Smite); the score takes the **minimum** over the defender's choices. Guard depletion, upkeep losses, and both players' follower totals are tracked along each line.
4. **Defense model** (`_forecast_incoming_follower_loss`): the opponent picks their best attack line against every legal target (followers, creatures, structures), the bot picks its best block/intercept, and one follow-up attack is re-checked with casualties and spent guard carried forward.
5. **Priority** (`_choose_priority_response`): responses are scored with the same `effect_score`/`target_score` tables used in the main phase, including buff sequences (`_score_combat_buff_sequence`).
6. **Prompts** (`BotCardPromptPolicy`): explicit per-trigger commands for ~30 selector prompts.

**What it already does well** (improvements should build on these, not replace them):

- Hidden-information discipline: `CardStrategy.visible()` gates nearly every read; the bot never peeks at stealth/face-down enemy cards, and wipe evaluation refuses to inspect hidden identities.
- Lethal detection across multi-attack sequences, removal-into-attack composition (`_plan_removal_setup`, `_plan_paired_removals`), and summon-into-attack composition.
- Opponent-reply modeling in combat: interceptors (with speed/row/stance legality via `match_manager._can_intercept`), three known traps, Jiang Ziya counterstroke, destruction guards, immunities, turn destruction wards.
- Mana economics: marginal rate, saturation ceiling from the bot's actual remaining deck, sinks that convert mana directly into follower swings.
- Locked-board detection (`_locked_board_state`) that turns Ancient Pyre's conversion into the win condition.
- Per-card rules for every non-creature card in the catalog (see §3).

---

## 2. Strategy Baseline: The Layer Model

A strong player runs five layers each turn. The bot executes layers 0 and 4 well, 3 partially, and barely runs 1 and 2.

### Layer 0 — Invariants (always true)

- Check lethal before anything else; check whether *you* die to the current stack first.
- Never attack into a Defensive body with insufficient STR (the rules' follower-loss-and-opponent-gain punishment is already priced by `_estimate_raw_attack_economy`).
- Spend mana only when the purchase beats the marginal mana rate.

### Layer 1 — Strategic posture (missing)

The bot has no concept of *what kind of game this is*. Add a posture evaluation once per turn (cheap, cached like `_locked_board_cache`):

- **Race clocks.** For each side estimate "turns to win at current rate": my best recurring unblocked follower damage vs. theirs (both already computable from `_get_combat_candidates` / `_forecast_incoming_follower_loss`), plus the **fatigue clock**: from turn 49 upkeep losses escalate every 7 turns (7, 14, 21…). `turns_to_fatigue_loss = followers / fatigue_loss(turn)` for each side. Three outcomes:
  - My clock < theirs and I can't lose to a burst → **RACE**: weight follower damage up (e.g., ×1.5 in `_score_follower_loss(opponent, …)` calls), accept worse card trades, attack followers over killing small bodies.
  - Their clock < mine → **DEFEND/DEVELOP**: weight danger forecast up, hold interceptors, prefer removal over tempo.
  - Locked board (already detected): if ahead on followers/fatigue, **do nothing risky** — passing wins; if behind, **force action** — the current Ancient Pyre exception should generalize to "any plan that breaks the lock," including bad trades that create an attack lane.
- **Win-condition inventory.** Once per turn, list "how do I actually win this game": follower damage / Ancient Pyre conversion / manifestation beats (Thor Active etc.) / token swarm (Hyena Pack, Harii Warband) / fatigue stall. Every scoring decision implicitly serves this list; today only Ancient Pyre gets this treatment.
- **Who's the beatdown.** Compare board strength + hand size + follower totals. The side with more tempo should attack followers and force answers; the side behind on board should trade and hold responses. Today stance and attack decisions are made purely from local economies, which produces the classic failure: the bot makes a "profitable" trade while it is the only deck capable of racing.

### Layer 2 — Resource ledger (partially there)

Mana is modeled deeply; the other resources are not:

- **Lanes** are a resource (10 per side). `CardStrategy.open_spaces()` exists but is only consulted by a handful of cards (Wild Magic, Drought, Palisade, Blot Sacrifice). Baseline rule: summon/prepare planning should reserve frontline slots for creatures when the board is contested, and prepared cards should claim reserve slots first (already the default via `_get_first_open_reserve_zone`) — but also: **don't prepare a second copy of a situational trap** (already implemented for Wheel of Fire; generalize), and **count enemy open lanes** when forecasting their next-turn summons (`_forecast_aggressive_exposure_risk` does this for stance; the danger forecast only sums existing attacker STR).
- **Actions** (minor/major per creature). The bot checks them per creature but never asks "how many of my majors are unspent at end of turn" as a global tempo metric. A cheap end-of-turn audit — any unspent major on an aggressive frontline creature with a legal attack means the attack planner said "not profitable" — is worth logging/tuning, because that is where race decks leak wins.
- **Cards.** `value()` treats all cards nearly equally. There is no "I'm card-poor vs. card-rich" term. Baseline: compute hand quality + deck velocity (draw options per turn); when card-poor, add a bonus to plays that draw/return cards and a penalty to plays that spend multiple cards for one effect; when card-rich (7+), convert cards to tempo freely.
- **Follower asymmetry.** `_score_follower_loss` handles pressure per point, but there's no *relative* term: losing 10 when the opponent is at 90 and I'm at 60 is much worse than the reverse. Add a race-differential weight (this is the Layer 1 hook in its cheapest form).

### Layer 3 — Threat assessment and opponent modeling (partial)

The one-and-a-half-ply danger forecast is good, but it only sees the current board plus a mana budget. Missing:

- **Opponent responses during my turn** are modeled for exactly three prepared cards (The Inferno, Void Shield, Smite) plus Jiang Ziya's counterstroke. A human holds charms/hexes in hand. Baseline: a "known responses" registry built from what the opponent has revealed (Mopsus reveals, Dellingr, sacrificed/destroyed cards seen this game) — the infrastructure (`CardStrategy.visible`, `_estimate_known_attack_response`) is already shaped for this; it just only ever consults the board.
- **Enemy god abilities are invisible to planning.** Aphrodite's Violent Delights is modeled only for the bot's own Aphrodite; the bot will happily make its one allowed combat kill into an open Aphrodite player with 5 mana, handing them a free enslave. Same class of problem: Guan Yu tactical break, Freyja resurrect, Odin draw, Mummu shelve. Baseline: a per-enemy-god `opponent_threat_profile()` that annotates the danger forecast and attack replies ("this clean kill costs me X if they have Violent Delights").
- **Free/cheap summon lines** (Skoll upkeep summon, Hati moon hunt, Raven Storm sighting, Harii Jarl warband, Hyena Pack scavenge) are modeled only when the *bot* runs them. Facing them, the attacker forecast should add "opponent can add up to N extra bodies next turn at these costs."
- **Multi-turn accumulation.** Pazuzu drains 2 mana per turn, Baldr gains 5 followers per upkeep, Caleuche grows with each Spirit. None of these make the next-turn danger/mana forecasts. `get_projected_upkeep_follower_loss` is exactly the right hook — it exists, and only some cards implement it.

### Layer 4 — Tactical execution (strong, some gaps)

- **Sequencing**: summon-then-attack is discounted 25% for the response window (good); removal-then-attack, buff sequences, and paired removals are composed. Gap: the bot doesn't consider *attacking first, then summoning* to bait responses — acceptable to skip, but noted.
- **Positioning**: movement scoring (`_score_creature_move`) covers attack enablement, shelter, equipment reach, freed lanes, and interception coverage. Gap: **summon lane choice** is "first open zone" (front-left bias, `_get_first_open_summon_zone`); there is no "place my RES body where their biggest attacker can reach it / place attackers where their interceptors can't." A lane-assignment pass at end of main phase (score each friendly creature × each open/adjacent lane for interception coverage of the *actual* forecast threats) would be the single best positioning improvement.
- **Stance**: `_choose_creature_summon_mode` and the defensive/aggressive switch planners are reasonable; `_forecast_aggressive_exposure_risk` is a genuinely good heuristic. Gap: end-of-turn defensive setup only happens under danger or follower scarcity; against race decks the bot routinely ends the turn all-aggressive.
- **Stealth**: `_should_summon_creature_stealthily` scans `ability_text` for the words "passive/impact/on summon" — a text-parsing holdover. It works, but it should be replaced by the same per-card reveal-value table `_estimate_reveal_trigger_value` already implements, extended with a "this creature's face-up passive matters" flag.

---

## 3. Card Comprehension Pass

### The comprehension ladder

A card is *understood* when the bot can answer five questions about it:

1. **Legal** — when can it be played/activated, and on what targets? (Always delegated to `MatchManager`/card authority — this is done well everywhere.)
2. **Valued** — what is the effect worth, in the shared economy?
3. **Timed** — is *now* the right moment, or should it be held (setup card, response card, late-game card)?
4. **Composed** — what other cards does it combine with (payment, sacrifice, buff, search targets)?
5. **Modeled** — when the *opponent* has it, what does it threaten, and how does that change my lines?

Most non-creature cards reach rungs 2–3; creatures mostly sit at rung 1 (bodies) with scattered rung-2/3 for ~35 of them; rung 5 is nearly empty except engine-level combat rules.

### Coverage map (as of this writing)

| Category | Count | Covered by explicit strategy | Notes |
|---|---|---|---|
| Spells | 22 | 22 | 18 in `TACTICAL_CARDS` + Apollyon's Demiurge / Blot Sacrifice / Deucalion's Infants / Key of Solomon special-cased |
| Hexes | 15 | 15 | 14 tactical + Wheel of Fire fully custom |
| Charms | 10 | 10 | 9 tactical + Mead of Poetry custom |
| Equipment | 7 | 7 | `EQUIPMENT` list + `equipment_score`/`equipment_pickup_score` |
| Structures | 9 | 9 | `STRUCTURES` list + `structure_score` |
| Powers | 33 | 33 | `ACTIVE_POWERS`/`PLANNED_POWERS`/`PASSIVE_POWERS`/`PASSIVE_TYPES` + extras; depth varies (see below) |
| Gods | 14 | 13 | Manannán mac Lir's activation is never used; Baldr/Cernunnos are passive-only |
| ActiveGods | 10 | generic | `_score_god_manifestation` scores bodies + attack availability; several impact prompts handled (Tiamat, Nusku, Freyja, Tezcatlipoca, GuanYu counters) |
| Creatures | 106 | ~35 | 42 are plain bodies (nothing to miss); 24 have activated abilities (16 used); 29 have passives; 16 impact; 6 reveal (all 6 handled) |

The gaps below are ordered by expected win-rate impact.

### 3.1 Creature activated abilities that are never activated (8 cards)

These are dead text when the bot plays them — the card is deployed as a vanilla body and its ability is never once used:

- **Berserker** — *Rage: once/turn, N mana: +STR and Immortal this turn; after any attack, Sleep until your next turn.* Profitable use: push a lethal or wall-breaking attack through, or make a trade where dying was the alternative (Immortal). Baseline heuristic: treat as a combat buff available to the attack planner (`combat_gain` with a sleep cost priced like Berserker Mead's −1500), usable on defense forecasts too (Immortal = no casualty).
- **En-hedu-anna** — *Exaltation (Major): if your God's power activated this turn while she was face-up, gain +7 RES/+7 STR/+1 SPD and cannot be attacked/destroyed/targeted until end of next turn.* She is a **combo piece**: play her, activate a power the same turn, then Exalt. Baseline: summon-score bonus when a cheap power activation is available this turn; value Exalt as a defensive stance-swap-plus (the "cannot be attacked" half is a superior version of shelter).
- **Gudud Priest** — *Creature Ward (Activate, Spd3): remove creature-applied effects from a creature; rest of turn unaffected by creature abilities.* A cleanse + combat-trick-proofing. Baseline: `cleanse_score` already exists (Gawain/Anointing Statue) — reuse it, plus a combat-reply value: casting it during an enemy buff-response makes the bot's attack immune to Charm/Hex stat tricks for that fight.
- **Harii Shaman** — *Transform: swap friendly Norse Warrior ↔ Animal subtypes.* Pure combo glue for Hunting Tactics/Norse Bloodlust decks (a Warrior can become a valid supporter/target and back). Baseline: value = "does this flip enable a Hunting Tactics pair or a Bloodlust buff that isn't currently legal?" — binary check against the bot's own power list.
- **Isimud** — *Forerunner: manifestations cost 6 less. Revelation (Major): summon a Divine Manifestation from hand for +2.* Baseline: summon-score bonus = 6 × marginal mana whenever a manifestation line exists in hand/deck, and a plan that spends his major action on Revelation when a manifestation is in hand and the god's Champion's Call is otherwise unaffordable this turn.
- **Mopsus** — *Seer (Minor): reveal an opponent hand card, +1 per friendly Avian.* Information is the weakest effect for a bot (it can't exploit reads), but the *registry* it feeds (Layer 3 known-responses) makes it real: value = number of unknown enemy responses currently unmodeled. If Layer 3 never lands, Mopsus stays near-zero and the ranked deck builder should treat it as a body.
- **Seventh Sage Utuabzu** — *Channel Ally (Impact)/Imbue Ally (Activate): re-trigger another Ancient Sage's impact.* Baseline: value = best other Sage impact on field/in Void (the sage impacts are already understood — Silence, Good Fortune, Search, Conjure Home), priced at the activation tax.
- **Winged Lion** — *Flank (Activate): move itself and another friendly creature to any friendly slots.* Free repositioning — the movement planner's dream. Baseline: value = best two `_score_creature_move` deltas it can create, evaluated in the same pass as `_try_improve_creature_position`.

### 3.2 Creature triggers with no summon/attack-time valuation (~12 cards)

The engine resolves these correctly once played; the bot just doesn't *know* it's getting them, so it mis-times or under-deploys:

- **Pazuzu** (Impact: −2 enemy mana; Passive: −2 enemy mana each upkeep) — should be summoned *before* the opponent's big turn, and when facing it, the bot's own mana forecasts must subtract 2/turn. Both directions missing.
- **Asakku** (on combat kill: +2 mana) — attack-economy bonus on kill lines, like the existing Masmassu mana valuation.
- **Aurboda** (Slay: Convert 7 followers) — attack-economy bonus on kill lines; also raises the creature's defensive value (trading up is a double reward).
- **Ankou, Servant to the Reaper** (Slay: draw a card) — kill lines should credit `CARD_VALUE ×` draw value; makes it a premium chump-blocker.
- **Rabisu** (Impact: Leech 3 STR/RES from each sleeping creature) — summon timing: play it when enemies are asleep (the bot already tracks sleep durations well for its own disables).
- **Gidim-Ensi** (Guardian: attackers of your followers Sleep; cannot attack) — a defensive wall whose *real* value is its Guardian trigger. `_estimate_defensive_summon_value` should add "attacks on followers now bounce into a sleep lock" when it's fielded.
- **Caleuche** (+10 STR/+1 SPD per other friendly Spirit) — stat passive flows through effective stats once on board, but summon-time comparison doesn't credit the delta, so the bot undervalues it in Spirit decks.
- **Raven Storm** (Spd 3: when a friendly Norse Human Warrior or Lupine attacks, summon it from hand for free) — the bot never does this; it's a free blocker/attacker every combat. Needs a hook in the attack planner: "declare attack X, then free-summon Raven Storm."
- **Pegasus** (Steed: a Human/Active God can wield it as equipment granting Spd 5 + Aerial + Evasive) — the equipment planner only handles `EquipmentCard`; Pegasus-as-gear is invisible. Add a steed branch to `equipment_score`.
- **Capricorn** (if sacrificed for a summon, +2 mana and return to hand) — the summon payment planner (`_build_creature_summon_payment_plan`) should treat Capricorn as a *discount* sacrifice (refund), making it the preferred payment card.
- **Wolf Cub / Wolf Adolescent** (Maturation: upkeep upgrade into a deck Lupine) — prompts are answered, but the summon score doesn't credit the upgrade chain (play a Cub early → it becomes a deck Lupine later), and the upkeep prompt decision isn't planned against danger.
- **Habrok** (Breakout: if it's your only creature at end of opponent's turn, return to hand + destroy their weakest creature) — the prompt always says yes, but the *strategy* (deliberately keeping it alone, attacking with it, replaying every turn) isn't modeled; worth a summon/attack-line bonus when the board is otherwise empty.

### 3.3 Creatures whose passive is engine-handled but under-*chosen* (selection/timing gaps)

- **Gullinbursti** (Dodge: slower creatures can't attack it) — engagement rules flow through, so the bot never makes an illegal attack; but it also doesn't *prefer* Gullinbursti as the attacker into slow blockers, or as the body that holds a lane against a slow board.
- **Edimmu / Gidim-Ensi** (Incorporeal: only Spirits/Mages engage them) — same: the matchup-aware summon bonus ("their board has no Mage/Spirit → this body is unkillable this turn") is missing.
- **Gilgamesh** (+STR per level deficit vs. higher-level creatures) — flows through combat math; missing as a *targeting preference*: he wants to attack up.
- **Tianlong, Holy Dragon / Urisk Grovekeepers** (special interception) — `_can_intercept` handles them live; `_estimate_defensive_summon_value` gets the benefit automatically only if the card is already on board. Summon-time credit for "can intercept regardless of stance/speed" is missing (it makes them the best blockers in the deck vs. fast attackers).
- **Minotaur Footsoldier / Telchine Apprentice / Low Light Troll / Seven-Headed Serpent / Asaruludu / Gala-Tura / Garm / Humbaba / Rabid Wolf / White Stag / Stone Monkey** — all resolve correctly; the gaps are valuation only (e.g., Garm should suppress the bot's own graveyard-line plans and boost its expectation against Freyja/Again Walker opponents; Rabid Wolf's disease should add a "survivor is crippled" term to fight scores; White Stag's Fatality giving the *opponent* 2 mana should slightly discount killing it via combat when the race is tight).

### 3.4 Non-creature cards: shallow-but-present understanding (timing/depth fixes)

All are "covered," but these have known shallow spots:

- **Dromi / Gleipnir** (bind hexes): scored as attack-lock/intercept-lock value; gap: they are best *pre-attached to the specific threat before combat*, and Dromi's drain-2-per-turn ticking end-game isn't priced (only an immediate 2×FOLLOWER_LOSS is).
- **Absence** (mute a power/God 2 turns): scored generically by target cost; gap: should prioritize powers that are about to pay off (counters, stored cards) over face-down randoms, and should be timed to the opponent's lethal/combo turn.
- **Circle of Rebirth**: evaluates `died_this_turn` only — correct, but the bot doesn't *create* lines where its own deaths feed it (acceptable; keep).
- **Watchtower** (reveal + counter enemies): flat 6000/3000 by enemy count; gap: doesn't distinguish which enemies (a counter on Fenrir/Jiang Ziya is worth far more than on a Bear).
- **Doorway to the Void**: values enemy graveyard recursion correctly (Again Walker/Huginn/Freyja bonuses exist) — this is one of the best-modeled structures; keep as the template.
- **Warding Stone**: unlock/play scored with attack-restriction awareness; gap: when the bot is *ahead* and racing, blocking its own attacks is a real cost the current score already handles via `attack_restrictions` — verify the reverse case (bot facing Warding Stone doesn't re-plan its attack lane after the restriction lands; the restriction map is only consulted in forecasts).
- **Ragnarok**: unlocked mainly as a panic reset; gap: the "I'm behind on board but ahead on hand" profile that makes it a fair card isn't in the posture layer yet — with Layer 1 in place its score can be posture-weighted.
- **Powers with activation depth issues**: `ManaGuard` guard sizing is excellent; `Palisade` pressure model is good; `AcceleratedFate`/`OraclesSight` are fine. **AnankesBinding/Breidablik/WalkOfTheSage/FireAndGold/DivineCaprice** (PLANNED_POWERS) each have real planners — the gap is *unlock timing* vs. the posture layer (e.g., Fire And Gold should wait for a ≥1-card-value enemy target, which it does, but only considers the current board).
- **SavingGrace**: understood as a response, but the unlock condition (no creatures/magical cards) means the bot must *choose* to be empty — a posture decision that doesn't exist today; in practice the factory includes it in the right decks, which is why it still fires.

### 3.5 Gods

- **Manannán mac Lir** (2 mana: all your Triskelion creatures enter stealth) — never activated. Correct use: dodge targeted removal for a turn, or set up reveal triggers (Sulak/Afanc/Pictish Beast in Triskelion culture) on the bot's own schedule. Add to `_try_activate_best_god_ability` with a target_score = "enemy holds targeted removal evidence × board value" or "reveal trigger value available."
- **Aphrodite Areia** — Violent Delights planning is deep (upkeep override, attack-line capture bonus). Missing only the *defensive* half (§2 Layer 3): facing her, the bot's combat kills should charge the risk of the follow-up enslave.
- **Freyja / Odin / Nusku / Mummu / Guan Yu / Hermes / Tezcatlipoca / Tiamat / Dellingr / Thor** — all have real planners. The consistent gap is the *opponent-side* model (their activations never appear in the bot's danger or attack-reply forecasts).
- **Baldr / Cernunnos** — passive-only; ensure `get_projected_upkeep_follower_loss`-style projections account for Baldr's +5 (it likely does via upkeep helpers — verify) and Cernunnos' Animal buff flows through effective stats (it does).

### 3.6 Active Gods (manifestations)

`_score_god_manifestation` correctly demands an immediate profitable attack and prices shelve payments. Per-form impact depth exists only where prompts exist (Tiamat/Freyja/Tezcatlipoca/Nusku/GuanYu). The biggest miss: **Baldr Active** (convert follower damage instead of dealing it — the alt win con) and **Thor Active** (patron intercept-any + team buff) should tilt the *whole posture* when available, the way Ancient Pyre already does.

---

## 4. Suggested Work Order

1. **Posture/clock layer** (§2 Layer 1) — race clocks, fatigue clock, locked-board generalization. Cheapest, biggest strategic lift; plugs into existing scoring as multiplicative weights.
2. **Opponent-response registry** (§2 Layer 3) — extend `_get_known_attack_response_cards` beyond the three traps to revealed-hand responses and enemy god abilities (start with Aphrodite/Freyja/GuanYu).
3. **Creature ability activations** (§3.1) — eight `BOARD_ABILITIES`-style additions; the command path (`activate_card_ability`) already exists and the pattern is proven.
4. **Trigger valuation at summon/attack time** (§3.2) — payoffs the engine already resolves; pure scoring work in `_score_creature_play_in_zone` / `_estimate_attack_economy` / the payment planner.
5. **Lane assignment pass** (§2 Layer 4) — end-of-main-phase positioning scored against the actual forecast threats.
6. **Stealth table** (§2 Layer 4) — replace the `ability_text` scan with the reveal-value table.
7. Then per-card depth fixes from §3.4 as needed, driven by observed bot-vs-bot losses in the ranked pool.

Testing follows the repo conventions: no new ad-hoc probe scripts; use the existing practice smoke roles (`scripts\tmp\run_practice_smoke.ps1`) and manual two-window lobby tests, and watch bot-vs-bot ladder results for regressions.

---

## 5. Implementation Status (updated)

Work-order items 1–4 are implemented. The uncommitted delta at the time of writing consists of two late fixes on top of the v0.2.367 snapshot (fatigue excluded from the combat forecast; Mopsus exact-count Seer selection).

**Item 1 — posture/clock layer (done).** New `scripts/bots/BotStrategyPosture.gd` computes one posture per turn, cached in `ThorPracticeBot._strategy_posture()` with a reentrancy guard:

- `race` (bot clock ≤ opponent clock + 1, or free damage): `_score_follower_loss` for opponent damage is scaled by `RACE_DAMAGE_MULTIPLIER` (1.35).
- `defend` (opponent clock faster or a large incoming bite): `_follower_safety_gain` scaled by `DEFEND_SAFETY_MULTIPLIER` (1.3).
- `locked_ahead` / `locked_behind`: only when `_locked_board_state()` and fatigue is actually active (turn ≥ 49); combat-trade scores get ±`CARD_VALUE/2` in `_score_attack_economy` to protect the board (ahead) or break the lock (behind).
- Combat push and fatigue are separate clocks: `_forecast_incoming_follower_loss` stays combat-only (it must — `_compute_locked_board_state` uses it, and folding fatigue in would permanently disable locked-board detection after turn 49). The fatigue clock is computed directly from `get_fatigue_follower_loss` in the posture module.

**Item 2 — opponent-response registry (partial).** `_get_known_attack_response_cards` now also models **revealed** enemy hand copies of The Inferno / Void Shield / Smite (visible via Seer/Dellingr reveals), priced by mana. Combat-killing casualties feed two new opponent-model terms in `_add_combat_casualty`: Freyja's Receiver of the Slain discount (killing a Norse Warrior is only a 1-turn borrow if she can pay) and Aphrodite's Violent Delights enslavement risk (their defender killing our creature unlocks her activation; charge `best_target/4`). Guan Yu and remaining enemy god abilities are still unmodeled.

**Item 3 — creature ability activations (done for all 8).** `Berserker` (Rage only when it flips a fight), `En-hedu-anna` (Exaltation: RES for defenders, STR for attackers), `GududPriest` (Creature Ward, creature-source statuses/buffs only), `HariiShaman` (restore Animals under Thor patron; transform Warriors to Lupine when Hunting Tactics wants support), `Isimud` (Revelation summons a hand Divine Manifestation at +2 tax), `Mopsus` (Seer reveals, sized to `get_required_seer_target_count` so the selection can't fizzle), `SeventhSageUtuabzu` (Imbue Ally replay of Sage impacts), `WingedLion` (Flank pair-moves scored with `_score_creature_move`). All payloads were verified against each card's `activate()` option parsing; WingedLion zone options use the `player_index/zone_type/zone_index` dict format its resolver expects.

**Item 4 — trigger valuation (done).** `_summon_trigger_setup_bonus` prices deployment-time triggers: Pazuzu (Locust drain), Rabisu (Life Drain vs. sleeping bodies), Caleuche (Spirit count), GidimEnsi (deterred push), Habrok (empty-board Breakout), Wolf Cub/Wolf Adolescent (maturation upgrade margin), Isimud (Forerunner discount), En-hedu-anna (god-ability pairing). `_score_summon_sacrifice_candidate` marks Capricorn as the premium sacrifice payment (refund + return to hand), and `_add_deck_combat_rewards` prices Aurboda's Pierce (7-follower convert), Ankou's Reap (draw), and Asakku's Offering (2 mana per kill). Pegasus steed mounting is planned in `_plan_equipment_pickup`, and Manannán mac Lir's Mists activation is scored in `_try_activate_best_god_ability` (`_estimate_reveal_trigger_value`/2 per hidden Triskelion, minus forfeited safe attacks, plus a per-hidden-answer bonus). Raven Storm's Sighting is taken unconditionally as a priority response (free body; zone auto-picked by the card).

**Item 6 — stealth table (done).** `_should_summon_creature_stealthily` no longer substring-scans `ability_text` for "passive"/"impact"/"on summon". `BotCardStrategy.STEALTH_SUPPRESSED_KEYS` now lists the creatures whose face-up value stealth suppresses (engine gates impact/kill/death hooks on `abilities_suppressed()`, and several passives self-gate the same way — intercept reach, Garm's watchbeast, Pegasus engagement, Enki hex protection, Gullinbursti, the Nagual/Thiazi/Sulak strength passives, Telchine Apprentice, Stone Monkey replacement, Harii Fransiscan action counts, Wolf Cub maturation). The check now also applies to reserve-line summons, where previously only `speed == 1` was considered. Reveal-trigger creatures (Afanc, PictishBeast, Grindylow, Lailoken, LowLightTroll, MasmassuPriest) are deliberately excluded — their payoff fires on reveal and is valued by `_estimate_reveal_trigger_value`.

**Not yet done:** work-order item 5 (lane assignment pass), item 7 (per-card depth fixes from §3.4), the remaining enemy god abilities (Guan Yu etc.), and the deeper non-creature timing fixes in §3.4.

**Verification notes.**
- `practice_thor`, `practice_thor_summon`, and `practice_thor_intercept` smokes pass with the implementation.
- `practice_thor_fuzz` has a **pre-existing, nondeterministic stall** (silent, no script error): the game wedges with no further validated actions while the state is quiescent (`priority_player=-1`; sometimes an unresolved stack, sometimes an empty stack on the bot's own turn). It reproduces at true baseline (pre-v0.2.367 bot files) — seed 1337 stalled at index 0 turn 8, seed 4242 at index 0 turn 8 — and is timing-sensitive: identical seed+code runs both stall and complete across attempts (seed 5050 stalled at turn 12, at turn 6, then passed). The mechanism looks like a race between the authoritative stack linger timers and uncapped headless frame timing, not bot logic. This implementation plays longer games (more activations, better survival), which surfaces the race more often.
- Two diagnostics were added to the fuzz stall snapshot in `MainMenu.gd` (`pending_prompt_types` and `authoritative_pending`, i.e. `MatchManager._authoritative_stack_resolution_pending`) so a future stall names the pending prompt and the authoritative flag directly.
- Validate fuzz changes by comparing completed-game counts per seed against a same-seed baseline run, not by expecting a clean 20-game pass.

