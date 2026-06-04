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
brew install xcodegen   # once
make                    # generates EB Finder/EB Finder.xcodeproj
make open               # generate, then open in Xcode
```

Re-run `make` whenever you pull changes that touch `project.yml`. The app version
lives in [`EB Finder/Config/Version.xcconfig`](EB%20Finder/Config/Version.xcconfig);
release tooling keeps it in sync from git tags.

The project ships **without a signing identity** so anyone can build it. To run on
a **physical device**, drop your Apple Developer team into a git-ignored
`EB Finder/Config/Signing.local.xcconfig`:

```
DEVELOPMENT_TEAM = YOURTEAMID
```

Simulator builds need nothing. (Xcode Cloud injects its own signing for releases.)
