# Kibo — Project Status

## Current Milestone: Phase 1 — Native Application Foundation

### Vision & Objective
Build a lightweight, exceptionally fast, keyboard-first macOS productivity utility combining clipboard history, prompt management, text snippets, and universal text insertion, following the BAMA framework.

### Status & Progress
- [x] **Phase 0 — Product & Architecture Planning**
  - Read and applied BAMA skills (`bama`, `app-brief`, `new-mac-app`, `swift-swiftui`, `os-integrations`, `mac-design`, `design-system`).
  - Architecture plan approved: SwiftData persistence, `NSPanel` non-activating floating panel, clipboard-assisted insertion, listen-only `CGEvent` tap for triggers.
  - Phasing order: Snippets & Foundation -> Floating Panel & Insertion -> Trigger Engine -> Clipboard History.
- [/] **Phase 1 — Native Application Foundation**
  - Scaffolded native macOS Swift Package (`Kibo` + `KiboKit`).
  - Target configured: macOS 15+ (`.macOS(.v15)`), Swift 6 language mode.
  - Concurrency: `@MainActor` default isolation in executable target.
  - App Lifecycle: Menu bar utility (`LSUIElement = YES`), `MenuBarExtra` with system clipboard icon, on-demand main window.
  - Data Model: Initial `Snippet` `@Model` with UUID identifier, audit dates, favourite flag, and usage count.
  - Library Target (`KiboKit`): `SnippetAlias` validation logic and unit test suite.
  - Navigation: `NavigationSplitView` with sidebar (Clipboard placeholder, Snippets, Favourites).
  - Settings (⌘,): Tabs for General (login item toggle, retention limits), Appearance (accent color swatches), and Permissions (Accessibility & Input Monitoring status indicators with deep links to System Settings).
  - Design tokens: 4pt grid spacing (`Space`), Apple system controls, `ThemeStore` with system accent default.
  - In progress: Compiling initial build and packaging into `~/Applications/Kibo.app`.

### Key Technical Decisions
1. **Target**: macOS 15+ for modern SwiftData, `@Observable`, and wide Sequoia/future compatibility.
2. **Persistence**: SwiftData container stored in `~/Library/Application Support/Kibo/Kibo.store`.
3. **App Architecture**: Menu bar extra (`MenuBarExtra`) + `Window("Kibo", id: "main")`. Kept alive when main window closes (`applicationShouldTerminateAfterLastWindowClosed = false`).
4. **Library Target Separation**: Pure logic in `KiboKit` (no SwiftUI/AppKit dependency) for fast, isolated unit testing.

### Next Actions
1. Confirm initial compilation and packaging of `Kibo.app`.
2. Run unit tests (`swift test`) and self-test verification.
3. Verify menu bar and main window launch behavior.
