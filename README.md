# ChainCopy

ChainCopy is a native macOS menu bar app for building a clean chain of copied text and pasting it as one composed block.

This repository is in early product scaffolding. It is public for CI visibility, but no open-source license has been granted yet.

## Current Scaffold

- Native SwiftUI macOS app generated with XcodeGen.
- Menu bar extra with capture, copy-composed, and clear controls.
- Main Chain window and Settings scene.
- Pasteboard polling service with self-write suppression.
- Unit tests for text composition.
- Project-local build/run script for Codex and local development.

## Requirements

- macOS 14.0 or newer at runtime.
- Xcode with macOS SDK.
- XcodeGen available locally: `brew install xcodegen`.

## Build

```sh
./script/build_and_run.sh
```

For tests:

```sh
xcodegen generate
xcodebuild -project ChainCopy.xcodeproj -scheme ChainCopy -destination 'platform=macOS' test
```

## Product Direction

The production target is a direct-download, notarized macOS utility with polished onboarding, customizable global hotkeys, privacy-first clipboard handling, Sparkle updates, and commercial licensing.
