# Kibo

A native macOS productivity app: clipboard history, snippet library, and
universal text insertion. It runs as a menu bar utility with a management
window and a floating search panel.

## Layout

- `Sources/Kibo/` the app. `App.swift` has the menu bar, window, and database.
- `Sources/KiboKit/` rules and data logic with no SwiftUI. Tests in `Tests/KiboKitTests/`.
- `Package.swift` a Swift package targeting macOS 15+. There is no Xcode project.
- `build.sh` builds, signs, and installs `~/Applications/Kibo.app`.
- `Icon/AppIcon.icon` the app icon (Icon Composer file). `build.sh` compiles it.
- `docs/` the brief, stories, and design docs.

## Build and check

- Build and install: `./build.sh`. Add `--open` to restart the app.
- Unit tests: `swift test --scratch-path ~/Library/Developer/Kibo/test-build`.
- Self-test: `tools/selftest.sh`. Exit 0 when every check passes.
- Snapshots: `tools/snap.sh` writes PNGs to `/tmp/Kibo-shots/`.
- Grid lint: `tools/grid-lint.sh` and `swift tools/check-layout.swift /tmp/Kibo-shots/*-layout.json`.
- Never test against the real database in `~/Library/Application Support/Kibo/`.

## Design rules

- Design rules: `docs/DESIGN-SYSTEM.md` (when it exists). Use its tokens; never raw colors, radii, or durations.
- Use Apple's controls and system styles. The accent color is `system` (follows macOS).
- Views use `.tint`, `Palette.accent`, `Palette.accentText`, and `Palette.onAccent`.
- Spacing from `Space` in `UI/Grid.swift`, on a 4 pt grid.
- Windows open calm: `.noInitialFocus()`, `.fitsContent()`.
- Settings: one tab per topic. Add a case to `SettingsTab`.
- Every action has a menu bar item and a keyboard shortcut.
- `Label` for icon+text pairs. SF Symbols for icons.
- `ContentUnavailableView` for empty states.

## Architecture

- Menu bar utility (`LSUIElement = YES`). App does not quit when main window closes.
- SwiftData for persistence. Models: `Snippet` (Phase 2+), `ClipboardEntry` (Phase 5+).
- Floating panel: `NSPanel` with `.nonactivatingPanel` (Phase 3+).
- Trigger detection: CGEvent tap, listen-only (Phase 4+).
- Clipboard monitoring: `NSPasteboard.general.changeCount` polling (Phase 5+).
- Text insertion: clipboard-assisted paste via CGEvent (Phase 3+).

## Skills

The bama plugin has a skill for each step: `mac-design`, `design-system`,
`layout-grid`, `ux-design`, `swift-swiftui`, `os-integrations`, `performance`,
`build-and-verify`, `test-mac-app`, `app-icon`, `user-stories`, `improve-loop`.

## Git

- Commit after each working change, with a message that says what the user can now do.
