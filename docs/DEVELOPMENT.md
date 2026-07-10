# Development Guide

## Requirements

- Apple Silicon Mac.
- macOS 14 or later.
- Xcode with macOS SDK.
- Ruby available for project generation.
- The `xcodeproj` Ruby gem (`1.27.0` is the tested version).
- Pillow for icon regeneration only (`11.3.0` is the tested version).

Install the helper dependencies if they are missing:

```bash
gem install xcodeproj -v 1.27.0
python3 -m pip install Pillow==11.3.0
```

## Generate Project

```bash
cd SeaLegs
ruby Scripts/generate_xcodeproj.rb
```

Optional signing configuration:

```bash
cd SeaLegs
SEALEGS_DEVELOPMENT_TEAM="<TEAM_ID>" ruby Scripts/generate_xcodeproj.rb
```

Optional bundle identifiers:

```bash
cd SeaLegs
SEALEGS_BUNDLE_IDENTIFIER="com.example.SeaLegs" \
SEALEGS_TEST_BUNDLE_IDENTIFIER="com.example.SeaLegsTests" \
ruby Scripts/generate_xcodeproj.rb
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
- Screen Recording request opens the correct System Settings page.
- Adaptive mode reports whether samples are being received.
- Diagnostics export does not contain private raw data.

## Common Permission Reset

```bash
tccutil reset ScreenCapture com.dawncrow.SeaLegs
```

After resetting, reopen SeaLegs and request permission again.
