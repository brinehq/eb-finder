#!/usr/bin/env bash
#
# Xcode Cloud post-clone hook.
#
# Apple runs this once per workflow execution, immediately after the repo is
# checked out and before Xcode resolves dependencies. Xcode Cloud looks for the
# ci_scripts folder NEXT TO the .xcodeproj — and this project is generated in the
# "EB Finder/" subdirectory — so this script must live at
# "EB Finder/ci_scripts/ci_post_clone.sh", NOT the repo root (a repo-root
# ci_scripts is silently ignored when the project lives in a subdirectory, which
# is why the first tag build failed at "Resolve package dependencies"). All paths
# below resolve from $CI_PRIMARY_REPOSITORY_PATH (the repo root), so the script's
# logic is unaffected by where ci_scripts sits.
#
# What we do here:
#   1. Install a pinned XcodeGen and generate "EB Finder.xcodeproj" from
#      project.yml — the project file is generated, never committed.
#   2. Stamp MARKETING_VERSION with the UTC build date (YYYY.M.D). Versions are
#      calendar-based and fully automatic — no tags or bumps. (The extension's
#      manifest.json derives its version from MARKETING_VERSION via a build phase
#      in project.yml, so it's stamped automatically too, local builds included.)
#   3. Stamp CURRENT_PROJECT_VERSION (CFBundleVersion) with Xcode Cloud's own
#      unique build number ($CI_BUILD_NUMBER).
#
# Version keys live in EB Finder/Config/Version.xcconfig and are read at build
# time. Nothing secret is committed: signing identity is NOT in the repo —
# DEVELOPMENT_TEAM lives only in the git-ignored Config/Signing.local.xcconfig
# (composed via `#include?` from Config/Build.xcconfig). For Archive actions
# Xcode Cloud manages distribution signing automatically, so no team is needed
# by default; the optional DEVELOPMENT_TEAM env var below is an escape hatch.
#
# Env vars provided by Xcode Cloud:
#   CI_BUILD_NUMBER             monotonically-increasing integer per workflow run
#   CI_PRIMARY_REPOSITORY_PATH  absolute path to the checked-out repo root
#
# Optional env vars (set under Workflow → Environment in App Store Connect;
# mark secret values as such). Unset → the step is skipped, no change in
# behavior:
#   DEVELOPMENT_TEAM            Apple Developer Team ID. When set, written into
#                              Config/Signing.local.xcconfig so the build picks
#                              up the team. Leave unset to let Xcode Cloud
#                              manage signing.
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

echo "==> Stamping calendar version (UTC build date) + build number"
# Marketing version = UTC build date with no leading zeros (e.g. 2026.6.4), a
# valid 1-3 integer CFBundleShortVersionString that increases day-over-day.
# 10# forces base-10 so a leading-zero month/day (08, 09) doesn't trip bash's
# octal parser. Same-day builds are made unique by CURRENT_PROJECT_VERSION below.
VERSION="$(date -u +%Y).$((10#$(date -u +%m))).$((10#$(date -u +%d)))"
echo "    MARKETING_VERSION = $VERSION"
sed -i.bak -E "s/^MARKETING_VERSION = .*/MARKETING_VERSION = $VERSION/" "$VERSION_XCCONFIG"
rm -f "$VERSION_XCCONFIG.bak"
# The extension manifest's version is derived from MARKETING_VERSION at build
# time by the "Stamp manifest version" phase (project.yml) — nothing to do here.

echo "==> Stamping CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER"
sed -i.bak -E "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER/" "$VERSION_XCCONFIG"
rm -f "$VERSION_XCCONFIG.bak"

# Optional signing-team injection. The xcconfig is git-ignored and read at build
# time via `#include?` in Config/Build.xcconfig, so this composes without
# touching project.yml — plain `xcodegen generate` keeps working with no env set.
if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  echo "==> Writing Config/Signing.local.xcconfig from \$DEVELOPMENT_TEAM"
  printf 'DEVELOPMENT_TEAM = %s\n' "$DEVELOPMENT_TEAM" > "EB Finder/Config/Signing.local.xcconfig"
else
  echo "==> DEVELOPMENT_TEAM not set — leaving signing to Xcode Cloud"
fi

echo "==> Generating Xcode project from project.yml"
( cd "EB Finder" && "$XCODEGEN" generate )

echo "==> Final versioning state:"
grep -E "^(MARKETING_VERSION|CURRENT_PROJECT_VERSION)" "$VERSION_XCCONFIG"
