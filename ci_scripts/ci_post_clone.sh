#!/usr/bin/env bash
#
# Xcode Cloud post-clone hook.
#
# Apple runs this once per workflow execution, immediately after the repo is
# checked out and before Xcode resolves dependencies. The script path is
# fixed by Apple's contract: ci_scripts/ci_post_clone.sh at the repo root.
#
# What we do here:
#   1. Install XcodeGen and generate "EB Finder.xcodeproj" from project.yml —
#      the project file is generated, not committed (see EB Finder/project.yml).
#   2. Sync the marketing version (MARKETING_VERSION + manifest.json) from the
#      most recent git tag (vX.Y.Z → X.Y.Z).
#   3. Stamp CURRENT_PROJECT_VERSION (CFBundleVersion) with Xcode Cloud's own
#      unique build number ($CI_BUILD_NUMBER), so every uploaded build is
#      automatically unique without any manual bumping.
#
# Version keys live in EB Finder/Config/Version.xcconfig and are read at build
# time, so they take effect whether or not the project is regenerated after.
#
# Env vars provided by Xcode Cloud:
#   CI_BUILD_NUMBER             monotonically-increasing integer per workflow run
#   CI_PRIMARY_REPOSITORY_PATH  absolute path to the checked-out repo root
#

set -euo pipefail

cd "$CI_PRIMARY_REPOSITORY_PATH"

VERSION_XCCONFIG="EB Finder/Config/Version.xcconfig"

echo "==> Installing XcodeGen"
# Xcode Cloud runs this script with a minimal environment, so Homebrew and the
# tools it installs aren't necessarily on PATH. Source brew's shellenv first so
# both `brew` and the freshly-installed `xcodegen` resolve.
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
brew install xcodegen
xcodegen --version   # fail loudly here (not mid-build) if it didn't land on PATH

echo "==> Syncing marketing version from latest git tag"
# Ensure tags exist on Xcode Cloud's shallow clone before describing them.
git fetch --tags --quiet 2>/dev/null || true
./scripts/sync-version.sh

echo "==> Stamping CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER"
sed -i.bak -E "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER/" "$VERSION_XCCONFIG"
rm -f "$VERSION_XCCONFIG.bak"

echo "==> Generating Xcode project from project.yml"
( cd "EB Finder" && xcodegen generate )

echo "==> Final versioning state:"
grep -E "^(MARKETING_VERSION|CURRENT_PROJECT_VERSION)" "$VERSION_XCCONFIG"
