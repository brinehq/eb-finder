#!/usr/bin/env bash
#
# Xcode Cloud post-clone hook.
#
# Apple runs this once per workflow execution, immediately after the repo is
# checked out and before Xcode resolves dependencies. The script path is
# fixed by Apple's contract: ci_scripts/ci_post_clone.sh at the repo root.
#
# What we do here:
#   1. Install a pinned XcodeGen and generate "EB Finder.xcodeproj" from
#      project.yml — the project file is generated, never committed.
#   2. Sync the marketing version (MARKETING_VERSION + manifest.json) from the
#      most recent git tag (vX.Y.Z → X.Y.Z).
#   3. Stamp CURRENT_PROJECT_VERSION (CFBundleVersion) with Xcode Cloud's own
#      unique build number ($CI_BUILD_NUMBER).
#
# Version keys live in EB Finder/Config/Version.xcconfig and are read at build
# time. Signing is NOT committed — DEVELOPMENT_TEAM lives in the git-ignored
# Config/Signing.local.xcconfig; Xcode Cloud injects distribution signing.
#
# Env vars provided by Xcode Cloud:
#   CI_BUILD_NUMBER             monotonically-increasing integer per workflow run
#   CI_PRIMARY_REPOSITORY_PATH  absolute path to the checked-out repo root
#

set -euo pipefail

cd "$CI_PRIMARY_REPOSITORY_PATH"

VERSION_XCCONFIG="EB Finder/Config/Version.xcconfig"
XCODEGEN_VERSION="2.45.4"
WORK="${TMPDIR:-/tmp}"

# Install XcodeGen from its pinned GitHub release binary rather than Homebrew:
# reproducible, and free of the brew-PATH issues that bite ci_post_clone.
echo "==> Installing XcodeGen $XCODEGEN_VERSION"
curl -fsSL -o "$WORK/xcodegen.zip" \
  "https://github.com/yonaskolb/XcodeGen/releases/download/${XCODEGEN_VERSION}/xcodegen.zip"
unzip -q -o "$WORK/xcodegen.zip" -d "$WORK/xcodegen-dist"
XCODEGEN="$(find "$WORK/xcodegen-dist" -type f -name xcodegen | head -1)"
chmod +x "$XCODEGEN"
"$XCODEGEN" --version

echo "==> Syncing marketing version from latest git tag"
git fetch --tags --quiet 2>/dev/null || true   # tags may be absent on a shallow CI clone
./scripts/sync-version.sh

echo "==> Stamping CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER"
sed -i.bak -E "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER/" "$VERSION_XCCONFIG"
rm -f "$VERSION_XCCONFIG.bak"

echo "==> Generating Xcode project from project.yml"
( cd "EB Finder" && "$XCODEGEN" generate )

echo "==> Final versioning state:"
grep -E "^(MARKETING_VERSION|CURRENT_PROJECT_VERSION)" "$VERSION_XCCONFIG"
