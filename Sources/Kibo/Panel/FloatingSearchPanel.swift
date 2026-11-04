import AppKit
import Carbon.HIToolbox
import SwiftData
import SwiftUI
import KiboKit

// MARK: - Custom Floating Panel with Key Window Support

final class FloatingPanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .popUpMenu // Floating HUD above all standard windows
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
    }

    /// Essential for allowing text input inside text fields.
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

// MARK: - Native Focused Command Search Bar

final class CommandSearchTextField: NSTextField {
    var onEscapePressed: (() -> Void)?
    var onReturnPressed: (() -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        focusField()
    }

    func focusField() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let win = self.window else { return }
            win.makeFirstResponder(self)
            self.currentEditor()?.moveToEndOfLine(nil)
        }
    }
}

struct CommandSearchBar: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onCommit: () -> Void
    var onEscape: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> CommandSearchTextField {
        let tf = CommandSearchTextField()
        tf.delegate = context.coordinator
        tf.isBordered = false
        tf.drawsBackground = false
        tf.focusRingType = .none
        tf.font = .systemFont(ofSize: 18, weight: .regular)
        tf.textColor = .white
        tf.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor.white.withAlphaComponent(0.38),
                .font: NSFont.systemFont(ofSize: 18, weight: .regular)
            ]
        )
        tf.target = context.coordinator
        tf.action = #selector(Coordinator.performSubmit)
        context.coordinator.textField = tf
        return tf
    }

    func updateNSView(_ nsView: CommandSearchTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        if context.environment.isEnabled {
            nsView.focusField()
        }
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CommandSearchBar
        weak var textField: CommandSearchTextField?

        init(_ parent: CommandSearchBar) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let tf = obj.object as? NSTextField {
                parent.text = tf.stringValue
            }
        }

        @objc func performSubmit() {
            parent.onCommit()
        }
    }
}

// MARK: - Floating Search Panel Controller

final class PlaceholderPromptState: ObservableObject, Identifiable {
    let id = UUID()
    let snippetName: String
    let template: String
    let backspaces: Int
    let placeholders: [SnippetPlaceholders.Placeholder]
    @Published var values: [String: String] = [:]
    @Published var activeIndex: Int = 0

    init(snippetName: String, template: String, backspaces: Int = 0) {
        self.snippetName = snippetName
        self.template = template
        self.backspaces = backspaces
        let extracted = SnippetPlaceholders.extract(from: template)
        self.placeholders = extracted
        var initial: [String: String] = [:]
        for p in extracted {
            initial[p.key] = p.defaultValue ?? ""
        }
        self.values = initial
        self.activeIndex = 0
    }

    var activeKey: String? {
        guard activeIndex >= 0 && activeIndex < placeholders.count else { return nil }
        return placeholders[activeIndex].key
    }

    var substituted: String {
        SnippetPlaceholders.substitute(template: template, with: values)
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
        guard let key = activeKey else { return }
        var current = values[key] ?? ""
        current.append(text)
        values[key] = current
    }

    func backspace() {
        guard let key = activeKey else { return }
        var current = values[key] ?? ""
        if !current.isEmpty {
            current.removeLast()
            values[key] = current
        }
    }

    func clearCurrent() {
        guard let key = activeKey else { return }
        values[key] = ""
    }
}

// MARK: - Action Item Model for ⌘K Actions Menu

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

@MainActor
final class FloatingPanelController: ObservableObject {
    static let shared = FloatingPanelController()

    private var panel: FloatingPanel?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private(set) var targetApp: NSRunningApplication?
    private weak var appModel: AppModel?

    @Published var isVisible = false
    @Published var placeholderPrompt: PlaceholderPromptState?
    @Published var selectedIndex: Int = 0
    @Published var query: String = ""

    // ⌘K Action Menu State
    @Published var isActionsMenuOpen = false
    @Published var actionIndex: Int = 0
    @Published var actionQuery: String = ""
    @Published var shortcodesBanner: (name: String, codes: [String])? = nil
    @Published var toastMessage: String? = nil

    var onCommit: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onMoveUp: (() -> Void)?
    var onActionCommit: (() -> Void)?
    var onActionMoveDown: (() -> Void)?
    var onActionMoveUp: (() -> Void)?
    var onCopyContent: (() -> Void)?
    var onCopyShortcode: (() -> Void)?
    var onToggleFavorite: (() -> Void)?
    var onResetRanking: (() -> Void)?
    var onHideItem: (() -> Void)?
    var onShowShortcodes: (() -> Void)?

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

        // Record the external app that was frontmost before Kibo's command bar appears
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

        p.orderFrontRegardless()
        NSApp.activate()
        p.makeKeyAndOrderFront(nil)
        p.makeKey()
        isVisible = true
    }

    private func setupPanelKeyHandling(panel p: FloatingPanel) {
        p.onKeyDown = { [weak self] event in
            guard let self else { return false }

            // Dynamic Variable Direct-Input mode handling
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
                if self.shortcodesBanner != nil {
                    self.shortcodesBanner = nil
                    return true
                }
                if self.isActionsMenuOpen {
                    self.isActionsMenuOpen = false
                    return true
                }
                if !self.query.isEmpty {
                    self.query = ""
                    self.selectedIndex = 0
                    return true
                }
                self.hide()
                return true
            }

            // If Actions Menu is open, route navigation and commit to actions
            if self.isActionsMenuOpen {
                switch event.keyCode {
                case 125: // Down Arrow
                    self.onActionMoveDown?()
                    return true
                case 126: // Up Arrow
                    self.onActionMoveUp?()
                    return true
                case 36: // Return
                    self.onActionCommit?()
                    return true
                default:
                    break
                }
            }

            // Command Shortcuts
            if isCommand {
                // ⌘C: Copy emoji / snippet
                if !isShift && !isOption && event.keyCode == 8 {
                    self.onCopyContent?()
                    return true
                }
                // ⌥⌘C or ⇧⌘C: Copy primary shortcode
                if (isOption || isShift) && event.keyCode == 8 {
                    self.onCopyShortcode?()
                    return true
                }
                // ⇧⌘F: Toggle Favorite
                if isShift && event.keyCode == 3 { // 'f'
                    self.onToggleFavorite?()
                    return true
                }
                // ⌘R: Reset Ranking
                if !isShift && !isOption && event.keyCode == 15 { // 'r'
                    self.onResetRanking?()
                    return true
                }
                // ⇧⌘H: Hide from Search
                if isShift && event.keyCode == 4 { // 'h'
                    self.onHideItem?()
                    return true
                }
                // ⌘S or ⌘I: Show all shortcodes
                if !isShift && !isOption && (event.keyCode == 1 || event.keyCode == 34) { // 's' or 'i'
                    self.onShowShortcodes?()
                    return true
                }
            }

            // Standard List Navigation
            switch event.keyCode {
            case 125: // Down Arrow
                self.onMoveDown?()
                return true
            case 126: // Up Arrow
                self.onMoveUp?()
                return true
            case 36: // Return
                self.onCommit?()
                return true
            default:
                // Text input is passed to the focused search field!
                return false
            }
        }
    }

    func toggleActionsMenu() {
        isActionsMenuOpen.toggle()
        actionIndex = 0
        actionQuery = ""
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
}

// MARK: - Search Result Item

enum SearchListItem: Identifiable, Equatable {
    case emoji(EmojiItem)
    case snippet(Snippet)

    var id: String {
        switch self {
        case .emoji(let e): return "e_\(e.id)"
        case .snippet(let s): return "s_\(s.id)"
        }
    }

    var title: String {
        switch self {
        case .emoji(let e): return e.name
        case .snippet(let s): return s.name
        }
    }

    var category: String {
        switch self {
        case .emoji(let e): return e.category
        case .snippet(let s): return s.category.isEmpty ? "Snippet" : s.category
        }
    }

    var primaryCode: String {
        switch self {
        case .emoji(let e): return e.primaryAlias
        case .snippet(let s): return s.alias.isEmpty ? "Snippet" : s.alias
        }
    }

    var emojiChar: String? {
        switch self {
        case .emoji(let e): return e.emoji
        case .snippet: return nil
        }
    }

    var allShortcodes: [String] {
        switch self {
        case .emoji(let e): return e.aliases
        case .snippet(let s): return [s.alias].filter { !$0.isEmpty }
        }
    }
}

struct SearchSection: Identifiable {
    let id: String
    let title: String
    let items: [SearchListItem]
}

// MARK: - Floating Search Panel SwiftUI Content

struct FloatingSearchPanelContent: View {
    @ObservedObject var controller: FloatingPanelController
    @Environment(AppModel.self) private var model

    @Query(sort: \Snippet.usageCount, order: .reverse) private var allSnippets: [Snippet]

    @State private var favs: Set<String> = []
    @State private var hid: Set<String> = []
    @State private var usage: [String: Int] = [:]

    private var matchingSnippets: [Snippet] {
        SnippetSearch.filter(items: allSnippets, query: controller.query) {
            ($0.name, $0.alias, $0.category, $0.content)
        }
    }

    private var sections: [SearchSection] {
        let trimmed = controller.query.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            var res: [SearchSection] = []

            // Suggestions: favorites, top used, frequently used snippets, essential fallbacks
            var suggestionItems: [SearchListItem] = []

            // 1. User favorites
            let favEmojis = EmojiCatalog.all.filter { favs.contains($0.emoji) && !hid.contains($0.emoji) }
            suggestionItems.append(contentsOf: favEmojis.map { .emoji($0) })

            // 2. High usage emojis
            let usedEmojis = EmojiCatalog.all.filter {
                (usage[$0.emoji] ?? 0) > 0 && !favs.contains($0.emoji) && !hid.contains($0.emoji)
            }.sorted { (usage[$0.emoji] ?? 0) > (usage[$1.emoji] ?? 0) }
            suggestionItems.append(contentsOf: usedEmojis.prefix(12).map { .emoji($0) })

            // 3. High usage snippets
            let usedSnippets = allSnippets.filter { $0.usageCount > 0 }
                .sorted { $0.usageCount > $1.usageCount }
            suggestionItems.append(contentsOf: usedSnippets.prefix(5).map { .snippet($0) })

            // Fallback: popular essentials
            if suggestionItems.count < 6 {
                let essentials = ["🔥", "👍", "🙏", "❤️", "😂", "😍", "✨", "🚀", "🎉", "☕", "🍕", "🌹"]
                for ess in essentials {
                    if let item = EmojiCatalog.all.first(where: { $0.emoji == ess }),
                       !suggestionItems.contains(where: { $0.id == "e_\(item.id)" }) {
                        suggestionItems.append(.emoji(item))
                    }
                }
            }

            res.append(SearchSection(id: "suggestions", title: "Suggestions", items: suggestionItems))

            // All Emojis (Full 1,723 dataset!)
            let remainingEmojis = EmojiCatalog.all.filter { !hid.contains($0.emoji) }
            res.append(SearchSection(id: "all_emojis", title: "All Emojis", items: remainingEmojis.map { .emoji($0) }))

            // Snippets
            if !allSnippets.isEmpty {
                res.append(SearchSection(id: "snippets", title: "Snippets", items: allSnippets.map { .snippet($0) }))
            }

            return res
        }

        // Search Mode: ALL emojis and snippets searched
        let emojiMatches = EmojiCatalog.filter(
            query: trimmed,
            usageCounts: usage,
            favorites: favs,
            hidden: hid
        )
        let snippetMatches = matchingSnippets

        var res: [SearchSection] = []

        let cleanQuery = trimmed.lowercased().replacingOccurrences(of: ":", with: "")
        let isExplicitEmoji = trimmed.hasPrefix(":") ||
            EmojiCatalog.reverseEngineer(input: trimmed) != nil ||
            emojiMatches.first?.aliases.contains(where: {
                let a = $0.trimmingCharacters(in: CharacterSet(charactersIn: ":")).lowercased()
                return a == cleanQuery || a.replacingOccurrences(of: "_", with: "") == cleanQuery
            }) == true

        if isExplicitEmoji || !emojiMatches.isEmpty {
            res.append(SearchSection(id: "emojis", title: "Emojis", items: emojiMatches.map { .emoji($0) }))
            if !snippetMatches.isEmpty {
                res.append(SearchSection(id: "snippets", title: "Snippets", items: snippetMatches.map { .snippet($0) }))
            }
        } else {
            if !snippetMatches.isEmpty {
                res.append(SearchSection(id: "snippets", title: "Snippets", items: snippetMatches.map { .snippet($0) }))
            }
            if !emojiMatches.isEmpty {
                res.append(SearchSection(id: "emojis", title: "Emojis", items: emojiMatches.map { .emoji($0) }))
            }
        }

        return res
    }

    private var flattenedItems: [SearchListItem] {
        sections.flatMap(\.items)
    }

    private var currentSelectedItem: SearchListItem? {
        guard controller.selectedIndex >= 0 && controller.selectedIndex < flattenedItems.count else { return nil }
        return flattenedItems[controller.selectedIndex]
    }

    private var primaryActionTitle: String {
        guard let item = currentSelectedItem else { return "Insert" }
        switch item {
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
                // Search Header
                HStack(spacing: Space.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.8))

                    CommandSearchBar(
                        text: $controller.query,
                        placeholder: "Search for emojis and snippets...",
                        onCommit: { selectCurrent() },
                        onEscape: { controller.hide() }
                    )
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
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(.horizontal, Space.lg)
                .frame(height: 56)
                .background(Color(red: 0.14, green: 0.15, blue: 0.18))
                .overlay(
                    Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1),
                    alignment: .bottom
                )

                // Optional Shortcodes Banner
                if let banner = controller.shortcodesBanner {
                    HStack(spacing: Space.sm) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
                        VStack(alignment: .leading, spacing: 1) {
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
                    .overlay(Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1), alignment: .bottom)
                }

                // Results List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: Space.xs) {
                            ForEach(sections) { section in
                                if !section.items.isEmpty {
                                    Text(section.title)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Color.white.opacity(0.42))
                                        .padding(.horizontal, Space.lg)
                                        .padding(.top, Space.sm)
                                        .padding(.bottom, 2)

                                    ForEach(section.items) { item in
                                        let index = flattenedItems.firstIndex(of: item) ?? 0
                                        FloatingRowView(
                                            item: item,
                                            isSelected: index == controller.selectedIndex,
                                            isFavorite: favs.contains(item.emojiChar ?? ""),
                                            usageCount: usage[item.emojiChar ?? ""] ?? 0
                                        )
                                        .id(index)
                                        .onTapGesture {
                                            controller.selectedIndex = index
                                            selectCurrent()
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
                    if flattenedItems.isEmpty {
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
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                    .shadow(radius: 6) // grid: ok shadow
                    .padding(.bottom, Space.xs)
                }

                // High Contrast Command Bar Footer
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

                    Text("\(flattenedItems.count) \(flattenedItems.count == 1 ? "item" : "items")")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.45))

                    Spacer()

                    // Unified Action Pill Container (Raycast / Spotlight Reference)
                    HStack(spacing: 0) {
                        Button {
                            selectCurrent()
                        } label: {
                            HStack(spacing: Space.xs) {
                                Text(primaryActionTitle)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("↵")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, Space.sm)
                            .padding(.vertical, Space.xs)
                        }
                        .buttonStyle(.plain)

                        Rectangle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 1, height: 16)

                        Button {
                            controller.toggleActionsMenu()
                        } label: {
                            HStack(spacing: Space.xs) {
                                Text("Actions")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.85))
                                HStack(spacing: 1) {
                                    Text("⌘")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("K")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
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
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    )
                }
                .padding(.horizontal, Space.lg)
                .frame(height: 36)
                .background(Color(red: 0.08, green: 0.09, blue: 0.11))
                .overlay(
                    Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1),
                    alignment: .top
                )
            }
        }
        .frame(width: 640, height: 460)
        .background(Color(red: 0.11, green: 0.12, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        )
        // ⌘K Actions Menu Overlay (Image 2)
        .overlay(alignment: .bottomTrailing) {
            if controller.isActionsMenuOpen, let item = currentSelectedItem {
                ActionsMenuOverlay(
                    controller: controller,
                    selectedItem: item,
                    actions: currentActions(for: item)
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
            refreshMetadata()
            setupCallbacks()
        }
        .onChange(of: controller.query) { _, _ in
            controller.selectedIndex = 0
        }
        .onChange(of: flattenedItems.count) { _, newCount in
            if controller.selectedIndex >= newCount {
                controller.selectedIndex = max(0, newCount - 1)
            }
        }
    }

    private func refreshMetadata() {
        usage = EmojiUsageTracker.shared.getCounts()
        favs = EmojiUsageTracker.shared.getFavorites()
        hid = EmojiUsageTracker.shared.getHidden()
    }

    private func setupCallbacks() {
        controller.onCommit = { selectCurrent() }
        controller.onMoveDown = {
            if controller.selectedIndex < flattenedItems.count - 1 {
                controller.selectedIndex += 1
            }
        }
        controller.onMoveUp = {
            if controller.selectedIndex > 0 {
                controller.selectedIndex -= 1
            }
        }
        controller.onCopyContent = { copyCurrentContent() }
        controller.onCopyShortcode = { copyCurrentShortcode() }
        controller.onToggleFavorite = { toggleCurrentFavorite() }
        controller.onResetRanking = { resetCurrentRanking() }
        controller.onHideItem = { hideCurrentItem() }
        controller.onShowShortcodes = { showCurrentShortcodes() }

        controller.onActionMoveDown = {
            guard let item = currentSelectedItem else { return }
            let actions = currentActions(for: item)
            if controller.actionIndex < actions.count - 1 {
                controller.actionIndex += 1
            }
        }
        controller.onActionMoveUp = {
            if controller.actionIndex > 0 {
                controller.actionIndex -= 1
            }
        }
        controller.onActionCommit = {
            guard let item = currentSelectedItem else { return }
            let actions = currentActions(for: item)
            guard controller.actionIndex >= 0 && controller.actionIndex < actions.count else { return }
            actions[controller.actionIndex].run()
        }
    }

    private func selectCurrent() {
        guard let item = currentSelectedItem else { return }

        switch item {
        case .snippet(let snippet):
            if SnippetPlaceholders.hasPlaceholders(snippet.content) {
                controller.placeholderPrompt = PlaceholderPromptState(
                    snippetName: snippet.name,
                    template: snippet.content,
                    backspaces: 0
                )
            } else {
                insertText(snippet.content)
                model.recordSnippetUsage(id: snippet.id)
                SoundFeedback.playExpansionClick()
            }
        case .emoji(let emojiItem):
            insertText(emojiItem.emoji)
            EmojiUsageTracker.shared.recordUsage(emoji: emojiItem.emoji)
            refreshMetadata()
            SoundFeedback.playExpansionClick()
        }
    }

    private func insertText(_ text: String) {
        controller.hide()
        let target = controller.targetApp
        TextInserter.insert(text: text, into: target)
        controller.query = ""
        controller.selectedIndex = 0
    }

    private func copyCurrentContent() {
        guard let item = currentSelectedItem else { return }
        switch item {
        case .emoji(let e):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(e.emoji, forType: .string)
            EmojiUsageTracker.shared.recordUsage(emoji: e.emoji)
            refreshMetadata()
            controller.showToast("Copied \(e.emoji) to clipboard")
        case .snippet(let s):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(s.content, forType: .string)
            model.recordSnippetUsage(id: s.id)
            controller.showToast("Copied \"\(s.name)\" to clipboard")
        }
    }

    private func copyCurrentShortcode() {
        guard let item = currentSelectedItem else { return }
        let code = item.primaryCode
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        controller.showToast("Copied shortcode \(code)")
    }

    private func toggleCurrentFavorite() {
        guard let item = currentSelectedItem else { return }
        switch item {
        case .emoji(let e):
            let isFav = EmojiUsageTracker.shared.toggleFavorite(e.emoji)
            refreshMetadata()
            controller.showToast(isFav ? "Added \(e.emoji) to Favorites" : "Removed \(e.emoji) from Favorites")
        case .snippet(let s):
            model.toggleFavourite(s)
            controller.showToast(s.isFavourite ? "Added \"\(s.name)\" to Favorites" : "Removed from Favorites")
        }
    }

    private func resetCurrentRanking() {
        guard let item = currentSelectedItem else { return }
        switch item {
        case .emoji(let e):
            EmojiUsageTracker.shared.resetRanking(for: e.emoji)
            refreshMetadata()
            controller.showToast("Reset ranking for \(e.name)")
        case .snippet(let s):
            s.usageCount = 0
            s.lastUsedAt = nil
            controller.showToast("Reset ranking for \(s.name)")
        }
    }

    private func hideCurrentItem() {
        guard let item = currentSelectedItem else { return }
        switch item {
        case .emoji(let e):
            EmojiUsageTracker.shared.toggleHidden(e.emoji)
            refreshMetadata()
            controller.showToast("Hidden \(e.name) from suggestions")
        case .snippet(let s):
            model.deleteSnippet(s)
            controller.showToast("Deleted snippet \"\(s.name)\"")
        }
    }

    private func showCurrentShortcodes() {
        guard let item = currentSelectedItem else { return }
        controller.shortcodesBanner = (name: item.title, codes: item.allShortcodes)
    }

    private func currentActions(for item: SearchListItem) -> [ActionItem] {
        var actions: [ActionItem] = []

        switch item {
        case .emoji(let e):
            actions.append(ActionItem(
                id: "insert",
                title: "Insert Emoji",
                icon: "arrow.turn.down.left",
                shortcut: "↵"
            ) {
                selectCurrent()
            })

            actions.append(ActionItem(
                id: "copy",
                title: "Copy Emoji to Clipboard",
                icon: "doc.on.doc",
                shortcut: "⌘C"
            ) {
                copyCurrentContent()
            })

            actions.append(ActionItem(
                id: "copy_shortcode",
                title: "Copy Shortcode (\(e.primaryAlias))",
                icon: "number",
                shortcut: "⌥⌘C"
            ) {
                copyCurrentShortcode()
            })

            actions.append(ActionItem(
                id: "show_shortcodes",
                title: "Show All Shortcodes",
                icon: "text.bubble",
                shortcut: "⌘S"
            ) {
                showCurrentShortcodes()
                controller.isActionsMenuOpen = false
            })

            actions.append(ActionItem(
                id: "reset_ranking",
                title: "Reset Ranking",
                icon: "arrow.counterclockwise",
                shortcut: "⌘R"
            ) {
                resetCurrentRanking()
                controller.isActionsMenuOpen = false
            })

            let isFav = favs.contains(e.emoji)
            actions.append(ActionItem(
                id: "toggle_fav",
                title: isFav ? "Remove from Favorites" : "Add to Favorites",
                icon: isFav ? "star.fill" : "star",
                shortcut: "⇧⌘F"
            ) {
                toggleCurrentFavorite()
                controller.isActionsMenuOpen = false
            })

            actions.append(ActionItem(
                id: "hide_search",
                title: "Hide from Search",
                icon: "eye.slash",
                shortcut: "⇧⌘H"
            ) {
                hideCurrentItem()
                controller.isActionsMenuOpen = false
            })

            actions.append(ActionItem(
                id: "copy_hex",
                title: "Copy Unicode Hex (\(e.unicodeHex))",
                icon: "curlybraces",
                shortcut: "⌥⌘U"
            ) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(e.unicodeHex, forType: .string)
                controller.showToast("Copied \(e.unicodeHex)")
                controller.isActionsMenuOpen = false
            })

        case .snippet(let s):
            actions.append(ActionItem(
                id: "insert",
                title: "Insert Snippet",
                icon: "arrow.turn.down.left",
                shortcut: "↵"
            ) {
                selectCurrent()
            })

            actions.append(ActionItem(
                id: "copy",
                title: "Copy Snippet to Clipboard",
                icon: "doc.on.doc",
                shortcut: "⌘C"
            ) {
                copyCurrentContent()
            })

            if !s.alias.isEmpty {
                actions.append(ActionItem(
                    id: "copy_alias",
                    title: "Copy Alias (\(s.alias))",
                    icon: "number",
                    shortcut: "⌥⌘C"
                ) {
                    copyCurrentShortcode()
                })
            }

            actions.append(ActionItem(
                id: "reset_ranking",
                title: "Reset Ranking",
                icon: "arrow.counterclockwise",
                shortcut: "⌘R"
            ) {
                resetCurrentRanking()
                controller.isActionsMenuOpen = false
            })

            actions.append(ActionItem(
                id: "toggle_fav",
                title: s.isFavourite ? "Remove from Favorites" : "Add to Favorites",
                icon: s.isFavourite ? "star.fill" : "star",
                shortcut: "⇧⌘F"
            ) {
                toggleCurrentFavorite()
                controller.isActionsMenuOpen = false
            })

            actions.append(ActionItem(
                id: "delete",
                title: "Delete Snippet",
                icon: "trash",
                shortcut: "⌘⌫",
                isDestructive: true
            ) {
                hideCurrentItem()
                controller.isActionsMenuOpen = false
            })
        }

        if !controller.actionQuery.isEmpty {
            let q = controller.actionQuery.lowercased()
            return actions.filter { $0.title.lowercased().contains(q) }
        }

        return actions
    }
}

// MARK: - Row View (Matches Reference Screenshot Image 1)

private struct FloatingRowView: View {
    let item: SearchListItem
    let isSelected: Bool
    let isFavorite: Bool
    let usageCount: Int

    var body: some View {
        HStack(spacing: Space.md) {
            // Left Icon + Indicator Dot
            ZStack(alignment: .bottomTrailing) {
                switch item {
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
                .padding(.vertical, 2)
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
                .strokeBorder(isSelected ? Color.white.opacity(0.18) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - ⌘K Actions Menu Overlay (Matches Reference Screenshot Image 2)

private struct ActionsMenuOverlay: View {
    @ObservedObject var controller: FloatingPanelController
    let selectedItem: SearchListItem
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
                        .font(.system(size: 10, weight: .bold))
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
            VStack(spacing: 2) {
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
                                .padding(.vertical, 2)
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
                TextField("Search for actions...", text: $controller.actionQuery)
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
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
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
            .overlay(Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1), alignment: .bottom)

            // Variables List & Live Inputs
            ScrollView {
                VStack(alignment: .leading, spacing: Space.md) {
                    Text("VARIABLES")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.white.opacity(0.5))

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
                                            lineWidth: isActive ? 2 : 1
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
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
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
            .overlay(Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1), alignment: .top)
        }
    }
}
