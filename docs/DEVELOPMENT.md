# Development Guide

## Requirements

- Apple Silicon Mac.
- macOS 14 or later.
- Xcode with macOS SDK.
- Ruby available for project generation.
- Bundler and the locked Ruby dependencies in `Gemfile.lock`.
- Pillow for icon regeneration only (`11.3.0` is the tested version).

Install the helper dependencies if they are missing:

```bash
bundle install
python3 -m pip install Pillow==11.3.0
```

## Generate Project

```bash
cd SeaLegs
BUNDLE_GEMFILE=../Gemfile bundle exec ruby Scripts/generate_xcodeproj.rb
```

Optional signing configuration:

```bash
cd SeaLegs
SEALEGS_DEVELOPMENT_TEAM="<TEAM_ID>" BUNDLE_GEMFILE=../Gemfile \
  bundle exec ruby Scripts/generate_xcodeproj.rb
```

Optional bundle identifiers:

```bash
cd SeaLegs
SEALEGS_BUNDLE_IDENTIFIER="com.example.SeaLegs" \
SEALEGS_TEST_BUNDLE_IDENTIFIER="com.example.SeaLegsTests" \
SEALEGS_UI_TEST_BUNDLE_IDENTIFIER="com.example.SeaLegsUITests" \
BUNDLE_GEMFILE=../Gemfile bundle exec ruby Scripts/generate_xcodeproj.rb
```

## Build

```bash
cd SeaLegs
xcodebuild -project SeaLegs.xcodeproj -scheme SeaLegs -destination 'platform=macOS' build
```

## Test

```bash
cd SeaLegs
xcodebuild -project SeaLegs.xcodeproj -scheme SeaLegs -destination 'platform=macOS' test
```

Run the UI smoke test separately when investigating UI failures:

```bash
cd SeaLegs
xcodebuild -project SeaLegs.xcodeproj -scheme SeaLegs \
  -destination 'platform=macOS' \
  -only-testing:SeaLegsUITests test
```

UI tests use an isolated temporary data directory and skip permission prompts,
workspace observers, and menu-bar setup. Real game-window targeting, macOS
permission flows, and Login Item approval still require manual testing.

## Run

```bash
cd SeaLegs
xcodebuild -project SeaLegs.xcodeproj -scheme SeaLegs -destination 'platform=macOS' build
open ~/Library/Developer/Xcode/DerivedData/SeaLegs-*/Build/Products/Debug/SeaLegs.app
```

## Manual QA

Check:

- Menu bar icon appears.
- Settings opens.
- `Show Feature Demo` displays every visual aid.
- `Toggle Overlay` works without a registered game.
- `Game Window` follows a registered game's window and reports display fallback
  while the window cannot be resolved.
- Active Game Display and All Displays still target the expected screens.
- Center Dot and Crosshair X/Y controls move the guides and reset correctly.
- Portable profile export/import previews conflicts, preserves built-in
  templates, supports Replace, Keep Both, and Cancel, and opens from Finder.
- Compatibility snapshot copies without local app identifiers or paths.
- Launch at Login reports its current macOS status and survives an app relaunch.
- Screen Recording request opens the correct System Settings page.
- Adaptive mode reports whether samples are being received.
- Diagnostics export does not contain private raw data.

## Common Permission Reset

```bash
tccutil reset ScreenCapture com.dawncrow.SeaLegs
```

After resetting, reopen SeaLegs and request permission again.

## Versioning and Release Builds

`VERSION` is the single source for the marketing version. Build number `2` is
the default for the `0.2.0` release line. The project generator and DMG script
read the version from this file.

```bash
SeaLegs/Scripts/build_dmg.sh
```

The packaging script requires a clean worktree at an annotated matching tag.
It creates the DMG, SHA-256 checksum, and build manifest under
`dist/v0.2.0/`.

## Continuous Integration

GitHub Actions regenerates the project twice to verify deterministic output,
checks for unsafe patterns, builds, runs unit and UI tests, and runs the static
analyzer. Failed test result bundles are uploaded for inspection.
