# Contributing to SeaLegs

Thank you for considering a contribution. SeaLegs is a privacy-first macOS
overlay for visual comfort in 3D games, so changes should be conservative around user
trust, local data, and macOS permissions.

## Project Priorities

- Keep screen analysis local. Do not add network upload of screenshots, video,
  OCR, typed text, raw input paths, or raw capture frames.
- Preserve click-through overlay behavior. SeaLegs should not intercept game
  input unless a future feature explicitly requires user opt-in.
- Make visible behavior testable. If a setting changes the overlay, users
  should be able to confirm it through the app UI.
- Prefer simple, native macOS implementation over hidden background complexity.
- Keep SeaLegs clear about its scope. It is not a medical product.

## Development Setup

Install the tested helper dependencies listed in
[`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md#requirements) before generating the
project.

```bash
cd SeaLegs
ruby Scripts/generate_xcodeproj.rb
xcodebuild -project SeaLegs.xcodeproj -scheme SeaLegs -destination 'platform=macOS' build
```

Run tests:

```bash
cd SeaLegs
xcodebuild -project SeaLegs.xcodeproj -scheme SeaLegs -destination 'platform=macOS' test
```

If you need stable macOS permission behavior during local testing, regenerate
the project with your development team:

```bash
cd SeaLegs
SEALEGS_DEVELOPMENT_TEAM="<TEAM_ID>" ruby Scripts/generate_xcodeproj.rb
```

## Pull Request Checklist

Before opening a pull request:

- Run `git diff --check`.
- Run the macOS build command.
- Run the test command when code changes behavior.
- Confirm no old product naming remains.
- Confirm privacy claims still match the implementation.
- Update README or docs for user-visible behavior changes.
- Include manual test notes for overlay, permission, or Settings changes.

## Code Style

- Match the existing Swift and SwiftUI style.
- Keep UI state changes explicit and observable.
- Keep capture and analysis code isolated from presentation code.
- Avoid broad refactors in feature or bug-fix pull requests.
- Use small comments only where intent is not obvious from the code.

## Tests

Add or update tests when changing:

- Motion scoring or visual metric calculations.
- Overlay state mapping.
- Profile persistence and migration.
- Diagnostics export and privacy redaction.
- Controller or input behavior.

## Privacy and Security Review

Any change that touches ScreenCaptureKit, Input Monitoring, session logs,
diagnostics, or app identifiers needs an explicit privacy note in the pull
request.

Do not include private game screenshots, user paths, bundle identifiers, or
raw diagnostic exports in public issues or pull requests.

## Commit Messages

Use concise conventional prefixes when possible:

- `feat:`
- `fix:`
- `docs:`
- `test:`
- `refactor:`
- `chore:`

Example:

```text
fix: improve visibility of overlay guide elements
```
