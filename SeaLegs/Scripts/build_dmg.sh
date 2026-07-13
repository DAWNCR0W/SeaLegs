#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: build_dmg.sh [--overwrite] [--allow-dirty]

Build an Apple Silicon, ad-hoc signed SeaLegs DMG without modifying the
source worktree.

Environment overrides:
  SEALEGS_RELEASE_VERSION  Marketing version (default: VERSION file)
  SEALEGS_BUILD_NUMBER     Bundle build number (default: 2)
  SEALEGS_RELEASE_ARCH     Build architecture (default: arm64)
  SEALEGS_OUTPUT_DIR       Artifact directory
EOF
}

overwrite=0
allow_dirty="${SEALEGS_ALLOW_DIRTY:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --overwrite)
      overwrite=1
      ;;
    --allow-dirty)
      allow_dirty=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

script_dir="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd -P "$script_dir/.." && pwd -P)"
repository_root="$(cd -P "$project_root/.." && pwd -P)"

version_file="$repository_root/VERSION"
if [[ ! -r "$version_file" ]]; then
  echo "Missing canonical version file: $version_file" >&2
  exit 1
fi

default_version="$(tr -d '[:space:]' < "$version_file")"
if [[ -z "$default_version" ]]; then
  echo "Canonical version file is empty: $version_file" >&2
  exit 1
fi

version="${SEALEGS_RELEASE_VERSION:-$default_version}"
build_number="${SEALEGS_BUILD_NUMBER:-2}"
architecture="${SEALEGS_RELEASE_ARCH:-arm64}"
requested_output_dir="${SEALEGS_OUTPUT_DIR:-$repository_root/dist/v${version}}"
output_parent="$(dirname "$requested_output_dir")"
output_name="$(basename "$requested_output_dir")"
artifact_name="SeaLegs-${version}-${architecture}.dmg"
release_tag="v${version}"

mkdir -p "$output_parent"
output_parent="$(cd -P "$output_parent" && pwd -P)"
output_dir="$output_parent/$output_name"

if [[ -L "$output_dir" ]]; then
  echo "Refusing to publish through a symbolic-link output directory: $output_dir" >&2
  exit 1
fi
if [[ -e "$output_dir" && "$overwrite" -ne 1 ]]; then
  echo "Refusing to overwrite existing artifact directory: $output_dir" >&2
  echo "Pass --overwrite to replace the complete verified artifact set." >&2
  exit 1
fi

if ! git -C "$repository_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "The release source must be a Git worktree." >&2
  exit 1
fi

source_commit="$(git -C "$repository_root" rev-parse HEAD)"
source_state="$source_commit"
source_tag="$release_tag"
worktree_status="$(git -C "$repository_root" status --porcelain)"
if [[ -n "$worktree_status" ]]; then
  source_state="$source_commit (dirty)"
  source_tag="none (local validation only)"
  if [[ "$allow_dirty" != "1" ]]; then
    echo "Refusing to build a release artifact from a dirty worktree." >&2
    echo "Commit the release source or pass --allow-dirty for local validation only." >&2
    exit 1
  fi
fi

canonical_output_dir="$repository_root/dist/v${version}"
if [[ -n "$worktree_status" && "$output_dir" == "$canonical_output_dir" ]]; then
  echo "Refusing to publish a dirty validation build to the canonical release directory." >&2
  echo "Set SEALEGS_OUTPUT_DIR to a separate local path, such as /tmp/sealegs-validation." >&2
  exit 1
fi

if [[ -z "$worktree_status" ]]; then
  if ! tag_type="$(git -C "$repository_root" cat-file -t "refs/tags/$release_tag" 2>/dev/null)" || \
    [[ "$tag_type" != "tag" ]]; then
    echo "A clean release build requires the annotated tag $release_tag." >&2
    exit 1
  fi
  tag_commit="$(git -C "$repository_root" rev-list -n 1 "$release_tag")"
  if [[ "$tag_commit" != "$source_commit" ]]; then
    echo "Release tag $release_tag does not point to HEAD ($source_commit)." >&2
    exit 1
  fi
fi

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/sealegs-dmg.XXXXXX")"
release_source="$work_dir/source"
archive_path="$work_dir/SeaLegs.xcarchive"
stage_dir="$work_dir/stage"
mount_point="$work_dir/mount"
publish_dir="$(mktemp -d "$output_parent/.${output_name}.partial.XXXXXX")"
backup_dir=""
mounted=0

cleanup() {
  local cleanup_failed=0

  if [[ "$mounted" -eq 1 ]]; then
    if hdiutil detach -quiet "$mount_point" || hdiutil detach -force -quiet "$mount_point"; then
      mounted=0
    else
      cleanup_failed=1
      echo "Could not detach $mount_point; retaining temporary work directory: $work_dir" >&2
    fi
  fi
  if [[ "$mounted" -eq 0 ]]; then
    rm -rf "$work_dir"
  fi
  if [[ -n "$publish_dir" && -d "$publish_dir" ]]; then
    rm -rf "$publish_dir"
  fi
  if [[ -n "$backup_dir" && -d "$backup_dir" ]]; then
    if [[ ! -e "$output_dir" ]]; then
      mv "$backup_dir" "$output_dir" || true
    else
      rm -rf "$backup_dir"
    fi
  fi
  return "$cleanup_failed"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p "$release_source"
if [[ "$allow_dirty" == "1" ]]; then
  rsync -a \
    --exclude '.git/' \
    --exclude '.build/' \
    --exclude 'build/' \
    --exclude 'DerivedData/' \
    --exclude 'dist/' \
    "$repository_root/" "$release_source/"
else
  git -C "$repository_root" archive --format=tar HEAD | tar -xf - -C "$release_source"
fi

release_project_root="$release_source/SeaLegs"
release_script_dir="$release_project_root/Scripts"

echo "Generating the Xcode project for SeaLegs $version ($build_number)..."
SEALEGS_MARKETING_VERSION="$version" \
SEALEGS_BUILD_NUMBER="$build_number" \
BUNDLE_GEMFILE="$repository_root/Gemfile" \
  bundle exec ruby "$release_script_dir/generate_xcodeproj.rb"

if [[ "$allow_dirty" != "1" ]] && ! cmp -s \
  "$release_project_root/SeaLegs.xcodeproj/project.pbxproj" \
  "$project_root/SeaLegs.xcodeproj/project.pbxproj"; then
  echo "Project generation differs from the committed SeaLegs.xcodeproj." >&2
  echo "Regenerate and commit the project before building the release." >&2
  exit 1
fi

if [[ "$allow_dirty" != "1" ]] && ! cmp -s \
  "$release_project_root/SeaLegs.xcodeproj/xcshareddata/xcschemes/SeaLegs.xcscheme" \
  "$project_root/SeaLegs.xcodeproj/xcshareddata/xcschemes/SeaLegs.xcscheme"; then
  echo "Shared scheme generation differs from the committed SeaLegs.xcscheme." >&2
  echo "Regenerate and commit the project before building the release." >&2
  exit 1
fi

echo "Archiving an ad-hoc signed $architecture Release build..."
xcodebuild archive \
  -project "$release_project_root/SeaLegs.xcodeproj" \
  -scheme SeaLegs \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$work_dir/DerivedData" \
  -archivePath "$archive_path" \
  "ARCHS=$architecture" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  -quiet

app_path="$archive_path/Products/Applications/SeaLegs.app"
executable_path="$app_path/Contents/MacOS/SeaLegs"

if [[ ! -d "$app_path" ]]; then
  echo "Archive did not contain SeaLegs.app." >&2
  exit 1
fi

actual_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")"
actual_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app_path/Contents/Info.plist")"
actual_architectures="$(lipo -archs "$executable_path")"

if [[ "$actual_version" != "$version" ]]; then
  echo "Version mismatch: expected $version, found $actual_version." >&2
  exit 1
fi
if [[ "$actual_build" != "$build_number" ]]; then
  echo "Build mismatch: expected $build_number, found $actual_build." >&2
  exit 1
fi
if [[ "$actual_architectures" != "$architecture" ]]; then
  echo "Architecture mismatch: expected $architecture, found $actual_architectures." >&2
  exit 1
fi

verify_ad_hoc_code() {
  local code_path="$1"
  local signature_output

  codesign --verify --strict --verbose=2 "$code_path"
  signature_output="$(codesign -dv --verbose=4 "$code_path" 2>&1)"
  if ! grep -q 'Signature=adhoc' <<<"$signature_output"; then
    echo "Expected an ad-hoc signature: $code_path" >&2
    exit 1
  fi
}

verify_ad_hoc_tree() {
  local root_app="$1"
  local nested_path

  codesign --verify --deep --strict --verbose=2 "$root_app"
  verify_ad_hoc_code "$root_app"

  while IFS= read -r -d '' nested_path; do
    verify_ad_hoc_code "$nested_path"
  done < <(
    find "$root_app/Contents" -type d \
      \( -name '*.app' -o -name '*.appex' -o -name '*.bundle' -o -name '*.framework' -o -name '*.xpc' \) \
      -print0
  )

  while IFS= read -r -d '' nested_path; do
    if file -b "$nested_path" | grep -q 'Mach-O'; then
      verify_ad_hoc_code "$nested_path"
    fi
  done < <(find "$root_app/Contents" -type f -print0)
}

verify_ad_hoc_tree "$app_path"
root_signature_info="$(codesign -dv --verbose=4 "$app_path" 2>&1)"
if ! grep -q 'runtime' <<<"$root_signature_info"; then
  echo "Expected Hardened Runtime in the beta artifact signature." >&2
  exit 1
fi

gatekeeper_status="rejected (expected for Developer ID unsigned and unnotarized beta)"
if spctl --assess --type execute "$app_path" >/dev/null 2>&1; then
  gatekeeper_status="accepted"
fi

mkdir -p "$stage_dir"
ditto "$app_path" "$stage_dir/SeaLegs.app"
ln -s /Applications "$stage_dir/Applications"

dmg_path="$publish_dir/$artifact_name"
dmg_partial="$publish_dir/.${artifact_name}.partial.dmg"
checksum_path="$publish_dir/SHA256SUMS.txt"
manifest_path="$publish_dir/BUILD_MANIFEST.txt"

echo "Creating $artifact_name..."
hdiutil create \
  -volname "SeaLegs $version" \
  -srcfolder "$stage_dir" \
  -format UDZO \
  -ov \
  -quiet \
  "$dmg_partial"

hdiutil verify -quiet "$dmg_partial"
mkdir -p "$mount_point"
hdiutil attach \
  -readonly \
  -nobrowse \
  -mountpoint "$mount_point" \
  "$dmg_partial" \
  >/dev/null
mounted=1

if [[ ! -d "$mount_point/SeaLegs.app" ]]; then
  echo "Mounted DMG is missing SeaLegs.app." >&2
  exit 1
fi
if [[ ! -L "$mount_point/Applications" || "$(readlink "$mount_point/Applications")" != "/Applications" ]]; then
  echo "Mounted DMG has an invalid Applications shortcut." >&2
  exit 1
fi
verify_ad_hoc_tree "$mount_point/SeaLegs.app"

hdiutil detach -quiet "$mount_point"
mounted=0

dmg_sha256="$(shasum -a 256 "$dmg_partial" | awk '{ print $1 }')"
dmg_size_bytes="$(stat -f '%z' "$dmg_partial")"
xcode_version="$(xcodebuild -version | paste -sd ';' -)"
sdk_version="$(xcrun --sdk macosx --show-sdk-version)"
built_at_utc="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

mv "$dmg_partial" "$dmg_path"
printf '%s  %s\n' "$dmg_sha256" "$artifact_name" >"$checksum_path"
{
  printf 'Product: SeaLegs\n'
  printf 'Version: %s\n' "$version"
  printf 'Build: %s\n' "$build_number"
  printf 'Architecture: %s\n' "$architecture"
  printf 'Source: %s\n' "$source_state"
  printf 'SourceTag: %s\n' "$source_tag"
  printf 'BuiltAtUTC: %s\n' "$built_at_utc"
  printf 'Xcode: %s\n' "$xcode_version"
  printf 'macOSSDK: %s\n' "$sdk_version"
  printf 'CodeSignature: ad-hoc with Hardened Runtime\n'
  printf 'Notarized: no\n'
  printf 'GatekeeperAssessment: %s\n' "$gatekeeper_status"
  printf 'Artifact: %s\n' "$artifact_name"
  printf 'ArtifactBytes: %s\n' "$dmg_size_bytes"
  printf 'SHA256: %s\n' "$dmg_sha256"
} >"$manifest_path"

if [[ -e "$output_dir" ]]; then
  backup_dir="$output_parent/.${output_name}.backup.$$"
  mv "$output_dir" "$backup_dir"
fi

if ! mv "$publish_dir" "$output_dir"; then
  if [[ -n "$backup_dir" && -d "$backup_dir" ]]; then
    mv "$backup_dir" "$output_dir"
    backup_dir=""
  fi
  echo "Failed to publish the complete artifact directory." >&2
  exit 1
fi
publish_dir=""

if [[ -n "$backup_dir" && -d "$backup_dir" ]]; then
  rm -rf "$backup_dir"
  backup_dir=""
fi

echo "Release artifacts created:"
echo "  $output_dir/$artifact_name"
echo "  $output_dir/SHA256SUMS.txt"
echo "  $output_dir/BUILD_MANIFEST.txt"
