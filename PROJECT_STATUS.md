# Kibo — Project Status

## Current Milestone: Phase 2 — Prompt & Snippet Library (COMPLETE)

### Vision & Objective
Build a lightweight, exceptionally fast, keyboard-first macOS productivity utility combining clipboard history, prompt management, text snippets, and universal text insertion, following the BAMA framework.

### Status & Progress
- [x] **Phase 0 — Product & Architecture Planning**
  - Read and applied BAMA skills (`bama`, `app-brief`, `new-mac-app`, `swift-swiftui`, `os-integrations`, `mac-design`, `design-system`).
  - Architecture plan approved: SwiftData persistence, `NSPanel` non-activating floating panel, clipboard-assisted insertion, listen-only `CGEvent` tap for triggers.
- [x] **Phase 1 — Native Application Foundation**
  - Scaffolded native macOS Swift Package (`Kibo` + `KiboKit`).
  - Target configured: macOS 15+ (`.macOS(.v15)`), Swift 6 language mode.
  - Concurrency: `@MainActor` default isolation in executable target.
  - App Lifecycle: Menu bar utility with `MenuBarExtra` + primary `Window("Kibo", id: "main")`.
  - Clean build, signed `.app` bundle, 100% test pass.
- [x] **Phase 2 — Prompt & Snippet Library**
  - **Enhanced Data Model**: `Snippet` with categories/tags, usage counters, audit timestamps (`createdAt`, `modifiedAt`, `lastUsedAt`), and stable `uid: UUID`.
  - **Validation & Search Engine in KiboKit**:
    - `SnippetAlias`: live validation rules with diagnostic feedback (`.valid`, `.empty`, `.missingColons`, `.tooShort`, `.invalidCharacters`) and `.clean()` auto-fixer.
    - `SnippetSearch`: fast multi-factor fuzzy matching and ranking across title, alias, category, and content body.
    - 10/10 unit tests passing in `KiboKitTests`.
  - **Dedicated Snippet Editor**:
    - Live alias validation pill and auto-fix action.
    - Tag/category input.
    - Prominent **"Copy Snippet"** action with animated visual confirmation (`⌘Return` / `⌘C`) for instant use in any application.
    - Markdown & code-friendly monospaced `TextEditor`.
    - Live word, line, and character count metrics.
  - **Library Search & Filtering**:
    - Real-time `.searchable` query matching.
    - Scrollable category filter pills (`All`, and each unique category in the library).
  - **Keyboard Shortcuts & Commands**:
    - `⌘N`: New Snippet.
    - `⌘D`: Duplicate selected snippet (with `-copy` alias generation).
    - `⌘S`: Star/unstar (favourite).
    - `⌘Return` / `⌘C`: Copy content to clipboard.
    - `⌘⌫` / `Delete`: Delete snippet with context safety.
  - **Verification**:
    - `tools/selftest.sh`: 23/23 assertions passing.
    - `tools/grid-lint.sh`: 100% on 4pt grid scale.
    - `tools/snap.sh`: 12 light and dark UI snapshots generated.
    - `tools/check-layout.swift`: 12/12 passing layout probes.

### Upcoming: Phase 3 — Floating Search Interface & Universal Insertion
1. Global hotkey registration (⌘⇧K via Carbon `RegisterEventHotKey`, zero permissions needed).
2. Non-activating floating HUD panel (`NSPanel` with `.nonactivatingPanel` and `NSHostingView`) so focus remains anchored in the target external app.
3. Universal keyboard-driven search, ranking, selection, and clipboard-assisted text paste (`CGEvent` synthetic ⌘V with clipboard backup/restore).
4. Validation across real apps: TextEdit, Notes, Safari, Chrome, VS Code.

### Key Technical Decisions
1. **Target**: macOS 15+ for modern SwiftData, `@Observable`, and wide Sequoia/future compatibility.
2. **Persistence**: SwiftData container stored in `~/Library/Application Support/Kibo/Kibo.store`.
3. **App Architecture**: Primary `Window("Kibo", id: "main")` + `MenuBarExtra`. Window closes without terminating the app.
4. **Library Target Separation**: Pure logic in `KiboKit` (no SwiftUI/AppKit dependency) for fast, isolated unit testing.
5. **Instant Snippet Utility**: Provided immediate `copyToClipboard` functionality directly in the editor and list so snippets are immediately usable while Phase 3/4 build the automated insertion and trigger engine.
