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

## Current Known Risk

- The automated cross-process smoke harness still runs into Godot editor-script RPC scene-tree limitations.
- That means the best proof right now is a real two-window menu test, not the editor-script harness.
