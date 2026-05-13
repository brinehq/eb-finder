#!/usr/bin/env bash
#
# Xcode Cloud post-clone hook.
#
# Apple runs this once per workflow execution, immediately after the repo is
# checked out and before Xcode resolves dependencies. The script path is
# fixed by Apple's contract: ci_scripts/ci_post_clone.sh at the repo root.
#
# What we do here:
#   1. Sync the marketing version (MARKETING_VERSION + manifest.json) from the
#      most recent git tag (vX.Y.Z → X.Y.Z).
#   2. Stamp CURRENT_PROJECT_VERSION (CFBundleVersion) with Xcode Cloud's own
#      unique build number ($CI_BUILD_NUMBER), so every uploaded build is
#      automatically unique without any manual bumping.
#
# Env vars provided by Xcode Cloud:
#   CI_BUILD_NUMBER          monotonically-increasing integer per workflow run
#   CI_PRIMARY_REPOSITORY_PATH  absolute path to the checked-out repo root
#

set -euo pipefail

cd "$CI_PRIMARY_REPOSITORY_PATH"

echo "==> Syncing marketing version from latest git tag"
./scripts/sync-version.sh

PBXPROJ="apple/EB Finder/EB Finder.xcodeproj/project.pbxproj"

echo "==> Stamping CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER"
sed -i.bak -E "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER;/g" "$PBXPROJ"
rm -f "$PBXPROJ.bak"

echo "==> Final versioning state:"
grep -E "(MARKETING_VERSION|CURRENT_PROJECT_VERSION)" "$PBXPROJ" | sort -u
