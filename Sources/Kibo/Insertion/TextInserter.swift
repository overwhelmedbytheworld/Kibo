import AppKit
import ApplicationServices
import Foundation

/// Universal text insertion into any macOS application using synthetic ⌘V.
@MainActor
public enum TextInserter {
    /// Checks whether Accessibility permissions are granted to synthesize keystrokes.
    /// If `promptIfMissing` is true, displays the macOS system permission dialog.
    public static func checkAccessibility(promptIfMissing: Bool = false) -> Bool {
        if promptIfMissing {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }

    /// Inserts text into the specified application (or the frontmost application).
    /// - Parameters:
    ///   - text: The text string to insert.
    ///   - targetApp: The application to receive the text. If nil, uses the currently frontmost application.
    ///   - backspaces: Number of characters to backspace before pasting (used to delete typed aliases).
    public static func insert(
        text: String,
        into targetApp: NSRunningApplication? = nil,
        backspaces: Int = 0
    ) {
        guard !text.isEmpty else { return }

        // Ensure accessibility permissions are requested if missing
        if !checkAccessibility(promptIfMissing: true) {
            print("TextInserter: Accessibility permission missing.")
        }

        let myPID = ProcessInfo.processInfo.processIdentifier

        // 1. Activate target application if it's not Kibo itself
        let destinationApp: NSRunningApplication?
        if let app = targetApp, app.processIdentifier != myPID {
            destinationApp = app
        } else {
            destinationApp = NSWorkspace.shared.runningApplications.first {
                $0.isActive && $0.processIdentifier != myPID
            }
        }

        if let dest = destinationApp {
            dest.activate()
        }

        // 2. Perform insertion asynchronously with short delays to let macOS route input events
        Task { @MainActor in
            // Wait for target app to gain window focus
            if destinationApp != nil {
                try? await Task.sleep(for: .milliseconds(75))
            }

            let source = CGEventSource(stateID: .combinedSessionState)

            // 3. Erase alias if requested (post backspaces)
            if backspaces > 0 {
                let deleteKeyCode: CGKeyCode = 0x33 // Backspace / Delete
                for _ in 0..<backspaces {
                    let down = CGEvent(keyboardEventSource: source, virtualKey: deleteKeyCode, keyDown: true)
                    let up = CGEvent(keyboardEventSource: source, virtualKey: deleteKeyCode, keyDown: false)
                    down?.post(tap: .cghidEventTap)
                    up?.post(tap: .cghidEventTap)
                }
                try? await Task.sleep(for: .milliseconds(35))
            }

            // 4. Clipboard-assisted paste
            let pb = NSPasteboard.general
            let oldString = pb.string(forType: .string)

            pb.clearContents()
            pb.setString(text, forType: .string)

            // Post Command-V
            let vKeyCode: CGKeyCode = 0x09 // 'v'
            guard let cmdVDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
                  let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
                return
            }

            cmdVDown.flags = .maskCommand
            cmdVUp.flags = .maskCommand

            cmdVDown.post(tap: .cghidEventTap)
            cmdVUp.post(tap: .cghidEventTap)

            // 5. Restore previous clipboard content after paste completes
            if let old = oldString {
                try? await Task.sleep(for: .milliseconds(350))
                // Only restore if user hasn't copied something else in the meantime
                if pb.string(forType: .string) == text {
                    pb.clearContents()
                    pb.setString(old, forType: .string)
                }
            }
        }
    }
}
