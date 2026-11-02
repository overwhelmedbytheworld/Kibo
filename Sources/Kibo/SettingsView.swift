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
