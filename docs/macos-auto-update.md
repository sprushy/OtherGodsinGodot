# macOS Auto-Update

macOS release builds use Sparkle 2 through the `MacSparkleBridge` GDExtension.
The bridge starts Sparkle when a release build opens and explicitly presents
Sparkle when the shared GitHub release check finds a newer version.

## Release Requirements

Tagged macOS releases require these GitHub Actions secrets:

- `MACOS_CERTIFICATE_P12_BASE64`
- `MACOS_CERTIFICATE_PASSWORD`
- `APPLE_ID`
- `APPLE_APP_PASSWORD`
- `APPLE_TEAM_ID`
- `SPARKLE_PUBLIC_ED_KEY`
- `SPARKLE_PRIVATE_ED_KEY`

The public and private Sparkle values must be from the same Ed25519 key pair.
`SPARKLE_PRIVATE_ED_KEY` contains the private key file contents accepted by
Sparkle's `sign_update --ed-key-file` option. Keep this value secret and retain
a secure backup outside GitHub.

The release workflow:

1. Builds a universal Intel/Apple Silicon GDExtension.
2. Embeds `Sparkle.framework` and the public update key.
3. Signs and notarizes the complete app.
4. Signs `OtherGods-macos.zip` with the Sparkle private key.
5. Publishes the archive and `appcast.xml` as GitHub release assets.

The app reads its feed from:

`https://github.com/sprushy/OtherGodsinGodot/releases/latest/download/appcast.xml`

## Bootstrap Limitation

Clients released before Sparkle was embedded cannot install the first
Sparkle-enabled build automatically. Those users must install that build once
from the GitHub release page. Later releases can update themselves.
