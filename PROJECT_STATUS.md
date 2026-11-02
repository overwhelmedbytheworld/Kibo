# Kibo — Project Status

## Current Milestone: Phase 1 — Native Application Foundation (COMPLETE)

### Vision & Objective
Build a lightweight, exceptionally fast, keyboard-first macOS productivity utility combining clipboard history, prompt management, text snippets, and universal text insertion, following the BAMA framework.

### Status & Progress
- [x] **Phase 0 — Product & Architecture Planning**
  - Read and applied BAMA skills (`bama`, `app-brief`, `new-mac-app`, `swift-swiftui`, `os-integrations`, `mac-design`, `design-system`).
  - Architecture plan approved: SwiftData persistence, `NSPanel` non-activating floating panel, clipboard-assisted insertion, listen-only `CGEvent` tap for triggers.
  - Phasing order: Snippets & Foundation -> Floating Panel & Insertion -> Trigger Engine -> Clipboard History.
- [x] **Phase 1 — Native Application Foundation**
  - Scaffolded native macOS Swift Package (`Kibo` + `KiboKit`).
  - Target configured: macOS 15+ (`.macOS(.v15)`), Swift 6 language mode.
  - Concurrency: `@MainActor` default isolation in executable target.
  - App Lifecycle: Menu bar utility with `MenuBarExtra` (system clipboard symbol) + primary `Window("Kibo", id: "main")`. App stays alive when window closes.
  - Data Model: Initial `Snippet` `@Model` with UUID identifier, audit dates, favourite flag, and usage count.
  - Library Target (`KiboKit`): `SnippetAlias` validation logic and unit test suite (4/4 tests pass).
  - Navigation: `NavigationSplitView` with sidebar (Clipboard placeholder, Snippets, Favourites).
  - Settings (⌘,): Tabs for General (login item toggle, retention limits), Appearance (accent color swatches), and Permissions (Accessibility & Input Monitoring status indicators with deep links to System Settings).
  - Design tokens: 4pt grid spacing (`Space`), Apple system controls, `ThemeStore` with system accent default.
  - Compilation & Packaging: Clean build with zero warnings via `./build.sh`, installed and codesigned to `~/Applications/Kibo.app`.
  - Self-Test Verification: In-app self-test (`tools/selftest.sh`) passes all 9 checks.
  - Visual Verification: Light and dark mode snapshots generated for all 3 views and 3 Settings tabs (`tools/snap.sh`); grid-lint and layout checks pass 100%.
  - Git: Committed to `main` with detailed commit message.

### Upcoming: Phase 2 — Prompt & Snippet Library
1. Data Model enhancements (tags/categories, multi-line format handling).
2. Snippet Editor (name, alias with live validation feedback, tag input, multi-line Markdown/code text editor).
3. Search and filtering (search bar in list, fuzzy title/alias/content search).
4. Keyboard navigation & actions (delete, duplicate, favourite toggling via shortcuts).
5. Persistence & restart verification test suite.

### Key Technical Decisions
1. **Target**: macOS 15+ for modern SwiftData, `@Observable`, and wide Sequoia/future compatibility.
2. **Persistence**: SwiftData container stored in `~/Library/Application Support/Kibo/Kibo.store`.
3. **App Architecture**: Primary `Window("Kibo", id: "main")` + `MenuBarExtra`. Window closes without terminating the app (`applicationShouldTerminateAfterLastWindowClosed = false`).
4. **Library Target Separation**: Pure logic in `KiboKit` (no SwiftUI/AppKit dependency) for fast, isolated unit testing.
5. **Toolchain**: Uses `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` to ensure full SDK macro plugin support (`SwiftUIMacros`, `SwiftDataMacros`).
