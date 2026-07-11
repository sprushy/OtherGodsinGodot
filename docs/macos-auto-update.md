# macOS Auto-Update

macOS release builds can use Sparkle 2 through the `MacSparkleBridge`
GDExtension. When Sparkle is bundled, the bridge starts Sparkle when a release
build opens and explicitly presents Sparkle when the shared GitHub release check
finds a newer version.

## Optional Release Secrets

Tagged macOS releases can publish `OtherGods-macos.zip` without signing or
Sparkle secrets. Configure these GitHub Actions secrets to notarize the app and
enable Sparkle auto-updates:

- `MACOS_CERTIFICATE_P12_BASE64`
- `MACOS_CERTIFICATE_PASSWORD`
- `APPLE_ID`
- `APPLE_APP_PASSWORD`
- `APPLE_TEAM_ID`
- `SPARKLE_PUBLIC_ED_KEY`
- `SPARKLE_PRIVATE_ED_KEY`

The public and private Sparkle values must be from the same Ed25519 key pair.
`SPARKLE_PUBLIC_ED_KEY` and `SPARKLE_PRIVATE_ED_KEY` must come from the same
Ed25519 key pair. `SPARKLE_PRIVATE_ED_KEY` contains the private key file
contents accepted by Sparkle's `sign_update --ed-key-file` option. Keep this
value secret and retain a secure backup outside GitHub.

When Sparkle secrets and bridge build tooling are available, the release
workflow:

1. Downloads Sparkle and builds a universal Intel/Apple Silicon `MacSparkleBridge` GDExtension into `addons/macos_sparkle/bin/`.
2. Embeds `Sparkle.framework` and the public update key.
3. Signs and notarizes the complete app.
4. Packages `OtherGods-macos.zip`, generates `appcast.xml` plus any Sparkle delta assets, and signs them with the Sparkle private key.
5. Publishes the archive, `appcast.xml`, and generated Sparkle assets as GitHub release assets.

Tagged releases always include `OtherGods-macos.zip`. Sparkle-enabled releases
also include `appcast.xml`; otherwise the workflow still publishes the macOS zip
and the app falls back to opening the release page for manual updates.

The app reads its feed from:

`https://github.com/sprushy/OtherGodsinGodot/releases/latest/download/appcast.xml`

The compiled macOS bridge binary is intentionally not checked into git.
Sparkle-enabled releases rebuild it in CI so exported apps always ship with a
matching `libmacos_sparkle.macos.universal.dylib`.

## Bootstrap Limitation

Clients released before Sparkle was embedded cannot install the first
Sparkle-enabled build automatically. Those users must install that build once
from the GitHub release page. Later releases can update themselves.
