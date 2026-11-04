import AppKit
import Carbon.HIToolbox
import SwiftData
import SwiftUI
import KiboKit

// MARK: - Floating HUD Panel (AppKit NSPanel with Key Window Support)

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
        level = .popUpMenu // Floating HUD above standard windows and full-screen spaces
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        // Hide standard window decorations to create a borderless HUD appearance
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }

    /// Essential for allowing keyboard input inside text fields.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            if let onKeyDown, onKeyDown(event) {
                return
            }
        }
        super.sendEvent(event)
    }
}

// MARK: - Models

enum CommandBarItemType: Equatable {
    case emoji(EmojiItem)
    case snippet(Snippet)
}

struct CommandBarItem: Identifiable, Equatable {
    let id: String
    let title: String
    let category: String
    let primaryCode: String
    let emojiChar: String?
    let allShortcodes: [String]
    let content: String
    let type: CommandBarItemType

    static func emojiItem(_ e: EmojiItem) -> CommandBarItem {
        CommandBarItem(
            id: "e_\(e.id)",
            title: e.name,
            category: e.category,
            primaryCode: e.primaryAlias,
            emojiChar: e.emoji,
            allShortcodes: e.aliases,
            content: e.emoji,
            type: .emoji(e)
        )
    }

    static func snippetItem(_ s: Snippet) -> CommandBarItem {
        CommandBarItem(
            id: "s_\(s.id)",
            title: s.name,
            category: s.category.isEmpty ? "Snippet" : s.category,
            primaryCode: s.alias.isEmpty ? "Snippet" : s.alias,
            emojiChar: nil,
            allShortcodes: s.alias.isEmpty ? [] : [s.alias],
            content: s.content,
            type: .snippet(s)
        )
    }

    static func == (lhs: CommandBarItem, rhs: CommandBarItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct CommandBarSection: Identifiable {
    let id: String
    let title: String
    let items: [CommandBarItem]
}

struct ActionItem: Identifiable, Sendable {
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

// MARK: - Placeholder Prompt State (For Variable Snippets)

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
        for p in placeholders {
            values[p.key] = p.defaultValue ?? ""
        }
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

    func appendText(_ text: String) {
        guard let p = activePlaceholder else { return }
        values[p.key] = (values[p.key] ?? "") + text
    }

    func backspace() {
        guard let p = activePlaceholder else { return }
        var current = values[p.key] ?? ""
        if !current.isEmpty {
            current.removeLast()
            values[p.key] = current
        }
    }

    func clearCurrent() {
        guard let p = activePlaceholder else { return }
        values[p.key] = ""
    }
}

// MARK: - Floating Panel Controller

@MainActor
final class FloatingPanelController: ObservableObject {
    static let shared = FloatingPanelController()

    private(set) var panel: FloatingPanel?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private(set) var targetApp: NSRunningApplication?
    private weak var appModel: AppModel?

    @Published var isVisible = false
    @Published var query: String = "" {
        didSet {
            if query != oldValue {
                selectedIndex = 0
                updateSearchResults()
            }
        }
    }
    @Published var selectedIndex: Int = 0
    @Published var sections: [CommandBarSection] = []
    @Published var flattenedItems: [CommandBarItem] = []
    @Published var focusToken: Int = 0

    // ⌘K Action Menu State
    @Published var isActionsMenuOpen = false
    @Published var actionIndex: Int = 0
    @Published var actionQuery: String = ""
    @Published var shortcodesBanner: (name: String, codes: [String])? = nil
    @Published var toastMessage: String? = nil

    // Variable Direct Input HUD
    @Published var placeholderPrompt: PlaceholderPromptState?

    private init() {
        registerGlobalHotKey()
    }

    /// Registers ⌘⇧K globally using Carbon Event HotKey API.
    private func registerGlobalHotKey() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let controller = Unmanaged<FloatingPanelController>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated {
                controller.toggle()
            }
            return noErr
        }, 1, &spec, selfPtr, &eventHandler)

        // ⌘⇧K : kVK_ANSI_K = 0x28, cmdKey = 0x0100, shiftKey = 0x0200
        let hotKeyID = EventHotKeyID(signature: 0x4B49424F, id: 1) // 'KIBO', 1
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_K),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            print("Kibo: RegisterEventHotKey failed with status \(status)")
        }
    }

    func configure(model: AppModel) {
        self.appModel = model
    }

    func show(model: AppModel) {
        self.appModel = model
        self.selectedIndex = 0
        self.query = ""
        self.isActionsMenuOpen = false
        self.actionIndex = 0
        self.actionQuery = ""
        self.shortcodesBanner = nil
        self.toastMessage = nil

        // Record the frontmost application before Kibo's command bar steals focus
        let frontApp = NSWorkspace.shared.frontmostApplication
        let myPID = ProcessInfo.processInfo.processIdentifier
        if let front = frontApp, front.processIdentifier != myPID {
            targetApp = front
        } else if let last = ActiveAppTracker.shared.lastExternalApp, last.processIdentifier != myPID {
            targetApp = last
        } else {
            targetApp = NSWorkspace.shared.runningApplications.first(where: {
                $0.activationPolicy == .regular && !$0.isTerminated && $0.processIdentifier != myPID
            })
        }

        updateSearchResults()

        if panel == nil {
            let p = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 640, height: 460))
            setupPanelKeyHandling(panel: p)

            let rootView = FloatingSearchPanelContent(controller: self)
                .environment(model)
                .modelContainer(model.container)
                .themed()

            let hostingView = NSHostingView(rootView: rootView)
            p.contentView = hostingView

            NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: p,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if self.placeholderPrompt == nil && self.isVisible {
                        self.hide()
                    }
                }
            }

            panel = p
        }

        guard let p = panel else { return }

        // Center on the active screen's upper third (Spotlight position)
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - (p.frame.width / 2)
            let y = screenFrame.maxY - p.frame.height - 120
            p.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Activate Kibo and make the panel key window
        p.orderFrontRegardless()
        NSApp.activate()
        p.makeKeyAndOrderFront(nil)
        p.makeKey()
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

    // MARK: - Fast Search & Filter Engine

    func updateSearchResults() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let usage = EmojiUsageTracker.shared.getCounts()
        let favs = EmojiUsageTracker.shared.getFavorites()
        let hid = EmojiUsageTracker.shared.getHidden()
        let allSnippets: [Snippet] = (try? appModel?.container.mainContext.fetch(FetchDescriptor<Snippet>())) ?? []

        if trimmed.isEmpty {
            var newSections: [CommandBarSection] = []

            // 1. Suggestions: Favorites + Frequently used
            var suggestionItems: [CommandBarItem] = []

            // Favorites first
            let favEmojis = EmojiCatalog.all.filter { favs.contains($0.emoji) && !hid.contains($0.emoji) }
            suggestionItems.append(contentsOf: favEmojis.map { CommandBarItem.emojiItem($0) })

            // High usage emojis
            let usedEmojis = EmojiCatalog.all.filter {
                (usage[$0.emoji] ?? 0) > 0 && !favs.contains($0.emoji) && !hid.contains($0.emoji)
            }.sorted { (usage[$0.emoji] ?? 0) > (usage[$1.emoji] ?? 0) }
            suggestionItems.append(contentsOf: usedEmojis.prefix(12).map { CommandBarItem.emojiItem($0) })

            // Frequently used snippets
            let usedSnippets = allSnippets.filter { $0.usageCount > 0 }.sorted { $0.usageCount > $1.usageCount }
            suggestionItems.append(contentsOf: usedSnippets.prefix(5).map { CommandBarItem.snippetItem($0) })

            // Fallback essential emojis
            if suggestionItems.count < 6 {
                let essentials = ["🔥", "👍", "🙏", "❤️", "😂", "😍", "✨", "🚀", "🎉", "☕", "🍕", "🌹"]
                for ess in essentials {
                    if let item = EmojiCatalog.all.first(where: { $0.emoji == ess }),
                       !suggestionItems.contains(where: { $0.emojiChar == ess }) {
                        suggestionItems.append(CommandBarItem.emojiItem(item))
                    }
                }
            }

            newSections.append(CommandBarSection(id: "suggestions", title: "Suggestions", items: suggestionItems))

            // 2. All Emojis (Top initial batch for instant 120 FPS rendering)
            let remaining = EmojiCatalog.all.filter { !hid.contains($0.emoji) }
            newSections.append(CommandBarSection(
                id: "all_emojis",
                title: "All Emojis",
                items: remaining.prefix(40).map { CommandBarItem.emojiItem($0) }
            ))

            // 3. User Snippets
            if !allSnippets.isEmpty {
                newSections.append(CommandBarSection(
                    id: "snippets",
                    title: "Snippets",
                    items: allSnippets.prefix(10).map { CommandBarItem.snippetItem($0) }
                ))
            }

            self.sections = newSections
            self.flattenedItems = newSections.flatMap(\.items)
            return
        }

        // Live Search Mode: Searches entire 1,723+ dataset and snippets
        let emojiMatches = EmojiCatalog.filter(
            query: trimmed,
            usageCounts: usage,
            favorites: favs,
            hidden: hid
        )

        let snippetMatches = SnippetSearch.filter(items: allSnippets, query: trimmed) { s in
            (name: s.name, alias: s.alias, category: s.category, content: s.content)
        }

        var newSections: [CommandBarSection] = []

        let cleanQuery = trimmed.lowercased().replacingOccurrences(of: ":", with: "")
        let isExplicitEmoji = trimmed.hasPrefix(":") ||
            EmojiCatalog.reverseEngineer(input: trimmed) != nil ||
            emojiMatches.first?.aliases.contains(where: {
                let a = $0.trimmingCharacters(in: CharacterSet(charactersIn: ":")).lowercased()
                return a == cleanQuery || a.replacingOccurrences(of: "_", with: "") == cleanQuery
            }) == true

        if isExplicitEmoji || !emojiMatches.isEmpty {
            if !emojiMatches.isEmpty {
                newSections.append(CommandBarSection(
                    id: "emojis",
                    title: "Emojis",
                    items: emojiMatches.prefix(50).map { CommandBarItem.emojiItem($0) }
                ))
            }
            if !snippetMatches.isEmpty {
                newSections.append(CommandBarSection(
                    id: "snippets",
                    title: "Snippets",
                    items: snippetMatches.prefix(20).map { CommandBarItem.snippetItem($0) }
                ))
            }
        } else {
            if !snippetMatches.isEmpty {
                newSections.append(CommandBarSection(
                    id: "snippets",
                    title: "Snippets",
                    items: snippetMatches.prefix(20).map { CommandBarItem.snippetItem($0) }
                ))
            }
            if !emojiMatches.isEmpty {
                newSections.append(CommandBarSection(
                    id: "emojis",
                    title: "Emojis",
                    items: emojiMatches.prefix(50).map { CommandBarItem.emojiItem($0) }
                ))
            }
        }

        self.sections = newSections
        self.flattenedItems = newSections.flatMap(\.items)
    }

    // MARK: - Navigation & Action Handlers

    func moveDown() {
        if isActionsMenuOpen {
            let actions = currentActions
            if actionIndex < actions.count - 1 {
                actionIndex += 1
            }
        } else {
            if selectedIndex < flattenedItems.count - 1 {
                selectedIndex += 1
            }
        }
    }

    func moveUp() {
        if isActionsMenuOpen {
            if actionIndex > 0 {
                actionIndex -= 1
            }
        } else {
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
        }
    }

    func commit() {
        if isActionsMenuOpen {
            let actions = currentActions
            guard actionIndex >= 0 && actionIndex < actions.count else { return }
            actions[actionIndex].run()
        } else {
            selectCurrentItem()
        }
    }

    func handleEscape() {
        if shortcodesBanner != nil {
            shortcodesBanner = nil
            return
        }
        if isActionsMenuOpen {
            isActionsMenuOpen = false
            return
        }
        if !query.isEmpty {
            query = ""
            selectedIndex = 0
            return
        }
        hide()
    }

    func toggleActionsMenu() {
        isActionsMenuOpen.toggle()
        actionIndex = 0
        actionQuery = ""
    }

    var selectedItem: CommandBarItem? {
        guard selectedIndex >= 0 && selectedIndex < flattenedItems.count else { return nil }
        return flattenedItems[selectedIndex]
    }

    func selectCurrentItem() {
        guard let item = selectedItem else { return }

        switch item.type {
        case .snippet(let snippet):
            if SnippetPlaceholders.hasPlaceholders(snippet.content) {
                showPlaceholderPrompt(snippetName: snippet.name, template: snippet.content)
            } else {
                insertText(snippet.content)
                appModel?.recordSnippetUsage(id: snippet.id)
                SoundFeedback.playExpansionClick()
            }
        case .emoji(let emojiItem):
            insertText(emojiItem.emoji)
            EmojiUsageTracker.shared.recordUsage(emoji: emojiItem.emoji)
            SoundFeedback.playExpansionClick()
        }
    }

    func insertText(_ text: String) {
        hide()
        let target = targetApp
        TextInserter.insert(text: text, into: target)
        query = ""
        selectedIndex = 0
    }

    func showToast(_ message: String) {
        self.toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.0))
            if self.toastMessage == message {
                self.toastMessage = nil
            }
        }
    }

    // MARK: - Actions Generator for ⌘K Menu

    var currentActions: [ActionItem] {
        guard let item = selectedItem else { return [] }
        var list: [ActionItem] = []

        switch item.type {
        case .emoji(let e):
            list.append(ActionItem(
                id: "insert",
                title: "Insert Emoji",
                icon: "arrow.turn.down.left",
                shortcut: "↵"
            ) { [weak self] in
                self?.selectCurrentItem()
            })

            list.append(ActionItem(
                id: "copy",
                title: "Copy Emoji to Clipboard",
                icon: "doc.on.doc",
                shortcut: "⌘C"
            ) { [weak self] in
                guard let self else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(e.emoji, forType: .string)
                EmojiUsageTracker.shared.recordUsage(emoji: e.emoji)
                self.showToast("Copied \(e.emoji) to clipboard")
                self.isActionsMenuOpen = false
            })

            list.append(ActionItem(
                id: "copy_shortcode",
                title: "Copy Shortcode (\(e.primaryAlias))",
                icon: "number",
                shortcut: "⌥⌘C"
            ) { [weak self] in
                guard let self else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(e.primaryAlias, forType: .string)
                self.showToast("Copied shortcode \(e.primaryAlias)")
                self.isActionsMenuOpen = false
            })

            list.append(ActionItem(
                id: "show_shortcodes",
                title: "Show All Shortcodes",
                icon: "text.bubble",
                shortcut: "⌘S"
            ) { [weak self] in
                guard let self else { return }
                self.shortcodesBanner = (name: e.name, codes: e.aliases)
                self.isActionsMenuOpen = false
            })

            list.append(ActionItem(
                id: "reset_ranking",
                title: "Reset Ranking",
                icon: "arrow.counterclockwise",
                shortcut: "⌘R"
            ) { [weak self] in
                guard let self else { return }
                EmojiUsageTracker.shared.resetRanking(for: e.emoji)
                self.updateSearchResults()
                self.showToast("Reset ranking for \(e.name)")
                self.isActionsMenuOpen = false
            })

            let isFav = EmojiUsageTracker.shared.isFavorite(e.emoji)
            list.append(ActionItem(
                id: "toggle_fav",
                title: isFav ? "Remove from Favorites" : "Add to Favorites",
                icon: isFav ? "star.fill" : "star",
                shortcut: "⇧⌘F"
            ) { [weak self] in
                guard let self else { return }
                let newFav = EmojiUsageTracker.shared.toggleFavorite(e.emoji)
                self.updateSearchResults()
                self.showToast(newFav ? "Added \(e.emoji) to Favorites" : "Removed from Favorites")
                self.isActionsMenuOpen = false
            })

            list.append(ActionItem(
                id: "hide_search",
                title: "Hide from Search",
                icon: "eye.slash",
                shortcut: "⇧⌘H"
            ) { [weak self] in
                guard let self else { return }
                EmojiUsageTracker.shared.toggleHidden(e.emoji)
                self.updateSearchResults()
                self.showToast("Hidden \(e.name) from suggestions")
                self.isActionsMenuOpen = false
            })

            list.append(ActionItem(
                id: "copy_hex",
                title: "Copy Unicode Hex (\(e.unicodeHex))",
                icon: "curlybraces",
                shortcut: "⌥⌘U"
            ) { [weak self] in
                guard let self else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(e.unicodeHex, forType: .string)
                self.showToast("Copied \(e.unicodeHex)")
                self.isActionsMenuOpen = false
            })

        case .snippet(let s):
            list.append(ActionItem(
                id: "insert",
                title: "Insert Snippet",
                icon: "arrow.turn.down.left",
                shortcut: "↵"
            ) { [weak self] in
                self?.selectCurrentItem()
            })

            list.append(ActionItem(
                id: "copy",
                title: "Copy Snippet to Clipboard",
                icon: "doc.on.doc",
                shortcut: "⌘C"
            ) { [weak self] in
                guard let self else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(s.content, forType: .string)
                self.appModel?.recordSnippetUsage(id: s.id)
                self.showToast("Copied \"\(s.name)\" to clipboard")
                self.isActionsMenuOpen = false
            })

            if !s.alias.isEmpty {
                list.append(ActionItem(
                    id: "copy_alias",
                    title: "Copy Alias (\(s.alias))",
                    icon: "number",
                    shortcut: "⌥⌘C"
                ) { [weak self] in
                    guard let self else { return }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(s.alias, forType: .string)
                    self.showToast("Copied alias \(s.alias)")
                    self.isActionsMenuOpen = false
                })
            }

            list.append(ActionItem(
                id: "reset_ranking",
                title: "Reset Ranking",
                icon: "arrow.counterclockwise",
                shortcut: "⌘R"
            ) { [weak self] in
                guard let self else { return }
                s.usageCount = 0
                s.lastUsedAt = nil
                self.updateSearchResults()
                self.showToast("Reset ranking for \(s.name)")
                self.isActionsMenuOpen = false
            })

            list.append(ActionItem(
                id: "toggle_fav",
                title: s.isFavourite ? "Remove from Favorites" : "Add to Favorites",
                icon: s.isFavourite ? "star.fill" : "star",
                shortcut: "⇧⌘F"
            ) { [weak self] in
                guard let self else { return }
                self.appModel?.toggleFavourite(s)
                self.updateSearchResults()
                self.showToast(s.isFavourite ? "Added to Favorites" : "Removed from Favorites")
                self.isActionsMenuOpen = false
            })

            list.append(ActionItem(
                id: "delete",
                title: "Delete Snippet",
                icon: "trash",
                shortcut: "⌘⌫",
                isDestructive: true
            ) { [weak self] in
                guard let self else { return }
                self.appModel?.deleteSnippet(s)
                self.updateSearchResults()
                self.showToast("Deleted snippet \"\(s.name)\"")
                self.isActionsMenuOpen = false
            })
        }

        if !actionQuery.isEmpty {
            let q = actionQuery.lowercased()
            return list.filter { $0.title.lowercased().contains(q) }
        }
        return list
    }

    // MARK: - Direct Key Handling Setup

    private func setupPanelKeyHandling(panel p: FloatingPanel) {
        p.onKeyDown = { [weak self] event in
            guard let self else { return false }

            // Variable Direct-Input mode handling
            if let prompt = self.placeholderPrompt {
                switch event.keyCode {
                case 53: // Escape
                    self.hide()
                    return true
                case 36: // Return
                    self.commitPlaceholderPrompt()
                    return true
                case 48: // Tab
                    if event.modifierFlags.contains(.shift) {
                        prompt.prevField()
                    } else {
                        prompt.nextField()
                    }
                    return true
                case 125: // Down Arrow
                    prompt.nextField()
                    return true
                case 126: // Up Arrow
                    prompt.prevField()
                    return true
                case 51: // Backspace
                    if event.modifierFlags.contains(.command) {
                        prompt.clearCurrent()
                    } else {
                        prompt.backspace()
                    }
                    return true
                default:
                    if event.keyCode == 9 && event.modifierFlags.contains(.command) { // ⌘V
                        if let pasted = NSPasteboard.general.string(forType: .string) {
                            prompt.appendText(pasted)
                            return true
                        }
                    }
                    if event.keyCode == 0 && event.modifierFlags.contains(.command) { // ⌘A
                        prompt.clearCurrent()
                        return true
                    }
                    if !event.modifierFlags.contains(.command),
                       let chars = event.characters, !chars.isEmpty {
                        let scalars = chars.unicodeScalars
                        if let first = scalars.first, first.value >= 32 && first.value != 127 {
                            prompt.appendText(chars)
                            return true
                        }
                    }
                    return false
                }
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let isCommand = flags.contains(.command)
            let isShift = flags.contains(.shift)
            let isOption = flags.contains(.option)

            // ⌘K: Toggle Actions Menu
            if isCommand && !isShift && !isOption && event.keyCode == 40 {
                self.toggleActionsMenu()
                return true
            }

            // Escape (53): dismiss shortcodes banner, close actions menu, or hide panel
            if event.keyCode == 53 {
                self.handleEscape()
                return true
            }

            // Down Arrow (125)
            if event.keyCode == 125 {
                self.moveDown()
                return true
            }

            // Up Arrow (126)
            if event.keyCode == 126 {
                self.moveUp()
                return true
            }

            // Return (36)
            if event.keyCode == 36 {
                self.commit()
                return true
            }

            // Command Shortcuts
            if isCommand {
                // ⌘C: Copy emoji / snippet
                if !isShift && !isOption && event.keyCode == 8 {
                    if let item = self.selectedItem {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(item.content, forType: .string)
                        self.showToast("Copied to clipboard")
                    }
                    return true
                }
                // ⌥⌘C: Copy shortcode
                if isOption && event.keyCode == 8 {
                    if let item = self.selectedItem {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(item.primaryCode, forType: .string)
                        self.showToast("Copied shortcode \(item.primaryCode)")
                    }
                    return true
                }
                // ⇧⌘F: Toggle Favorite
                if isShift && event.keyCode == 3 {
                    if let item = self.selectedItem, let emoji = item.emojiChar {
                        let isFav = EmojiUsageTracker.shared.toggleFavorite(emoji)
                        self.updateSearchResults()
                        self.showToast(isFav ? "Added to Favorites" : "Removed from Favorites")
                    }
                    return true
                }
                // ⌘R: Reset Ranking
                if !isShift && !isOption && event.keyCode == 15 {
                    if let item = self.selectedItem, let emoji = item.emojiChar {
                        EmojiUsageTracker.shared.resetRanking(for: emoji)
                        self.updateSearchResults()
                        self.showToast("Reset ranking for \(item.title)")
                    }
                    return true
                }
                // ⇧⌘H: Hide from Search
                if isShift && event.keyCode == 4 {
                    if let item = self.selectedItem, let emoji = item.emojiChar {
                        EmojiUsageTracker.shared.toggleHidden(emoji)
                        self.updateSearchResults()
                        self.showToast("Hidden from suggestions")
                    }
                    return true
                }
                // ⌘S: Show all shortcodes
                if !isShift && !isOption && event.keyCode == 1 {
                    if let item = self.selectedItem {
                        self.shortcodesBanner = (name: item.title, codes: item.allShortcodes)
                    }
                    return true
                }
            }

            // All other keystrokes (text input, typing, delete, spaces) route to the focused TextField
            return false
        }
    }

    // MARK: - Snippet Dynamic Variable HUD

    func showPlaceholderPrompt(snippetName: String, template: String, backspacesToErase: Int = 0) {
        guard let model = appModel else { return }
        self.placeholderPrompt = PlaceholderPromptState(
            snippetName: snippetName,
            template: template,
            backspaces: backspacesToErase
        )
        show(model: model)
    }

    func commitPlaceholderPrompt() {
        guard let prompt = placeholderPrompt else { return }
        let substituted = prompt.substituted
        let target = targetApp
        let backspaces = prompt.backspaces
        hide()
        TextInserter.insert(text: substituted, into: target, backspaces: backspaces)
        SoundFeedback.playExpansionClick()
    }
}

// MARK: - Floating Search Panel SwiftUI Content

struct FloatingSearchPanelContent: View {
    @ObservedObject var controller: FloatingPanelController
    @Environment(AppModel.self) private var model
    @FocusState private var isSearchFocused: Bool

    private var primaryActionTitle: String {
        guard let item = controller.selectedItem else { return "Insert" }
        switch item.type {
        case .emoji: return "Insert Emoji"
        case .snippet: return "Insert Snippet"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let prompt = controller.placeholderPrompt {
                // Dynamic Variable Direct-Input Mode
                PlaceholderPromptHUDView(prompt: prompt, controller: controller)
            } else {
                // Search Header (Image 1)
                HStack(spacing: Space.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.8))

                    TextField(
                        "",
                        text: $controller.query,
                        prompt: Text("Search for emojis and snippets...").foregroundColor(Color.white.opacity(0.38))
                    )
                    .font(.system(size: 18, weight: .regular))
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .focused($isSearchFocused)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)

                    if !controller.query.isEmpty {
                        Button {
                            controller.query = ""
                            controller.selectedIndex = 0
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: Space.xs) {
                        Text("⌘⇧K")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .padding(.horizontal, Space.sm)
                            .padding(.vertical, 2) // grid: ok badge
                            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(.horizontal, Space.lg)
                .frame(height: 56)
                .background(Color(red: 0.14, green: 0.15, blue: 0.18))
                .overlay(
                    Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1), // grid: ok border
                    alignment: .bottom
                )

                // Optional Shortcodes Banner
                if let banner = controller.shortcodesBanner {
                    HStack(spacing: Space.sm) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
                        VStack(alignment: .leading, spacing: 1) { // grid: ok label
                            Text("All Shortcodes for \(banner.name)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(banner.codes.joined(separator: "   "))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.85))
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
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.vertical, Space.xs)
                    .background(Color(red: 0.16, green: 0.20, blue: 0.26))
                    .overlay(Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1), alignment: .bottom) // grid: ok border
                }

                // Results List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: Space.xs) {
                            ForEach(controller.sections) { section in
                                if !section.items.isEmpty {
                                    Text(section.title)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Color.white.opacity(0.42))
                                        .padding(.horizontal, Space.lg)
                                        .padding(.top, Space.sm)
                                        .padding(.bottom, 2) // grid: ok label spacing

                                    ForEach(section.items) { item in
                                        let index = controller.flattenedItems.firstIndex(where: { $0.id == item.id }) ?? 0
                                        FloatingRowView(
                                            item: item,
                                            isSelected: index == controller.selectedIndex,
                                            isFavorite: EmojiUsageTracker.shared.isFavorite(item.emojiChar ?? ""),
                                            usageCount: EmojiUsageTracker.shared.usageCount(for: item.emojiChar ?? "")
                                        )
                                        .id(index)
                                        .onTapGesture {
                                            controller.selectedIndex = index
                                            controller.commit()
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Space.sm)
                        .padding(.vertical, Space.xs)
                    }
                    .frame(maxHeight: .infinity)
                    .background(Color(red: 0.11, green: 0.12, blue: 0.14))
                    .onChange(of: controller.selectedIndex) { _, newIndex in
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
                .overlay {
                    if controller.flattenedItems.isEmpty {
                        VStack(spacing: Space.xs) {
                            Text("No results")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Try another search term or emoji shortcode like :fire:.")
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }

                // Toast Notification Overlay
                if let toast = controller.toastMessage {
                    HStack(spacing: Space.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color(red: 0.22, green: 0.82, blue: 0.52))
                        Text(toast)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.vertical, Space.sm)
                    .background(Color(red: 0.15, green: 0.17, blue: 0.22), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1)) // grid: ok border
                    .shadow(radius: 8)
                    .padding(.bottom, Space.xs)
                }

                // High Contrast Command Bar Footer (Image 1)
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

                    Text("\(controller.flattenedItems.count) \(controller.flattenedItems.count == 1 ? "item" : "items")")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.45))

                    Spacer()

                    // Unified Action Pill Container (Raycast / Spotlight Reference)
                    HStack(spacing: 0) {
                        Button {
                            controller.commit()
                        } label: {
                            HStack(spacing: Space.xs) {
                                Text(primaryActionTitle)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("↵")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1) // grid: ok keycap
                                    .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, Space.sm)
                            .padding(.vertical, Space.xs)
                        }
                        .buttonStyle(.plain)

                        Rectangle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 1, height: 16) // grid: ok divider

                        Button {
                            controller.toggleActionsMenu()
                        } label: {
                            HStack(spacing: Space.xs) {
                                Text("Actions")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.85))
                                HStack(spacing: 1) { // grid: ok keycap
                                    Text("⌘")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("K")
                                        .font(.system(size: 9, weight: .bold))
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1) // grid: ok border
                    )
                }
                .padding(.horizontal, Space.lg)
                .frame(height: 36)
                .background(Color(red: 0.08, green: 0.09, blue: 0.11))
                .overlay(
                    Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1), // grid: ok border
                    alignment: .top
                )
            }
        }
        .frame(width: 640, height: 460)
        .background(Color(red: 0.11, green: 0.12, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1) // grid: ok border
        )
        // ⌘K Actions Menu Overlay (Image 2)
        .overlay(alignment: .bottomTrailing) {
            if controller.isActionsMenuOpen, let item = controller.selectedItem {
                ActionsMenuOverlay(
                    controller: controller,
                    selectedItem: item,
                    actions: controller.currentActions
                )
                .padding(.trailing, Space.md)
                .padding(.bottom, 44)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.96, anchor: .bottomTrailing).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .onAppear {
            isSearchFocused = true
        }
        .onChange(of: controller.focusToken) { _, _ in
            isSearchFocused = true
        }
    }
}

// MARK: - Row View (Matches Reference Screenshot Image 1)

private struct FloatingRowView: View {
    let item: CommandBarItem
    let isSelected: Bool
    let isFavorite: Bool
    let usageCount: Int

    var body: some View {
        HStack(spacing: Space.md) {
            // Left Icon + Indicator Dot
            ZStack(alignment: .bottomTrailing) {
                switch item.type {
                case .emoji(let e):
                    Text(e.emoji)
                        .font(.system(size: 24))
                        .frame(width: 32, height: 32)
                case .snippet:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.18, green: 0.44, blue: 0.88).opacity(0.35))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "text.quote")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
                        )
                }

                if isFavorite || usageCount > 0 {
                    Circle()
                        .fill(isFavorite ? Color.yellow : Color(red: 0.22, green: 0.82, blue: 0.52))
                        .frame(width: 6, height: 6) // grid: ok indicator dot
                        .offset(x: 2, y: 2) // grid: ok indicator dot offset
                }
            }

            // Name
            Text(item.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)

            // Category Pill (compact short pill next to name)
            Text(item.category)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.85))
                .padding(.horizontal, Space.sm)
                .padding(.vertical, 2) // grid: ok capsule padding
                .background(
                    isSelected ? Color.white.opacity(0.20) : Color.white.opacity(0.10),
                    in: Capsule()
                )

            Spacer()

            // Primary shortcode aligned on the right (Where "Application" was in Image 1)
            Text(item.primaryCode)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(isSelected ? Color.white.opacity(0.95) : Color.white.opacity(0.42))
                .lineLimit(1)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .background(
            isSelected ? Color.white.opacity(0.14) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.white.opacity(0.18) : Color.clear, lineWidth: 1) // grid: ok border
        )
        .contentShape(Rectangle())
    }
}

// MARK: - ⌘K Actions Menu Overlay (Matches Reference Screenshot Image 2)

private struct ActionsMenuOverlay: View {
    @ObservedObject var controller: FloatingPanelController
    let selectedItem: CommandBarItem
    let actions: [ActionItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Selected item title
            HStack {
                Text(selectedItem.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(1)
                Spacer()
                Button {
                    controller.isActionsMenuOpen = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold)) // grid: ok symbol
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Space.md)
            .padding(.top, Space.md)
            .padding(.bottom, Space.sm)

            Divider()
                .overlay(Color.white.opacity(0.12))

            // Actions List
            VStack(spacing: 2) { // grid: ok list spacing
                ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                    let isSelected = index == controller.actionIndex
                    HStack(spacing: Space.sm) {
                        Image(systemName: action.icon)
                            .font(.system(size: 13))
                            .frame(width: 20)
                            .foregroundStyle(action.isDestructive ? Color.red : (isSelected ? .white : Color.white.opacity(0.7)))

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
                    .background(
                        isSelected ? Color.white.opacity(0.16) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        action.run()
                    }
                }
            }
            .padding(Space.xs)

            Divider()
                .overlay(Color.white.opacity(0.12))

            // Action Search Input (Image 2)
            HStack(spacing: Space.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.4))
                TextField(
                    "",
                    text: $controller.actionQuery,
                    prompt: Text("Search for actions...").foregroundColor(Color.white.opacity(0.35))
                )
                .font(.system(size: 12))
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .background(Color.black.opacity(0.25))
        }
        .frame(width: 312)
        .background(Color(red: 0.16, green: 0.17, blue: 0.20))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1) // grid: ok border
        )
        .shadow(color: Color.black.opacity(0.5), radius: 16, x: 0, y: 8)
    }
}

// MARK: - Direct-Input Variable HUD (Preserved for Placeholder Prompts)

private struct BlinkingCursor: View {
    @State private var visible = true

    var body: some View {
        Rectangle()
            .fill(Color(red: 0.45, green: 0.75, blue: 1.0))
            .frame(width: 2, height: 20)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                    visible.toggle()
                }
            }
    }
}

private struct PlaceholderPromptHUDView: View {
    @ObservedObject var prompt: PlaceholderPromptState
    @ObservedObject var controller: FloatingPanelController

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: Space.sm) {
                Image(systemName: "text.badge.plus")
                    .font(.title3)
                    .foregroundStyle(Color(red: 0.18, green: 0.82, blue: 0.44))

                VStack(alignment: .leading, spacing: 0) {
                    Text(prompt.snippetName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Type variable values. ⇥ or ↓ Next • ↵ Insert directly into app")
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

            // Variables List
            ScrollView {
                VStack(spacing: Space.md) {
                    VStack(spacing: Space.sm) {
                        ForEach(Array(prompt.placeholders.enumerated()), id: \.element.id) { index, p in
                            let isActive = index == prompt.activeIndex
                            let val = prompt.values[p.key] ?? ""

                            HStack(spacing: Space.md) {
                                Text("{{" + p.key + "}}")
                                    .font(.caption.monospaced().weight(.semibold))
                                    .foregroundStyle(isActive ? Color(red: 0.18, green: 0.82, blue: 0.44) : Color.white.opacity(0.7))
                                    .frame(width: 120, alignment: .leading)

                                HStack(spacing: Space.xs) {
                                    if val.isEmpty {
                                        Text(p.defaultValue.map { "Default: \($0)" } ?? "Type \(p.key)...")
                                            .font(.body)
                                            .foregroundStyle(Color.white.opacity(0.35))
                                    } else {
                                        Text(val)
                                            .font(.body)
                                            .foregroundStyle(.white)
                                    }

                                    if isActive {
                                        BlinkingCursor()
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, Space.sm)
                                .frame(height: 36)
                                .background(
                                    isActive ? Color(red: 0.20, green: 0.22, blue: 0.26) : Color(red: 0.14, green: 0.15, blue: 0.17),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            isActive ? Color(red: 0.18, green: 0.82, blue: 0.44) : Color.white.opacity(0.1),
                                            lineWidth: isActive ? 2 : 1 // grid: ok border
                                        )
                                )
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                prompt.activeIndex = index
                            }
                        }
                    }

                    // Live Preview
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("LIVE PREVIEW (WHAT WILL BE INSERTED)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.white.opacity(0.5))

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

            // Footer
            HStack(spacing: Space.sm) {
                Text("↵ Insert")
                Text("•")
                Text("⇥ / ↓ Next Field")
                Text("•")
                Text("esc Cancel")
                Spacer()
                if let target = controller.targetApp {
                    Text("Target: \(target.localizedName ?? "Active App")")
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
