import AppKit
import SwiftUI
import KiboKit

// MARK: - Non-Activating Floating Panel

final class InlineSuggestionPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .popUpMenu
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

public struct ExcludedAppItem: Codable, Identifiable, Hashable, Sendable {
    public var id: String { bundleID }
    public let name: String
    public let bundleID: String
    public let path: String?

    public init(name: String, bundleID: String, path: String? = nil) {
        self.name = name
        self.bundleID = bundleID
        self.path = path
    }
}

// MARK: - Controller

@MainActor
public final class InlineSuggestionController: ObservableObject {
    public static let shared = InlineSuggestionController()

    public static let defaultExcludedBundles: [String] = [
        "net.whatsapp.WhatsApp",
        "net.whatsapp.WhatsApp.mac",
        "com.tinyspeck.slackmacgap",
        "com.hnc.Discord",
        "com.discord"
    ]

    public static var customExcludedApps: [ExcludedAppItem] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "kibo.inline.custom_apps"),
                  let items = try? JSONDecoder().decode([ExcludedAppItem].self, from: data) else {
                return []
            }
            return items
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "kibo.inline.custom_apps")
            }
        }
    }

    public static func addCustomExcludedApp(name: String, bundleID: String, path: String?) {
        var apps = customExcludedApps
        if !apps.contains(where: { $0.bundleID.lowercased() == bundleID.lowercased() }) {
            apps.append(ExcludedAppItem(name: name, bundleID: bundleID, path: path))
            customExcludedApps = apps
        }
        setAppExcluded(bundleID: bundleID, isExcluded: true)
    }

    public static func removeCustomExcludedApp(bundleID: String) {
        var apps = customExcludedApps
        apps.removeAll(where: { $0.bundleID.lowercased() == bundleID.lowercased() })
        customExcludedApps = apps
        setAppExcluded(bundleID: bundleID, isExcluded: false)
    }

    public static var isInlineSuggestionEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "kibo.inline.enabled") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "kibo.inline.enabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "kibo.inline.enabled")
        }
    }

    public static var excludedBundleIDs: Set<String> {
        get {
            if let saved = UserDefaults.standard.array(forKey: "kibo.inline.excluded_bundles") as? [String] {
                return Set(saved)
            }
            return Set(defaultExcludedBundles)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "kibo.inline.excluded_bundles")
        }
    }

    public static func isAppExcluded(bundleID: String?, appName: String?) -> Bool {
        guard isInlineSuggestionEnabled else { return true }
        let excluded = excludedBundleIDs
        if let bid = bundleID?.lowercased() {
            if excluded.contains(where: { $0.lowercased() == bid }) { return true }
            if bid.contains("whatsapp") || bid.contains("discord") || bid.contains("slack") {
                if excluded.contains(where: { bid.contains($0.lowercased()) }) { return true }
            }
        }
        if let name = appName?.lowercased() {
            if excluded.contains(where: { $0.lowercased() == name }) { return true }
            if name.contains("whatsapp") && excluded.contains(where: { $0.lowercased().contains("whatsapp") }) { return true }
            if name.contains("discord") && excluded.contains(where: { $0.lowercased().contains("discord") }) { return true }
            if name.contains("slack") && excluded.contains(where: { $0.lowercased().contains("slack") }) { return true }
        }
        return false
    }

    public static func setAppExcluded(bundleID: String, isExcluded: Bool) {
        var current = excludedBundleIDs
        if isExcluded {
            current.insert(bundleID)
        } else {
            current.remove(bundleID)
        }
        excludedBundleIDs = current
    }

    @Published public var isVisible: Bool = false
    @Published public var suggestions: [InlineSuggestionItem] = []
    @Published public var selectedIndex: Int = 0

    public private(set) var currentTrigger: String = ""

    private var panel: InlineSuggestionPanel?
    private var hostingView: NSHostingView<InlineSuggestionBarView>?

    private init() {}

    public func show(
        suggestions: [InlineSuggestionItem],
        trigger: String,
        targetApp: NSRunningApplication? = nil
    ) {
        let app = targetApp ?? ActiveAppTracker.shared.lastExternalApp ?? NSWorkspace.shared.frontmostApplication
        if Self.isAppExcluded(bundleID: app?.bundleIdentifier, appName: app?.localizedName) {
            hide()
            return
        }

        guard !suggestions.isEmpty else {
            hide()
            return
        }

        self.suggestions = suggestions
        self.currentTrigger = trigger
        self.selectedIndex = 0

        let itemWidth: CGFloat = 48
        let totalWidth = max(CGFloat(suggestions.count) * itemWidth + 16, 120)
        let panelHeight: CGFloat = 48

        if panel == nil {
            let p = InlineSuggestionPanel(contentRect: NSRect(x: 0, y: 0, width: totalWidth, height: panelHeight))
            let content = InlineSuggestionBarView(controller: self)
            let host = NSHostingView(rootView: content)
            p.contentView = host
            self.panel = p
            self.hostingView = host
        } else {
            panel?.setContentSize(NSSize(width: totalWidth, height: panelHeight))
        }

        guard let p = panel else { return }

        // Position panel near text caret if Accessibility coordinates are available
        let caretRect = getCaretScreenFrame()
        let screen = NSScreen.main ?? NSScreen.screens.first

        if let screen = screen {
            let screenFrame = screen.visibleFrame
            var originX: CGFloat
            var originY: CGFloat

            if let caret = caretRect, caret.width > 0 || caret.height > 0 {
                // Place 8pt above the typing caret
                originX = max(screenFrame.minX + 16, min(caret.midX - (totalWidth / 2), screenFrame.maxX - totalWidth - 16))
                // Convert Quartz top-left coordinates to Cocoa bottom-left coordinates
                originY = (screen.frame.height - caret.minY) + 8
                if originY + panelHeight > screenFrame.maxY {
                    // Flip below caret if above screen bounds
                    originY = (screen.frame.height - caret.maxY) - panelHeight - 8
                }
            } else {
                // Centered lower-third HUD position
                originX = screenFrame.midX - (totalWidth / 2)
                originY = screenFrame.minY + 120
            }

            p.setFrameOrigin(NSPoint(x: originX, y: originY))
        }

        p.orderFrontRegardless()
        isVisible = true
    }

    public func hide() {
        panel?.orderOut(nil)
        isVisible = false
        suggestions = []
        currentTrigger = ""
        selectedIndex = 0
    }

    public func moveNext() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % suggestions.count
    }

    public func movePrev() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + suggestions.count) % suggestions.count
    }

    public func selectIndex(_ index: Int) {
        guard index >= 0 && index < suggestions.count else { return }
        selectedIndex = index
        commitCurrent()
    }

    public func commitCurrent(targetApp: NSRunningApplication? = nil) {
        guard selectedIndex >= 0 && selectedIndex < suggestions.count else {
            hide()
            return
        }

        let item = suggestions[selectedIndex]
        let backspacesToErase = currentTrigger.count

        hide()

        switch item {
        case .emoji(let emojiItem):
            TextInserter.insert(text: emojiItem.emoji, into: targetApp, backspaces: backspacesToErase)
            EmojiUsageTracker.shared.recordUsage(emoji: emojiItem.emoji)
            SoundFeedback.playExpansionClick()
        case .snippet(_, let content, let name):
            if SnippetPlaceholders.hasPlaceholders(content) {
                FloatingPanelController.shared.showPlaceholderPrompt(
                    snippetName: name,
                    template: content,
                    backspacesToErase: backspacesToErase
                )
            } else {
                TextInserter.insert(text: content, into: targetApp, backspaces: backspacesToErase)
                SoundFeedback.playExpansionClick()
            }
        }
    }

    /// Queries the macOS Accessibility API for active text cursor coordinates.
    private func getCaretScreenFrame() -> CGRect? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedAppValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedAppValue) == .success,
              let appRef = focusedAppValue else {
            return nil
        }
        // swiftlint:disable:next force_cast
        let app = appRef as! AXUIElement

        var focusedElementValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focusedElementValue) == .success,
              let elementRef = focusedElementValue else {
            return nil
        }
        // swiftlint:disable:next force_cast
        let element = elementRef as! AXUIElement

        var selectedRangeValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue) == .success,
           let rangeVal = selectedRangeValue {
            // swiftlint:disable:next force_cast
            let axVal = rangeVal as! AXValue
            var boundsValue: CFTypeRef?
            if AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, axVal, &boundsValue) == .success,
               let bVal = boundsValue {
                // swiftlint:disable:next force_cast
                let rectVal = bVal as! AXValue
                var rect = CGRect()
                AXValueGetValue(rectVal, .cgRect, &rect)
                if rect.width > 0 || rect.height > 0 {
                    return rect
                }
            }
        }

        // Fallback: get position of focused element
        var posVal: CFTypeRef?
        var sizeVal: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posVal) == .success,
           AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeVal) == .success,
           let p = posVal, let s = sizeVal {
            // swiftlint:disable:next force_cast
            let posAx = p as! AXValue
            // swiftlint:disable:next force_cast
            let sizeAx = s as! AXValue
            var point = CGPoint()
            var size = CGSize()
            AXValueGetValue(posAx, .cgPoint, &point)
            AXValueGetValue(sizeAx, .cgSize, &size)
            return CGRect(origin: point, size: size)
        }

        return nil
    }
}
