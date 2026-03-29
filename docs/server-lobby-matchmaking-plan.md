# Server Lobby And Matchmaking Plan

## Goal

Turn this project from a direct-connect two-player game into a server-based system
where one machine hosts:

- a persistent lobby server
- one or more authoritative match servers
- reconnect-safe player sessions
- room-based matchmaking

This document is intentionally tied to the current codebase so we can build it in
small slices without breaking the local game.

## Current State

The project already has the beginnings of a server-authoritative match model:

- `scripts/Other/NetworkManager.gd` accepts ENet connections and routes RPC calls.
- `scripts/Other/MatchManager.gd` validates and executes gameplay commands.
- `scripts/Other/GameEventBroadcaster.gd` serializes authoritative state back to clients.
- `scripts/Other/GameState.gd` already provides full-state sync.
- `scripts/Other/CombatMockGame.gd` currently mixes three concerns:
  - match authority
  - client presentation
  - interactive prompt handling

The main architectural task is to separate "server match authority" from
"client UI scene."

## Target Runtime Topology

### Process layout

This PC runs:

- `LobbyServer` on a fixed public port
- `MatchSupervisor` inside the lobby process
- one `HeadlessMatchHost` per live match

Recommended first deployment:

- one lobby process
- one match at a time
- fixed match port range, for example `12345` to `12365`

Recommended later deployment:

- one lobby process
- multiple concurrent headless match processes
- automatic port allocation

### Client flow

1. Client connects to the lobby server.
2. Client creates or joins a room.
3. Room tracks deck choice, readiness, and membership.
4. When the room is ready, lobby assigns a match endpoint.
5. Both clients connect to the match server.
6. Match server runs all rules authoritatively.
7. Client only renders state and sends player intent.

## Repository Layout To Add

Create these folders over time:

- `docs/`
- `scripts/network/`
- `scripts/server/`
- `scripts/client/`
- `scenes/server/`
- `scenes/ui/lobby/`

## New Files And Responsibilities

### Shared networking layer

`scripts/network/NetMessage.gd`

- Defines normalized message envelopes.
- Fields:
  - `type`
  - `request_id`
  - `session_id`
  - `payload`
  - `version`

`scripts/network/LobbyProtocol.gd`

- Central constants for lobby message names.
- Validates required keys for each lobby message.

`scripts/network/MatchProtocol.gd`

- Central constants for match message names.
- Keeps gameplay transport separate from lobby transport.

`scripts/network/SessionRegistry.gd`

- Maps session IDs to connected peers.
- Stores reconnect tokens and expiration times.

`scripts/network/PortAllocator.gd`

- Hands out free match ports from a configured range.
- Reclaims ports when matches end.

### Lobby server

`scripts/server/LobbyServer.gd`

- Always-on ENet server for menu and matchmaking traffic.
- Owns room registry, session registry, and match supervisor.
- Handles:
  - guest login
  - room list
  - create room
  - join room
  - leave room
  - ready state
  - deck selection metadata
  - reconnect to room

`scripts/server/LobbyRoom.gd`

- In-memory room model.
- Tracks:
  - room ID
  - host session
  - members
  - selected decks
  - ready states
  - room status
  - assigned match ID

`scripts/server/MatchSupervisor.gd`

- Starts and stops match hosts.
- For phase 1 it can instantiate match hosts in the same process.
- For phase 2 it can spawn separate headless Godot processes.

`scripts/server/ServerPersistence.gd`

- Lightweight persistence layer.
- Start with JSON.
- Upgrade later to SQLite if needed.
- Stores:
  - reconnect tokens
  - room metadata
  - optional deck loadouts
  - match results

### Match authority

`scripts/server/HeadlessMatchHost.gd`

- The new authoritative server wrapper around the current game rules.
- Owns:
  - `GameManager`
  - `MatchManager`
  - `GameEventBroadcaster`
  - match-scoped `NetworkManager` or match transport
- Does not render any UI.
- Emits data-only prompt events to clients.

`scripts/server/MatchSession.gd`

- Match metadata and lifecycle state.
- Tracks:
  - match ID
  - port
  - player sessions
  - reconnect deadline
  - match status

`scripts/server/PromptRouter.gd`

- Replaces direct server-side UI branching.
- Converts server prompt needs into serializable prompt messages.
- Examples:
  - combat retreat
  - resurrection choice
  - doorway choice
  - priority response

### Client side

`scripts/client/LobbyClient.gd`

- Connects to the lobby server.
- Sends lobby messages and receives room snapshots.

`scripts/client/MatchClient.gd`

- Connects to a `HeadlessMatchHost`.
- Sends gameplay actions.
- Receives:
  - full state
  - prompt events
  - match results

`scripts/client/ClientSession.gd`

- Stores local session ID, reconnect token, selected deck, current room, and current match.

### UI

`scenes/ui/lobby/LobbyMenu.tscn`

- Replaces the current direct-connect-only join flow.

`scripts/ui/LobbyMenu.gd`

- Menu controller for:
  - create room
  - join room
  - room code display
  - ready button
  - start match state

`scenes/server/LobbyServer.tscn`

- Boot scene for the persistent server.

`scenes/server/HeadlessMatchHost.tscn`

- Boot scene for a single headless match host.

## What To Extract From CombatMockGame

The current `CombatMockGame.gd` should stop being the implicit match authority.

### Keep in CombatMockGame

- board rendering
- drag and drop
- hover, prompts, overlays, action log UI
- translating local clicks into gameplay commands
- applying state received from the server

### Move out of CombatMockGame

- match startup and player assignment
- server-only peer registration
- server-only full-state broadcast wiring
- server-only prompt routing
- any logic that assumes the authority also owns the visible UI

### Replace with interfaces

Introduce these seams:

- `IGameTransport`
  - send gameplay command
  - receive full state
  - receive prompt
- `IInteractionRouter`
  - server side: serialize prompt requests
  - client side: render prompt UI and submit answer
- `IMatchBootstrap`
  - local game bootstrap
  - direct-connect bootstrap
  - lobby-assigned match bootstrap

## Protocol Design

### Lobby messages

Client to server:

- `hello`
- `login_guest`
- `create_room`
- `list_rooms`
- `join_room`
- `leave_room`
- `set_ready`
- `select_deck`
- `request_reconnect_lobby`

Server to client:

- `hello_ok`
- `room_list`
- `room_snapshot`
- `room_error`
- `match_assigned`
- `lobby_reconnect_ok`

### Match messages

Client to server:

- `hello_match`
- `submit_action`
- `submit_prompt_response`
- `request_reconnect_match`
- `heartbeat`

Server to client:

- `match_join_ok`
- `full_state`
- `ui_prompt`
- `upkeep_needed`
- `turn_started`
- `game_ended`
- `peer_left`
- `match_reconnect_ok`

## Match Lifecycle

### Room phase

- players connect to lobby
- players join room
- server validates version and deck selection
- room moves to `READY` when both are ready

### Match start phase

- supervisor allocates a match ID and port
- headless match host is created
- players receive `match_assigned`
- room becomes `IN_MATCH`

### Match phase

- each client joins match endpoint with a reconnect token
- host assigns player indices
- authoritative state is broadcast
- all gameplay commands route through `MatchManager.process_command()`

### Disconnect phase

- disconnected player gets a grace window
- match remains paused or forfeit-timed depending on rules
- reconnect restores same player index and hidden-hand perspective

## Rollout Plan

### Phase 1: Stabilize match authority boundary

Deliverables:

- extract a `HeadlessMatchHost` wrapper around current authoritative logic
- make prompt delivery data-driven
- keep existing direct-connect flow working

Acceptance criteria:

- local game still works
- direct host/join still works
- match logic can run without menu scene ownership

### Phase 2: Add lobby transport and room model

Deliverables:

- `LobbyServer`
- `LobbyRoom`
- `LobbyClient`
- create/join/ready room flow

Acceptance criteria:

- two clients can meet in a room
- room state survives reconnects during lobby phase

### Phase 3: Launch match from lobby

Deliverables:

- `MatchSupervisor`
- lobby-to-match handoff
- `MatchClient`

Acceptance criteria:

- room becomes active match
- both players land in same authoritative match
- game starts without direct IP entry

### Phase 4: Reconnect and persistence

Deliverables:

- reconnect tokens
- `ServerPersistence`
- player session recovery

Acceptance criteria:

- brief disconnect does not kill the match
- players can rejoin the same match seat

### Phase 5: Multi-match hosting

Deliverables:

- port allocator
- concurrent match sessions
- cleanup for dead matches

Acceptance criteria:

- one lobby can host multiple matches at once
- one match crashing does not destroy the lobby

## First Concrete Implementation Slice

Build these first, in this exact order:

1. `scripts/server/HeadlessMatchHost.gd`
2. `scripts/server/PromptRouter.gd`
3. `scripts/client/MatchClient.gd`
4. Refactor `CombatMockGame.gd` to use `MatchClient` instead of owning authority
5. Keep current direct host/join working through the new boundary

This gives the project a stable server/client split before adding lobby features.

## Risks

### Biggest technical risk

Some prompts currently assume the authoritative game can directly show UI.
Those must become serialized prompt requests and prompt responses.

### Biggest product risk

Trying to add public lobby, reconnects, and multi-match concurrency before
extracting `HeadlessMatchHost` will likely create a brittle system.

### Deployment risk

If players are outside the local network, this PC will need:

- a public IP or DNS name
- forwarded ports
- Windows firewall rules
- a stable process that stays running

## Recommended Next Task

Implement Phase 1 only:

- create `HeadlessMatchHost`
- create `PromptRouter`
- adapt the current direct-connect flow to run through those new abstractions

That is the smallest slice that unlocks the full lobby architecture without
forcing a full rewrite all at once.
