# Kibo — Project Status

## Current Milestone: Phase 5 — Clipboard History & Hardened Universal Insertion (COMPLETE)

### Vision & Objective
Build a lightweight, exceptionally fast, keyboard-first macOS productivity utility combining clipboard history, prompt management, text snippets, and universal text insertion, following the BAMA framework.

### Status & Progress
- [x] **Phase 0 — Product & Architecture Planning**
  - Applied BAMA skills (`bama`, `app-brief`, `new-mac-app`, `swift-swiftui`, `os-integrations`, `mac-design`, `design-system`).
  - Architecture plan approved: SwiftData persistence, `NSPanel` non-activating floating panel, clipboard-assisted insertion, listen-only `CGEvent` tap for triggers.
- [x] **Phase 1 — Native Application Foundation**
  - Scaffolded native macOS Swift Package (`Kibo` + `KiboKit`).
  - Target configured: macOS 15+ (`.macOS(.v15)`), Swift 6 language mode.
  - Concurrency: `@MainActor` default isolation in executable target.
  - App Lifecycle: Menu bar utility with `MenuBarExtra` + primary `Window("Kibo", id: "main")`.
- [x] **Phase 2 — Prompt & Snippet Library**
  - Enhanced Data Model: `Snippet` with category, audit timestamps, and stable UUIDs.
  - Validation: `SnippetAlias` with diagnostic statuses and `.clean()` auto-fixer.
  - Search: `SnippetSearch` multi-factor fuzzy ranking across title, alias, category, and body.
  - Category Pills: Interactive category pill with dropdown menu to select/create categories.
  - Sorting: Multi-criteria sort menu (Recently Modified, A-Z, Most Used, Recently Used, Category).
- [x] **Phase 3 — Universal Text Insertion Everywhere**
  - **Universal Text Inserter (`TextInserter.swift`)**:
    - Synthesizes `CGEvent` keystrokes (Command-V) into the frontmost application.
    - Automatic target app activation (`yieldActivation(to:)` + `.activate()`).
    - Focus tracking with `ActiveAppTracker.shared` so clicking "Insert" inside Kibo correctly hides Kibo and routes into the user's previous application.
    - Preserves and restores existing clipboard content after pasting.
    - Synthesizes backspaces with cadence delays to delete typed aliases in-place.
  - **Dynamic Placeholder Variables (`{{variable}}`)**:
    - `SnippetPlaceholders`: parses `{{name}}` or `{{name:default}}` patterns with deduplication and substitution.
    - `PlaceholderPromptView`: interactive variable-filling sheet with live substitution preview, Return to insert, Esc to cancel.
  - **Global Floating Search Panel (`FloatingSearchPanel.swift`)**:
    - Global shortcut **⌘⇧K** registered via Carbon `RegisterEventHotKey` (works globally).
    - Non-activating HUD panel (`NSPanel` with `.nonactivatingPanel`) floating over TextEdit, Notes, Safari, Chrome, VS Code without stealing focus.
    - Supports instant placeholder prompting directly in HUD when selecting templated snippets.
- [x] **Phase 4 — Trigger Engine & Keystroke Expansion Hardening**
  - **Zero-Disk In-Memory Cache (`CachedTrigger`)**:
    - Fixed crash root cause (`Store.makeContainer()` called in event tap).
    - Replaced disk queries with in-memory thread-safe `cachedTriggers`.
    - Instant keystroke matching in microseconds with zero SQLite contention.
    - Automatic trigger synchronization on snippet add, duplicate, delete, and edit.
- [x] **Phase 5 — Clipboard History & Management**
  - **Model (`ClipboardEntry.swift`)**:
    - Captured text with content, `copiedAt`, `isPinned`, `charCount`, `wordCount`, and stable UUID.
    - Integrated with SwiftData container schema alongside `Snippet`.
  - **Background Monitor (`ClipboardMonitor.swift`)**:
    - Low-overhead timer polling `NSPasteboard.general.changeCount` every 0.4s.
    - Dedupes consecutive identical items and ignores internal synthetic pastes from `TextInserter`.
    - Automatically enforces history retention limits (default 250 items, protects pinned items).
  - **User Interface (`ClipboardView.swift`)**:
    - Searchable list of past clippings with relative timestamps and word/character counts.
    - Filter pills (`All`, `Pinned`).
    - Quick actions: "Insert into Active App", "Copy Again" (`⌘C`), "Pin / Unpin" (`⌘P`), "Save as Reusable Snippet" (`⌘⇧S`), "Delete" (`⌘⌫`), and "Clear Unpinned History".
    - Rich inspector detail view with syntax typography and metadata.
- [x] **Double-Verification Quality Bar**:
  - `swift test`: 16/16 unit tests passing across all suites.
  - `tools/selftest.sh`: 33/33 automated in-app assertions passing.
  - `tools/grid-lint.sh`: 100% compliant with 4pt layout grid.
  - `tools/snap.sh`: 12 light and dark UI window snapshots captured in `/tmp/Kibo-shots/`.
  - `tools/check-layout.swift`: 12/12 passing layout probes.

### Key Technical Decisions
1. **Universal Insertion Cadence**: Uses explicit Command key down, V key down (25ms hold duration), V key up, and Command key up, paired with `yieldActivation(to:)` and `NSApp.hide(nil)` when invoked from Kibo.
2. **In-Memory Keystroke Matching**: Event taps MUST never perform disk I/O. `GlobalTriggerEngine` maintains an in-memory trigger lookup cache synchronized by `AppModel`.
3. **Non-Activating Floating Panel**: Uses `NSPanel` with `.nonactivatingPanel` and `NSHostingView`. This ensures the active document/browser tab never loses its active selection/cursor state when the floating panel is summoned.
4. **Template Placeholders**: Uses regex-based `{{key}}` and `{{key:default}}` extraction so users can create dynamic prompts with immediate variable input before insertion.
5. **Pasteboard Loop Prevention**: `TextInserter.isInternalPasteInFlight` prevents `ClipboardMonitor` from recording Kibo's own insertion events as new clippings.
