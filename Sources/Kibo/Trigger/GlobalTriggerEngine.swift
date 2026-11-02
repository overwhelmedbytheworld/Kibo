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

/// Background keystroke monitor for automatic trigger alias expansion and inline suggestion HUD.
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
            options: .defaultTap, // Allows intercepting Enter/Tab/Arrows when inline suggestions are visible
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
                let swallowed = engine.handleKeyDownIntercept(event: event)
                if swallowed {
                    return nil // Swallows the keystroke so host app doesn't receive it
                }

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

    /// Processes typed character off main thread callback, intercepting navigation keys if suggestions are shown.
    private nonisolated func handleKeyDownIntercept(event: CGEvent) -> Bool {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Check whether the inline suggestion bar is active
        var isInlineActive = false
        MainActor.assumeIsolated {
            isInlineActive = InlineSuggestionController.shared.isVisible
        }

        if isInlineActive {
            // Return / Enter (0x24) or Tab (0x30)
            if keyCode == 0x24 || keyCode == 0x30 {
                Task { @MainActor in
                    InlineSuggestionController.shared.commitCurrent(targetApp: ActiveAppTracker.shared.lastExternalApp)
                    self.buffer = ""
                }
                return true // Swallows Return/Tab so message is not sent in WhatsApp
            }

            // Right Arrow (0x7C)
            if keyCode == 0x7C {
                Task { @MainActor in
                    InlineSuggestionController.shared.moveNext()
                }
                return true
            }

            // Left Arrow (0x7B)
            if keyCode == 0x7B {
                Task { @MainActor in
                    InlineSuggestionController.shared.movePrev()
                }
                return true
            }

            // Escape (0x35)
            if keyCode == 0x35 {
                Task { @MainActor in
                    InlineSuggestionController.shared.hide()
                }
                return true
            }
        }

        // Handle Backspace (0x33)
        if keyCode == 0x33 {
            Task { @MainActor in
                if !self.buffer.isEmpty {
                    self.buffer.removeLast()
                    self.evaluateInlineSuggestions()
                }
            }
            return false
        }

        // Get typed Unicode character
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
        guard length > 0 else { return false }

        let str = String(utf16CodeUnits: chars, count: length)

        Task { @MainActor in
            self.appendCharacter(str)
        }

        return false
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

        // If buffer ends with colon :, check for exact trigger match
        if buffer.hasSuffix(":") {
            checkForTriggerMatch()
        } else {
            // Otherwise, evaluate real-time inline suggestions (WhatsApp style)
            evaluateInlineSuggestions()
        }
    }

    /// Evaluates whether the current typing buffer matches any partial shortcode (e.g. ":fi" or ":smil").
    private func evaluateInlineSuggestions() {
        guard InlineSuggestionController.isInlineSuggestionEnabled else {
            InlineSuggestionController.shared.hide()
            return
        }

        let frontApp = ActiveAppTracker.shared.lastExternalApp ?? NSWorkspace.shared.frontmostApplication
        if let target = frontApp,
           InlineSuggestionController.isAppExcluded(bundleID: target.bundleIdentifier, appName: target.localizedName) {
            InlineSuggestionController.shared.hide()
            return
        }

        guard let lastColonIndex = buffer.lastIndex(of: ":") else {
            InlineSuggestionController.shared.hide()
            return
        }

        // Ensure the colon is either at start of buffer or preceded by whitespace / newline
        if lastColonIndex > buffer.startIndex {
            let prevIndex = buffer.index(before: lastColonIndex)
            if !buffer[prevIndex].isWhitespace && buffer[prevIndex] != "\n" {
                InlineSuggestionController.shared.hide()
                return
            }
        }

        let triggerSlice = buffer[lastColonIndex...]
        let triggerString = String(triggerSlice) // e.g. ":fi" or ":smil"

        // Require at least 1 character after colon and no spaces
        guard triggerString.count >= 2 && !triggerString.contains(" ") else {
            InlineSuggestionController.shared.hide()
            return
        }

        let query = String(triggerString.dropFirst()) // e.g. "fi" or "smil"
        let usage = EmojiUsageTracker.shared.getCounts()

        let matchingEmojis = EmojiCatalog.filter(query: query, usageCounts: usage).prefix(8)
        let matchingSnippets = cachedTriggers.filter {
            $0.alias.lowercased().contains(query.lowercased())
        }.prefix(3)

        if matchingEmojis.isEmpty && matchingSnippets.isEmpty {
            InlineSuggestionController.shared.hide()
            return
        }

        var items: [InlineSuggestionItem] = []
        for emoji in matchingEmojis {
            items.append(.emoji(emoji))
        }
        for snippet in matchingSnippets {
            items.append(.snippet(alias: snippet.alias, content: snippet.content, name: snippet.name))
        }

        InlineSuggestionController.shared.show(
            suggestions: items,
            trigger: triggerString,
            targetApp: ActiveAppTracker.shared.lastExternalApp
        )
    }

    private func checkForTriggerMatch() {
        // Hide inline suggestions on complete trigger entry
        InlineSuggestionController.shared.hide()

        // 1. Fast in-memory check against user snippet triggers first
        for trigger in cachedTriggers {
            guard buffer.hasSuffix(trigger.alias) else { continue }

            // Match detected!
            buffer = ""
            triggerSnippet(trigger)
            return
        }

        // 2. Instant Emoji Expansion! (e.g. :fire: -> 🔥, :thumbs_up: / :thumbsup: -> 👍)
        if let emojiMatch = EmojiCatalog.findMatch(in: buffer) {
            buffer = ""
            TextInserter.insert(text: emojiMatch.emoji, backspaces: emojiMatch.alias.count)
            EmojiUsageTracker.shared.recordUsage(emoji: emojiMatch.emoji)
            SoundFeedback.playExpansionClick()
            return
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
            SoundFeedback.playExpansionClick()
        }
    }
}
