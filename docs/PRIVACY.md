# Privacy

SeaLegs is designed around local-only analysis.

## Summary

- Basic overlay mode does not require Screen Recording.
- Adaptive mode requires Screen Recording.
- Input Monitoring is optional and off by default.
- SeaLegs does not store screenshots, video, audio, OCR output, typed text,
  key strings, or raw mouse paths.
- Adaptive analysis reduces frames in memory to numeric motion metrics.
- Session logs contain numeric state, not raw frames.

## Permissions

### Screen Recording

Required only for Adaptive mode. macOS may require restarting SeaLegs after
permission is granted.

### Input Monitoring

Optional. Used only as an auxiliary turn signal when the user enables it.
The opt-in is stored locally so the signal can resume after macOS permission is
granted and SeaLegs is reopened. Turning the setting off stops the event tap.

### App Sandbox

SeaLegs is distributed directly rather than through the Mac App Store and does
not enable App Sandbox. Its current design needs to observe the active app and
game window, coordinate transparent overlay windows across displays, and, when
the user opts in, use ScreenCaptureKit and an input-monitoring event tap.
Disabling App Sandbox does not bypass macOS privacy controls: Screen Recording
and Input Monitoring still require explicit user approval, and the optional
input signal remains off by default.

## Local Files

SeaLegs stores data in:

```text
~/Library/Application Support/SeaLegs/
```

Files:

- `profiles.json`: game profiles and overlay settings.
- `settings.json`: language, telemetry, and privacy settings.
- `Sessions/*.jsonl`: numeric motion samples, profile identifiers, permission
  state, optional discomfort ratings, and emergency-mode events.

## Diagnostics

Diagnostics export should contain:

- Numeric state.
- Permission state.
- Overlay state.
- Salted hashes where identifiers are needed.

Diagnostics export should not contain:

- Screenshots.
- Video.
- Audio.
- OCR output.
- Typed text.
- Raw app identifiers.
- Full executable paths.
- Raw mouse paths.

## User Control

Users can:

- Use manual overlay modes without Screen Recording.
- Disable session logging in Settings > Privacy.
- Delete stored session logs in Settings > Privacy.
- Reset macOS Screen Recording permission with:

```bash
tccutil reset ScreenCapture com.dawncrow.SeaLegs
```

Disabling session logging prevents samples, discomfort ratings, and emergency
events from being written to disk. The current in-memory report can still use
these values and is discarded when its session is replaced or the app exits.

## Contributor Rule

If a change adds data collection, persistence, export, or network behavior, the
pull request must update this document and explain the user-visible privacy
impact.
