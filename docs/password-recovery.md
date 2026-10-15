# Account password recovery

The login screen has a **Forgot password?** button. Enter the account email,
choose **Email recovery code**, and enter the emailed 6-digit code into the dialog.
Enter and confirm a new password, then choose **Reset password** and sign in.
The email goes only to the email stored on the account. Recovery emails are
transactional and do not depend on the optional game-update email preference.
Username-only legacy accounts must first be claimed with an email while the
player still knows their password. Duplicate legacy email records must be
repaired before email recovery can identify a single account.

## Gmail setup (no domain required)

The lobby supports a Gmail sender through authenticated SMTP with verified TLS.
It connects only to `smtp.gmail.com:465`; it does not use the normal Google
account password or bypass certificate verification.

Gmail TLS explicitly uses `certificates/google_roots.pem`, Google's published
trust-root bundle. This is included in each export. Godot 4.7 otherwise prefers
the Windows system root store over its builtin roots, and a sparse Windows Server
root store can fail Gmail verification with `-0x2700` / `-9984`. These errors occur
before Google authenticates the app password. Also verify the server UTC clock
with `[DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')` when troubleshooting TLS.

1. Sign into `OtherGodsGame@gmail.com`. Change any account password that has
   been shared publicly or in a chat.
2. Enable 2-Step Verification in [Google Account Security](https://myaccount.google.com/security).
3. Open [Google App Passwords](https://myaccount.google.com/apppasswords), create
   one named **Other Gods Server**, and save it on the server. Google requires
   2-Step Verification and may block app passwords for security-key-only accounts,
   organization-managed accounts, or Advanced Protection. See
   [Google's app password instructions](https://support.google.com/accounts/answer/185833).
   If unavailable, do not use the normal password instead; OAuth support would
   need to be added separately.
4. Publish and install a client/server release containing this change. The server
   ZIP includes `Set-RecoveryEmail.ps1`; the existing Lightsail updater extracts
   it into `C:\OtherGodsServer` automatically. On that server, open **Administrator
   PowerShell** and run this once:

   ```powershell
   & 'C:\OtherGodsServer\Set-RecoveryEmail.ps1' -Address 'OtherGodsGame@gmail.com'
   ```

   Paste the app password at the hidden prompt. The helper stores these Windows
   System variables locally, outside Git and the public release archive:

   | Name | Value |
   |---|---|
   | `OTHERGODS_GMAIL_ADDRESS` | `OtherGodsGame@gmail.com` |
   | `OTHERGODS_GMAIL_APP_PASSWORD` | The generated 16-character app password |

   Spaces in Google's displayed app password are removed automatically. The
   Lightsail startup/updater/watchdog tasks run as SYSTEM, so User variables in
   the RDP account are insufficient. Keep credentials out of Git, project
   settings, exported clients, release archives, and logs.
5. Allow outbound TCP 465 to `smtp.gmail.com`. The next lobby restart or update
   loads the saved settings directly from Windows System variables, without a
   Windows reboot. Running setup does not stop an active lobby or match. If the
   lobby is already running, its existing environment is unchanged until its
   next restart. Credentials remain saved across later updates; repeat setup
   only when changing the Gmail address or app password. You can also configure
   the same variables manually through Windows Environment Variables.
6. Test recovery using an account whose inbox you control, as described below.

[Personal Gmail sending limits](https://support.google.com/mail/answer/22839)
apply. Google can reject mail when limits are reached or abuse is suspected.
Changing the Google account password revokes its app passwords; generate and
configure a replacement afterward.

## Optional Resend setup

If no Gmail variables are set, delivery uses
[Resend's send-email API](https://resend.com/docs/api-reference/emails/send-email).
Configure `OTHERGODS_RESEND_API_KEY` and `OTHERGODS_RECOVERY_EMAIL_FROM` in the
server's System environment, using a sending API key and an address on a verified
domain you control. Outbound HTTPS to `api.resend.com:443` is required. Setting
either Gmail variable selects Gmail and requires both Gmail values to be valid;
it does not silently fall back to a different sender.

Public recovery requires the verified WSS lobby endpoint described in
[restrictive-network-websocket.md](restrictive-network-websocket.md). Recovery
does not honor the legacy insecure-password-auth override. Loopback ENet is
supported for local tests.

If delivery is not configured, the dialog reports that email recovery is
unavailable. Once configured, requests give the same acknowledgement for known
and unknown emails, cooldowns, and delivery failures to protect account privacy.
Provider acceptance is not a guarantee of inbox delivery. Check the spam folder,
Google account security notices, or Resend's dashboard when investigating delivery
problems. Server warnings contain transport/HTTP/SMTP status codes only, never
provider response bodies, recipient addresses, passwords, or recovery codes.

## Security and checks

Codes contain six decimal digits generated using Godot's cryptographic random
generator, including leading zeros, and expire in 15 minutes. They are stored
only as SHA-256 hashes in `accounts.json`. Five incorrect attempts invalidate a
code; the attempt budget is persisted across lobby restarts. A new code replaces
the previous one and starts a fresh attempt budget. Accounts allow one email request per minute; the lobby
also allows at most 30 recovery requests/attempts per minute across connections,
and at most four email requests in flight. Failed delivery invalidates that code.
Pending codes survive lobby restarts and are invalidated by an email/password
change. Successful reset saves the existing account with the normal PBKDF2
password scheme and consumes the code in the same storage write. Failed saves
restore the previous state. Public account payloads exclude recovery credentials.

A successful reset invalidates lobby reconnect tokens and removes command access
for that account's old lobby peers. Existing dedicated-match connections have
their own session lifecycle and are not terminated by password recovery.

Nonvisual regression checks (uses isolated temporary account storage and a fake
mailer; does not send email or change real accounts):

```powershell
. scripts\tmp\GodotPortableEnv.ps1
$recoveryGodot = Resolve-GodotExecutable -PreferConsole
$null = Set-GodotPortableEnvironment -ProjectRoot (Get-GodotProjectRoot)
& $recoveryGodot --headless --path . --script scripts/tests/account_password_recovery_test.gd
& $recoveryGodot --headless --path . --script scripts/tests/gmail_recovery_delivery_test.gd
```

Optional real Gmail TLS handshake check (does not authenticate or send email):

```powershell
& $recoveryGodot --headless --path . --script scripts/tests/gmail_recovery_delivery_test.gd -- --gmail-tls-check
```

For manual delivery QA, use a test account you own: request a code, confirm its
arrival, reset the password, check that the old password and consumed code fail,
and sign in with the new password. Also check expiry, requesting another code
after a minute, and rejection of the previous code. Delivery QA requires a
configured provider and a deployed client/server pair containing this change.
