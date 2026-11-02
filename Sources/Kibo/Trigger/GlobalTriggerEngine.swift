import AppKit
import ApplicationServices
import Foundation
import SwiftData
import KiboKit

/// Thread-safe in-memory representation of an expansion trigger.
public struct CachedTrigger: Sendable, Equatable {
    public let id: PersistentIdentifier
    public let alias: String
    public let content: String
    public let name: String
    public let hasPlaceholders: Bool

    public init(
        id: PersistentIdentifier,
        alias: String,
        content: String,
        name: String,
        hasPlaceholders: Bool
    ) {
        self.id = id
        self.alias = alias
        self.content = content
        self.name = name
        self.hasPlaceholders = hasPlaceholders
    }
}

/// Background keystroke monitor for automatic trigger alias expansion (e.g. typing `:email:`).
@MainActor
final class GlobalTriggerEngine {
    static let shared = GlobalTriggerEngine()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var buffer = ""
    private var lastKeyTime = Date()
    private weak var model: AppModel?

    /// In-memory cache of triggers to avoid disk I/O and ModelContainer crashes on keystrokes.
    private var cachedTriggers: [CachedTrigger] = []

    private(set) var isRunning = false

    private init() {}

    /// Starts monitoring keystrokes if Accessibility/Input Monitoring is granted.
    func start(model: AppModel) {
        self.model = model
        guard !isRunning else { return }

        let mask = (1 << CGEventType.keyDown.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passUnretained(event) }

                if type == .tapDisabledByTimeout {
                    // Tap was disabled by OS timeout; re-enable it
                    let engine = Unmanaged<GlobalTriggerEngine>.fromOpaque(userInfo).takeUnretainedValue()
                    if let t = engine.eventTap {
                        CGEvent.tapEnable(tap: t, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }

                guard type == .keyDown else { return Unmanaged.passUnretained(event) }

                let engine = Unmanaged<GlobalTriggerEngine>.fromOpaque(userInfo).takeUnretainedValue()
                engine.handleKeyDown(event: event)

                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else {
            print("GlobalTriggerEngine: Failed to create CGEvent tap (requires Accessibility permission)")
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
    }

    /// Synchronizes the in-memory trigger cache from the current snippet collection.
    func updateTriggers(from snippets: [Snippet]) {
        self.cachedTriggers = snippets.compactMap { snippet in
            let alias = snippet.alias.trimmingCharacters(in: .whitespaces)
            guard !alias.isEmpty && alias.count >= 3 else { return nil }
            return CachedTrigger(
                id: snippet.id,
                alias: alias,
                content: snippet.content,
                name: snippet.name,
                hasPlaceholders: SnippetPlaceholders.hasPlaceholders(snippet.content)
            )
        }
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        buffer = ""
        isRunning = false
    }

    /// Processes typed character off main thread callback and hops to MainActor.
    private nonisolated func handleKeyDown(event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Handle Backspace (keycode 0x33)
        if keyCode == 0x33 {
            Task { @MainActor in
                if !self.buffer.isEmpty {
                    self.buffer.removeLast()
                }
            }
            return
        }

        // Get typed Unicode character
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
        guard length > 0 else { return }

        let str = String(utf16CodeUnits: chars, count: length)

        Task { @MainActor in
            self.appendCharacter(str)
        }
    }

    private func appendCharacter(_ char: String) {
        // Reset buffer if more than 3 seconds elapsed between keystrokes
        if Date().timeIntervalSince(lastKeyTime) > 3.0 {
            buffer = ""
        }
        lastKeyTime = Date()

        buffer.append(char)
        if buffer.count > 40 {
            buffer = String(buffer.suffix(40))
        }

        // Check if buffer ends with any registered alias
        checkForTriggerMatch()
    }

    private func checkForTriggerMatch() {
        guard buffer.hasSuffix(":") else { return }

        // Fast in-memory check without touching SwiftData or disk
        for trigger in cachedTriggers {
            guard buffer.hasSuffix(trigger.alias) else { continue }

            // Match detected!
            buffer = ""
            triggerSnippet(trigger)
            break
        }
    }

    private func triggerSnippet(_ trigger: CachedTrigger) {
        if trigger.hasPlaceholders {
            // Summon interactive variable prompt with auto-erase on completion
            FloatingPanelController.shared.showPlaceholderPrompt(
                snippetName: trigger.name,
                template: trigger.content,
                backspacesToErase: trigger.alias.count
            )
        } else {
            // Direct expansion: backspace the typed alias and paste the snippet content
            TextInserter.insert(text: trigger.content, backspaces: trigger.alias.count)
            model?.recordSnippetUsage(id: trigger.id)
        }
    }
}
