# HogShot

[![CI](https://github.com/dreamkhv/hogshot/actions/workflows/ci.yml/badge.svg)](https://github.com/dreamkhv/hogshot/actions/workflows/ci.yml)

A macOS menu-bar screenshot & annotation tool. Lives in the menu bar (no Dock icon),
triggered by a global hotkey.

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

- macOS (deployment target: 27.0, per the Xcode project)
- Xcode 26+ to build

## Build & run

```bash
open HogShot.xcodeproj                                        # develop/run from Xcode (⌘R)
xcodebuild -project HogShot.xcodeproj -scheme HogShot build    # app only
xcodebuild -project HogShot.xcodeproj -scheme HogShot test     # full test suite (⌘U in Xcode)
```

## Permissions

The first capture prompts for Screen Recording access
(System Settings → Privacy & Security → Screen Recording).

## Author

Ivan Baranovskii

## License

MIT — see [LICENSE](LICENSE).
