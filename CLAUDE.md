# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A macOS menu-bar screenshot & annotation app (Swift/SwiftUI + AppKit). No Dock icon
(`LSUIElement = YES`); it lives in the menu bar and is driven by a global hotkey
(⌃⇧A). Flow: press hotkey → capture all displays → full-screen overlay per display for
drag-to-select + annotate → copy to clipboard or save as PNG.

There is no README; this file and the source are the only documentation.

## Build / run

Two targets: `HogShot` (the macOS app) and `HogShot Tests` (`HogShotTests/`, XCTest,
hosted in the app via `TEST_HOST`/`BUNDLE_LOADER`). A shared scheme
(`HogShot.xcodeproj/xcshareddata/xcschemes/HogShot.xcscheme`) builds and tests both.

```bash
open HogShot.xcodeproj                                            # develop/run from Xcode (⌘R)
xcodebuild -project HogShot.xcodeproj -scheme HogShot build       # app only
xcodebuild -project HogShot.xcodeproj -scheme HogShot test        # full test suite (⌘U in Xcode)
```

Requires full Xcode (not just CLT) — `xcodebuild` needs `xcode-select -s
/Applications/Xcode.app/Contents/Developer` if the active developer dir is the
command-line-tools instance.

`ScreenCaptureServiceTests.test_captureAllDisplays_returnsOneNonEmptyCapturePerScreen`
exercises real `ScreenCaptureKit` capture and self-skips (`XCTSkipUnless`) unless Screen
Recording permission has already been granted to the test-runner process — that grant
can only happen through the interactive system dialog, not headlessly.

Screen-recording permission (`ScreenPermissions.swift`, backed by
`CGPreflightScreenCaptureAccess`) must be granted to the built app for capture to work;
the first capture attempt prompts for it.

### Test-only seams

Two things were relaxed from `private` specifically so `HogShotTests` can drive them
without duplicating app logic — not general-purpose API surface:
- `Preferences.init(defaults:)` takes a `UserDefaults` (default `.standard`) instead of
  hardcoding it, so tests can point a fresh instance at an isolated suite.
- `OverlayView.currentTool` is internal instead of private, so tests can select a tool
  the way a click on the SwiftUI toolbar would, without hosting that toolbar.

## Architecture

One capture-to-export pipeline, organized as one folder per stage:

- **App/** — `ScreenshotApp` (MenuBarExtra scene + Settings scene) and `AppDelegate`,
  which owns the hotkey and kicks off `startCapture()`.
- **Hotkey/** — `GlobalHotkey` wraps the Carbon `RegisterEventHotKey` API rather than
  `NSEvent.addGlobalMonitorForEvents`, specifically because it fires without a key
  window and doesn't require Accessibility permission.
- **Capture/** — `ScreenCaptureService` uses `ScreenCaptureKit`
  (`SCScreenshotManager.captureImage`) to grab a still `CGImage` per connected display,
  paired with the `NSScreen` it came from. `ScreenPermissions` gates this.
- **Overlay/** — one borderless, always-on-top `OverlayWindow` per display
  (`.screenSaver` level, joins all Spaces). `OverlayView` is the real controller: drag
  selection, resize/move via `ResizeHandle`, per-tool annotation drawing, undo/redo,
  keyboard shortcuts (Esc cancel, Enter finish, ⌘C/⌘S/⌘Z/⇧⌘Z), and hosts
  `OverlayToolbarView` (SwiftUI, embedded via `NSHostingView`) positioned next to the
  selection. `OverlaySession` fans capture-to-window-per-display out and back in,
  tearing everything down and forwarding the result to `ExportService` via the
  `OverlayViewDelegate` callback.
- **Annotations/** — `Annotation` is the tool-agnostic data model (points + style);
  `AnnotationRenderer` draws a list of them into a `CGContext`. This renderer is shared
  verbatim between the live overlay preview and the final flattened export, so the two
  can never visually drift apart.
- **Export/** — `ExportService` crops to the selection and re-draws the annotations onto
  the crop (via `AnnotationRenderer`) to produce the final flattened `CGImage`, then
  either copies it to the pasteboard or drives an `NSSavePanel`.
- **Settings/** — `Preferences` is a `UserDefaults`-backed `ObservableObject` singleton
  (default color, default line width, post-capture action); `SettingsView` edits it.

### The coordinate-space contract (read before touching drawing code)

Annotation points, selection rects, and everything `AnnotationRenderer` touches live in
**source-image pixel space** (top-left origin, y-down) — never view points. This is
deliberate so the on-screen preview and the exported PNG can never diverge on Retina
displays. Consequences:

- `OverlayView` converts view points to pixel space via `pixelScale` in exactly one
  place (`pixelPoint(from:)` / `viewRect(fromPixels:)`); don't scatter more scale math
  elsewhere.
- `OverlayView.isFlipped == true` gives it the y-down convention for free; any *new*
  off-screen bitmap context (as `ExportService` already does) must apply the flip
  transform manually right after creation.
- `CGImage` draws need one extra local flip on top of the ambient one — always route
  them through `AnnotationRenderer.drawImageRightSideUp(_:in:ctx:)`, never
  `ctx.draw(_:in:)` directly, or the image renders upside down.

### Screenshots (Russian only)

All user-facing strings (menu items, settings, alerts) are in Russian — match that when
adding UI text.
