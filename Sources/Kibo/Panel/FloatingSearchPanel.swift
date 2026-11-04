import AppKit
import Carbon.HIToolbox
import SwiftData
import SwiftUI
import KiboKit

// ═══════════════════════════════════════════════════════════════════════════
// MARK: 1 — NSPanel (Key-Window Floating HUD)
// ═══════════════════════════════════════════════════════════════════════════

final class FloatingPanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .fullSizeContentView],
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
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, let onKeyDown, onKeyDown(event) { return }
        super.sendEvent(event)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: 2 — AppKit Search TextField (NSViewRepresentable)
// ═══════════════════════════════════════════════════════════════════════════

final class PanelSearchTextField: NSTextField {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, let w = self.window else { return }
            w.makeFirstResponder(self)
        }
    }
}

struct CommandBarSearchField: NSViewRepresentable {
    @ObservedObject var controller: FloatingPanelController

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }

    func makeNSView(context: Context) -> PanelSearchTextField {
        let tf = PanelSearchTextField()
        tf.delegate = context.coordinator
        tf.isBordered = false
        tf.drawsBackground = false
        tf.focusRingType = .none
        tf.font = .systemFont(ofSize: 18, weight: .regular)
        tf.textColor = .white
        tf.placeholderAttributedString = NSAttributedString(
            string: "Search for emojis and snippets...",
            attributes: [
                .foregroundColor: NSColor.white.withAlphaComponent(0.38),
                .font: NSFont.systemFont(ofSize: 18, weight: .regular)
            ]
        )
        return tf
    }

    func updateNSView(_ nsView: PanelSearchTextField, context: Context) {
        if nsView.stringValue != controller.query {
            nsView.stringValue = controller.query
        }
        if context.coordinator.lastFocusToken != controller.focusToken {
            context.coordinator.lastFocusToken = controller.focusToken
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let controller: FloatingPanelController
        var lastFocusToken: Int = 0

        init(controller: FloatingPanelController) {
            self.controller = controller
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            controller.onUserTyped(tf.stringValue)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: 3 — Display Models
// ═══════════════════════════════════════════════════════════════════════════

struct DisplayRow: Identifiable {
    let id: String
    let index: Int
    let emoji: String?
    var emojiChar: String? { emoji }
    let title: String
    let category: String
    let primaryCode: String
    let isFavorite: Bool
    let usageCount: Int
    let isSnippet: Bool
    let allShortcodes: [String]
    let emojiItem: EmojiItem?
    let snippet: Snippet?

    var content: String {
        emoji ?? snippet?.content ?? ""
    }
}

struct DisplaySection: Identifiable {
    let id: String
    let title: String
    let rows: [DisplayRow]
}

struct ActionItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let shortcut: String
    let isDestructive: Bool
    let run: @MainActor () -> Void

    init(
        id: String,
        title: String,
        icon: String,
        shortcut: String = "",
        isDestructive: Bool = false,
        run: @escaping @MainActor () -> Void
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.shortcut = shortcut
        self.isDestructive = isDestructive
        self.run = run
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: 4 — Placeholder Prompt State (For Template Snippets)
// ═══════════════════════════════════════════════════════════════════════════

final class PlaceholderPromptState: ObservableObject, Identifiable {
    let id = UUID()
    let snippetName: String
    let template: String
    let placeholders: [SnippetPlaceholders.Placeholder]
    let backspaces: Int

    @Published var values: [String: String] = [:]
    @Published var activeIndex: Int = 0

    init(snippetName: String, template: String, backspaces: Int = 0) {
        self.snippetName = snippetName
        self.template = template
        self.backspaces = backspaces
        self.placeholders = SnippetPlaceholders.extract(from: template)
        for p in placeholders { values[p.key] = p.defaultValue ?? "" }
    }

    var substituted: String {
        SnippetPlaceholders.substitute(template: template, with: values)
    }

    var activePlaceholder: SnippetPlaceholders.Placeholder? {
        guard activeIndex >= 0 && activeIndex < placeholders.count else { return nil }
        return placeholders[activeIndex]
    }

    func nextField() {
        guard !placeholders.isEmpty else { return }
        activeIndex = (activeIndex + 1) % placeholders.count
    }

    func prevField() {
        guard !placeholders.isEmpty else { return }
        activeIndex = (activeIndex - 1 + placeholders.count) % placeholders.count
    }

    func appendText(_ t: String) {
        guard let p = activePlaceholder else { return }
        values[p.key, default: ""] += t
    }

    func backspace() {
        guard let p = activePlaceholder else { return }
        var v = values[p.key] ?? ""
        if !v.isEmpty {
            v.removeLast()
            values[p.key] = v
        }
    }

    func clearCurrent() {
        guard let p = activePlaceholder else { return }
        values[p.key] = ""
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: 5 — Floating Panel Controller
// ═══════════════════════════════════════════════════════════════════════════

@MainActor
final class FloatingPanelController: ObservableObject {
    static let shared = FloatingPanelController()

    private var panel: FloatingPanel?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private(set) var targetApp: NSRunningApplication?
    private weak var appModel: AppModel?

    // ── Published state ──
    @Published var isVisible = false
    @Published var query: String = "" {
        didSet {
            guard query != oldValue else { return }
            selectedIndex = 0
            refreshTrackerCache()
            buildResults(for: query.trimmingCharacters(in: .whitespaces))
        }
    }
    var flattenedItems: [DisplayRow] { flatRows }
    @Published var selectedIndex: Int = 0
    @Published var sections: [DisplaySection] = []
    @Published var flatRows: [DisplayRow] = []
    @Published var focusToken: Int = 0

    // ── ⌘K Actions Overlay state ──
    @Published var isActionsMenuOpen = false
    @Published var actionIndex: Int = 0
    @Published var actionQuery: String = ""
    @Published var shortcodesBanner: (name: String, codes: [String])? = nil
    @Published var toastMessage: String? = nil
    @Published var placeholderPrompt: PlaceholderPromptState?

    // Cached tracker data read once per search batch
    private var cachedUsage: [String: Int] = [:]
    private var cachedFavs: Set<String> = []
    private var cachedHidden: Set<String> = []

    private init() {
        registerGlobalHotKey()
    }

    // ── Hot Key ──

    private func registerGlobalHotKey() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let ctrl = Unmanaged<FloatingPanelController>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { ctrl.toggle() }
            return noErr
        }, 1, &spec, selfPtr, &eventHandler)

        let hotKeyID = EventHotKeyID(signature: 0x4B49424F, id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_K),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    // ── Show / Hide / Toggle ──

    func configure(model: AppModel) { appModel = model }

    func show(model: AppModel) {
        appModel = model
        query = ""
        selectedIndex = 0
        isActionsMenuOpen = false
        actionIndex = 0
        actionQuery = ""
        shortcodesBanner = nil
        toastMessage = nil

        let myPID = ProcessInfo.processInfo.processIdentifier
        if let f = NSWorkspace.shared.frontmostApplication, f.processIdentifier != myPID {
            targetApp = f
        } else if let l = ActiveAppTracker.shared.lastExternalApp, l.processIdentifier != myPID {
            targetApp = l
        } else {
            targetApp = NSWorkspace.shared.runningApplications.first {
                $0.activationPolicy == .regular && !$0.isTerminated && $0.processIdentifier != myPID
            }
        }

        refreshTrackerCache()
        buildResults(for: "")

        if panel == nil {
            let p = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 640, height: 460))
            installKeyHandler(on: p)
            let root = FloatingSearchPanelContent(controller: self)
                .environment(model)
                .modelContainer(model.container)
                .themed()
            p.contentView = NSHostingView(rootView: root)
            NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: p,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    if let s = self, s.placeholderPrompt == nil, s.isVisible {
                        s.hide()
                    }
                }
            }
            panel = p
        }
        guard let p = panel else { return }
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            p.setFrameOrigin(NSPoint(
                x: f.midX - p.frame.width / 2,
                y: f.maxY - p.frame.height - 120
            ))
        }
        p.orderFrontRegardless()
        NSApp.activate()
        p.makeKeyAndOrderFront(nil)
        isVisible = true
        focusToken += 1
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
        placeholderPrompt = nil
        isActionsMenuOpen = false
        shortcodesBanner = nil
        toastMessage = nil
    }

    func toggle(model: AppModel? = nil) {
        if isVisible {
            hide()
        } else if let m = model ?? appModel {
            show(model: m)
        }
    }

    // ── Input & Search ──

    /// Called synchronously by NSTextField delegate when user types.
    /// Updates query immediately for instant zero-latency rendering.
    func onUserTyped(_ text: String) {
        self.query = text
    }

    func clearQuery() {
        query = ""
        selectedIndex = 0
        refreshTrackerCache()
        buildResults(for: "")
    }

    func updateSearchResults() {
        refreshTrackerCache()
        buildResults(for: query.trimmingCharacters(in: .whitespaces))
    }

    private func refreshTrackerCache() {
        cachedUsage = EmojiUsageTracker.shared.getCounts()
        cachedFavs = EmojiUsageTracker.shared.getFavorites()
        cachedHidden = EmojiUsageTracker.shared.getHidden()
    }

    // ── Result Builder ──

    private func buildResults(for trimmed: String) {
        let snippets: [Snippet] = (try? appModel?.container.mainContext.fetch(FetchDescriptor<Snippet>())) ?? []

        if trimmed.isEmpty {
            var sugg: [DisplayRow] = []
            var idx = 0

            // Favorites
            for e in EmojiCatalog.all where cachedFavs.contains(e.emoji) && !cachedHidden.contains(e.emoji) {
                sugg.append(emojiRow(e, section: "sugg", index: idx)); idx += 1
            }
            // Frequently used emojis (top 12)
            let used = EmojiCatalog.all
                .filter { (cachedUsage[$0.emoji] ?? 0) > 0 && !cachedFavs.contains($0.emoji) && !cachedHidden.contains($0.emoji) }
                .sorted { (cachedUsage[$0.emoji] ?? 0) > (cachedUsage[$1.emoji] ?? 0) }
            for e in used.prefix(12) {
                sugg.append(emojiRow(e, section: "sugg", index: idx)); idx += 1
            }
            // Frequently used snippets (top 5)
            for s in snippets.filter({ $0.usageCount > 0 }).sorted(by: { $0.usageCount > $1.usageCount }).prefix(5) {
                sugg.append(snippetRow(s, section: "sugg", index: idx)); idx += 1
            }
            // Fallback essential emojis
            if sugg.count < 6 {
                for ch in ["🔥", "👍", "🙏", "❤️", "😂", "😍", "✨", "🚀", "🎉", "☕", "🍕", "🌹"] {
                    if let e = EmojiCatalog.all.first(where: { $0.emoji == ch }),
                       !sugg.contains(where: { $0.emoji == ch }) {
                        sugg.append(emojiRow(e, section: "sugg", index: idx)); idx += 1
                    }
                }
            }

            var sects = [DisplaySection(id: "suggestions", title: "Suggestions", rows: sugg)]

            // Top initial batch of all emojis
            var allRows: [DisplayRow] = []
            for e in EmojiCatalog.all.prefix(40) where !cachedHidden.contains(e.emoji) {
                allRows.append(emojiRow(e, section: "all", index: idx)); idx += 1
            }
            sects.append(DisplaySection(id: "all", title: "All Emojis", rows: allRows))

            if !snippets.isEmpty {
                var snipRows: [DisplayRow] = []
                for s in snippets.prefix(10) {
                    snipRows.append(snippetRow(s, section: "all_snip", index: idx)); idx += 1
                }
                sects.append(DisplaySection(id: "snippets", title: "Snippets", rows: snipRows))
            }

            sections = sects
            flatRows = sects.flatMap(\.rows)
            return
        }

        // ── Search mode ──
        let emojiHits = EmojiCatalog.filter(
            query: trimmed,
            usageCounts: cachedUsage,
            favorites: cachedFavs,
            hidden: cachedHidden
        )
        let snippetHits = SnippetSearch.filter(items: snippets, query: trimmed) { s in
            (name: s.name, alias: s.alias, category: s.category, content: s.content)
        }

        var sects: [DisplaySection] = []
        var idx = 0

        if !emojiHits.isEmpty {
            var rows: [DisplayRow] = []
            for e in emojiHits.prefix(40) {
                rows.append(emojiRow(e, section: "search", index: idx)); idx += 1
            }
            sects.append(DisplaySection(id: "search_emojis", title: "Emojis", rows: rows))
        }
        if !snippetHits.isEmpty {
            var rows: [DisplayRow] = []
            for s in snippetHits.prefix(15) {
                rows.append(snippetRow(s, section: "search_snip", index: idx)); idx += 1
            }
            sects.append(DisplaySection(id: "search_snippets", title: "Snippets", rows: rows))
        }

        sections = sects
        flatRows = sects.flatMap(\.rows)
    }

    private func emojiRow(_ e: EmojiItem, section: String, index: Int) -> DisplayRow {
        DisplayRow(
            id: "\(section)_\(e.id)",
            index: index,
            emoji: e.emoji,
            title: e.name,
            category: e.category,
            primaryCode: e.primaryAlias,
            isFavorite: cachedFavs.contains(e.emoji),
            usageCount: cachedUsage[e.emoji] ?? 0,
            isSnippet: false,
            allShortcodes: e.aliases,
            emojiItem: e,
            snippet: nil
        )
    }

    private func snippetRow(_ s: Snippet, section: String, index: Int) -> DisplayRow {
        DisplayRow(
            id: "\(section)_\(s.id)",
            index: index,
            emoji: nil,
            title: s.name,
            category: s.category.isEmpty ? "Snippet" : s.category,
            primaryCode: s.alias.isEmpty ? "Snippet" : s.alias,
            isFavorite: s.isFavourite,
            usageCount: s.usageCount,
            isSnippet: true,
            allShortcodes: s.alias.isEmpty ? [] : [s.alias],
            emojiItem: nil,
            snippet: s
        )
    }

    // ── Navigation ──

    func moveDown() {
        if isActionsMenuOpen {
            let count = currentActions.count
            if actionIndex < count - 1 { actionIndex += 1 }
        } else if selectedIndex < flatRows.count - 1 {
            selectedIndex += 1
        }
    }

    func moveUp() {
        if isActionsMenuOpen {
            if actionIndex > 0 { actionIndex -= 1 }
        } else if selectedIndex > 0 {
            selectedIndex -= 1
        }
    }

    func moveToStart() {
        if isActionsMenuOpen {
            actionIndex = 0
        } else {
            selectedIndex = 0
        }
    }

    func moveToEnd() {
        if isActionsMenuOpen {
            actionIndex = max(0, currentActions.count - 1)
        } else {
            selectedIndex = max(0, flatRows.count - 1)
        }
    }

    func commit() {
        if isActionsMenuOpen {
            let a = currentActions
            guard actionIndex >= 0 && actionIndex < a.count else { return }
            a[actionIndex].run()
        } else {
            selectCurrent()
        }
    }

    func handleEscape() {
        if shortcodesBanner != nil { shortcodesBanner = nil; return }
        if isActionsMenuOpen { isActionsMenuOpen = false; return }
        if !query.isEmpty { clearQuery(); return }
        hide()
    }

    func toggleActionsMenu() {
        isActionsMenuOpen.toggle()
        actionIndex = 0
        actionQuery = ""
    }

    var selectedRow: DisplayRow? {
        guard selectedIndex >= 0 && selectedIndex < flatRows.count else { return nil }
        return flatRows[selectedIndex]
    }

    // ── Select / Insert ──

    func selectCurrent() {
        guard let row = selectedRow else { return }
        if let snippet = row.snippet {
            if SnippetPlaceholders.hasPlaceholders(snippet.content) {
                placeholderPrompt = PlaceholderPromptState(snippetName: snippet.name, template: snippet.content)
                return
            }
            insertText(snippet.content)
            appModel?.recordSnippetUsage(id: snippet.id)
        } else if let e = row.emojiItem {
            insertText(e.emoji)
            EmojiUsageTracker.shared.recordUsage(emoji: e.emoji)
        }
        SoundFeedback.playExpansionClick()
    }

    func insertText(_ text: String) {
        let target = targetApp
        hide()
        TextInserter.insert(text: text, into: target)
    }

    func showToast(_ msg: String) {
        toastMessage = msg
        Task {
            try? await Task.sleep(for: .seconds(2))
            if toastMessage == msg { toastMessage = nil }
        }
    }

    // ── ⌘K Actions ──

    var currentActions: [ActionItem] {
        guard let row = selectedRow else { return [] }
        var list: [ActionItem] = []

        if let e = row.emojiItem {
            list.append(ActionItem(id: "insert", title: "Insert Emoji", icon: "arrow.turn.down.left", shortcut: "↵") { [weak self] in
                self?.selectCurrent()
            })
            list.append(ActionItem(id: "copy", title: "Copy Emoji to Clipboard", icon: "doc.on.doc", shortcut: "⌘C") { [weak self] in
                guard let self else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(e.emoji, forType: .string)
                EmojiUsageTracker.shared.recordUsage(emoji: e.emoji)
                self.showToast("Copied \(e.emoji)")
                self.isActionsMenuOpen = false
            })
            list.append(ActionItem(id: "shortcode", title: "Copy Shortcode (\(e.primaryAlias))", icon: "number", shortcut: "⌥⌘C") { [weak self] in
                guard let self else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(e.primaryAlias, forType: .string)
                self.showToast("Copied \(e.primaryAlias)")
                self.isActionsMenuOpen = false
            })
            list.append(ActionItem(id: "all_codes", title: "Show All Shortcodes", icon: "text.bubble", shortcut: "⌘S") { [weak self] in
                guard let self else { return }
                self.shortcodesBanner = (name: e.name, codes: e.aliases)
                self.isActionsMenuOpen = false
            })
            let fav = cachedFavs.contains(e.emoji)
            list.append(ActionItem(id: "fav", title: fav ? "Remove from Favorites" : "Add to Favorites",
                                   icon: fav ? "star.fill" : "star", shortcut: "⇧⌘F") { [weak self] in
                guard let self else { return }
                let r = EmojiUsageTracker.shared.toggleFavorite(e.emoji)
                self.refreshTrackerCache()
                self.buildResults(for: self.query.trimmingCharacters(in: .whitespaces))
                self.showToast(r ? "Added to Favorites" : "Removed from Favorites")
                self.isActionsMenuOpen = false
            })
            list.append(ActionItem(id: "reset", title: "Reset Ranking", icon: "arrow.counterclockwise", shortcut: "⌘R") { [weak self] in
                guard let self else { return }
                EmojiUsageTracker.shared.resetRanking(for: e.emoji)
                self.refreshTrackerCache()
                self.buildResults(for: self.query.trimmingCharacters(in: .whitespaces))
                self.showToast("Reset ranking")
                self.isActionsMenuOpen = false
            })
            list.append(ActionItem(id: "hide", title: "Hide from Search", icon: "eye.slash", shortcut: "⇧⌘H") { [weak self] in
                guard let self else { return }
                EmojiUsageTracker.shared.toggleHidden(e.emoji)
                self.refreshTrackerCache()
                self.buildResults(for: self.query.trimmingCharacters(in: .whitespaces))
                self.showToast("Hidden from search")
                self.isActionsMenuOpen = false
            })
            list.append(ActionItem(id: "hex", title: "Copy Unicode Hex (\(e.unicodeHex))", icon: "curlybraces", shortcut: "⌥⌘U") { [weak self] in
                guard let self else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(e.unicodeHex, forType: .string)
                self.showToast("Copied \(e.unicodeHex)")
                self.isActionsMenuOpen = false
            })
        } else if let s = row.snippet {
            list.append(ActionItem(id: "insert", title: "Insert Snippet", icon: "arrow.turn.down.left", shortcut: "↵") { [weak self] in
                self?.selectCurrent()
            })
            list.append(ActionItem(id: "copy", title: "Copy to Clipboard", icon: "doc.on.doc", shortcut: "⌘C") { [weak self] in
                guard let self else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(s.content, forType: .string)
                self.appModel?.recordSnippetUsage(id: s.id)
                self.showToast("Copied \"\(s.name)\"")
                self.isActionsMenuOpen = false
            })
            if !s.alias.isEmpty {
                list.append(ActionItem(id: "alias", title: "Copy Alias (\(s.alias))", icon: "number", shortcut: "⌥⌘C") { [weak self] in
                    guard let self else { return }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(s.alias, forType: .string)
                    self.showToast("Copied \(s.alias)")
                    self.isActionsMenuOpen = false
                })
            }
            list.append(ActionItem(id: "fav", title: s.isFavourite ? "Remove from Favorites" : "Add to Favorites",
                                   icon: s.isFavourite ? "star.fill" : "star", shortcut: "⇧⌘F") { [weak self] in
                guard let self else { return }
                self.appModel?.toggleFavourite(s)
                self.showToast(s.isFavourite ? "Favorited" : "Removed")
                self.isActionsMenuOpen = false
            })
            list.append(ActionItem(id: "reset", title: "Reset Ranking", icon: "arrow.counterclockwise", shortcut: "⌘R") { [weak self] in
                guard let self else { return }
                s.usageCount = 0
                s.lastUsedAt = nil
                self.showToast("Reset ranking")
                self.isActionsMenuOpen = false
            })
            list.append(ActionItem(id: "del", title: "Delete Snippet", icon: "trash", shortcut: "⌘⌫", isDestructive: true) { [weak self] in
                guard let self else { return }
                self.appModel?.deleteSnippet(s)
                self.refreshTrackerCache()
                self.buildResults(for: self.query.trimmingCharacters(in: .whitespaces))
                self.showToast("Deleted snippet")
                self.isActionsMenuOpen = false
            })
        }

        if !actionQuery.isEmpty {
            let q = actionQuery.lowercased()
            return list.filter { $0.title.lowercased().contains(q) }
        }
        return list
    }

    // ── Key Handler ──

    private func installKeyHandler(on p: FloatingPanel) {
        p.onKeyDown = { [weak self] event in
            guard let self else { return false }

            // Variable Direct-Input mode
            if let prompt = self.placeholderPrompt {
                switch event.keyCode {
                case 53: self.hide(); return true
                case 36: self.commitPlaceholderPrompt(); return true
                case 48:
                    event.modifierFlags.contains(.shift) ? prompt.prevField() : prompt.nextField()
                    return true
                case 125: prompt.nextField(); return true
                case 126: prompt.prevField(); return true
                case 51:
                    event.modifierFlags.contains(.command) ? prompt.clearCurrent() : prompt.backspace()
                    return true
                default:
                    if event.keyCode == 9 && event.modifierFlags.contains(.command),
                       let p = NSPasteboard.general.string(forType: .string) {
                        prompt.appendText(p)
                        return true
                    }
                    if event.keyCode == 0 && event.modifierFlags.contains(.command) {
                        prompt.clearCurrent()
                        return true
                    }
                    if !event.modifierFlags.contains(.command),
                       let ch = event.characters, !ch.isEmpty,
                       let s = ch.unicodeScalars.first, s.value >= 32 && s.value != 127 {
                        prompt.appendText(ch)
                        return true
                    }
                    return false
                }
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let cmd = flags.contains(.command)
            let shift = flags.contains(.shift)
            let opt = flags.contains(.option)

            switch event.keyCode {
            case 40 where cmd && !shift && !opt: self.toggleActionsMenu(); return true // ⌘K
            case 53:  self.handleEscape(); return true                                 // Esc
            case 125: self.moveDown(); return true                                     // ↓
            case 126: self.moveUp(); return true                                       // ↑
            case 115: self.moveToStart(); return true                                  // Home
            case 119: self.moveToEnd(); return true                                    // End
            case 36:  self.commit(); return true                                       // ↵
            case 8 where cmd && !shift && !opt:                                        // ⌘C
                if let r = self.selectedRow {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(r.content, forType: .string)
                    self.showToast("Copied \(r.content)")
                }
                return true
            case 8 where cmd && opt:                                                   // ⌥⌘C
                if let r = self.selectedRow {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(r.primaryCode, forType: .string)
                    self.showToast("Copied \(r.primaryCode)")
                }
                return true
            case 3 where cmd && shift:                                                 // ⇧⌘F
                if let r = self.selectedRow, let ch = r.emoji {
                    let f = EmojiUsageTracker.shared.toggleFavorite(ch)
                    self.refreshTrackerCache()
                    self.buildResults(for: self.query.trimmingCharacters(in: .whitespaces))
                    self.showToast(f ? "Added to Favorites" : "Removed from Favorites")
                }
                return true
            case 15 where cmd && !shift && !opt:                                       // ⌘R
                if let r = self.selectedRow, let ch = r.emoji {
                    EmojiUsageTracker.shared.resetRanking(for: ch)
                    self.refreshTrackerCache()
                    self.buildResults(for: self.query.trimmingCharacters(in: .whitespaces))
                    self.showToast("Reset ranking")
                }
                return true
            case 4 where cmd && shift:                                                 // ⇧⌘H
                if let r = self.selectedRow, let ch = r.emoji {
                    EmojiUsageTracker.shared.toggleHidden(ch)
                    self.refreshTrackerCache()
                    self.buildResults(for: self.query.trimmingCharacters(in: .whitespaces))
                    self.showToast("Hidden from search")
                }
                return true
            case 1 where cmd && !shift && !opt:                                        // ⌘S
                if let r = self.selectedRow {
                    self.shortcodesBanner = (name: r.title, codes: r.allShortcodes)
                }
                return true
            default:
                return false // All regular typing routed to AppKit NSTextField natively
            }
        }
    }

    // ── Placeholder Prompt ──

    func showPlaceholderPrompt(snippetName: String, template: String, backspacesToErase: Int = 0) {
        guard let m = appModel else { return }
        placeholderPrompt = PlaceholderPromptState(
            snippetName: snippetName,
            template: template,
            backspaces: backspacesToErase
        )
        show(model: m)
    }

    func commitPlaceholderPrompt() {
        guard let p = placeholderPrompt else { return }
        let text = p.substituted
        let target = targetApp
        let bs = p.backspaces
        hide()
        TextInserter.insert(text: text, into: target, backspaces: bs)
        SoundFeedback.playExpansionClick()
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: 6 — Main SwiftUI View
// ═══════════════════════════════════════════════════════════════════════════

struct FloatingSearchPanelContent: View {
    @ObservedObject var controller: FloatingPanelController
    @Environment(AppModel.self) private var model

    private var actionTitle: String {
        guard let r = controller.selectedRow else { return "Insert" }
        return r.isSnippet ? "Insert Snippet" : "Insert Emoji"
    }

    var body: some View {
        VStack(spacing: 0) {
            if let prompt = controller.placeholderPrompt {
                PlaceholderPromptHUDView(prompt: prompt, controller: controller)
            } else {
                searchHeader
                if let b = controller.shortcodesBanner {
                    shortcodesBannerView(b)
                }
                resultsList
                if let t = controller.toastMessage {
                    toastView(t)
                }
                footerBar
            }
        }
        .frame(width: 640, height: 460)
        .background(Color(red: 0.11, green: 0.12, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.16), lineWidth: 1)) // grid: ok border
        .overlay(alignment: .bottomTrailing) {
            if controller.isActionsMenuOpen, let row = controller.selectedRow {
                ActionsMenuOverlay(controller: controller, row: row, actions: controller.currentActions)
                    .padding(.trailing, Space.md)
                    .padding(.bottom, 44)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96, anchor: .bottomTrailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
    }

    // ── Search Header (Image 1 Top) ──
    private var searchHeader: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.8))

            CommandBarSearchField(controller: controller)
                .frame(maxWidth: .infinity)
                .frame(height: 28)

            if !controller.query.isEmpty {
                Button {
                    controller.clearQuery()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            Text("⌘⇧K")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.7))
                .padding(.horizontal, Space.sm)
                .padding(.vertical, 2) // grid: ok badge
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, Space.lg)
        .frame(height: 56)
        .background(Color(red: 0.14, green: 0.15, blue: 0.18))
        .overlay(Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1), alignment: .bottom) // grid: ok border
    }

    // ── Results List ──
    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(controller.sections) { section in
                        Text(section.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.42))
                            .padding(.horizontal, Space.lg)
                            .padding(.top, Space.sm)
                            .padding(.bottom, Space.xs)

                        ForEach(section.rows) { row in
                            RowView(row: row, isSelected: row.index == controller.selectedIndex)
                                .id(row.id)
                                .onTapGesture {
                                    controller.selectedIndex = row.index
                                    controller.commit()
                                }
                        }
                    }
                }
                .padding(.horizontal, Space.sm)
                .padding(.vertical, Space.xs)
            }
            .frame(maxHeight: .infinity)
            .background(Color(red: 0.11, green: 0.12, blue: 0.14))
            .onChange(of: controller.selectedIndex) { _, _ in
                if let sel = controller.selectedRow {
                    proxy.scrollTo(sel.id, anchor: .center)
                }
            }
            .onChange(of: controller.flatRows.first?.id) { _, firstId in
                if let firstId {
                    proxy.scrollTo(firstId, anchor: .top)
                }
            }
        }
        .overlay {
            if controller.flatRows.isEmpty {
                VStack(spacing: Space.xs) {
                    Text("No results").font(.headline).foregroundStyle(.white)
                    Text("Try another search term or emoji shortcode like :fire:.")
                        .font(.caption).foregroundStyle(Color.white.opacity(0.6))
                }
            }
        }
    }

    // ── Footer (Image 1 Bottom) ──
    private var footerBar: some View {
        HStack(spacing: Space.sm) {
            Button {
                controller.toggleActionsMenu()
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Actions (⌘K)")

            Text("\(controller.flatRows.count) items")
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.45))

            Spacer()

            HStack(spacing: 0) {
                Button {
                    controller.commit()
                } label: {
                    HStack(spacing: Space.xs) {
                        Text(actionTitle)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                        keycap("↵")
                    }
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, Space.xs)
                }
                .buttonStyle(.plain)

                Rectangle().fill(Color.white.opacity(0.18)).frame(width: 1, height: 16) // grid: ok divider

                Button {
                    controller.toggleActionsMenu()
                } label: {
                    HStack(spacing: Space.xs) {
                        Text("Actions")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.85))
                        HStack(spacing: 1) { // grid: ok keycap
                            Text("⌘").font(.system(size: 9, weight: .bold))
                            Text("K").font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1) // grid: ok keycap
                        .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.white)
                    }
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, Space.xs)
                }
                .buttonStyle(.plain)
            }
            .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.14), lineWidth: 1)) // grid: ok border
        }
        .padding(.horizontal, Space.lg)
        .frame(height: 36)
        .background(Color(red: 0.08, green: 0.09, blue: 0.11))
        .overlay(Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1), alignment: .top) // grid: ok border
    }

    private func keycap(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 1) // grid: ok keycap
            .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(.white)
    }

    private func shortcodesBannerView(_ banner: (name: String, codes: [String])) -> some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "info.circle.fill").foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
            VStack(alignment: .leading, spacing: 1) { // grid: ok label
                Text("All Shortcodes for \(banner.name)").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                Text(banner.codes.joined(separator: "   ")).font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.white.opacity(0.85))
            }
            Spacer()
            Button("Copy All") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(banner.codes.joined(separator: ", "), forType: .string)
                controller.showToast("Copied all shortcodes")
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)

            Button {
                controller.shortcodesBanner = nil
            } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.xs)
        .background(Color(red: 0.16, green: 0.20, blue: 0.26))
        .overlay(Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1), alignment: .bottom) // grid: ok border
    }

    private func toastView(_ text: String) -> some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(red: 0.22, green: 0.82, blue: 0.52))
            Text(text).font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .background(Color(red: 0.15, green: 0.17, blue: 0.22), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1)) // grid: ok border
        .shadow(radius: 8)
        .padding(.bottom, Space.xs)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: 7 — Row View (Image 1 Row Layout)
// ═══════════════════════════════════════════════════════════════════════════

private struct RowView: View {
    let row: DisplayRow
    let isSelected: Bool

    var body: some View {
        HStack(spacing: Space.md) {
            ZStack(alignment: .bottomTrailing) {
                if let emoji = row.emoji {
                    Text(emoji).font(.system(size: 24)).frame(width: 32, height: 32)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.18, green: 0.44, blue: 0.88).opacity(0.35))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "text.quote")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
                        )
                }
                if row.isFavorite || row.usageCount > 0 {
                    Circle()
                        .fill(row.isFavorite ? Color.yellow : Color(red: 0.22, green: 0.82, blue: 0.52))
                        .frame(width: 6, height: 6) // grid: ok dot
                        .offset(x: 2, y: 2) // grid: ok dot
                }
            }

            Text(row.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(row.category)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.85))
                .padding(.horizontal, Space.sm)
                .padding(.vertical, 2) // grid: ok pill
                .background(isSelected ? Color.white.opacity(0.20) : Color.white.opacity(0.10), in: Capsule())

            Spacer()

            Text(row.primaryCode)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(isSelected ? Color.white.opacity(0.95) : Color.white.opacity(0.42))
                .lineLimit(1)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .background(isSelected ? Color.white.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isSelected ? Color.white.opacity(0.18) : Color.clear, lineWidth: 1)) // grid: ok border
        .contentShape(Rectangle())
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: 8 — ⌘K Actions Menu (Image 2)
// ═══════════════════════════════════════════════════════════════════════════

private struct ActionsMenuOverlay: View {
    @ObservedObject var controller: FloatingPanelController
    let row: DisplayRow
    let actions: [ActionItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(row.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(1)
                Spacer()
                Button {
                    controller.isActionsMenuOpen = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Space.md)
            .padding(.top, Space.md)
            .padding(.bottom, Space.sm)

            Divider().overlay(Color.white.opacity(0.12))

            VStack(spacing: 2) { // grid: ok list
                ForEach(Array(actions.enumerated()), id: \.element.id) { idx, action in
                    let sel = idx == controller.actionIndex
                    HStack(spacing: Space.sm) {
                        Image(systemName: action.icon)
                            .font(.system(size: 13))
                            .frame(width: 20)
                            .foregroundStyle(action.isDestructive ? Color.red : (sel ? .white : Color.white.opacity(0.7)))
                        Text(action.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(action.isDestructive ? Color.red : .white)
                            .lineLimit(1)
                        Spacer()
                        if !action.shortcut.isEmpty {
                            Text(action.shortcut)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .padding(.horizontal, Space.xs)
                                .padding(.vertical, 2) // grid: ok keycap
                                .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
                                .foregroundStyle(Color.white.opacity(0.85))
                        }
                    }
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, Space.sm)
                    .background(sel ? Color.white.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                    .onTapGesture { action.run() }
                }
            }
            .padding(Space.xs)

            Divider().overlay(Color.white.opacity(0.12))

            HStack(spacing: Space.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.4))
                TextField("", text: $controller.actionQuery,
                          prompt: Text("Search for actions...").foregroundColor(Color.white.opacity(0.35)))
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .background(Color.black.opacity(0.25))
        }
        .frame(width: 320)
        .background(Color(red: 0.16, green: 0.17, blue: 0.20))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.18), lineWidth: 1)) // grid: ok border
        .shadow(color: Color.black.opacity(0.5), radius: 16, x: 0, y: 8)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: 9 — Placeholder Prompt HUD
// ═══════════════════════════════════════════════════════════════════════════

private struct BlinkingCursor: View {
    @State private var on = true
    var body: some View {
        Rectangle()
            .fill(Color(red: 0.45, green: 0.75, blue: 1.0))
            .frame(width: 2, height: 20)
            .opacity(on ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                    on.toggle()
                }
            }
    }
}

private struct PlaceholderPromptHUDView: View {
    @ObservedObject var prompt: PlaceholderPromptState
    @ObservedObject var controller: FloatingPanelController

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.sm) {
                Image(systemName: "text.badge.plus")
                    .font(.title3)
                    .foregroundStyle(Color(red: 0.18, green: 0.82, blue: 0.44))
                VStack(alignment: .leading, spacing: 0) {
                    Text(prompt.snippetName).font(.headline).foregroundStyle(.white)
                    Text("Type variable values. ⇥ or ↓ Next • ↵ Insert")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                Spacer()
                Button {
                    controller.hide()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.white.opacity(0.6))
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Space.lg)
            .frame(height: 56)
            .background(Color(red: 0.14, green: 0.15, blue: 0.18))
            .overlay(Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1), alignment: .bottom) // grid: ok border

            ScrollView {
                VStack(spacing: Space.md) {
                    VStack(spacing: Space.sm) {
                        ForEach(Array(prompt.placeholders.enumerated()), id: \.element.id) { idx, p in
                            let active = idx == prompt.activeIndex
                            let val = prompt.values[p.key] ?? ""
                            HStack(spacing: Space.md) {
                                Text("{{\(p.key)}}")
                                    .font(.caption.monospaced().weight(.semibold))
                                    .foregroundStyle(active ? Color(red: 0.18, green: 0.82, blue: 0.44) : Color.white.opacity(0.7))
                                    .frame(width: 120, alignment: .leading)
                                HStack(spacing: Space.xs) {
                                    if val.isEmpty {
                                        Text(p.defaultValue.map { "Default: \($0)" } ?? "Type \(p.key)...")
                                            .font(.body)
                                            .foregroundStyle(Color.white.opacity(0.35))
                                    } else {
                                        Text(val).font(.body).foregroundStyle(.white)
                                    }
                                    if active { BlinkingCursor() }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, Space.sm)
                                .frame(height: 36)
                                .background(
                                    active ? Color(red: 0.20, green: 0.22, blue: 0.26) : Color(red: 0.14, green: 0.15, blue: 0.17),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8).strokeBorder(
                                        active ? Color(red: 0.18, green: 0.82, blue: 0.44) : Color.white.opacity(0.1),
                                        lineWidth: active ? 2 : 1
                                    ) // grid: ok border
                                )
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { prompt.activeIndex = idx }
                        }
                    }
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("LIVE PREVIEW").font(.caption2.weight(.bold)).foregroundStyle(Color.white.opacity(0.5))
                        Text(prompt.substituted)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.white)
                            .textSelection(.enabled)
                            .padding(Space.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(red: 0.08, green: 0.09, blue: 0.11), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.12), lineWidth: 1)) // grid: ok border
                    }
                }
                .padding(Space.lg)
            }
            .frame(maxHeight: 280)
            .background(Color(red: 0.11, green: 0.12, blue: 0.14))

            HStack(spacing: Space.sm) {
                Text("↵ Insert"); Text("•"); Text("⇥ / ↓ Next"); Text("•"); Text("esc Cancel")
                Spacer()
                if let t = controller.targetApp {
                    Text("Target: \(t.localizedName ?? "App")")
                        .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
                        .fontWeight(.medium)
                }
                Button("Insert Text") {
                    controller.commitPlaceholderPrompt()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .font(.caption2)
            .foregroundStyle(Color.white.opacity(0.65))
            .padding(.horizontal, Space.lg)
            .frame(height: 40)
            .background(Color(red: 0.08, green: 0.09, blue: 0.11))
            .overlay(Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1), alignment: .top) // grid: ok border
        }
    }
}
