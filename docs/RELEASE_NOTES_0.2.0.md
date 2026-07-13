# SeaLegs 0.2.0

SeaLegs 0.2.0 makes the overlay easier to place, share, and troubleshoot while
keeping analysis local to the Mac.

## Highlights

- Target a registered game's window, with a clearly reported display fallback.
- Position Center Dot and Crosshair guides independently on both axes.
- Export and import privacy-safe `.sealegsprofile` files with app-match and
  conflict preview, including Finder double-click support.
- Inspect and copy a redacted compatibility snapshot.
- Start SeaLegs at login through the native macOS Login Item service.
- Run deterministic project generation, builds, unit tests, UI smoke tests, and
  static analysis in CI.

## Installation

1. Download `SeaLegs-0.2.0-arm64.dmg` and `SHA256SUMS.txt`.
2. Verify the checksum with `shasum -a 256 -c SHA256SUMS.txt`.
3. Open the DMG and drag SeaLegs to Applications.

This build is ad-hoc signed and is not Apple-notarized. Developer ID signing
and notarization remain planned work.

## Compatibility

- Apple Silicon Mac
- macOS 14 or later

Real-game tuning remains title-specific. If Game Window targeting cannot find
the current window, SeaLegs safely falls back to the display containing the
active game and reports that fallback in Settings.
