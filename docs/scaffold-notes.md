# ChainCopy Scaffold Notes

Date: 2026-06-19

## Decisions

- Product name: `ChainCopy` for now.
- Bundle ID: `com.abhinavgupta.ChainCopy`.
- Minimum macOS: 14.0.
- Distribution path: direct download first.
- Code signing for local development: ad hoc signing with hardened runtime enabled.
- License provider: not configured in the scaffold; evaluate before paid beta.
- Project shape: XcodeGen-managed native SwiftUI macOS app.
- Default UI posture: menu bar utility with an on-demand main window and Settings scene.

## Why XcodeGen

XcodeGen gives us a production-shaped Xcode project without hand-editing generated project files. It also keeps parallel agent work cleaner because source, build settings, and CI are reviewable as text.

## First Functional Slice

- Poll `NSPasteboard.general.changeCount`.
- Capture plain text when the pasteboard changes.
- Avoid recapturing ChainCopy's own composed pasteboard writes.
- Show recent copied snippets in a menu bar window.
- Compose captured text using a configurable separator.
- Copy the composed chain back to the pasteboard.

## Immediate Gaps

- No global hotkeys yet.
- No Accessibility/Input Monitoring onboarding yet.
- No rich text, images, files, or source-app exclusion rules yet.
- No persistence yet.
- No Sparkle update feed yet.
- No licensing provider yet.
- No release signing/notarization automation yet.

## Parallel Workstreams Ready Next

- Capture engine: pasteboard type support, ignored marker types, source app rules, privacy filters.
- Hotkeys and paste automation: KeyboardShortcuts, Accessibility onboarding, paste verification.
- UI polish: premium menu bar HUD, composer panel, settings, iconography, motion.
- Persistence: local encrypted or plaintext store decision, history limits, retention policy.
- Distribution: Sparkle, signing, notarization, DMG/ZIP packaging, GitHub Releases.
- Commercial: license provider evaluation, activation flow, trial policy, support diagnostics.
