# Security policy

## Supported versions

Only the latest release receives fixes. Updating is safe: settings and practice history are kept.

## Reporting a vulnerability

Please report security problems privately through GitHub's
[private vulnerability reporting](https://github.com/lobojoel2003/Speakagain/security/advisories/new),
not in a public issue. Include the Speakagain version (Settings › About Speakagain), the device
and system version, and steps to reproduce. You should get a reply within a week.

## What Speakagain does to stay safe

- **No network by default.** The internet is used only to download a speech model or voice the
  person picks, over HTTPS, from this repository's releases.
- **Checked downloads.** Every model and voice file is checked against a SHA-256 sum built into the
  app before it is used; a partial or changed file is deleted. The models release itself is rebuilt
  in CI from pinned upstream archives and must match the app's catalog byte for byte.
- **Untrusted files are read defensively.** Packs imported from files are size-limited (30 MB,
  3 MB per picture, 1,000 files), picture paths that try to leave the pack folder are refused, and
  nothing in a pack is executed: it is data (JSON and pictures).
- **Private storage.** Practice history, imported packs and models live in the app's private
  storage.
- **Pinned build inputs.** OpenMoji symbols and the upstream model archives are pinned by SHA-256;
  Flutter is pinned in CI; Dependabot proposes updates.
- **Signed releases.** Android release builds are signed in CI; each release lists the signing
  certificate fingerprint and SHA-256 checksums of every file.
