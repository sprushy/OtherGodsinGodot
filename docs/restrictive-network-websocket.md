# Restrictive network connections

The client supports verified TLS WebSockets on public TCP 443 for both the
lobby and dedicated matches. UDP remains available for existing clients.
The local WebSocket backends bind only to 127.0.0.1; Caddy terminates TLS and
routes /lobby to TCP 24443 and /match/<port> to each dedicated match process.
Match tokens and personalized state snapshots use the same authority checks
on both transports. Player-hosted UDP matches are disabled when the public
WebSocket endpoint is configured.

## Automatic setup through GitHub releases

The Windows server release ZIP includes `start_server.ps1`, `update_server.ps1`,
`Initialize-WebSocketProxy.ps1`, and WebSocket defaults generated from the
client's `config/public_websocket_url` setting. The current public endpoint is
`wss://othergods-server.duckdns.org`.

The existing Lightsail updater extracts these files into `C:\OtherGodsServer`
and calls the updated launcher. On its first run, the launcher installs the
missing `Caddyfile` and `network.json` from `websocket-defaults`, validates the
configuration using the already-downloaded `caddy.exe`, adds the Windows
Firewall rule for TCP 80/443, and installs/starts the automatic `OtherGodsCaddy`
service. The downloaded filename `caddy_windows_amd64.exe` is also accepted.
Later updates preserve the installed configuration files. A watchdog run
retries setup if Caddy was missing or setup failed, and starts a stopped proxy.
Setup failures are recorded in `C:\OtherGodsServer\updater.log`; they do not
prevent the UDP lobby from starting.

The scheduled updater/watchdog runs as SYSTEM with administrator privileges.
For a manual startup, use Administrator PowerShell. The updater cannot change
the AWS-side firewall: allow inbound TCP 80 and 443 in the Lightsail instance's
Networking tab. DNS must point to the server's public IP for certificates to
be provisioned. No manual transfer of the configuration files is required.

Changes on a GitHub branch alone do not reach the server: the release workflow
must publish a new tagged `OtherGodsServer-windows.zip` asset for the existing
updater to download it. A new client release is also needed to distribute the
configured secure endpoint and failed-connection crash fix.

To check the packaging and install behavior without touching a live server:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/ci/server_runtime_package_test.ps1
```

The test covers the old updater's archive extraction, first-install defaults,
configuration preservation on a second update, and a non-mutating proxy setup
preview. It does not install a real Windows service or request certificates.
Pass `-CaddyExe <path-to-caddy.exe>` to also check real Caddy validation,
idempotent service setup, and recovery of a stopped proxy using mocked Windows
firewall/service commands.

## Manual server setup

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

## Free address and HTTPS on the existing Windows Lightsail server

[DuckDNS](https://www.duckdns.org/) provides free subdomains. Caddy is
[free software](https://caddyserver.com/docs/install) and
[obtains and renews public TLS certificates automatically](https://caddyserver.com/docs/automatic-https).
This setup adds no domain or certificate subscription to the existing server.
It does not require an AWS load balancer.

1. Sign into DuckDNS and register an available subdomain. The commands below
   use `your-name.duckdns.org` as a placeholder; replace it throughout.
   Set its IPv4 address to the game server's public IP (currently
   `63.33.96.156`), rather than the laptop's IP. Leave IPv6 empty unless the
   server has working public IPv6 and matching firewall rules. Keep this DNS
   record updated if the server IP changes. An attached Lightsail static IP
   has [no separate static-IP fee](https://docs.aws.amazon.com/lightsail/latest/userguide/amazon-lightsail-frequently-asked-questions-faq-billing-and-account-management.html).

2. In the Lightsail instance's Networking tab, allow inbound HTTP TCP 80 and
   HTTPS TCP 443 from any IPv4 address. These are the public proxy ports.
   See the [Lightsail firewall instructions](https://docs.aws.amazon.com/lightsail/latest/userguide/understanding-firewall-and-port-mappings-in-amazon-lightsail.html).

3. On the Windows server, download the Windows amd64 Caddy binary from its
   [official download page](https://caddyserver.com/download), and save it as
   `C:\OtherGodsServer\caddy.exe`. Copy the repository's
   `scripts/server/lightsail/New-WebSocketProxyConfig.ps1` and updated
   `start_server.ps1` into `C:\OtherGodsServer`. The server build must also
   include WebSocket support. In an Administrator PowerShell window, run:

   ```powershell
   New-NetFirewallRule -DisplayName 'Other Gods HTTPS proxy' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 80,443 -Program 'C:\OtherGodsServer\caddy.exe'
   Set-Location C:\OtherGodsServer
   powershell.exe -ExecutionPolicy Bypass -File .\New-WebSocketProxyConfig.ps1 -Domain your-name.duckdns.org
   .\caddy.exe validate --config C:\OtherGodsServer\Caddyfile --adapter caddyfile
   ```

   The generator creates the proxy routes and `network.json`. If those files
   already exist, generate into another directory using `-OutputDirectory`
   and review them before replacing the installed configuration.

4. Install Caddy as an automatically-starting Windows service, following
   [Caddy's service instructions](https://caddyserver.com/docs/running#windows-service):

   ```powershell
   sc.exe create OtherGodsCaddy start= auto binPath= "C:\OtherGodsServer\caddy.exe run --config C:\OtherGodsServer\Caddyfile --adapter caddyfile"
   sc.exe start OtherGodsCaddy
   ```

   DNS must resolve to the server and both public ports must be reachable for
   certificate provisioning. Caddy must remain running to serve HTTPS and
   renew certificates. If that service name already exists, inspect its
   configuration instead of creating a duplicate service.

5. When no matches are active, launch the updated game server through
   `start_server.ps1`. With `network.json` present it requires the local
   WebSocket listener and restarts an existing UDP-only process. It propagates
   the public WebSocket origin into dedicated match assignments. Keep the
   backend ports loopback-only; only the proxy needs public TCP access.

6. From another machine, verify the certificate and proxy:

   ```powershell
   curl.exe --fail --max-time 10 https://your-name.duckdns.org/healthz
   ```

   Expect `Other Gods TLS proxy`. Also run the WebSocket upgrade check below
   with the chosen hostname; a healthy proxy alone does not prove the lobby
   backend is running.

7. Set `config/public_websocket_url="wss://your-name.duckdns.org"` in the
   `[application]` section of `project.godot`, then export the updated client.
   To try it before a new export, use
   `wss://your-name.duckdns.org/lobby` in the game's server address field.
   Test sign-in and joining a match from eduroam; its local network policy
   still determines whether the connection is allowed.

## Client configuration

Set application/config/public_websocket_url in project.godot to the origin,
for example wss://game.example.com, before exporting the client. Keep
default_lobby_host as the UDP address for compatibility. Both the client and
server also accept OTHERGODS_PUBLIC_WEBSOCKET_URL as an environment override.
The configured URL takes priority, with verified certificates; certificate
errors do not disable verification.

Automatic WebSocket fallback requires that configured endpoint. The client
does not assume the UDP address also hosts a TLS WebSocket service. Without
an endpoint, a failed UDP connection reports the missing configuration;
adding WebSocket support to the client alone does not enable TCP 443 on the
server.

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
