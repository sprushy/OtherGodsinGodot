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
- Also test two windows on one machine and two machines on the same LAN; those
  should use the private endpoint automatically instead of hairpinning the
  public reflection endpoint.
- Confirm inbound UDP `22346-22355` is open in both Lightsail and Windows Firewall.
- Confirm the server log shows `punch reflector listening on port ...`.
- Ideally disable UPnP on the host so the punch fallback is actually exercised.

### Steps

1. In the host window, start a rated bot challenge from the lobby.
2. Wait for the challenge row to change from `Not watchable` to `Click to Watch`.
3. In the spectator window, open `View Bot Matches` and select that row.
4. Confirm the loading overlay resolves into the match and that `full_state` arrives.
5. Let the host or spectator reconnect once, then confirm the watch link survives.
6. Check the host and spectator traces for the rendezvous sequence:
   - `punch bounce kind=host ...`
   - `relay spectator punch target for match ...`
   - `punch bounce kind=client ...`
   - `spectator punch begin ...`
   - `Spectator rendezvous: host reply=true, remapped port=...`
   - `Spectator punch observer=...: punching ...` on the host
   - `Spectator punch observer=...: skipped: ...` if the host rejected the relay
   - `punch local port bind failed ...` or `punch local port remapped ...` if the primed spectator port was not reusable.

### Pass Criteria

- The host advertises a watchable endpoint without UPnP.
- The spectator authenticates, receives `full_state`, and sees the correct hand visibility.
- Reconnect keeps the same punched local port and original host endpoint.
- No `not accepting spectators right now` error appears while the host match is live.

## Current Known Risk

- The automated cross-process smoke harness still runs into Godot editor-script RPC scene-tree limitations.
- That means the best proof right now is a real two-window menu test, not the editor-script harness.
- Hole punching remains best-effort; symmetric NAT/CGNAT needs a relay fallback, which is not implemented yet.
