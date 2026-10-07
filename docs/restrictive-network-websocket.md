# Restrictive network connections

The client supports verified TLS WebSockets on public TCP 443 for both the
lobby and dedicated matches. UDP remains available for existing clients.
The local WebSocket backends bind only to 127.0.0.1; Caddy terminates TLS and
routes /lobby to TCP 24443 and /match/<port> to each dedicated match process.
Match tokens and personalized state snapshots use the same authority checks
on both transports. Player-hosted UDP matches are disabled when the public
WebSocket endpoint is configured.

## Server setup

1. Point a domain's A record at the server. Add AAAA only if IPv6 is reachable.
2. Install Caddy using its [official instructions](https://caddyserver.com/docs/install).
3. Generate the configuration on the server, replacing game.example.com:

   ```powershell
   .\New-WebSocketProxyConfig.ps1 -Domain game.example.com
   caddy validate --config C:\OtherGodsServer\Caddyfile --adapter caddyfile
   ```

4. Allow inbound TCP 80 and 443 in Lightsail and Windows Firewall. Caddy uses
   these for HTTPS and certificate provisioning. The internal TCP 24443 and
   12345-12408 listeners stay loopback-only and need no public firewall rules.
   Keep existing UDP rules if UDP clients will still be supported.
5. Run Caddy as a service, following its
   [service documentation](https://caddyserver.com/docs/running).
6. Deploy the updated game server and restart it through start_server.ps1.
   It reads network.json and propagates the public URL into match assignments.
   Its health check requires both the UDP and WebSocket lobby listeners when
   network.json enables the public endpoint.

The default match pool has 64 ports, 12345-12408. If changing MatchPort or
LobbyWebSocketPort, regenerate the proxy and network.json together. Generation
refuses to overwrite existing files; use another output directory to review
updated configurations. /healthz confirms the TLS proxy is reachable; it does
not certify that the lobby or a match process is healthy.

## Client configuration

Set application/config/public_websocket_url in project.godot to the origin,
for example wss://game.example.com, before exporting the client. Keep
default_lobby_host as the UDP address for compatibility. Both the client and
server also accept OTHERGODS_PUBLIC_WEBSOCKET_URL as an environment override.
The configured URL takes priority, with verified certificates; certificate
errors do not disable verification.

For testing without a new export, enter wss://game.example.com/lobby into the
existing server address field. OTHERGODS_LOBBY_TRANSPORT=ws forces WebSocket.
Explicit ws:// URLs are available for local tests. An old server that does
not advertise match_websocket_url cannot provide match WebSocket fallback.

When the lobby connects over WebSocket, the assigned match starts over
WebSocket as well. If a UDP match times out, its existing retry path switches
to the advertised WebSocket endpoint. Reconnects retain that endpoint.
Password authentication is allowed on verified WSS independently of the
legacy allow_insecure_account_auth flag. After confirming WSS deployment,
that flag can be disabled on client and server for password authentication.

## Verification

```powershell
curl.exe -I https://game.example.com/healthz
curl.exe --http1.1 -i --max-time 5 `
  -H 'Connection: Upgrade' -H 'Upgrade: websocket' `
  -H 'Sec-WebSocket-Version: 13' `
  -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' `
  https://game.example.com/lobby
```

The upgrade request should return 101 Switching Protocols before curl times
out on the open connection. Then test sign-in, a mixed UDP/WebSocket match,
spectating, and reconnecting on both mobile data and the restricted network.
A timeout before TCP connects still requires a listener/firewall/routing check.

The maintained local transport test runs with:

```powershell
godot_console.exe --headless --path . --script scripts/ci/websocket_transport_test.gd
```
