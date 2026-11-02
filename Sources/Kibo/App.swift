import AppKit
import SwiftData
import SwiftUI

// Kibo — clipboard history, snippet library, universal text insertion.
//
//   Kibo                      the app (menu bar utility)
//   APP_STORE=<file> Kibo     use another database (tests, experiments)
//   APP_SNAPSHOT=<dir> Kibo   save PNGs of every sidebar page and Settings tab, then quit
//   APP_SEED=1 Kibo           fill an empty /tmp store with sample items
//   Kibo --selftest           run the self-test on a /tmp store and quit with 0 or 1
//   APP_ACCENT=<id> Kibo      run with another accent from Theme.all
//   APP_GRID=1 Kibo           draw the 4 pt grid and layout probes over the window

@main
struct KiboApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel(container: Store.makeContainer())

    var body: some Scene {
        // Main management window.
        Window("Kibo", id: "main") {
            ContentView()
                .environment(model)
                .themed()
                .overlay { if GridOverlay.enabled { GridOverlay() } }
                .frame(minWidth: 720, minHeight: 440)
                .onAppear {
                    model.mainWindowOpen = true
                    NSApp.setActivationPolicy(.regular)
                }
                .onDisappear {
                    model.mainWindowOpen = false
                }
        }
        .modelContainer(model.container)
        .defaultSize(width: 960, height: 640)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            ToolbarCommands()
            CommandGroup(replacing: .newItem) {
                Button("New Snippet") { model.addSnippet() }
                    .keyboardShortcut("n")
            }
            CommandMenu("Snippet") {
                Button("Copy Snippet Content") {
                    if let id = model.selection,
                       let s = try? model.container.mainContext.fetch(FetchDescriptor<Snippet>()).first(where: { $0.id == id }) {
                        model.copyToClipboard(s)
                    }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(model.selection == nil)

                Button("Toggle Favourite") {
                    if let id = model.selection,
                       let s = try? model.container.mainContext.fetch(FetchDescriptor<Snippet>()).first(where: { $0.id == id }) {
                        model.toggleFavourite(s)
                    }
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(model.selection == nil)

                Button("Duplicate Snippet") {
                    if let id = model.selection,
                       let s = try? model.container.mainContext.fetch(FetchDescriptor<Snippet>()).first(where: { $0.id == id }) {
                        model.duplicateSnippet(s)
                    }
                }
                .keyboardShortcut("d", modifiers: [.command])
                .disabled(model.selection == nil)

                Divider()

                Button("Delete Snippet") {
                    if let id = model.selection,
                       let s = try? model.container.mainContext.fetch(FetchDescriptor<Snippet>()).first(where: { $0.id == id }) {
                        model.deleteSnippet(s)
                    }
                }
                .keyboardShortcut(.delete, modifiers: [.command])
                .disabled(model.selection == nil)
            }
        }

        // Menu bar presence — always visible.
        MenuBarExtra("Kibo", systemImage: "doc.on.clipboard") {
            MenuBarMenu(model: model)
        }

        Settings {
            SettingsView()
                .environment(model)
                .themed()
        }
        .windowResizability(.contentSize)
    }
}

// MARK: - Menu Bar Menu

struct MenuBarMenu: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Quick Search & Insert") {
            FloatingPanelController.shared.show(model: model)
        }
        .keyboardShortcut("k", modifiers: [.command, .shift])

        Button("Open Kibo") {
            openWindow(id: "main")
            NSApp.activate()
        }
        .keyboardShortcut("o")

        Divider()

        // Placeholder for clipboard monitoring status — Phase 5.
        Text("Clipboard monitoring: coming soon")
            .foregroundStyle(.secondary)

        Divider()

        Button("Settings…") {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            NSApp.activate()
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit Kibo") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    /// Do not quit when the main window closes — the menu bar item stays.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// The self-test's result becomes the exit code, after a normal quit.
    func applicationWillTerminate(_ notification: Notification) {
        if SelfTest.requested { exit(SelfTest.exitCode) }
    }
}

// MARK: - Store

/// Where the data lives: ~/Library/Application Support/Kibo/Kibo.store
enum Store {
    /// True when APP_STORE points somewhere else (tests, snapshots, seed data).
    static var isOverridden: Bool {
        !(ProcessInfo.processInfo.environment["APP_STORE"] ?? "").isEmpty
    }

    static var url: URL {
        if let path = ProcessInfo.processInfo.environment["APP_STORE"], !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        let dir = URL.applicationSupportDirectory.appending(path: "Kibo", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "Kibo.store")
    }

    static func makeContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: Snippet.self, configurations: ModelConfiguration(url: url))
        } catch {
            fatalError("Could not open the database at \(url.path): \(error)")
        }
    }
}
