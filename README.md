# HogShot

[![CI](https://github.com/dreamkhv/hogshot/actions/workflows/ci.yml/badge.svg)](https://github.com/dreamkhv/hogshot/actions/workflows/ci.yml)

A macOS menu-bar screenshot & annotation tool. Lives in the menu bar (no Dock icon),
triggered by a global hotkey.

## Download

Signed & notarized builds are published to
[Releases](https://github.com/dreamkhv/hogshot/releases) for every tagged version —
download `HogShot-vX.Y.Z.zip`, unzip, and move `HogShot.app` to `/Applications`.

## Features

- Global hotkey (⌘9 by default, configurable in Settings) — works without Accessibility
  permission, via the classic Carbon hot key API
- Full-screen overlay: drag to select a region, resize/move the selection
- Annotation tools: arrow, rectangle, ellipse, line, pen, text, highlighter, pixelate
- Undo/redo
- Copy to clipboard or save as PNG
- Settings: hotkey, default annotation color, default line width, post-capture action
- Interface language: Russian or English, switchable in Settings independently of the
  system language

## Requirements

- macOS 14.0 (Sonoma) or later — the app's real minimum, set by
  `SCScreenshotManager.captureImage`
- Xcode 16+ to build

## Build & run

```bash
open HogShot.xcodeproj                                        # develop/run from Xcode (⌘R)
xcodebuild -project HogShot.xcodeproj -scheme HogShot build    # app only
xcodebuild -project HogShot.xcodeproj -scheme HogShot test     # full test suite (⌘U in Xcode)
```

## Permissions

The first capture prompts for Screen Recording access
(System Settings → Privacy & Security → Screen Recording).

## Releasing (maintainers)

Pushing a tag matching `v*` (e.g. `v1.0.0`) triggers
[`.github/workflows/release.yml`](.github/workflows/release.yml), which runs the test
suite, archives a Release build, signs it with a Developer ID Application certificate,
notarizes and staples it, then publishes `HogShot-vX.Y.Z.zip` to a new GitHub Release.

```bash
git tag v1.0.0
git push origin v1.0.0
```

This needs the following repository secrets (Settings → Secrets and variables →
Actions), set up once:

| Secret | What it is |
| --- | --- |
| `APPLE_TEAM_ID` | Your Apple Developer Team ID (Membership page on developer.apple.com) |
| `MACOS_CERTIFICATE_P12` | A "Developer ID Application" certificate + private key, exported from Keychain Access as `.p12`, then base64-encoded (`base64 -i cert.p12 \| pbcopy`) |
| `MACOS_CERTIFICATE_PASSWORD` | The password you set when exporting the `.p12` |
| `KEYCHAIN_PASSWORD` | Any password — used only to protect the temporary CI keychain for the duration of the job |
| `NOTARY_API_KEY_P8` | An App Store Connect API key (Users and Access → Integrations → App Store Connect API), `.p8` file, base64-encoded |
| `NOTARY_KEY_ID` | That API key's Key ID |
| `NOTARY_ISSUER_ID` | That API key's Issuer ID |

## Author

Ivan Baranovskii

## License

MIT — see [LICENSE](LICENSE).
