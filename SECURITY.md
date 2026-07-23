# Security Policy

## Supported versions

Only the most recent release receives active security patches.

| Version | Supported          |
| ------- | ------------------ |
| 0.x     | :white_check_mark: |

## Reporting a vulnerability

Found a security issue? Help us by **not** reporting it publicly in an issue. Instead, use one of these private channels:

- Open a **private security advisory** on GitHub:
  [github.com/Bolt-Connect/WinGet-Manager/security/advisories/new](https://github.com/Bolt-Connect/WinGet-Manager/security/advisories/new)
- Or email the maintainer via the [@Bolt-Connect](https://github.com/Bolt-Connect) profile

What to include in your report:

- A clear description of the issue
- Steps to reproduce
- The impact you foresee (data read, code execution, etc.)
- Optional: a proposed fix

## What you can expect

| Time    | Response |
| ------- | -------- |
| 48 hours | Initial confirmation that we received your report |
| 7 days   | Substantive reply with our first analysis |
| 30 days  | Target date for a patch (depending on complexity) |

If you report responsibly and give us time to fix it, we will credit you in the release notes (unless you want to stay anonymous).

## Scope

WinGet Manager is a wrapper around `winget.exe`. Security issues specific to WinGet itself don't belong here — report those at [microsoft/winget-cli](https://github.com/microsoft/winget-cli/security).

Keep this project focused on:

- Local code execution risks (e.g. command injection in our wrappers)
- Insecure defaults or configuration
- Path traversal in import/export
- Insecure install flows
- Privacy issues (logging of sensitive data)

## Self-update channel

The built-in self-update is the most security-sensitive path. Current measures:

- **HTTPS + host allow-list** — both the releases API URL and the resolved asset
  URLs are validated against `api.github.com` / `github.com` /
  `objects.githubusercontent.com` (`Test-TrustedUpdateUrl`) before any request.
- **PE-header check** — the downloaded file must be a valid Windows executable
  before it is used.
- **SHA256 verification** (v0.3.3+) — each release publishes `checksums.txt`, and
  the downloaded `WinGetManager.exe` is verified against its published hash before
  replacing the running exe. This protects against corrupt or in-transit-tampered
  downloads. It is **not** authenticity: a fully compromised release could swap
  both the exe and the checksums. Genuine authenticity requires code-signing,
  which is on the roadmap.

Users can verify any download manually against the `checksums.txt` published with
each release.

## Disclosure

After a patch is released, the issue is made public via a GitHub Security Advisory with a CVE if applicable.
