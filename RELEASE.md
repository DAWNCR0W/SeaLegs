# Release Process

SeaLegs releases must be reproducible, explicit about signing state, and
consistent with the privacy-sensitive permissions used by the app.

## Release Channels

- `0.x`: public GitHub releases. The DMG is ad-hoc signed with Hardened Runtime,
  but is not signed with Developer ID and is not notarized by Apple.
- `1.0` and later stable releases: Developer ID signed and Apple notarized
  before publication.

Tag releases as `vX.Y.Z`. Keep `CFBundleShortVersionString`, the changelog, the
tag, the DMG filename, and the GitHub Release title on the same version.

For `0.x`, the bundle version, tag, changelog entry, and release version remain
numeric (for example, `0.2.0` and `v0.2.0`). The DMG artifact directories and
filenames use the numeric version format.

## Pre-Release Checklist

- Confirm the release source is committed and the worktree is clean.
- Run `bundle install`, then `bundle exec ruby SeaLegs/Scripts/generate_xcodeproj.rb`
  from the repository root.
- Confirm the generated `project.pbxproj` and shared `SeaLegs.xcscheme` are
  committed and unchanged after a second generator run.
- Run `git diff --check`.
- Run the complete XCTest suite and read the xcresult summary.
- Run Xcode Analyze and a Release build.
- Confirm `README.md`, `README.ko.md`, `CHANGELOG.md`, `SECURITY.md`, and the
  release notes are current.
- Confirm privacy statements still match implementation.
- Scan the worktree and Git history with Gitleaks.
- Enable private vulnerability reporting before or immediately after the
  repository becomes public, then verify the reporting URL anonymously.

## Build a 0.x DMG

Build from a clean detached worktree at the exact release commit or tag. The
script refuses a dirty worktree unless `--allow-dirty` is supplied for local
validation. Do not use `ExportOptions.plist` for this path because that
file is reserved for Developer ID export.

A clean release build also requires an annotated `vX.Y.Z` tag at `HEAD` and
records it in `BUILD_MANIFEST.txt`. Dirty validation builds cannot write to the
canonical release directory; point them to a separate location instead:

```bash
SEALEGS_OUTPUT_DIR=/tmp/sealegs-validation \
  ./Scripts/build_dmg.sh --allow-dirty --overwrite
```

```bash
cd SeaLegs
./Scripts/build_dmg.sh
```

The script:

1. Regenerates the Xcode project with the requested version and build number.
2. Archives an arm64 Release build with an ad-hoc signature and Hardened
   Runtime.
3. Verifies bundle version `0.2.0`, build `2`, architecture, and code seal.
4. Creates a compressed DMG containing `SeaLegs.app` and an `Applications`
   shortcut.
5. Attaches the DMG read-only and verifies its mounted contents.
6. Writes `SHA256SUMS.txt` and `BUILD_MANIFEST.txt` only after all checks pass.

Default output:

```text
dist/v0.2.0/SeaLegs-0.2.0-arm64.dmg
dist/v0.2.0/SHA256SUMS.txt
dist/v0.2.0/BUILD_MANIFEST.txt
```

An existing artifact set is not replaced unless `--overwrite` is supplied.
Gatekeeper rejection is expected for this Developer ID unsigned and
unnotarized release and is recorded in the manifest; it is not a build failure.

## Verify the Artifact

```bash
cd dist/v0.2.0
shasum -a 256 -c SHA256SUMS.txt
hdiutil verify SeaLegs-0.2.0-arm64.dmg
```

Also test from a fresh macOS user account:

1. Open the DMG and drag SeaLegs to Applications.
2. Attempt the first launch and confirm Gatekeeper blocks it.
3. Use System Settings > Privacy & Security > Open Anyway.
4. Confirm the manual overlay works without Screen Recording permission.
5. Confirm the Adaptive permission guidance, restart, and Refresh flow.
6. Confirm the app process exits after Quit.

Do not instruct users to disable Gatekeeper globally or use `xattr` as the
primary installation path.

## Publish a 0.x GitHub Release

1. Push the verified release commit to `main`.
2. Create and push an annotated tag such as `v0.2.0`.
3. Create a GitHub Release.
4. Use the changelog entry as the release body.
5. Attach the DMG, `SHA256SUMS.txt`, and `BUILD_MANIFEST.txt`.
6. Download the published assets again and verify their size and SHA-256.

## Archive and Notarize a Stable Release

For the planned 1.0 stable release, use a Developer ID certificate and a
configured notarization keychain profile.

```bash
cd SeaLegs
xcodebuild archive \
  -scheme SeaLegs \
  -configuration Release \
  -archivePath build/SeaLegs.xcarchive

xcodebuild -exportArchive \
  -archivePath build/SeaLegs.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist

ditto -c -k --keepParent build/export/SeaLegs.app build/SeaLegs.zip

xcrun notarytool submit build/SeaLegs.zip \
  --keychain-profile "notary-profile" \
  --wait

xcrun stapler staple build/export/SeaLegs.app
xcrun stapler validate build/export/SeaLegs.app
spctl --assess --type execute --verbose=4 build/export/SeaLegs.app
```

Test the transition from the final ad-hoc release to the Developer ID build before
1.0 because Screen Recording and Input Monitoring permissions may need to be
granted again when the code identity changes.

## After Release

- Verify the GitHub Release tag and target commit.
- Verify every uploaded asset and checksum.
- Confirm the repository visibility and public unauthenticated access.
- Confirm private vulnerability reporting is enabled.
- Start a new empty `Unreleased` section in `CHANGELOG.md`.
