# Changelog

All notable changes to SeaLegs will be documented in this file.

This project follows the spirit of Keep a Changelog and uses semantic versioning
once tagged releases begin.

## Unreleased

## [0.2.0] - 2026-07-13

### Added

- Game Window overlay targeting that follows the active game's largest visible
  window as it moves or resizes, with an automatic Active Game Display fallback.
- Per-profile horizontal and vertical positioning for the center dot and minimal
  crosshair, plus a one-click position reset.
- Versioned `.sealegsprofile` import and export with a review screen and explicit
  Replace Existing, Keep Both, or Cancel conflict handling.
- A Compatibility settings page for game registration, overlay targeting,
  Adaptive sample readiness, permissions, and privacy-preserving report copying.
- A Launch SeaLegs at Login setting backed by the macOS Login Items service.
- Automated macOS UI smoke coverage and GitHub Actions quality gates for project
  reproducibility, tests, Analyze, and unsafe installation guidance.

### Changed

- New installations now prefer Game Window targeting; existing stored Active Game
  Display and All Displays preferences remain unchanged.
- Built-in templates now have an explicit protected identity, allowing imported
  unlinked profiles to remain editable without being mistaken for templates.
- The project generator and DMG builder now read the marketing version from the
  repository `VERSION` file and use build number `2` for v0.2.0.
- Added Korean, Japanese, and Simplified Chinese coverage for all v0.2.0 controls,
  statuses, import warnings, and compatibility guidance.

### Fixed

- Prevented profile imports from replacing or unlocking protected built-in
  templates, even when an archive contains the same profile identifier.
- Made game-window coordinate conversion use the main display as the global
  vertical reference so arrangements above or below the primary display align.

### Security

- Portable profile archives exclude executable-path hashes, sessions, diagnostic
  salts, permissions, runtime selections, and captured content.
- Compatibility reports exclude screenshots, frames, paths, window titles, and
  raw application identifiers.

## [0.1.0] - 2026-07-10

### Added

- Menu bar macOS app structure.
- Transparent click-through overlay panels.
- Metal-rendered vignette, center dot, crosshair, horizon, dashboard, virtual
  nose, and peripheral-frame visual aids.
- Profile-based game detection and editable registered game profiles.
- Adaptive local motion analysis with ScreenCaptureKit.
- Settings UI for language, overlay, adaptive capture, privacy, reports,
  diagnostics, calibration, hotkeys, and game-setting recommendations.
- First-run onboarding, feature demo, and app registration guidance.
- App icon and menu bar icon assets.
- Korean, English, Japanese, and Simplified Chinese interface and README
  coverage.
- Ko-fi support link and open-source project documents and templates.
- Active-game display targeting with an optional all-displays setting.
- Persisted opt-in for the optional input turn signal.
- Recovery handling for sleep/wake and interrupted adaptive capture.
- Regression tests for capture target geometry, profile matching, settings
  migration, session privacy, stale readiness state, capture generations,
  input-signal decay, profile ramp-out behavior, and localized app labels.
- Reproducible Apple Silicon DMG packaging with SHA-256 checksums, a build
  manifest, and explicit Gatekeeper installation guidance.

### Changed

- Improved default visual guide visibility and added a high-contrast feature
  demo.
- Reworked Settings navigation and first-run onboarding for clearer status and
  feature discovery.
- Adaptive response now honors each profile's ramp-in and ramp-out values.
- Session samples are bounded to the configured interval for lower memory use.
- Overlay rendering updates only when state changes instead of drawing
  continuously while idle.
- Active-game display targeting follows a game window when it moves between
  displays.
- The Xcode project generator now resolves paths from its own directory and is
  safe to run from the repository root or the `SeaLegs` directory.
- Status surfaces now distinguish the frontmost app from an actively matched
  game profile.

### Fixed

- Persisted Off and preview mode changes for the selected profile.
- Kept manual profile previews separate from the automatically detected game.
- Prevented duplicate registrations and false matches between apps that share
  an executable name.
- Prevented stale asynchronous capture starts from outliving a newer stop.
- Rejected queued motion results from an older capture generation after game,
  profile, sleep, or mode transitions.
- Invalidated frame output even when ScreenCaptureKit reports a stop failure.
- Stopped capture and reset stale metrics when a game or profile deactivates.
- Kept hidden Adaptive overlays from restarting capture after settings edits.
- Refreshed stale capture readiness automatically instead of waiting for an
  unrelated UI update.
- Restored the active game after deleting a different manually previewed
  profile.
- Restored Adaptive capture after wake while a SeaLegs window remains in front.
- Decayed optional mouse-turn input after movement stops.
- Prevented ratings and emergency events from writing files when session
  logging is disabled.
- Prevented the overlay HUD from remaining visible after its timeout.
- Lowered the fullscreen overlay behind focused SeaLegs windows while restoring
  its game-level presentation when the user returns to another app.
- Avoided counting emergency-overlay previews before a game session starts.
- Kept first-run onboarding incomplete when its window is merely closed.
- Kept feature demos alive through frontmost-app changes for their full
  duration and restored their prior runtime state after settings edits.
- Completed Japanese and Simplified Chinese coverage for settings, status,
  error, and onboarding copy, with key-set and format-specifier regression
  tests.
- Matched calibration anchor labels to their canonical localization keys.

### Security

- Documented private vulnerability reporting and local privacy expectations.
- Kept Adaptive analysis local and excluded screenshots, video, audio, OCR,
  typed text, key strings, raw mouse paths, and raw capture frames from stored
  data.
