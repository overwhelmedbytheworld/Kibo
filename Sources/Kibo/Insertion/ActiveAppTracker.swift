import AppKit
import Foundation

/// Tracks the frontmost third-party application so Kibo can insert text into it
/// even after Kibo or its floating panel takes focus.
@MainActor
public final class ActiveAppTracker {
    public static let shared = ActiveAppTracker()

    /// The most recently active application that is NOT Kibo.
    public private(set) var lastExternalApp: NSRunningApplication?

    private var observer: NSObjectProtocol?

    private init() {
        let myPID = ProcessInfo.processInfo.processIdentifier

        // Record initial frontmost app if not Kibo
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != myPID {
            lastExternalApp = front
        }

        // Observe future app activations
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            if app.processIdentifier != myPID {
                Task { @MainActor in
                    self?.lastExternalApp = app
                }
            }
        }
    }

    /// Pre-warms the tracker.
    public func start() {
        // Shared instance initialized on first access.
    }
}
