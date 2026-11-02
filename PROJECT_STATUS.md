# Kibo — Project Status

## Current Milestone: Phase 3 — Universal Text Insertion & Floating Search (COMPLETE)

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
- [x] **Phase 2 — Prompt & Snippet Library**
  - Enhanced Data Model: `Snippet` with category, audit timestamps, and stable UUIDs.
  - Validation: `SnippetAlias` with diagnostic statuses and `.clean()` auto-fixer.
  - Search: `SnippetSearch` multi-factor fuzzy ranking across title, alias, category, and body.
  - Category Pills: Interactive category pill with dropdown menu to select/create categories.
  - Sorting: Multi-criteria sort menu (Recently Modified, A-Z, Most Used, Recently Used, Category).
- [x] **Phase 3 & Trigger Expansion — Universal Text Insertion Everywhere**
  - **Universal Text Inserter (`TextInserter.swift`)**:
    - Synthesizes `CGEvent` keystrokes (Command-V) into the frontmost application.
    - Automatic target app activation and focus handling.
    - Preserves and restores existing clipboard content after pasting.
    - Synthesizes backspaces to delete typed aliases in-place.
  - **Dynamic Placeholder Variables (`{{variable}}`)**:
    - `SnippetPlaceholders`: parses `{{name}}` or `{{name:default}}` patterns with deduplication and substitution.
    - `PlaceholderPromptView`: interactive variable-filling sheet with live substitution preview, Return to insert, Esc to cancel.
  - **Global Floating Search Panel (`FloatingSearchPanel.swift`)**:
    - Global shortcut **⌘⇧K** registered via Carbon `RegisterEventHotKey` (works globally).
    - Non-activating HUD panel (`NSPanel` with `.nonactivatingPanel`) floating over TextEdit, Notes, Safari, Chrome, VS Code without stealing focus.
    - Arrow keys navigation, Return to insert (or prompt for placeholders), Esc to dismiss.
  - **Live Trigger Engine (`GlobalTriggerEngine.swift`)**:
    - Listen-only `CGEvent` tap monitors typed characters.
    - Detects registered aliases (e.g. typing `:email:`, `:debate:`).
    - Automatically erases the typed alias and pastes the snippet content into the active app.
  - **Verification**:
    - `swift test`: 16/16 unit tests passing.
    - `tools/selftest.sh`: 27/27 assertions passing.
    - `tools/grid-lint.sh`: 100% compliant with 4pt grid scale.
    - `tools/snap.sh`: 12 light and dark UI snapshots generated.
    - `tools/check-layout.swift`: 12/12 passing layout probes.

### Upcoming: Phase 5 — Clipboard History
1. NSPasteboard changeCount background polling.
2. `ClipboardEntry` data model and persistence.
3. Deduping, search, pinning, and deletion.
4. Privacy retention limit configuration.

### Key Technical Decisions
1. **Universal Insertion Mechanism**: Uses synthetic ⌘V via `CGEvent` with clipboard backup and restore. This provides ~95% compatibility across all macOS applications (including electron/browsers) without requiring custom accessibility bindings.
2. **Non-Activating Floating Panel**: Uses `NSPanel` with `.nonactivatingPanel` and `NSHostingView`. This ensures the active document/browser tab never loses its active selection/cursor state when the floating panel is summoned.
3. **Template Placeholders**: Uses regex-based `{{key}}` and `{{key:default}}` extraction so users can create dynamic prompts with immediate variable input before insertion.
