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
    @State private var locationManager = AppLocationManager.shared
    @AppStorage("appearance.menuBarIconStyle") private var menuBarIconStyleRaw = MenuBarIconStyle.color.rawValue

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
                    locationManager.apply()
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
            CommandGroup(replacing: .help) {
                Button("Welcome to Kibo…") {
                    OnboardingWindowController.shared.show()
                }
            }
        }

        // Menu bar presence — visible when configured for Menu Bar or Both.
        MenuBarExtra(isInserted: Binding(
            get: { locationManager.showsInMenuBar },
            set: { _ in }
        )) {
            MenuBarMenu(model: model)
        } label: {
            Image(nsImage: MenuBarIcon.image(for: MenuBarIconStyle(rawValue: menuBarIconStyleRaw) ?? .color))
                .accessibilityLabel("Kibo")
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
        if !AXIsProcessTrusted() {
            Button("⚠️ Accessibility: Not Granted (Triggers Inactive)") {
                OnboardingWindowController.shared.show()
            }
            Divider()
        }

        Button("Quick Search & Insert") {
            FloatingPanelController.shared.show(model: model)
        }
        .keyboardShortcut("k", modifiers: [.command, .shift])

        Button("Open Kibo") {
            openWindow(id: "main")
            for window in NSApp.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
            }
            NSApp.activate()
        }
        .keyboardShortcut("o")

        Divider()

        Text("Clipboard monitoring: active")
            .foregroundStyle(.secondary)

        Divider()

        Button("Welcome to Kibo…") {
            OnboardingWindowController.shared.show()
        }

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
        AppLocationManager.shared.apply()

        // Show onboarding automatically on first launch (unless overridden by tests/snapshots)
        if !Store.isOverridden && !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            OnboardingWindowController.shared.show()
        }
    }

    /// Handle clicking the Dock icon when running in Dock mode or reopen requested.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
                sender.activate()
                return true
            }
        }
        return true
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
            let schema = Schema([
                Snippet.self,
                ClipboardEntry.self,
            ])
            return try ModelContainer(for: schema, configurations: ModelConfiguration(url: url))
        } catch {
            fatalError("Could not open the database at \(url.path): \(error)")
        }
    }
}
