import AppKit
import SwiftUI

/// Manages the lifecycle, activation policy, and presentation of the standalone Onboarding window.
@MainActor
public final class OnboardingWindowController: NSObject, NSWindowDelegate {
    public static let shared = OnboardingWindowController()

    private var window: NSWindow?
    private var viewModel: OnboardingViewModel?

    private override init() {
        super.init()
    }

    /// Shows the onboarding window, temporarily elevating activation policy to `.regular`.
    public func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let vm = OnboardingViewModel()
        self.viewModel = vm

        vm.onComplete = { [weak self] in
            self?.closeWithTransition()
        }

        let hostingView = NSHostingView(rootView: OnboardingView(viewModel: vm).themed())

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 490),
            styleMask: [.titled, .fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )

        win.title = "Welcome to Kibo"
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.center()
        win.delegate = self
        win.contentView = hostingView
        win.isReleasedWhenClosed = false

        self.window = win

        // Temporarily elevate activation policy so the window receives key focus and dock representation
        NSApp.setActivationPolicy(.regular)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Intercepts window close attempt (red button or ⌘W) to enforce 2-stage skip protection.
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        if let vm = viewModel {
            vm.skipOrClose()
            return false
        }
        return true
    }

    /// Fades out the window and restores the user's configured activation policy (e.g. .accessory for menu bar).
    public func closeWithTransition() {
        guard let win = window else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            win.animator().alphaValue = 0.0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                win.orderOut(nil)
                win.alphaValue = 1.0
                self?.window = nil
                self?.viewModel = nil

                // Restore activation policy via AppLocationManager
                AppLocationManager.shared.apply()
            }
        }
    }
}
