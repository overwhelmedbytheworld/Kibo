import AppKit
import Foundation
import SwiftUI

/// Where Kibo displays its presence:
/// - `menuBar`: Menu bar only (accessory policy, no Dock icon). Default.
/// - `dock`: Dock only (regular policy, menu bar extra hidden).
/// - `both`: Both Menu Bar and Dock.
public enum AppLocation: String, CaseIterable, Identifiable, Sendable {
    case menuBar = "menuBar"
    case dock = "dock"
    case both = "both"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .menuBar: "Menu Bar"
        case .dock: "Dock"
        case .both: "Both"
        }
    }

    public var showsInMenuBar: Bool {
        self == .menuBar || self == .both
    }

    public var showsInDock: Bool {
        self == .dock || self == .both
    }
}

@MainActor
@Observable
public final class AppLocationManager {
    public static let shared = AppLocationManager()

    public static let defaultsKey = "appIconLocation"

    public var location: AppLocation {
        didSet {
            UserDefaults.standard.set(location.rawValue, forKey: Self.defaultsKey)
            apply()
        }
    }

    public var showsInMenuBar: Bool {
        location.showsInMenuBar
    }

    public var showsInDock: Bool {
        location.showsInDock
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? AppLocation.menuBar.rawValue
        self.location = AppLocation(rawValue: saved) ?? .menuBar
    }

    /// Applies the appropriate activation policy based on the current location setting.
    public func apply() {
        let policy: NSApplication.ActivationPolicy = showsInDock ? .regular : .accessory
        NSApp.setActivationPolicy(policy)
        if showsInDock {
            NSApp.activate()
        }
    }
}
