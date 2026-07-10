# Security Policy

SeaLegs handles screen recording permission, optional input signals, local
session logs, and diagnostics. Please report security and privacy issues
privately.

## Supported Versions

SeaLegs is pre-1.0. Security fixes target the latest `main` branch unless a
tagged release line is created later.

| Version | Supported |
| --- | --- |
| `main` | Yes |
| Older snapshots | No |

## Report a Vulnerability

Use GitHub private vulnerability reporting for this repository:

https://github.com/DAWNCR0W/SeaLegs/security/advisories/new

If GitHub makes private vulnerability reporting temporarily unavailable, open
a minimal public issue asking for a private security contact. Do not include exploit details,
private screenshots, diagnostic files, user paths, bundle identifiers, or logs
in the public issue.

## What to Include

- A concise description of the issue.
- Affected SeaLegs version or commit hash.
- macOS version and hardware model.
- Steps to reproduce, if safe to share privately.
- Whether Screen Recording or Input Monitoring permission was enabled.
- Expected privacy or security impact.

## Scope

Security reports are in scope when they involve:

- Unauthorized capture or retention of screenshots, video, OCR, typed text, or
  raw input paths.
- Diagnostics or session logs exposing sensitive local data.
- Overlay behavior that intercepts game or system input unexpectedly.
- Permission state or restart behavior that misleads the user.
- Build, signing, or release artifacts that create supply-chain risk.

Out of scope:

- General gameplay discomfort.
- Requests to bypass game anti-cheat systems.
- Requests to patch game memory or automate gameplay.
- Bugs requiring a modified local build with unsafe entitlements added by the
  reporter.

## Maintainer Response Target

- Initial acknowledgement: best effort within 7 days.
- Triage and reproduction: best effort within 14 days.
- Fix timing depends on severity, complexity, and maintainer availability.

## Disclosure

Please do not disclose a vulnerability publicly until a maintainer has had a
reasonable chance to investigate and publish a fix or mitigation.
