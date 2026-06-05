# Contributing

A proper contributor guide is coming. The project is still in early alpha and
the workflow is being figured out as we go.

In the meantime:

- **Bug reports and feedback** — join the Messenger community group:
  <https://m.me/cm/AbYqbMSdJHLmDqnD>.
- **Code contributions** — open a GitHub issue first so we can discuss the
  change before you spend time on a PR.

## Building the app

The Xcode project is **generated** from [`EB Finder/project.yml`](EB%20Finder/project.yml)
with [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `EB Finder.xcodeproj` is
not committed, so it can never cause a merge conflict.

```sh
brew install xcodegen          # once
cd "EB Finder"
xcodegen generate              # writes EB Finder.xcodeproj (git-ignored)
open "EB Finder.xcodeproj"
```

Re-run `xcodegen generate` from the `EB Finder/` folder whenever you pull changes
that touch `project.yml`. Versions are automatic — see [Releases](#releases)
below; [`EB Finder/Config/Version.xcconfig`](EB%20Finder/Config/Version.xcconfig)
only holds the local fallback.

The project ships **without a signing identity** so anyone can build it. To run on
a **physical device**, drop your Apple Developer team into a git-ignored
`EB Finder/Config/Signing.local.xcconfig`:

```
DEVELOPMENT_TEAM = YOURTEAMID
```

Simulator builds need nothing. (Xcode Cloud injects its own signing for releases.)

## Releases

There's nothing to manage — **versions are calendar-based and fully automatic**:

- The version is the **UTC build date** (`CFBundleShortVersionString`, e.g.
  `2026.6.4`) plus Xcode Cloud's **build number** (`CFBundleVersion`). Both are
  stamped at build time by
  [`EB Finder/ci_scripts/ci_post_clone.sh`](EB%20Finder/ci_scripts/ci_post_clone.sh) — no tags, no
  version bumps, no release commits.
- The extension's `manifest.json` version is **derived from `MARKETING_VERSION`**
  by the "Stamp manifest version" Xcode build phase (defined in `project.yml`),
  so the app and extension always share one version — on local builds too. The
  committed `manifest.json` carries only a `0.0.0` placeholder.
- Xcode Cloud builds when you **cut a release** — push a `v*` tag (e.g.
  `gh release create v2026.6.5 --generate-notes`) and the build uploads to
  TestFlight. Merging to `main` does not build.
- "Releasing" is just promoting a build to TestFlight or the App Store from App
  Store Connect whenever you choose — the repo plays no part in shipping.

`MARKETING_VERSION` in
[`EB Finder/Config/Version.xcconfig`](EB%20Finder/Config/Version.xcconfig) is only
the fallback for local builds; shipped builds are stamped fresh from the date.
