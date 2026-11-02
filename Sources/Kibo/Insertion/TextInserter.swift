import AppKit
import ApplicationServices
import Foundation

/// Universal text and image insertion into any macOS application using synthetic ⌘V.
@MainActor
public enum TextInserter {
    /// Flag indicating an internal copy operation is in-flight so ClipboardMonitor ignores it.
    public private(set) static var isInternalPasteInFlight = false

    /// Checks whether Accessibility permissions are granted to synthesize keystrokes.
    /// If `promptIfMissing` is true, displays the macOS system permission dialog.
    public static func checkAccessibility(promptIfMissing: Bool = false) -> Bool {
        if promptIfMissing {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }

    /// Inserts text into the specified application (or the frontmost external application).
    /// - Parameters:
    ///   - text: The text string to insert.
    ///   - targetApp: The application to receive the text. If nil, uses the active or last external app.
    ///   - backspaces: Number of characters to backspace before pasting (used to delete typed aliases).
    public static func insert(
        text: String,
        into targetApp: NSRunningApplication? = nil,
        backspaces: Int = 0
    ) {
        guard !text.isEmpty else { return }

        // Prompt if accessibility permissions are missing
        if !checkAccessibility(promptIfMissing: true) {
            print("TextInserter: Accessibility permission not granted yet.")
        }

        let myPID = ProcessInfo.processInfo.processIdentifier

        // 1. Determine destination application
        let destinationApp: NSRunningApplication?
        if let app = targetApp, app.processIdentifier != myPID {
            destinationApp = app
        } else if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != myPID {
            destinationApp = front
        } else if let last = ActiveAppTracker.shared.lastExternalApp, last.processIdentifier != myPID {
            destinationApp = last
        } else {
            destinationApp = NSWorkspace.shared.runningApplications.first(where: {
                $0.activationPolicy == .regular && !$0.isTerminated && $0.processIdentifier != myPID
            })
        }

        // If Kibo is currently frontmost, hide Kibo so destination app regains focus
        if NSApp.isActive || NSWorkspace.shared.frontmostApplication?.processIdentifier == myPID {
            NSApp.windows.forEach { window in
                if window.isKeyWindow {
                    window.orderOut(nil)
                }
            }
            NSApp.hide(nil)
        }

        if let dest = destinationApp {
            if #available(macOS 14.0, *) {
                NSApp.yieldActivation(to: dest)
            }
            dest.activate()
        }

        // 2. Perform insertion asynchronously with proper event cadence
        Task { @MainActor in
            // Wait for target app window to gain full keyboard focus
            if destinationApp != nil {
                try? await Task.sleep(for: .milliseconds(220))
            } else {
                try? await Task.sleep(for: .milliseconds(50))
            }

            let source = CGEventSource(stateID: .combinedSessionState)

            // 3. Erase alias if requested (post backspaces)
            if backspaces > 0 {
                let deleteKeyCode: CGKeyCode = 0x33 // Delete / Backspace
                for _ in 0..<backspaces {
                    let down = CGEvent(keyboardEventSource: source, virtualKey: deleteKeyCode, keyDown: true)
                    let up = CGEvent(keyboardEventSource: source, virtualKey: deleteKeyCode, keyDown: false)
                    down?.post(tap: .cghidEventTap)
                    up?.post(tap: .cghidEventTap)
                    try? await Task.sleep(for: .milliseconds(4))
                }
                // Allow the target text input context to process deletions
                try? await Task.sleep(for: .milliseconds(60))
            }

            // 4. Clipboard-assisted paste with explicit Command key hold & release
            let pb = NSPasteboard.general
            let oldString = pb.string(forType: .string)

            isInternalPasteInFlight = true
            pb.clearContents()
            pb.setString(text, forType: .string)

            let cmdKeyCode: CGKeyCode = 0x37 // Left Command
            let vKeyCode: CGKeyCode = 0x09   // 'v'

            // Command down
            let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: cmdKeyCode, keyDown: true)
            cmdDown?.flags = .maskCommand
            cmdDown?.post(tap: .cghidEventTap)

            // V down with Command modifier
            let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
            vDown?.flags = .maskCommand
            vDown?.post(tap: .cghidEventTap)

            // Hold for 25ms to emulate physical keystroke duration
            try? await Task.sleep(for: .milliseconds(25))

            // V up with Command modifier
            let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
            vUp?.flags = .maskCommand
            vUp?.post(tap: .cghidEventTap)

            // Command up
            let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: cmdKeyCode, keyDown: false)
            cmdUp?.post(tap: .cghidEventTap)

            // 5. Restore previous clipboard content after paste completes
            if let old = oldString {
                try? await Task.sleep(for: .milliseconds(1000))
                if pb.string(forType: .string) == text {
                    pb.clearContents()
                    pb.setString(old, forType: .string)
                }
            }

            isInternalPasteInFlight = false
        }
    }

    /// Inserts raw image data (PNG/TIFF) into the active application via pasteboard synthesis.
    public static func insertImage(
        data: Data,
        into targetApp: NSRunningApplication? = nil
    ) {
        guard !data.isEmpty else { return }

        let myPID = ProcessInfo.processInfo.processIdentifier

        let destinationApp: NSRunningApplication?
        if let app = targetApp, app.processIdentifier != myPID {
            destinationApp = app
        } else if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != myPID {
            destinationApp = front
        } else if let last = ActiveAppTracker.shared.lastExternalApp, last.processIdentifier != myPID {
            destinationApp = last
        } else {
            destinationApp = NSWorkspace.shared.runningApplications.first(where: {
                $0.activationPolicy == .regular && !$0.isTerminated && $0.processIdentifier != myPID
            })
        }

        if NSApp.isActive || NSWorkspace.shared.frontmostApplication?.processIdentifier == myPID {
            NSApp.windows.forEach { if $0.isKeyWindow { $0.orderOut(nil) } }
            NSApp.hide(nil)
        }

        if let dest = destinationApp {
            if #available(macOS 14.0, *) {
                NSApp.yieldActivation(to: dest)
            }
            dest.activate()
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))

            let pb = NSPasteboard.general
            isInternalPasteInFlight = true
            pb.clearContents()
            pb.setData(data, forType: .png)
            pb.setData(data, forType: .tiff)

            let source = CGEventSource(stateID: .combinedSessionState)
            let cmdKeyCode: CGKeyCode = 0x37
            let vKeyCode: CGKeyCode = 0x09

            let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: cmdKeyCode, keyDown: true)
            cmdDown?.flags = .maskCommand
            cmdDown?.post(tap: .cghidEventTap)

            let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
            vDown?.flags = .maskCommand
            vDown?.post(tap: .cghidEventTap)

            try? await Task.sleep(for: .milliseconds(25))

            let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
            vUp?.flags = .maskCommand
            vUp?.post(tap: .cghidEventTap)

            let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: cmdKeyCode, keyDown: false)
            cmdUp?.post(tap: .cghidEventTap)

            try? await Task.sleep(for: .milliseconds(1000))
            isInternalPasteInFlight = false
        }
    }
}
