import AppKit
import Foundation

/// Tracks the frontmost third-party application so Kibo can insert text into it
/// even after Kibo or its floating panel takes focus.
@MainActor
public final class ActiveAppTracker {
    public static let shared = ActiveAppTracker()

    /// The most recently active application that is NOT Kibo.
    public private(set) var lastExternalApp: NSRunningApplication?

    private var activateObserver: NSObjectProtocol?
    private var deactivateObserver: NSObjectProtocol?

    private init() {
        let myPID = ProcessInfo.processInfo.processIdentifier

        // Record initial frontmost app if not Kibo
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != myPID {
            lastExternalApp = front
        } else {
            // Find the most recently active regular running app
            lastExternalApp = NSWorkspace.shared.runningApplications.first(where: {
                $0.activationPolicy == .regular && !$0.isTerminated && $0.processIdentifier != myPID
            })
        }

        // Observe app activations
        activateObserver = NSWorkspace.shared.notificationCenter.addObserver(
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

        // Observe app deactivations (captures the app that surrendered focus to Kibo)
        deactivateObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
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
