#!/usr/bin/env bash
#
# Sync the marketing version (CFBundleShortVersionString) across:
#   - extension/manifest.json            "version" field
#   - apple/EB Finder/.../project.pbxproj MARKETING_VERSION (all targets)
#
# Source of truth: the most recent git tag matching `vX.Y.Z`.
#
# Build number (CFBundleVersion) is NOT touched — that's owned by Xcode Cloud
# via $CI_BUILD_NUMBER, stamped in ci_scripts/ci_post_clone.sh.
#
# Usage:
#   scripts/sync-version.sh           sync to latest tag
#   scripts/sync-version.sh v0.2.0    sync to a specific tag/version
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

MANIFEST="extension/manifest.json"
PBXPROJ="apple/EB Finder/EB Finder.xcodeproj/project.pbxproj"

if [[ $# -ge 1 ]]; then
  TAG="$1"
else
  TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"
fi

if [[ -z "$TAG" ]]; then
  echo "error: no git tag found and none provided" >&2
  echo "        cut a release tag first:  git tag v0.1.0 && git push --tags" >&2
  exit 1
fi

VERSION="${TAG#v}"

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: tag $TAG doesn't look like vX.Y.Z (got version $VERSION)" >&2
  exit 1
fi

echo "Syncing marketing version → $VERSION (from tag $TAG)"

# Cross-platform in-place sed via .bak suffix (works on BSD/macOS and GNU sed).
sed -i.bak -E "s/(\"version\"[[:space:]]*:[[:space:]]*\")[^\"]+(\")/\1$VERSION\2/" "$MANIFEST"
rm -f "$MANIFEST.bak"

sed -i.bak -E "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $VERSION;/g" "$PBXPROJ"
rm -f "$PBXPROJ.bak"

echo "Done."
echo "  manifest.json: $(grep -E '"version"' "$MANIFEST" | head -1 | xargs)"
echo "  pbxproj:       $(grep -E 'MARKETING_VERSION' "$PBXPROJ" | head -1 | xargs)"
