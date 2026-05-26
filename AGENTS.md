# Codex Notes For OtherGods

Read this first on a fresh thread, then inspect the files relevant to the user's request. This repo is a Godot/GDScript implementation of **Other Gods**, a mythic strategy card game with a local UI, practice bot, deck builder, multiplayer lobby, and headless match/server work in progress.

## Project Shape

- Engine target is Godot 4.6.x. The exact CI/export patch version is stored in `.godot-version` and loaded by `.github/workflows/windows-release.yml`; debug/editor runs should use the same Godot patch version as the deployed server to avoid scene RPC checksum mismatches.
- Main configured scene is `res://scenes/main_3d.tscn`, which runs `scripts/three_d/Main3D.gd`.
- `Main3D.gd` embeds `res://scenes/mainfork.tscn` into a viewport/flat 2D canvas. Server-mode launches bypass the 3D shell and load the original scene directly.
- `scripts/Other/MainMenu.gd` owns the menu, embedded game selection, deck builder entry, practice Thor mode, update prompts, smoke modes, and lobby UI flow.
- `scripts/Other/CombatMockGame.gd` is the main match UI/controller bridge. It is large and still owns a lot of presentation, prompt, and client-side interaction code.
- Rules documentation lives in `docs/new-player-rules.md`. Lobby architecture notes live in `docs/server-lobby-matchmaking-plan.md`. Manual lobby QA notes live in `docs/lobby-manual-smoke-test.md`.

## Core Gameplay Architecture

- `scripts/Other/game_manager.gd` (`GameManager`) is the main authoritative rules/state object: turn phases, action stack, priority, upkeep, combat, followers, mana, destruction/replacement, and game-end signals.
- `scripts/Other/MatchManager.gd` validates and executes player commands, targeting state, authoritative match flow, and UI interaction requests.
- `scripts/Other/GameState.gd` serializes/deserializes full match state. It masks opponent hands and hidden board cards for network clients and spectators.
- `scripts/Other/GameEventBroadcaster.gd` listens to authoritative signals and sends personalized `full_state` and prompt events.
- `scripts/Other/NetworkManager.gd` wraps ENet RPC, player peer IDs, spectators, command submission, match join, and game-event broadcasts.
- `scripts/Other/GameInput.gd`, `LocalGameInput.gd`, `NetworkedGameInput.gd`, and `scripts/bots/BotGameInput.gd` are the input boundary. Prefer submitting commands through `GameInput` instead of reaching into UI methods.
- `scripts/Other/Player.gd` defines player zones: hand, deck, graveyard, abyss, god slot, 3 power slots, 5 frontline lanes, and 5 reserve lanes.
- `scripts/Other/CardAction.gd` is the stack/action envelope for spells, abilities, attacks, charms, and event-style triggers.

## Cards And Catalog

- Card base data starts in `scripts/cards/card.gd` (`Card` Resource). `scripts/cards/BaseCard.gd` adds UIDs, keyword hints, cost helpers, art-path redirects, and common hooks.
- Type bases include `CreatureCard`, `SpellCard`, `HexCard`, `CharmCard`, `EquipmentCard`, `StructureCard`, `PowerCard`, `GodCard`, and `ActiveGodCard`.
- Concrete cards live under `scripts/cards/Creatures`, `Gods`, `ActiveGods`, `Powers`, `Spells`, `Hexes`, `Charms`, `Equipment`, and `Structures`.
- New concrete cards usually set all display/gameplay data in `_init()` after `super._init()`, including `card_name`, `card_type`, stats, culture, ability/flavor text, art path, and artist.
- `scripts/cards/CardCatalog.gd` has an explicit `CARD_SCRIPT_PATHS` list. When adding a card script, add it there or the deck builder/catalog will not reliably see it.
- Card art is mostly under `images/card_art/...`; Godot `.import` files are tracked. Avoid deleting import artifacts casually.
- Deck construction rules are in `docs/new-player-rules.md` and enforced in `Player.validate_deck()` and `scripts/server/DeckValidator.gd`: 1 God, up to 3 Powers, at least 35 regular cards, normal copy/legendary limits, and power/culture restrictions.

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

Use targeted Godot probes or smoke runs when possible. The helper script resolves `godot.exe`, sets portable Godot appdata under `.godot_portable`, and disables the MCP plugin:

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

CI export presets are `Windows Desktop`, `Windows Dedicated Server`, and `macOS` in `export_presets.cfg`.

## Working Habits For This Repo

- Run `git status --short` before edits. The worktree is often dirty; never revert user changes unless explicitly asked.
- Prefer small, targeted edits. This project has large controller files, so avoid broad cleanups mixed with behavior changes.
- Use Godot `res://` paths in GDScript/resources.
- Preserve Godot's tab-indented GDScript style in existing files.
- Do not hand-edit `.godot/` cache files. Treat `scripts/tmp` as probe/smoke territory and avoid committing new logs unless the user asked for evidence artifacts.
- If touching networking, remember the server sends personalized full-state snapshots for privacy. Do not replace that with a shared snapshot unless hand privacy/hidden board privacy is handled.
- If touching prompts or priority, inspect both `GameManager` and `MatchManager`; many UI prompts are now serialized through `PromptRouter`/`GameEventBroadcaster`, but older UI paths still exist in `CombatMockGame.gd`.
- If touching deck/card availability, update both catalog/deck validation paths and any relevant deck-builder UI assumptions.
