# Codex Notes For OtherGods

Read this first on a fresh thread, then inspect the files relevant to the user's request. This repo is a Godot/GDScript implementation of **Other Gods**, a mythic strategy card game with a local UI, practice bot, deck builder, multiplayer lobby, and headless match/server work in progress.

## Project Shape

- Engine target is Godot 4.7 stable. The CI/export runtime marker is stored in `.godot-version` and loaded by `.github/workflows/windows-release.yml`; debug/editor runs should use the same Godot version as the deployed server to avoid scene RPC checksum mismatches.
- Main configured scene is `res://scenes/main_3d.tscn`, which runs `scripts/three_d/Main3D.gd`.
- `Main3D.gd` embeds `res://scenes/mainfork.tscn` into a viewport/flat 2D canvas. Server-mode launches bypass the 3D shell and load the original scene directly.
- `scripts/Other/MainMenu.gd` owns the menu, embedded game selection, deck builder entry, practice Thor mode, update prompts, smoke modes, and lobby UI flow.
- `scripts/Other/CombatMockGame.gd` is the main match UI/controller bridge. It is large and still owns a lot of presentation, prompt, and client-side interaction code.
- Rules documentation lives in `docs/new-player-rules.md`. Lobby architecture notes live in `docs/server-lobby-matchmaking-plan.md`. Manual lobby QA notes live in `docs/lobby-manual-smoke-test.md`.

## Game Rules Quick Reference

The full authoritative rules are `docs/new-player-rules.md`. Read that doc before any task that changes or questions gameplay behavior (card text, combat math, timing, prompts, keywords, deck rules). Specific card text overrides these general rules, and division rounds down unless the card says otherwise.

- Win condition: reduce the opponent's Followers from 100 to 0. Gods are not normal combat bodies; attacking the enemy God damages that player's Followers.
- Zones per player: God slot, 3 Power slots, 5 Frontline lanes (normal attacks start here), 5 Reserve lanes (safer, usually cannot attack), hand, deck, Graveyard, Abyss (exile zone).
- Turn flow: Upkeep, then Main, Combat, End. At upkeep you gain 1 automatic mana (not on turn 1, removed after God Death), then choose +4 mana or draw 1 card. The second player starts with +2 mana. Hand limit is 7, discard down at End. Fatigue: from turn 49 the turn player loses 7 Followers per upkeep, growing by 7 every 7 turns.
- Deck legality: exactly 1 God, up to 3 Powers, at least 40 regular cards (Gods and Powers do not count). Reinforcements max is (regular cards + Powers) divided by 3, rounded down; the God cannot go there and copy limits are shared with the main deck. Up to 3 copies of a regular card, 1 copy of a specific Legendary, 1 Legendary per 10 regular cards. Powers must match the God's culture or be Neutral.
- Summons: one normal Creature summon per turn unless a card grants an extra; the normal summon spends the creature's Minor Action, and a Stealth summon also spends its Major Action. One normal Structure summon per turn (effect-summons do not count). No summoning sickness, but no creature attacks on turn 1, and a creature summoned after the first resolved attack of the turn cannot attack that turn.
- Creature actions per turn: 1 Minor (move to adjacent empty zone, change stance, pick up friendly unequipped Equipment in reach) and 1 Major (attack, steal or destroy enemy unequipped Equipment, major activated ability).
- Stances: Aggressive is the attacking stance (frontline); Defensive is face-up blocking with RES; Stealth is face-down Defensive, hidden from the opponent, and must match an attack's Speed to intercept.
- Combat: Aggressive vs Aggressive compares STR; the higher destroys the lower, its controller loses Followers equal to the difference, and a tie destroys both. Attacking a Defensive compares attacker STR to defender RES; if STR is lower, the attacker's controller loses (and the defender's controller gains) Followers equal to the difference. United Front: two eligible creatures combine STR. Apply all Follower-damage halvings, rounding down, before Guard.
- Interception: face-up Defensive intercepts regardless of Speed; any other interceptor must be at least as fast as the attack unless an ability ignores Speed. "Cannot be attacked" does not stop interception because intercepting is not attacking. Aggressive interceptors need a deeper protected target than Defensive: Frontline Aggressive covers Followers/God, Frontline Defensive covers Reserve/Followers/God, Reserve Defensive covers Followers/God, and Reserve Aggressive needs Reach. Sleeping or cannot-intercept creatures cannot intercept.
- Stack and Priority: spells, abilities, attacks, and reactive Charms go on the stack and resolve Last-In-First-Out. The opponent gets Priority after a stack action; when both pass consecutively the top resolves. Responses need Speed 2 or higher and must be equal to or faster than the action they answer.
- Card types: Power (starts face-down, pay to unlock), Spell (most go to the Graveyard after resolving; Auras stay on the field), Hex (prepared face-down trap, triggers automatically), Charm (reactive; some prepared on board, some played from hand in priority windows), Equipment (attaches to creatures; unequipped pieces sit on the board), Structure (has RES, can be attacked).
- Keywords: Void sends to the Abyss. Immortal cannot be destroyed. Sleep means no actions or intercepts. Paralyze means no move, stance change, attack, or intercept. Mute suppresses abilities; muted Powers cannot be unlocked or activated. Impact triggers entering from hand; Universal Impact entering from any zone. Prime/Shelve put a card on top/bottom of its owner's deck, staying visible only if it was already public. Mill puts top deck cards into the Graveyard. Dodge prevents attacks from lower-Speed creatures. Reach intercepts regardless of position. Incorporeal only engages or is engaged by Spirits or Mages and is immune to Sleep and Poison. Friendly means your cards including this one; Allied means your other cards. Perish triggers on any field-to-Graveyard move including sacrifice, while Destroyed triggers do not fire on sacrifice. Slain means destroyed in combat and sent to the Graveyard (see the Slain notes under Cards And Catalog).
- Subtype inheritance: Porcine counts as Animal, Raven counts as Avian/Animal/Aerial, and Knight and Archer count as Warrior.

## Core Gameplay Architecture

- `scripts/Other/game_manager.gd` (`GameManager`) is the main authoritative rules/state object: turn phases, action stack, priority, upkeep, combat, followers, mana, destruction/replacement, and game-end signals.
- `scripts/Other/MatchManager.gd` validates and executes player commands, targeting state, authoritative match flow, and UI interaction requests.
- `scripts/Other/GameState.gd` serializes/deserializes full match state. It masks opponent hands and hidden board cards for network clients and spectators.
- `scripts/Other/GameEventBroadcaster.gd` listens to authoritative signals and sends personalized `full_state` and prompt events.
- `scripts/Other/NetworkManager.gd` wraps ENet RPC, player peer IDs, spectators, command submission, match join, and game-event broadcasts.
- `scripts/Other/GameInput.gd`, `InProcessGameInput.gd`, `NetworkedGameInput.gd`, and `scripts/bots/BotGameInput.gd` are the input boundary. Every implementation submits commands to `MatchManager`; prefer this boundary instead of reaching into UI methods.
- `scripts/Other/player.gd` defines player zones: hand, deck, graveyard, abyss, god slot, 3 power slots, 5 frontline lanes, and 5 reserve lanes. Keep this path lowercase; opening it as `Player.gd` can make Godot load a duplicate global class on Windows.
- `scripts/Other/CardAction.gd` is the stack/action envelope for spells, abilities, attacks, charms, and event-style triggers.

## Cards And Catalog

- Card base data starts in `scripts/cards/card.gd` (`Card` Resource). `scripts/cards/BaseCard.gd` adds UIDs, keyword hints, cost helpers, art-path redirects, and common hooks.
- Type bases include `CreatureCard`, `SpellCard`, `HexCard`, `CharmCard`, `EquipmentCard`, `StructureCard`, `PowerCard`, `GodCard`, and `ActiveGodCard`.
- Concrete cards live under `scripts/cards/Creatures`, `Gods`, `ActiveGods`, `Powers`, `Spells`, `Hexes`, `Charms`, `Equipment`, and `Structures`.
- New concrete cards usually set all display/gameplay data in `_init()` after `super._init()`, including `card_name`, `card_type`, stats, culture, ability/flavor text, art path, and artist.
- `scripts/cards/CardCatalog.gd` has an explicit `CARD_SCRIPT_PATHS` list. When adding a card script, add it there or the deck builder/catalog will not reliably see it.
- Card art is mostly under `images/card_art/...`; Godot `.import` files are tracked. Avoid deleting import artifacts casually.
- Deck construction rules are in `docs/new-player-rules.md` and enforced in `Player.validate_deck()` and `scripts/server/DeckValidator.gd`: 1 God, up to 3 Powers, at least 40 regular cards, normal copy/legendary limits, and power/culture restrictions.
- Keep `Slain` distinct from `destroyed in combat` in card text and rules logic. `Slain` requires combat destruction and arrival in the Graveyard. Combat destruction also covers cases where the victim is sent to the Abyss, such as Asag's Class Rend. Use `Cannot be Slain` for Stone Skin and `Cannot be destroyed in combat` for protection that also covers those Abyss cases.

## Lobby, Server, And Persistence

- Shared lobby constants are in `scripts/network/LobbyProtocol.gd`. Default ports are `22345` for lobby and `12345` for match.
- Lobby/server files live in `scripts/server`: `LobbyServer.gd`, `LobbyRoom.gd`, `MatchSupervisor.gd`, `MatchSession.gd`, `HeadlessMatchHost.gd`, `HeadlessMatchServer.gd`, `PromptRouter.gd`, stores, and deployment scripts.
- Client-side lobby/match files live in `scripts/client`: `LobbyClient.gd`, `MatchClient.gd`, `AppReleaseInfo.gd`.
- Public server/update scripts target Windows and GitHub releases. Be careful with scripts under `scripts/server/lightsail` and `scripts/server/update_public_lobby.ps1`; they can stop processes, download releases, and modify server installs.
- Local player/profile persistence uses Godot `user://` JSON stores through `scripts/core/LocalProfileStore.gd` and server-side stores under `scripts/server`.

## UI Hotspots

- Main board UI is `scripts/ui/BoardZoneUI.gd`.
- Card rendering/interaction is `scripts/ui/VisualCard.gd`.
- Hover/detail text is built by `scripts/ui/CardDetailContentBuilder.gd`.
- Deck builder UI is `scripts/ui/DeckBuilderUI.gd`.
- Board/card art scaling helpers are in `scripts/ui/UIArtScaler.gd`.
- `CombatMockGame.gd` still contains many prompt panels, cursor modes, movement/attack affordances, timers, action log UI, and network match state handling. Search locally before adding another parallel mechanism.

## Verification

Do not run visual testing, launch previews for visual QA, or automate the UI to inspect appearance unless the user explicitly asks. This applies to UI and animation changes too; use relevant nonvisual checks when needed.

Prefer existing smoke runs only when they are already maintained and clearly relevant. Do not create new ad hoc Godot probe scripts for gameplay debugging unless the user explicitly asks; the user prefers to test these interactions manually because local probes have been inconsistent.

The helper script resolves `godot.exe`, sets portable Godot appdata under `.godot_portable`, and disables the MCP plugin:

```powershell
powershell.exe -ExecutionPolicy Bypass -File scripts\tmp\run_practice_smoke.ps1 -Role practice_thor
```

Useful `-Role` values include:

- `practice_thor`
- `practice_thor_summon`
- `practice_thor_intercept`
- `practice_thor_divine_lightning`
- `practice_thor_byggvir`
- `practice_thor_fuzz`
- `ranked_timeout_upkeep`
- `card_test_turn2`
- `card_test_occult_singularity`

Lobby/manual smoke:

```powershell
powershell.exe -ExecutionPolicy Bypass -File scripts\tmp\run_lobby_smoke.ps1
```

`docs/lobby-manual-smoke-test.md` notes that the automated cross-process lobby smoke has Godot editor-script RPC limitations, so a real two-window test is still the strongest proof for that flow.

CI export presets are `Windows Desktop`, `Windows Dedicated Server`, `macOS`, `iOS`, and `Android` in `export_presets.cfg`. The iOS job exports an unsigned Xcode project; the manual iPad signing flow is documented in `docs/ios-ipad-release.md`. Android APK builds and signing setup are documented in `docs/android-release.md`; without release signing secrets CI produces a separate preview app as a workflow artifact.

## Working Habits For This Repo

- Run `git status --short` before edits. The worktree is often dirty; never revert user changes unless explicitly asked.
- Prefer small, targeted edits. This project has large controller files, so avoid broad cleanups mixed with behavior changes.
- Use Godot `res://` paths in GDScript/resources.
- Preserve Godot's tab-indented GDScript style in existing files.
- Do not hand-edit `.godot/` cache files. Treat `scripts/tmp` as smoke/scratch territory and avoid adding new probe scripts or committing new logs unless the user asked for evidence artifacts.
- If touching networking, remember the server sends personalized full-state snapshots for privacy. Do not replace that with a shared snapshot unless hand privacy/hidden board privacy is handled.
- If touching prompts or priority, inspect both `GameManager` and `MatchManager`; many UI prompts are now serialized through `PromptRouter`/`GameEventBroadcaster`, but older UI paths still exist in `CombatMockGame.gd`.
- If the active player attempts a normal turn action during their own priority, including a drag-to-attack, queue the intended action and pass their priority. Resume it once the opponent passes and the stack clears, if the action is still legal. An opponent response cancels the queued action. Legal at-speed responses use the current priority window.
- If touching deck/card availability, update both catalog/deck validation paths and any relevant deck-builder UI assumptions.
