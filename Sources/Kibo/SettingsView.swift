import Combine
import ServiceManagement
import SwiftUI

/// The Settings window (⌘,). One tab per topic. Each tab is a grouped Form
/// that sizes to its content, so the window grows to fit.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.settingsTab) {
            ForEach(SettingsTab.allCases) { tab in
                page(tab)
                    .tabItem { Label(tab.title, systemImage: tab.symbol) }
                    .tag(tab)
            }
        }
        .noInitialFocus()
    }

    @ViewBuilder
    private func page(_ tab: SettingsTab) -> some View {
        Form {
            switch tab {
            case .general: GeneralSettings()
            case .appearance: AppearanceSettings()
            case .permissions: PermissionsSettings()
            }
        }
        .formStyle(.grouped)
        .fitsContent()
        .frame(width: 520)
    }
}

/// The Settings tabs. Snapshot mode walks through every case.
enum SettingsTab: String, CaseIterable, Identifiable {
    case general, appearance, permissions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .permissions: "Permissions"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintpalette"
        case .permissions: "lock.shield"
        }
    }
}

// MARK: - General Settings

struct GeneralSettings: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("historyLimit") private var historyLimit = 500
    @State private var locationManager = AppLocationManager.shared

    var body: some View {
        Section("Startup") {
            Toggle("Launch Kibo at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        // Registration can fail silently; reset the toggle.
                        launchAtLogin = !enabled
                    }
                }
        }

        Section("App Icon & Visibility") {
            Picker("Show Kibo in", selection: Binding(
                get: { locationManager.location },
                set: { locationManager.location = $0 }
            )) {
                ForEach(AppLocation.allCases) { loc in
                    Text(loc.title).tag(loc)
                }
            }
            .pickerStyle(.segmented)

            Text("Default is Menu Bar. Choose Dock to show the app icon on the Dock every time, or Both to display in both places.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("Clipboard History") {
            Picker("Keep history for", selection: $historyLimit) {
                Text("100 items").tag(100)
                Text("250 items").tag(250)
                Text("500 items").tag(500)
                Text("1,000 items").tag(1000)
                Text("Unlimited").tag(0)
            }
        }

        Section("Sound & Feedback") {
            Toggle("Play audio click on text expansion", isOn: Binding(
                get: { SoundFeedback.isEnabled },
                set: { SoundFeedback.isEnabled = $0 }
            ))
        }

        Section("Inline Suggestions (:emoji: bar)") {
            Toggle("Show inline suggestion bar when typing :shortcode", isOn: Binding(
                get: { InlineSuggestionController.isInlineSuggestionEnabled },
                set: { InlineSuggestionController.isInlineSuggestionEnabled = $0 }
            ))

            Text("Shows a floating WhatsApp-style horizontal suggestion bar as you type :shortcodes like :fire or :rose.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        DisableSuggestionsInAppsView()
    }
}

// MARK: - Excluded Apps Section

struct DisableSuggestionsInAppsView: View {
    @State private var customApps: [ExcludedAppItem] = InlineSuggestionController.customExcludedApps
    @State private var selectedBundleID: String? = nil

    private struct BuiltInAppInfo: Identifiable {
        let id: String
        let name: String
        let bundleIDs: [String]
        let primaryBundleID: String
    }

    private let builtInApps: [BuiltInAppInfo] = [
        BuiltInAppInfo(id: "whatsapp", name: "WhatsApp", bundleIDs: ["net.whatsapp.WhatsApp", "net.whatsapp.WhatsApp.mac"], primaryBundleID: "net.whatsapp.WhatsApp"),
        BuiltInAppInfo(id: "discord", name: "Discord", bundleIDs: ["com.hnc.Discord", "com.discord"], primaryBundleID: "com.hnc.Discord"),
        BuiltInAppInfo(id: "slack", name: "Slack", bundleIDs: ["com.tinyspeck.slackmacgap"], primaryBundleID: "com.tinyspeck.slackmacgap")
    ]

    var body: some View {
        Section("Disable Inline Suggestions in Apps") {
            Text("Some apps already have built-in shortcode pickers. Disable Kibo's suggestion bar in these apps to prevent duplicate or conflicting popups:")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(builtInApps) { app in
                HStack(spacing: Space.sm) {
                    appIcon(bundleID: app.primaryBundleID, path: nil)
                    Text(app.name)
                        .foregroundStyle(.primary)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: {
                            app.bundleIDs.contains { InlineSuggestionController.excludedBundleIDs.contains($0) }
                        },
                        set: { isExcluded in
                            for bid in app.bundleIDs {
                                InlineSuggestionController.setAppExcluded(bundleID: bid, isExcluded: isExcluded)
                            }
                        }
                    ))
                    .labelsHidden()
                }
            }

            ForEach(customApps) { app in
                HStack(spacing: Space.sm) {
                    appIcon(bundleID: app.bundleID, path: app.path)
                    Text(app.name)
                        .foregroundStyle(.primary)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: {
                            InlineSuggestionController.excludedBundleIDs.contains(app.bundleID)
                        },
                        set: { isExcluded in
                            InlineSuggestionController.setAppExcluded(bundleID: app.bundleID, isExcluded: isExcluded)
                        }
                    ))
                    .labelsHidden()
                }
                .padding(.horizontal, Space.xs)
                .padding(.vertical, 2)
                .background(
                    selectedBundleID == app.bundleID ? Palette.accent.opacity(0.12) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedBundleID = (selectedBundleID == app.bundleID) ? nil : app.bundleID
                }
            }

            // + / - button toolbar matching macOS System Settings
            HStack {
                HStack(spacing: 0) {
                    Button(action: openAppPicker) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 28, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Add another application from Applications")

                    Divider()
                        .frame(height: 12)

                    Button(action: removeSelectedApp) {
                        Image(systemName: "minus")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 28, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedBundleID == nil || !customApps.contains(where: { $0.bundleID == selectedBundleID }))
                    .help("Remove selected custom application")
                }
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))

                Spacer()
            }
            .padding(.top, Space.xs)
        }
    }

    private func appIcon(bundleID: String, path: String?) -> some View {
        let image: NSImage
        if let path, FileManager.default.fileExists(atPath: path) {
            image = NSWorkspace.shared.icon(forFile: path)
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            image = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            image = NSWorkspace.shared.icon(for: .application)
        }
        image.size = NSSize(width: 20, height: 20) // grid: ok app icon size
        return Image(nsImage: image)
            .resizable()
            .frame(width: 20, height: 20)
    }

    private func openAppPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Open"
        panel.message = "Choose an application to disable inline suggestions in:"
        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            let name = FileManager.default.displayName(atPath: path)
            let bundle = Bundle(url: url)
            let bundleID = bundle?.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent
            InlineSuggestionController.addCustomExcludedApp(name: name, bundleID: bundleID, path: path)
            customApps = InlineSuggestionController.customExcludedApps
            selectedBundleID = bundleID
        }
    }

    private func removeSelectedApp() {
        guard let id = selectedBundleID else { return }
        InlineSuggestionController.removeCustomExcludedApp(bundleID: id)
        customApps = InlineSuggestionController.customExcludedApps
        selectedBundleID = nil
    }
}

// MARK: - Permissions Settings

struct PermissionsSettings: View {
    @State private var accessibilityGranted = PermissionStatus.checkAccessibility()
    @State private var inputMonitoringGranted = PermissionStatus.checkInputMonitoring()
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Section {
            Text("Kibo needs system permissions to detect triggers in other apps and insert text. These permissions are optional — the snippet library and clipboard history work without them.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }

        Section("Accessibility") {
            HStack {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Label(
                        accessibilityGranted ? "Granted" : "Not Granted",
                        systemImage: accessibilityGranted ? "checkmark.circle.fill" : "xmark.circle"
                    )
                    .foregroundStyle(accessibilityGranted ? .green : .secondary)
                    Text("Required for inserting text into other apps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Open System Settings") {
                    PermissionStatus.openAccessibilitySettings()
                }
                .controlSize(.small)
            }
        }

        Section("Input Monitoring") {
            HStack {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Label(
                        inputMonitoringGranted ? "Granted" : "Not Granted",
                        systemImage: inputMonitoringGranted ? "checkmark.circle.fill" : "xmark.circle"
                    )
                    .foregroundStyle(inputMonitoringGranted ? .green : .secondary)
                    Text("Required for detecting trigger aliases as you type.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Open System Settings") {
                    PermissionStatus.openInputMonitoringSettings()
                }
                .controlSize(.small)
            }
        }
        .onReceive(timer) { _ in
            accessibilityGranted = PermissionStatus.checkAccessibility()
            inputMonitoringGranted = PermissionStatus.checkInputMonitoring()
        }
    }
}

// MARK: - Permission Status

/// Checks macOS permission state. Permissions are granted in System Settings;
/// no callback tells us when they change, so we poll.
enum PermissionStatus {
    /// Accessibility: needed for simulating paste (CGEvent posting).
    static func checkAccessibility() -> Bool {
        AXIsProcessTrusted()
    }

    /// Input Monitoring: needed for CGEvent tap (listen-only) to detect triggers.
    /// There is no public API to check this directly. We attempt to check
    /// by testing if we could create a listen-only event tap. For now, we
    /// use AXIsProcessTrusted as a proxy since both are in the same area.
    /// A real check happens when the trigger detector starts in Phase 4.
    static func checkInputMonitoring() -> Bool {
        // CGRequestListenEventAccess() prompts the user. We only call it when
        // the user explicitly enables the feature. For Settings display, we
        // check if a listen-only tap would succeed (non-destructive test).
        // This is a best-effort check.
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        )
        if let tap {
            // We got a tap — permission is granted. Clean up immediately.
            CFMachPortInvalidate(tap)
            return true
        }
        return false
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}
