# Gmail TLS trust roots

`google_roots.pem` is the public Google Trust Services CA bundle downloaded from
<https://pki.goog/roots.pem> on 2026-10-14. It contains no private keys or account
credentials. The issuing authority publishes certificate information at
<https://pki.goog/repository/>.

Downloaded bundle SHA-256:
`ec989df46c8f4419ef2ee2517cad7619d555e4973f3307be697662aa2497e480`.

Gmail SMTP uses this bundle explicitly with `TLSOptions.client`, retaining
certificate-chain, validity-date, and `smtp.gmail.com` hostname verification.
This avoids depending on Windows Server's sometimes incomplete system root
store. Godot 4.7 uses the system roots instead of its builtin roots whenever
the system returns any certificates.

Refresh this file from the official HTTPS endpoint when Google changes its
trust roots, and run the Gmail regression/TLS checks. All export presets include
`certificates/*.pem`, because PEM files are read directly through FileAccess.
Do not replace this bundle with a certificate captured from a failed handshake,
and do not disable verification to resolve TLS failures.
