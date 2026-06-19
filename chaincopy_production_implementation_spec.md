# ChainCopy Production Implementation Spec

Document status: Production planning draft v1.0
Date: 2026-06-19
Related PRD: `chaincopy_macos_app_prd.md`
Target outcome: A premium, production-grade, sellable native macOS utility for chain-copy composition.

## 1. Product North Star

ChainCopy is a private, native macOS menu bar utility that lets a user collect many copied snippets, review or refine them, paste one composed block, and reset cleanly.

The product should feel closer to a polished system-level utility like Wispr Flow than to a hobby clipboard script:

- immediate and reliable in every app where possible;
- visible enough that users trust what it is doing;
- quiet enough to stay out of the way;
- premium native macOS look and behavior;
- production onboarding, settings, diagnostics, updates, signing, support, and licensing;
- privacy-first by design, not as marketing afterthought.

The first sellable release should include all P0 and most P1 features from the PRD. It should not become a generic clipboard history manager.

## 2. Baseline Assumptions

These are the working assumptions unless product direction changes:

- Product name: `ChainCopy`.
- Platform: macOS 14+ minimum, with macOS 26 Liquid Glass enhancements where available.
- Architecture: native Swift 6, SwiftUI first, narrow AppKit/CoreGraphics bridges.
- Distribution: direct-download first, Developer ID signed, notarized, Sparkle updates.
- Mac App Store: later parallel build with possible auto-paste fallback.
- Core clipboard contents: plain text in v1.
- Storage: no persistent clipboard content by default.
- Backend: not required for core app behavior.
- Monetization: one-time Pro unlock, direct license provider first.
- Telemetry: none by default; if added, opt-in and never include clipboard content.

## 3. Source And Reuse Strategy

### 3.1 Reuse Allowed With Attribution

The following references are MIT or otherwise suitable for code study and selective reuse, provided license notices are preserved:

- Batch Clipboard: closest product reference for batch mode, pasteboard filtering, accessibility onboarding, menu bar state, dual distribution, appcast/release setup.
- Maccy: pasteboard filtering, ignored pasteboard types, current pasteboard content extraction, keyboard-layout edge cases, hotkey/settings patterns.
- Hammerspoon: prototype logic and timing patterns, especially pasteboard `changeCount`, polling, copy timeout, hotkeys, and synthetic keystrokes.
- VibeMeter and CodexBar: menu bar shell, SwiftUI/AppKit split, settings, Sparkle integration, release automation, agent-friendly file organization.
- KeyboardShortcuts: dependency for global customizable shortcuts.
- Sparkle: dependency for direct-download updates.
- LaunchAtLogin-Modern: dependency for launch-at-login.

### 3.2 Reference Only, Do Not Copy Code

SaneClip is useful as a product and architecture reference, especially direct-download versus App Store behavior, accessibility fallback, privacy positioning, and release maturity. However, its license is not MIT-style for competing products. Do not copy SaneClip source into ChainCopy.

### 3.3 Extraction Rules

For each borrowed implementation idea:

- record the origin in `docs/third-party-references.md`;
- copy only small, necessary code when license-compatible;
- preserve license notices in `THIRD_PARTY_NOTICES.md`;
- prefer reimplementing around ChainCopy's own protocols rather than importing large foreign abstractions;
- do not inherit generic history-manager surface area.

## 4. Product Scope For Sellable V1

### 4.1 Core Workflows

1. Normal-first-copy workflow:
   - user presses `Cmd+C` normally for first item;
   - user presses `Ctrl+Cmd+C` for subsequent selected text;
   - ChainCopy seeds the prior clipboard item if chain is empty;
   - final paste joins all snippets and resets internal chain.

2. Explicit chain workflow:
   - user presses `Ctrl+Cmd+C` for every selected snippet;
   - chain starts immediately.

3. Copy button workflow:
   - user clicks Copy in ChatGPT, Claude, Codex, GitHub, docs, or web apps;
   - user presses `Ctrl+Cmd+Shift+C` to append current clipboard;
   - or toggles Append Mode and clicks multiple copy buttons.

4. Paste and reset workflow:
   - user presses `Ctrl+Cmd+V`;
   - app writes composed output to system clipboard;
   - app attempts auto-paste when permitted;
   - app clears internal chain after paste;
   - composed output remains on clipboard by default.

5. Review before paste workflow:
   - user opens popover or composer panel;
   - user edits, deletes, reorders, changes separator/profile;
   - user pastes or copies the final block.

### 4.2 Production Feature Set

#### Capture

- Append selected text.
- Append current clipboard.
- Toggle Append Mode.
- One-shot "Capture next clipboard change" command.
- Pause capture globally.
- Ignore own writes.
- Ignore duplicates.
- Ignore empty/unsupported/non-text data.
- Seed first chain item from previous clipboard when enabled.
- Source app capture using frontmost app and `org.nspasteboard.source` when available.
- Per-app capture rules.
- Max item size and max item count.
- Copy timeout handling with actionable fallback.

#### Compose

- Separator presets:
  - blank line;
  - newline;
  - space;
  - comma;
  - Markdown bullet list;
  - Markdown divider;
  - XML-ish tagged blocks;
  - custom separator.
- Profiles:
  - General;
  - Code;
  - Research;
  - AI Prompt;
  - Support Evidence;
  - Custom.
- Per-profile options:
  - separator;
  - trim whitespace;
  - preserve whitespace;
  - collapse repeated blank lines;
  - add source labels;
  - wrap code blocks;
  - include timestamps;
  - reset behavior.
- Live output preview.
- Copy joined block without paste.
- Paste joined block and reset.
- Paste joined block without reset.
- Clear chain.

#### Composer UI

- Preview current chain.
- Edit individual snippets.
- Delete individual snippets.
- Reorder snippets by drag and keyboard commands.
- Duplicate a snippet.
- Split a snippet by selection or delimiter.
- Merge selected snippets.
- Show source app, capture method, timestamp, and size.
- Toggle output transform/profile.
- Export chain as text or Markdown.
- Save composed result as a reusable template only if user explicitly chooses.

#### Menu Bar

- Always-visible status item while running.
- Idle state.
- Collecting count.
- Append Mode state.
- Paused state.
- Permission-needed state.
- Error state.
- Compact menu with core actions.
- Rich popover/panel for full composer.

#### Onboarding

- Explain the mental model in one screen.
- Show essential shortcuts.
- Teach copy-button support.
- Permission setup for Accessibility only when needed.
- Interactive test playground.
- Hotkey conflict detection.
- Privacy explanation.
- "I prefer manual paste" setup path.

#### Settings

- General.
- Shortcuts.
- Capture.
- Compose.
- Append Mode.
- Privacy.
- Profiles.
- Updates.
- Account or License.
- Advanced and Diagnostics.

#### Privacy And Safety

- No persistent clipboard content by default.
- No content analytics.
- No content logs by default.
- Ignore confidential and transient pasteboard types.
- Ignore known password/security apps by default.
- Optional content logging for 5 minutes with explicit warning.
- Clear chain on lock/sleep setting.
- Auto-clear after inactivity setting.
- Manual pause.
- Manual clear.
- Privacy policy and in-app privacy explainer.

#### Distribution And Commercial

- Signed and notarized direct-download app.
- Sparkle updates with stable and beta channels.
- Website and landing page.
- Privacy policy.
- Support email and diagnostics export.
- License provider integration.
- Trial and Pro unlock.
- Homebrew cask after stable launch.
- Optional Mac App Store edition later.

## 5. Premium macOS UX Direction

### 5.1 Overall Feel

ChainCopy should feel like a first-party-quality macOS utility: small, calm, precise, and fast. It should use system typography, semantic colors, native controls, keyboard navigation, and system materials. The premium feeling should come from correctness, fluidity, and restraint, not decorative chrome.

The Wispr Flow lesson is "system-level confidence": a small cross-app tool that works where the user already is, with a tight overlay, simple shortcuts, strong onboarding, and polished defaults.

### 5.2 Surfaces

#### Menu Bar Status Item

Purpose: ambient trust and fast access.

Behavior:

- idle: simple monochrome linked-copy icon;
- collecting: count badge in menu bar;
- append mode: highlighted icon or subtle active state;
- paused: dimmed icon;
- permission/error: small warning indicator.

Implementation:

- start with `MenuBarExtra` if sufficient;
- use AppKit `NSStatusItem` bridge if badge/status customization needs more control;
- keep menu labels short;
- never render raw long snippet text in the menu.

#### Quick HUD

Purpose: lightweight feedback after captures and paste.

Appearance:

- small floating Liquid Glass pill near the menu bar or focused screen center;
- shows count, latest source, and short confirmation;
- fades quickly;
- reduced-motion friendly;
- never blocks typing.

States:

- `Added 3`;
- `Append Mode On`;
- `Copied joined block`;
- `Paste blocked. Press Cmd+V`;
- `Ignored concealed clipboard`;
- `Copy timed out`;
- `Chain cleared`.

Implementation:

- SwiftUI floating borderless panel via AppKit window bridge;
- use system materials on macOS 14/15;
- add `glassEffect` on macOS 26+ where available;
- avoid custom opaque backgrounds.

#### Composer Popover Or Panel

Purpose: full chain control.

Layout:

- top status row: chain count, active profile, append mode toggle;
- main list: snippets with source badge, timestamp, and preview;
- right or bottom output preview depending on width;
- bottom command bar: Paste, Copy, Clear, profile selector.

Interaction:

- keyboard-first;
- drag reorder;
- delete with `Delete`;
- paste with `Cmd+Return` or configured shortcut;
- edit with `Return`;
- search/filter optional after v1 if composer gets dense.

Visual style:

- native density;
- system list rows, not stacked marketing cards;
- code snippets use a quiet monospace preview;
- source badges are subtle semantic labels;
- primary action uses glass-prominent/system-primary styling.

#### Settings Window

Purpose: complete configuration without feeling like a control panel spill.

Structure:

- native `Settings` scene;
- tabbed layout or sidebar layout depending final density;
- sections are compact and scannable;
- each setting has a clear default and reset path.

Suggested tabs:

- General;
- Shortcuts;
- Capture;
- Compose;
- Privacy;
- Updates;
- Account;
- Advanced.

#### Onboarding

Purpose: get to the first successful chain in under 90 seconds.

Flow:

1. Concept: "Copy normally. Append more. Paste one clean block."
2. Shortcuts: show defaults and allow quick customization.
3. Permission: explain Accessibility only for auto-copy and auto-paste.
4. Copy-button path: Append Current Clipboard and Append Mode.
5. Playground: Alpha, Beta, Gamma test with success animation.
6. Privacy: local-only and no persistent history by default.

#### Diagnostics Panel

Purpose: support without exposing content.

Content:

- app version, build, macOS version;
- permission status;
- hotkey registration status;
- append mode state;
- last 50 event metadata entries without clipboard content;
- ignored pasteboard type hits;
- copy timeout count;
- export diagnostic ZIP.

## 6. Liquid Glass And Native Design Rules

Use Liquid Glass as a system-native enhancement, not as a theme pasted on top.

Rules:

- use standard SwiftUI structures first;
- use system sidebars, toolbars, settings, controls;
- avoid custom opaque fills behind sidebars, toolbars, popovers, and sheets;
- use `glassEffect` only for custom surfaces like Quick HUD and compact action clusters;
- group related custom glass elements in one `GlassEffectContainer`;
- use semantic icon tint only;
- support Reduce Transparency, Increase Contrast, and Reduce Motion;
- provide macOS 14/15 fallback using `regularMaterial`, `thinMaterial`, and native vibrancy;
- do not make readability dependent on transparency.

## 7. Technical Architecture

### 7.1 App Shape

Recommended structure:

```text
ChainCopy/
  ChainCopy.xcodeproj
  ChainCopy/
    App/
    Core/
    Clipboard/
    Capture/
    Compose/
    Hotkeys/
    Permissions/
    Privacy/
    Settings/
    UI/
    Infrastructure/
    Licensing/
    Resources/
  ChainCopyTests/
  ChainCopyUITests/
  scripts/
  docs/
  website/
```

Use a normal Xcode app project for first-class macOS signing and notarization. Consider extracting `ChainCopyCore` as a Swift package only if it improves test isolation without complicating app lifecycle work.

### 7.2 Module Responsibilities

#### App

- `ChainCopyApp.swift`;
- `AppDelegate.swift`;
- activation policy;
- single-instance behavior;
- lifecycle notifications;
- lock/sleep handling;
- open settings/composer commands.

#### Core

- `ChainEngine`;
- `ChainItem`;
- `ChainComposer`;
- `CaptureMetadata`;
- `ChainProfile`;
- `ChainState`;
- pure logic only.

#### Clipboard

- `ClipboardServiceProtocol`;
- `NSPasteboardClipboardService`;
- `PasteboardSnapshot`;
- `PasteboardTypes`;
- `OwnWriteTracker`;
- `PasteboardChangeWaiter`.

#### Capture

- `CaptureService`;
- `AppendModeMonitor`;
- `EventSynthesizer`;
- `CGEventEventSynthesizer`;
- `SourceAppService`;
- `CaptureResult`.

#### Compose

- profile application;
- separator rendering;
- code fence wrapping;
- source label formatting;
- whitespace transforms.

#### Hotkeys

- KeyboardShortcuts names;
- default registrations;
- handlers;
- conflict status display;
- shortcut reset.

#### Permissions

- Accessibility checks;
- manual fallback state;
- deep links to System Settings;
- permission onboarding state;
- later Input Monitoring only if advanced event monitoring is added.

#### Privacy

- sensitive pasteboard filter;
- ignored apps;
- ignored pasteboard types;
- ignored regex;
- no-content diagnostics;
- auto-clear policies.

#### UI

- menu bar controller;
- quick HUD panel;
- composer panel/popover;
- settings;
- onboarding;
- diagnostics;
- shared components.

#### Infrastructure

- OSLog categories;
- diagnostic export;
- Sparkle updater;
- launch at login;
- app version/build metadata;
- release channel.

#### Licensing

- license state;
- trial state;
- Pro feature gates;
- license provider client;
- local signed license cache.

### 7.3 Core Interfaces

```swift
protocol ChainEngineProtocol: AnyObject {
    var items: [ChainItem] { get }
    var isEmpty: Bool { get }
    func append(_ text: String, metadata: CaptureMetadata) throws
    func update(id: ChainItem.ID, text: String) throws
    func remove(id: ChainItem.ID)
    func move(fromOffsets: IndexSet, toOffset: Int)
    func clear()
    func compose(profile: ChainProfile) throws -> String
}
```

```swift
protocol ClipboardServiceProtocol {
    var changeCount: Int { get }
    func readString() -> String?
    func readTypes() -> [String]
    func snapshot() -> PasteboardSnapshot
    func writeString(_ value: String, marker: PasteboardWriteMarker)
    func restore(_ snapshot: PasteboardSnapshot)
    func waitForChange(after oldChangeCount: Int, timeout: TimeInterval) async -> Bool
}
```

```swift
protocol EventSynthesizerProtocol {
    func sendCopy() async throws
    func sendPaste() async throws
}
```

```swift
protocol SensitivePasteboardFiltering {
    func decision(for snapshot: PasteboardInspection) -> PasteboardFilterDecision
}
```

### 7.4 State Model

Use one app-owned observable state model on the main actor:

```text
AppState
  chainState
  captureState
  appendModeState
  pasteState
  permissionState
  settingsState
  licenseState
  diagnosticsState
```

Keep non-UI services actor-isolated or explicitly serialized where needed. Pasteboard access can remain main-thread/AppKit-oriented if wrapped carefully and tested with mocks.

### 7.5 Key Reliability Patterns

- Use pasteboard `changeCount`, not fixed delays, to detect copy results.
- Use a timeout for synthetic copy.
- Track own writes by change count and marker type.
- Do not clear or restore clipboard immediately after paste unless explicitly configured.
- Leave composed output on clipboard by default.
- Detect permission failure and provide manual fallback.
- Poll pasteboard only in Append Mode or active capture windows.
- Serialize pasteboard reads/writes to avoid race conditions.
- Store content hashes instead of content in logs.

## 8. Workstreams

Each workstream should be owned by one primary agent at a time. Agents can run in parallel after interface contracts are defined. The integration owner merges frequently and keeps shared files stable.

### Stream A: Product, UX, And Design System

Owner profile: product/design-oriented agent.

Deliverables:

- `docs/product-v1-scope.md`;
- `docs/ux-flows.md`;
- `docs/design-system.md`;
- onboarding copy;
- settings taxonomy;
- state diagrams;
- icon brief;
- UI acceptance checklist.

Tasks:

- convert PRD into final v1 feature list;
- define Pro versus Free boundaries;
- define all empty/loading/error states;
- define composer layout for compact and expanded sizes;
- define Quick HUD behavior and timing;
- define menu bar states;
- define permission copy;
- define privacy language;
- define visual QA checklist.

Dependencies:

- none, can start immediately.

Acceptance:

- every feature has a user-facing surface and state;
- no feature depends on hidden behavior alone;
- UI rules include reduced motion/transparency/accessibility.

### Stream B: Project Bootstrap And Build System

Owner profile: macOS build/release agent.

Deliverables:

- Xcode project;
- app target;
- test targets;
- dependency setup;
- `scripts/build.sh`;
- `scripts/test.sh`;
- `scripts/lint.sh`;
- Codex run integration if needed.

Tasks:

- initialize git repository if not already initialized;
- create app project;
- set bundle ID;
- set macOS deployment target;
- add Swift Package dependencies:
  - KeyboardShortcuts;
  - LaunchAtLogin-Modern;
  - Sparkle behind release flag;
  - license SDK if selected;
- configure SwiftLint/formatting if desired;
- create app icon placeholder;
- create Info.plist and entitlements;
- add Debug and Release configs;
- add unit test target;
- add UI test target.

Dependencies:

- product name and bundle ID decision.

Acceptance:

- debug build runs;
- tests run;
- app launches as menu bar utility;
- no Dock icon by default unless setting enabled;
- build scripts work from clean checkout.

### Stream C: Reference Mining And Safe Reuse

Owner profile: research/code-reading agent.

Deliverables:

- `docs/reference-audit.md`;
- `THIRD_PARTY_NOTICES.md`;
- small reusable snippets or rewritten equivalents;
- risk notes for App Store/direct distribution.

Tasks:

- inspect Batch Clipboard clipboard service, app model, settings, entitlements, release scripts;
- inspect Maccy pasteboard type handling and keyboard layout handling;
- inspect Hammerspoon docs/source for timing and watcher behavior;
- inspect VibeMeter/CodexBar release and menu bar patterns;
- create "copy, rewrite, avoid" list;
- identify exact license obligations;
- flag SaneClip as reference-only.

Dependencies:

- none.

Acceptance:

- every borrowed idea has a source;
- no incompatible code copied;
- core engineers have concrete implementation notes.

### Stream D: Chain Engine And Compose Core

Owner profile: pure Swift/testing agent.

Deliverables:

- `ChainEngine`;
- `ChainItem`;
- `ChainProfile`;
- `ChainComposer`;
- `ContentHasher`;
- unit tests.

Tasks:

- append/update/delete/reorder items;
- duplicate suppression;
- max items;
- max bytes;
- whitespace transform;
- separator presets;
- source label rendering;
- code fence mode;
- profile model;
- compose preview;
- Codable settings models where needed.

Dependencies:

- initial model contracts from integration owner.

Acceptance:

- high unit coverage;
- no AppKit imports;
- deterministic output;
- large text tests;
- Unicode tests;
- profile snapshot tests.

### Stream E: Clipboard And Pasteboard Infrastructure

Owner profile: macOS systems agent.

Deliverables:

- `ClipboardServiceProtocol`;
- `NSPasteboardClipboardService`;
- `PasteboardSnapshot`;
- `OwnWriteTracker`;
- `PasteboardChangeWaiter`;
- tests with fake clipboard.

Tasks:

- read string;
- read pasteboard types;
- snapshot and restore;
- write string with own marker;
- wait for change count;
- support current-host-only writes where appropriate;
- preserve previous clipboard for restore option;
- handle non-text clipboard content safely;
- avoid content logs.

Dependencies:

- Stream D model contracts.

Acceptance:

- unit tests with fake pasteboard;
- manual test utility can show types without content;
- own writes do not append in Append Mode.

### Stream F: Capture And Automation

Owner profile: macOS permissions/event agent.

Deliverables:

- `CaptureService`;
- `AppendModeMonitor`;
- `EventSynthesizer`;
- `SourceAppService`;
- permission-gated append selected;
- capture result taxonomy.

Tasks:

- append current clipboard;
- append selected text via synthetic copy;
- copy timeout behavior;
- seed previous clipboard;
- append mode polling;
- one-shot next clipboard capture;
- source app detection;
- secure input/failure messaging;
- fallback to manual path.

Dependencies:

- Stream E clipboard infrastructure;
- Stream H permissions status.

Acceptance:

- works in TextEdit, Notes, Safari, Chrome, VS Code, Terminal, Slack, Notion;
- copy-button workflow works with append current and append mode;
- no mutation on timeout;
- no duplicate own writes;
- clear event results for UI.

### Stream G: Paste, Reset, And Output Delivery

Owner profile: macOS systems agent.

Deliverables:

- `PasteService`;
- paste mode settings;
- auto-paste and manual fallback;
- tests.

Tasks:

- compose output;
- write output to clipboard;
- send paste when permitted;
- clear internal chain after paste;
- leave/restore/clear clipboard based on setting;
- paste without reset;
- copy joined block;
- handle no chain state;
- App Store compile-time fallback path.

Dependencies:

- Stream D compose core;
- Stream E clipboard;
- Stream H permissions.

Acceptance:

- paste into major apps;
- manual fallback is clear and non-annoying;
- clipboard restore delay does not break paste;
- chain reset is correct.

### Stream H: Permissions, Privacy, And Safety

Owner profile: privacy/security macOS agent.

Deliverables:

- `PermissionManager`;
- `SensitivePasteboardFilter`;
- ignored apps/types settings;
- privacy docs;
- diagnostics redaction.

Tasks:

- Accessibility permission check and prompt flow;
- System Settings deep link;
- Input Monitoring research for future advanced modes;
- default ignored pasteboard types;
- default ignored app list;
- ignored regex;
- clear on lock/sleep;
- auto-clear after inactivity;
- pause mode;
- diagnostics without content;
- security/privacy threat model.

Dependencies:

- Stream E pasteboard inspection.

Acceptance:

- content never appears in logs by default;
- transient/concealed/autogenerated types ignored;
- 1Password and similar markers ignored;
- ignored app rules apply;
- permission denial has useful fallbacks.

### Stream I: Hotkeys And Commands

Owner profile: SwiftUI/AppKit desktop agent.

Deliverables:

- KeyboardShortcuts integration;
- shortcuts settings view;
- command routing;
- conflict UI.

Tasks:

- register defaults;
- allow disabling every hotkey;
- reset shortcuts;
- display shortcut equivalents in menu;
- route hotkeys to app actions;
- disable conflicting modes when composer text editing has focus if needed;
- expose app menu commands.

Dependencies:

- Stream B project setup;
- app action contracts.

Acceptance:

- no permission dialog for hotkeys;
- conflicts visible;
- shortcuts persist;
- all actions can be triggered via keyboard and UI.

### Stream J: Menu Bar, HUD, And Composer UI

Owner profile: UI-heavy macOS agent.

Deliverables:

- menu bar status item;
- compact menu;
- Quick HUD panel;
- composer popover/panel;
- snippet row components;
- output preview.

Tasks:

- implement status states;
- count badge;
- menu actions;
- HUD animations;
- composer list;
- edit/delete/reorder;
- profile selector;
- output preview;
- empty states;
- error states;
- keyboard navigation;
- VoiceOver labels.

Dependencies:

- Stream A UX decisions;
- Stream D models;
- Stream F/G action results.

Acceptance:

- professional in light/dark/high contrast;
- no text overflow;
- no UI overlap;
- reduced motion/transparency supported;
- all controls accessible by keyboard.

### Stream K: Settings And Preferences

Owner profile: SwiftUI settings agent.

Deliverables:

- native Settings scene;
- typed settings store;
- defaults migration;
- reset controls.

Tasks:

- General tab;
- Shortcuts tab;
- Capture tab;
- Compose tab;
- Privacy tab;
- Profiles tab;
- Updates tab;
- Account tab;
- Advanced tab;
- import/export settings.

Dependencies:

- settings schema from streams D, F, H, I, L.

Acceptance:

- every setting in PRD is represented or explicitly deferred;
- defaults are sane;
- settings changes apply live where appropriate;
- no need to relaunch except rare release-channel changes.

### Stream L: Licensing, Trial, And Commercial Packaging

Owner profile: commercial app agent.

Deliverables:

- license provider decision doc;
- trial model;
- Pro feature gates;
- purchase/activation UI;
- local license cache.

Tasks:

- choose Lemon Squeezy, Paddle, Gumroad, or custom signed license file;
- define free/basic limits;
- define trial duration;
- implement license activation;
- implement offline grace period;
- implement "manage license";
- ensure no clipboard content sent to license provider;
- support future App Store IAP abstraction.

Dependencies:

- business decision from product owner.

Acceptance:

- direct purchase flow works;
- app remains usable offline within policy;
- no core workflow broken by license check outage;
- Pro gates clear and tasteful.

### Stream M: Onboarding, Help, And Support

Owner profile: product/UI/support agent.

Deliverables:

- onboarding window;
- playground;
- help docs;
- troubleshooting docs;
- support diagnostic export.

Tasks:

- first-run flow;
- permission education;
- shortcut setup;
- copy-button education;
- Alpha/Beta/Gamma playground;
- "why paste did not happen" help;
- support email template;
- local help pages;
- in-app release notes.

Dependencies:

- Stream A copy;
- Stream H permission flow;
- Stream N diagnostics.

Acceptance:

- new user completes first successful chain in under 90 seconds;
- permission denial path still leaves user with manual workflows;
- help content is concise and accurate.

### Stream N: Diagnostics, Logging, And Observability

Owner profile: infrastructure agent.

Deliverables:

- OSLog categories;
- event log model;
- diagnostics panel;
- export diagnostic ZIP;
- optional crash reporting decision.

Tasks:

- define event taxonomy;
- log metadata only;
- hash content where necessary;
- track copy timeout and ignored events;
- export permissions/settings/system info;
- redact bundle paths if needed;
- optional opt-in crash reporting.

Dependencies:

- all service event contracts.

Acceptance:

- support can debug most issues without clipboard content;
- content logging requires explicit timed opt-in;
- diagnostic export is human-readable.

### Stream O: Release Engineering And Updates

Owner profile: release/build agent.

Deliverables:

- signing scripts;
- notarization scripts;
- DMG/ZIP packaging;
- Sparkle integration;
- appcast generation;
- release checklist;
- CI workflow.

Tasks:

- Developer ID signing;
- hardened runtime;
- entitlements;
- Sparkle EdDSA signing;
- stable/beta appcast;
- update-channel setting;
- GitHub Releases;
- DMG background/license;
- appcast validation;
- Gatekeeper validation;
- Homebrew cask draft.

Dependencies:

- Stream B project;
- Apple Developer credentials;
- release asset decisions.

Acceptance:

- clean machine install works;
- notarization stapled;
- Sparkle update from N to N+1 works;
- beta channel can be enabled;
- no scary launch warnings.

### Stream P: QA And Compatibility

Owner profile: QA automation/manual agent.

Deliverables:

- `docs/qa-matrix.md`;
- test plans;
- manual scripts;
- release acceptance report.

Tasks:

- unit tests;
- integration tests with fake pasteboard;
- UI tests for settings/composer;
- manual app matrix;
- permission denied tests;
- secure input tests;
- sleep/wake tests;
- lock/unlock tests;
- large snippet tests;
- Unicode tests;
- update tests;
- release build tests.

Dependencies:

- all feature streams.

Acceptance:

- no release without completed QA matrix;
- release build behavior tested, not only debug;
- critical bugs triaged before beta.

### Stream Q: Website, Brand, And Launch

Owner profile: web/product/marketing agent.

Deliverables:

- landing page;
- download page;
- privacy page;
- changelog page;
- support page;
- press kit basics.

Tasks:

- positioning;
- screenshots;
- demo GIF/video;
- pricing copy;
- privacy policy;
- terms/license;
- download and update links;
- docs for install/uninstall;
- affiliate/referral optional later.

Dependencies:

- final UI screenshots;
- pricing decision;
- release channel.

Acceptance:

- user can understand, download, install, buy, and get support;
- privacy claims match implementation;
- download link points to notarized build.

## 9. Parallel Execution Plan

### 9.1 Roles

Use one integration lead and multiple focused agents.

Recommended roles:

- Integration Lead: owns architecture, interfaces, merge order, build health.
- Product/Design Agent: Stream A and M.
- Core Agent: Stream D.
- macOS Systems Agent 1: Streams E and F.
- macOS Systems Agent 2: Streams G and H.
- UI Agent: Streams J and K.
- Release Agent: Streams B and O.
- Commercial Agent: Stream L and Q.
- QA Agent: Stream P and N.
- Reference Agent: Stream C.

### 9.2 Agent Working Rules

- One agent owns a file at a time.
- Shared interfaces are changed only by Integration Lead or through approved interface PR.
- Pure logic lands before UI that depends on it.
- Each stream has tests or a manual verification checklist.
- Every agent must update `docs/implementation-log.md` with decisions and caveats.
- Every merge must leave `scripts/build.sh` and `scripts/test.sh` passing.
- No agent copies source from non-compatible repositories.
- No agent adds clipboard-content logging.
- No generic clipboard history unless explicitly approved.

### 9.3 Branching Model

Suggested branches:

```text
main
  feature/bootstrap
  feature/core-chain
  feature/clipboard-service
  feature/capture-service
  feature/paste-service
  feature/privacy-permissions
  feature/hotkeys
  feature/menu-hud
  feature/composer-ui
  feature/settings
  feature/onboarding
  feature/licensing
  feature/release
  feature/website
```

Merge order:

1. bootstrap;
2. core-chain;
3. clipboard-service;
4. privacy-permissions;
5. hotkeys;
6. capture-service;
7. paste-service;
8. menu-hud;
9. composer-ui;
10. settings;
11. onboarding;
12. diagnostics;
13. licensing;
14. release;
15. website.

Streams can be developed in parallel, but merges should follow this dependency order.

## 10. Timeline

With 5-7 agents working in parallel, plan for 8-10 weeks to a polished paid launch. A credible private beta can happen around week 5 or 6 if release engineering starts early.

### Week 0: Decisions And Project Setup

- lock name, bundle ID, price/trial, license provider;
- create repository and Xcode project;
- clone/reference repos into `references/`;
- define architecture contracts;
- create build/test scripts;
- create design direction.

Exit:

- app launches;
- tests run;
- specs for streams are assigned.

### Week 1: Core And Vertical Slice Foundations

- ChainEngine complete;
- ClipboardService fake and real implementations;
- hotkey registration;
- basic menu bar status item;
- append current clipboard;
- compose output;
- copy joined block.

Exit:

- user can append current clipboard and copy composed output from a rough build.

### Week 2: Automation Vertical Slice

- append selected text;
- paste and reset;
- permission prompt/fallback;
- own write tracking;
- append mode MVP;
- first diagnostic event log.

Exit:

- full keyboard workflow works in several common apps.

### Week 3: Premium Composer And Settings

- composer panel;
- edit/delete/reorder;
- output preview;
- settings store;
- shortcuts settings;
- compose profiles;
- privacy settings.

Exit:

- app feels useful without debug tools.

### Week 4: Onboarding, Privacy, And Reliability

- onboarding playground;
- permission education;
- ignored apps/types;
- auto-clear;
- pause mode;
- lock/sleep behavior;
- manual QA matrix starts.

Exit:

- new users can self-onboard.

### Week 5: Commercial And Release Beta

- licensing/trial;
- Sparkle integration;
- notarized beta build;
- beta appcast;
- diagnostics export;
- support docs.

Exit:

- private beta can be distributed outside the development machine.

### Weeks 6-7: Polish And Compatibility

- visual refinements;
- Liquid Glass/macOS 26 enhancements;
- high-contrast/reduced-transparency;
- app compatibility fixes;
- large-snippet performance;
- copy-button matrix;
- settings refinements.

Exit:

- release candidate quality.

### Weeks 8-10: Launch

- landing page;
- screenshots/video;
- stable appcast;
- Homebrew cask draft;
- launch checklist;
- final privacy/legal;
- support workflows.

Exit:

- public paid direct-download launch.

## 11. Quality Gates

### Engineering Gates

- `scripts/build.sh` passes.
- `scripts/test.sh` passes.
- no clipboard content in logs by default.
- no persistent clipboard content unless explicitly user-saved.
- no always-on clipboard polling unless user enables a mode that requires it.
- all hotkeys customizable or disable-able.
- direct build signed and notarized before beta.
- Sparkle update tested before launch.

### UX Gates

- first successful chain within 90 seconds from fresh install;
- no confusing state where app is silently capturing;
- Append Mode visibly active;
- paste fallback understandable;
- settings are complete but not overwhelming;
- UI works in Light, Dark, Increase Contrast, Reduce Transparency, Reduce Motion.

### Reliability Gates

Manual matrix includes:

- TextEdit;
- Notes;
- Safari;
- Chrome;
- Arc;
- Firefox;
- ChatGPT web;
- Claude web;
- Codex/Cursor surfaces;
- GitHub;
- VS Code;
- Cursor;
- Terminal;
- iTerm2;
- Slack;
- Notion;
- Google Docs;
- Mail;
- Gmail web;
- Linear/Jira;
- Preview PDF text;
- Microsoft Word;
- Obsidian.

Scenarios:

- selected text append;
- copy button append current;
- append mode copy buttons;
- paste into web app;
- paste into terminal;
- duplicate suppression;
- sensitive password copy;
- huge stack trace;
- Unicode text;
- Markdown code block;
- secure input failure;
- sleep/wake;
- lock/unlock;
- denied Accessibility;
- hotkey conflict;
- release build.

## 12. Settings Inventory

### General

- launch at login;
- show Dock icon;
- show notifications: all, errors only, never;
- show Quick HUD;
- auto-clear after inactivity;
- clear on lock/sleep;
- default profile;
- default paste action.

### Shortcuts

- append selected text;
- append current clipboard;
- toggle append mode;
- capture next clipboard change;
- paste and reset;
- paste without reset;
- copy joined block;
- clear chain;
- pause/resume;
- open composer;
- reset defaults.

### Capture

- seed from previous clipboard;
- duplicate suppression;
- trim copied text;
- max item size;
- max chain items;
- append mode polling interval;
- append mode auto-off after paste;
- append mode auto-off after inactivity;
- capture source app.

### Compose

- profile selector;
- separator;
- custom separator;
- whitespace rules;
- source label format;
- code fence behavior;
- timestamp behavior;
- output preview options.

### Privacy

- never persist clipboard contents;
- ignored apps;
- ignored pasteboard types;
- ignored text regex;
- ignored source bundles;
- pause capture;
- clear current chain;
- content logging timed opt-in.

### Updates

- check for updates;
- automatic updates;
- include beta updates;
- current version/build;
- release notes.

### Account

- license status;
- trial status;
- activate license;
- deactivate license;
- manage purchase;
- restore purchase later for App Store edition.

### Advanced

- permission status;
- test copy-selected;
- test paste;
- diagnostics export;
- reset app settings;
- reset onboarding;
- reveal logs;
- debug event stream.

## 13. Direct Download Versus Mac App Store

### Direct Download

Primary channel.

Capabilities:

- auto-paste with Accessibility permission;
- Sparkle auto-updates;
- direct licensing;
- faster release iteration;
- fewer sandbox constraints.

Requirements:

- Developer ID certificate;
- hardened runtime;
- notarization;
- Sparkle EdDSA update signing;
- privacy policy;
- clear permission onboarding.

### Mac App Store

Later channel.

Potential differences:

- sandboxed;
- StoreKit licensing;
- App Store updates;
- auto-paste may become copy-only fallback depending review and implementation;
- additional review scrutiny around clipboard and Accessibility.

Implementation:

- compile-time build configuration;
- shared core;
- separate entitlement profile;
- feature flag for auto-paste;
- separate onboarding copy.

## 14. Open Decisions For Product Owner

The plan can proceed with assumptions, but these decisions should be locked early:

1. Final product name and bundle ID.
2. Minimum OS: macOS 14+ only, or macOS 13+.
3. Price and trial: suggested $9-12 one-time with 14-day trial.
4. License provider: Lemon Squeezy, Paddle, Gumroad, or signed offline keys.
5. Whether Append Mode is free or Pro.
6. Whether source labels/code profiles are Pro.
7. Whether to include saved templates in v1 or v1.1.
8. Whether to build a Mac App Store edition before or after direct launch.
9. Whether the app will be open source, source-available, or closed.
10. Whether to include optional crash reporting.

Recommended defaults:

- ChainCopy name;
- macOS 14+;
- direct-download first;
- $9 one-time launch price, later $12;
- 14-day full trial;
- Append Mode and Composer editing in Pro;
- no persistent saved chains in v1 unless user explicitly exports/saves;
- no crash/content telemetry by default.

## 15. First Agent Tickets

### Ticket 1: Bootstrap Repository And Xcode Project

Create the native macOS app skeleton, build/test scripts, dependencies, and initial app shell.

### Ticket 2: Reference Audit

Audit Batch Clipboard, Maccy, Hammerspoon, VibeMeter, CodexBar, and SaneClip. Produce copy/rewrite/avoid notes.

### Ticket 3: Chain Engine

Implement pure Swift chain model, profiles, composition, duplicate suppression, and tests.

### Ticket 4: Clipboard Service

Implement pasteboard wrapper, fake pasteboard, own write tracking, snapshots, and tests.

### Ticket 5: Hotkeys

Add KeyboardShortcuts names, defaults, handlers, and shortcut settings UI stub.

### Ticket 6: Append Current Vertical Slice

Append current clipboard, show count in menu bar, compose and copy joined output.

### Ticket 7: Append Selected And Paste

Synthetic copy/paste with Accessibility gating and fallback.

### Ticket 8: Append Mode

Visible append mode with scoped polling, own-write ignoring, privacy filtering, and menu/HUD state.

### Ticket 9: Composer UI

Premium native composer panel with edit, reorder, delete, profile selector, and output preview.

### Ticket 10: Production Onboarding

First-run flow, permission setup, shortcut intro, copy-button education, and playground.

## 16. Launch Definition Of Done

ChainCopy is launch-ready when:

- all core workflows work from a fresh install;
- direct-download build is signed, notarized, and updateable;
- onboarding successfully guides a non-technical user;
- composer and settings feel production-grade;
- privacy defaults are implemented, tested, and documented;
- QA matrix is complete;
- license/trial flow works;
- website/download/privacy/support pages are live;
- support diagnostics are useful without content exposure;
- no P0/P1 known issues remain;
- app feels fast, quiet, and trustworthy after a full workday of use.

