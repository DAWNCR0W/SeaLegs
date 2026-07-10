# Architecture

SeaLegs is a native macOS menu bar app.

## High-Level Flow

1. `AppDelegate` creates `AppCoordinator`.
2. `MenuBarController` exposes app actions through the macOS menu bar.
3. `GameDetector` watches the frontmost app.
4. A matching `GameProfile` selects overlay and adaptive settings.
5. `OverlayManager` creates transparent click-through panels on the active game
   display by default, or on all displays when the user selects that scope.
6. `OverlayRenderer` draws vignette and visual guide elements with Metal.
7. `ScreenCaptureManager` optionally captures low-resolution frames for
   adaptive analysis when Screen Recording permission is granted.
8. `MotionAnalyzer` converts reduced frames into numeric motion metrics.
9. `MotionScoreEngine` maps metrics to overlay strength.
10. `SessionLogger` stores numeric session samples when enabled.

The detected game profile and a manual preview profile are separate runtime
states. Editing or previewing a preset must not make it the automatically
detected game.

## Major Areas

- `App`: coordination, app state, constants.
- `Analysis`: motion metrics and scoring.
- `Capture`: ScreenCaptureKit integration and frame reduction.
- `Diagnostics`: privacy-preserving diagnostic export.
- `GameDetection`: frontmost app and registered game matching.
- `Input`: hotkeys and optional input signal helpers.
- `Localization`: app string localization.
- `Overlay`: NSPanel, Metal view, renderer, and overlay state.
- `Permissions`: macOS permission checks and System Settings routing.
- `Profiles`: default profiles, persistence, and game setting guidance.
- `Telemetry`: local session logging and reports.
- `UI`: Settings, onboarding, reports, debug HUD, and profile editor.

## Privacy Boundary

The privacy-sensitive boundary is capture and diagnostics:

- Screen frames are reduced in memory to numeric metrics.
- Raw screenshots, video, OCR, typed text, and raw input paths must not be
  persisted.
- Diagnostics must use numeric state and redacted or salted identifiers.
- Disabling session logging applies to samples, ratings, and emergency events.

Any change crossing this boundary needs explicit review.

## Overlay Boundary

The overlay should remain click-through by default. It may show UI-like status
information, but it should not unexpectedly capture mouse or keyboard input.
Its window level is lowered while SeaLegs menus or windows are active so the
app's own controls remain readable.

## Capture Lifecycle

Capture start and stop transitions are serialized and cancellation-aware. A
newer stop or target change invalidates older work, stream delegate failures
only clear the matching stream, and bounded retries are attempted only while
the same registered profile remains in Adaptive mode.

Each capture start has a generation identifier. Results from an older
generation are rejected before they can update the overlay or session report.
Frame output is invalidated before stopping the underlying stream, including
the stop-error path.

A low-frequency main-run-loop maintenance timer refreshes time-based capture
readiness and retargets the overlay when the active game window moves between
displays. It does not capture frames or run motion analysis.

## Persistence

SeaLegs stores local data under:

```text
~/Library/Application Support/SeaLegs/
```

Main files:

- `profiles.json`
- `settings.json`
- `Sessions/*.jsonl`

## Testing Focus

Highest-value tests cover:

- Motion score math.
- Overlay state mapping.
- Profile persistence and migration.
- Diagnostics redaction.
- Permission and capture fallback behavior.
