# Lobby Manual Smoke Test

Use this when you want to test the real menu flow in two game windows.

## Goal

Verify that:

- one instance can host a lobby room
- a second instance can join by IP and room code
- both players can ready up
- the lobby hands both players into the existing match flow

## Setup

- Run two copies of the game on the same machine.
- Keep both on the main menu.
- Use `127.0.0.1` as the IP in both windows for a local test.

## Automated Option

You can also launch the temporary auto-smoke flow with:

```powershell
powershell.exe -ExecutionPolicy Bypass -File scripts\tmp\run_lobby_smoke.ps1
```

That starts one host window and one client window, fills the lobby flow automatically,
and writes result files into `scripts/tmp/`.

## Host Window

1. Enter a player name in the multiplayer panel.
2. Click `Host Game`.
3. Confirm the status area shows a generated room code.
4. Click `Ready`.

Expected:

- The status text should show your room code.
- The room should list the host as `waiting` and then `ready`.

## Join Window

1. Enter `127.0.0.1` in the IP field.
2. Enter a second player name.
3. Click `Join Game`.
4. Enter the host room code.
5. Click `Join Room`.
6. Click `Ready`.

Expected:

- The joiner should connect without typing a gameplay port.
- The room snapshot should show both players.
- When both are ready, both windows should leave the menu and enter the game.

## Pass Criteria

- Host sees room creation and ready state.
- Joiner sees the same room membership.
- Both windows transition into `CombatMockGame`.

## Client-Hosted Bot Match Spectator Smoke

Use this for rated bot challenges hosted on a player's machine. The automated
`scripts/ci/websocket_transport_test.gd` covers the local rendezvous, but only a
real two-window/two-network test proves the public UDP path.

### Setup

- Use the public lobby, or two clients on different networks when possible.
- Two windows on one machine against the **public lobby** are a useful way to
  exercise the internet path: the spectator ignores the host's private hint and
  uses the advertised public endpoint plus punch/relay.
- A local/private lobby may prefer the host's private endpoint. When it does, it
  uses the host's real ENet listener port, which can differ from the UPnP
  external port advertised as `match_port`.
- Common subnets like `192.168.1.x` are reused in different homes, so a subnet
  match is never proof that a public-lobby host is privately reachable.
- Confirm inbound UDP `22346-22355` is open in both Lightsail and Windows Firewall.
- Confirm the server log shows `punch reflector listening on port ...`.
- Ideally disable UPnP on the host so the punch advertising path is actually
  exercised. A successful UPnP mapping no longer disables the relay: the host
  still bounces the reflector in bounce-only mode, so a relay fallback exists
  even when the advertised public endpoint looks healthy.

### Steps

1. In the host window, start a rated bot challenge from the lobby.
2. Wait for the challenge row to change from `Not watchable` to `Click to Watch`.
3. In the spectator window, open `View Bot Matches` and select that row.
4. Confirm the loading overlay resolves into the match and that `full_state` arrives.
5. Let the host or spectator reconnect once, then confirm the watch link survives.
6. Check the host, spectator, and lobby-server consoles for the shared breadcrumb
   prefix `Spectate breadcrumb`. Search that exact string in each console window;
   the `observer` and `match` fields let you line the three logs up:
   - Host: `spectate_advertising_started`, `endpoint_advertised`,
     `approval_received`, `bounce_sent`, `endpoint_submitted_via_punch`,
     `punch_advertising_upgraded`, `punch_result`
   - Lobby: `host_endpoint_recorded`, `observe_requested`, `host_approval_requested`,
     `assignment_sent`, `relay_session_armed`, `punch_ready_received`,
     `spectator_endpoint_resolved`, `host_punch_relayed`,
     `relay_sessions_disabled`
   - Spectator: `assignment_received`, `private_endpoint_ignored` or
     `private_endpoint_preferred`, `rendezvous_armed`, `bounce_sent`,
     `punch_ready_reported`, `prime_finished`, `dial_endpoint_selected`,
     `enet_dial_started`, `relay_fallback_dial`, `enet_connected`,
     `join_request_sent`, `join_approved`
   - Every breadcrumb now carries `t=<monotonic_ms>`, so the host, spectator,
     and lobby lines can be ordered even when the consoles are not side by side.
   - `assignment_received` shows `public`, `lan`, and `selected` as `ip:port`
     pairs, plus `relay_enabled` and `via_relay`. On a public lobby, `selected`
     must equal `public` and you should see `private_endpoint_ignored`.
     `private_endpoint_missing_port` only applies to local/private lobbies and
     means the lobby server was not rebuilt with the lan-port fix.
   - A public-lobby host should log `relay=true` on `endpoint_advertised` and
     `relay_session_armed` should appear on the lobby even when UPnP succeeded.
     If UPnP later fails, `punch_advertising_upgraded` shows the bounce-only loop
     switching to advertising the reflector-learned endpoint.
   - Spectating is direct-first. With a working UPnP endpoint the spectator
     dials `public` immediately (`dial_endpoint_selected` has
     `via_relay=false`), and only a failed direct dial produces
     `relay_fallback_dial` with the reflector endpoint. A punch-assigned
     spectator instead primes first and may report `prime_finished
     via_relay=true` straight away.
   - Either way, `Spectate breadcrumb role=reflector stage=relay_ready ...`
     should appear on the lobby, followed by normal ENet/join breadcrumbs on
     both ends.
   - When the match ends, expires, or its room closes, the lobby logs
     `relay_sessions_disabled` for that `match` instead of waiting for the
     reflector TTL.
   - Legacy single-line checks still present: `Spectator rendezvous: ...`,
     `Spectator punch observer=...: punching ...`, and
     `Spectator punch observer=...: skipped: ...` on the host.

### Pass Criteria

- The host advertises a watchable endpoint without UPnP.
- The host keeps a relay fallback armed even when UPnP succeeds.
- The spectator authenticates, receives `full_state`, and sees the correct hand visibility.
- A working direct endpoint is used directly; a dead one retries through the
  lobby relay and still authenticates.
- Reconnect keeps the same punched local port and either the original direct
  endpoint or the lobby relay endpoint.
- No `not accepting spectators right now` error appears while the host match is live.

## Current Known Risk

- The automated cross-process smoke harness still runs into Godot editor-script RPC scene-tree limitations.
- That means the best proof right now is a real two-window menu test, not the editor-script harness.
- Hole punching remains best-effort; symmetric NAT/CGNAT now falls back to the
  public UDP relay on the lobby reflector, which adds bandwidth and latency.
