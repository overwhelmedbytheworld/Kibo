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
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .popUpMenu // Above all standard windows and full screen apps
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

// MARK: - Floating Search Panel Controller

@MainActor
final class FloatingPanelController: ObservableObject {
    static let shared = FloatingPanelController()

    struct PlaceholderPromptState: Identifiable {
        let id = UUID()
        let snippetName: String
        let template: String
        let backspaces: Int
    }

    private var panel: FloatingPanel?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private(set) var targetApp: NSRunningApplication?
    private weak var appModel: AppModel?

    @Published var isVisible = false
    @Published var placeholderPrompt: PlaceholderPromptState?
    @Published var selectedIndex: Int = 0

    var onCommit: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onMoveUp: (() -> Void)?

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

    /// Pre-configures the model reference on startup so placeholder prompts can summon immediately.
    func configure(model: AppModel) {
        self.appModel = model
    }

    func show(model: AppModel) {
        self.appModel = model
        self.selectedIndex = 0

        // Record the app that was frontmost before Kibo's panel appears
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
            let p = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 580, height: 440))
            p.onKeyDown = { [weak self] event in
                guard let self else { return false }
                if self.placeholderPrompt != nil {
                    if event.keyCode == 53 { // Escape
                        self.hide()
                        return true
                    }
                    return false
                }

                switch event.keyCode {
                case 125: // Down Arrow
                    if let onMoveDown = self.onMoveDown {
                        onMoveDown()
                        return true
                    }
                    return false
                case 126: // Up Arrow
                    if let onMoveUp = self.onMoveUp {
                        onMoveUp()
                        return true
                    }
                    return false
                case 36: // Return
                    if let onCommit = self.onCommit {
                        onCommit()
                        return true
                    }
                    return false
                case 53: // Escape
                    self.hide()
                    return true
                default:
                    return false
                }
            }

            let rootView = FloatingSearchPanelContent(controller: self)
                .environment(model)
                .modelContainer(model.container)
                .themed()

            let hostingView = NSHostingView(rootView: rootView)
            p.contentView = hostingView
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
        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
        p.makeKey()
        isVisible = true
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

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
        placeholderPrompt = nil
    }

    func toggle(model: AppModel? = nil) {
        if isVisible {
            hide()
        } else if let m = model ?? appModel {
            show(model: m)
        }
    }
}

// MARK: - Search Result Model

private enum PanelItem: Identifiable {
    case snippet(Snippet)
    case emoji(EmojiItem)

    var id: String {
        switch self {
        case .snippet(let s): return "s_\(s.id)"
        case .emoji(let e): return "e_\(e.id)"
        }
    }
}

// MARK: - Floating Search Panel SwiftUI Content

struct FloatingSearchPanelContent: View {
    @ObservedObject var controller: FloatingPanelController
    @Environment(AppModel.self) private var model

    @State private var query = ""
    @FocusState private var isSearchFocused: Bool

    @Query(sort: \Snippet.usageCount, order: .reverse) private var allSnippets: [Snippet]

    private var matchingSnippets: [Snippet] {
        SnippetSearch.filter(items: allSnippets, query: query) {
            ($0.name, $0.alias, $0.category, $0.content)
        }
    }

    /// Unified search results with intelligent ranking:
    /// Emojis rank at top when query matches emoji code, name, or raw pasted emoji.
    /// When query is empty, frequently used emojis and snippets appear at top.
    private var searchResults: [PanelItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let usage = EmojiUsageTracker.shared.getCounts()

        if trimmed.isEmpty {
            // Merge frequently used snippets and emojis, ranked by frequency
            let sortedSnippets = allSnippets.sorted {
                if $0.usageCount != $1.usageCount { return $0.usageCount > $1.usageCount }
                return ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast)
            }

            let topEmojis = EmojiUsageTracker.shared.topEmojis(limit: 50)

            // Any emojis with usage > 0 and snippets with usage > 0
            let usedEmojis = topEmojis.filter { (usage[$0.emoji] ?? 0) > 0 }
            let usedSnippets = sortedSnippets.filter { $0.usageCount > 0 }

            var highUsage: [(item: PanelItem, count: Int)] = []
            for e in usedEmojis {
                highUsage.append((.emoji(e), usage[e.emoji] ?? 0))
            }
            for s in usedSnippets {
                highUsage.append((.snippet(s), s.usageCount))
            }
            highUsage.sort { $0.count > $1.count }

            var items: [PanelItem] = []
            items.append(contentsOf: highUsage.map(\.item))

            // Append remaining snippets
            let unusedSnippets = sortedSnippets.filter { $0.usageCount == 0 }
            items.append(contentsOf: unusedSnippets.map { PanelItem.snippet($0) })

            // Append top popular emojis
            let unusedEmojis = topEmojis.filter { (usage[$0.emoji] ?? 0) == 0 }
            items.append(contentsOf: unusedEmojis.map { PanelItem.emoji($0) })

            return items
        }

        let emojiMatches = EmojiCatalog.filter(query: trimmed, usageCounts: usage)
        let snippetMatches = matchingSnippets

        let cleanQuery = trimmed.lowercased().replacingOccurrences(of: ":", with: "")

        // Check if query is explicitly an emoji trigger (starts with :, raw emoji, or exact alias)
        let isExplicitEmoji = trimmed.hasPrefix(":") ||
            EmojiCatalog.reverseEngineer(input: trimmed) != nil ||
            emojiMatches.first?.aliases.contains(where: {
                let aliasClean = $0.trimmingCharacters(in: CharacterSet(charactersIn: ":")).lowercased()
                return aliasClean == cleanQuery || aliasClean.replacingOccurrences(of: "_", with: "") == cleanQuery.replacingOccurrences(of: " ", with: "")
            }) == true

        if isExplicitEmoji {
            // Emojis first, then snippets
            let emojis = emojiMatches.prefix(40).map { PanelItem.emoji($0) }
            let snippets = snippetMatches.map { PanelItem.snippet($0) }
            return Array(emojis) + snippets
        } else if let topEmoji = emojiMatches.first,
                  topEmoji.aliases.contains(where: { $0.trimmingCharacters(in: CharacterSet(charactersIn: ":")).localizedCaseInsensitiveCompare(cleanQuery) == .orderedSame }) ||
                  topEmoji.name.localizedCaseInsensitiveCompare(cleanQuery) == .orderedSame ||
                  topEmoji.keywords.contains(cleanQuery) {
            // Strong emoji match (e.g. searching "pray", "fire", "rose", "thumbs up")
            let exactEmoji = PanelItem.emoji(topEmoji)
            let otherEmojis = emojiMatches.dropFirst().prefix(35).map { PanelItem.emoji($0) }
            let snippets = snippetMatches.map { PanelItem.snippet($0) }
            return [exactEmoji] + otherEmojis + snippets
        } else if !snippetMatches.isEmpty {
            // Snippets match best
            let snippets = snippetMatches.map { PanelItem.snippet($0) }
            let emojis = emojiMatches.prefix(35).map { PanelItem.emoji($0) }
            return snippets + Array(emojis)
        } else {
            // Emojis match
            let emojis = emojiMatches.prefix(50).map { PanelItem.emoji($0) }
            return Array(emojis)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let prompt = controller.placeholderPrompt {
                // Dynamic Variable Filling Mode
                PlaceholderPromptView(
                    snippetName: prompt.snippetName,
                    template: prompt.template,
                    onInsert: { finalContent in
                        controller.hide()
                        let target = controller.targetApp
                        TextInserter.insert(text: finalContent, into: target, backspaces: prompt.backspaces)
                    },
                    onCancel: {
                        controller.hide()
                    }
                )
            } else {
                // Search Bar
                HStack(spacing: Space.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(Color.white.opacity(0.8))

                    TextField("Search snippets, emojis (:rose:), or paste 🌹...", text: $query)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .focused($isSearchFocused)
                        .onKeyPress(.downArrow) {
                            if controller.selectedIndex < searchResults.count - 1 {
                                controller.selectedIndex += 1
                            }
                            return .handled
                        }
                        .onKeyPress(.upArrow) {
                            if controller.selectedIndex > 0 {
                                controller.selectedIndex -= 1
                            }
                            return .handled
                        }
                        .onSubmit {
                            selectCurrent()
                        }

                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }

                    Text("⌘⇧K")
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.white.opacity(0.7))
                        .padding(.horizontal, Space.xs)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                }
                .padding(.horizontal, Space.lg)
                .frame(height: 56)
                .background(Color(red: 0.14, green: 0.15, blue: 0.18))
                .overlay(
                    Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1),
                    alignment: .bottom
                )

                // Results List (Snippets + Matching Emojis)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, item in
                                switch item {
                                case .snippet(let snippet):
                                    FloatingSnippetRow(
                                        snippet: snippet,
                                        isSelected: index == controller.selectedIndex
                                    )
                                    .id(index)
                                    .onTapGesture {
                                        controller.selectedIndex = index
                                        selectCurrent()
                                    }
                                case .emoji(let emojiItem):
                                    FloatingEmojiRow(
                                        item: emojiItem,
                                        isSelected: index == controller.selectedIndex
                                    )
                                    .id(index)
                                    .onTapGesture {
                                        controller.selectedIndex = index
                                        selectCurrent()
                                    }
                                }
                            }
                        }
                        .padding(Space.sm)
                    }
                    .frame(maxHeight: 320)
                    .background(Color(red: 0.11, green: 0.12, blue: 0.14))
                    .onChange(of: controller.selectedIndex) { _, newIndex in
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
                .overlay {
                    if searchResults.isEmpty {
                        VStack(spacing: Space.xs) {
                            Text("No results")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Type a snippet name, code like :rose:, or paste any emoji to inspect.")
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }

                // High Contrast HUD Footer
                HStack(spacing: Space.sm) {
                    Text("↑↓ Navigate")
                    Text("•")
                    Text("↵ Insert")
                    Text("•")
                    Text("esc Cancel")
                    Spacer()
                    if let target = controller.targetApp {
                        Text("Target: \(target.localizedName ?? "Active App")")
                            .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))
                            .fontWeight(.medium)
                    }
                }
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.65))
                .padding(.horizontal, Space.lg)
                .frame(height: 32)
                .background(Color(red: 0.08, green: 0.09, blue: 0.11))
                .overlay(
                    Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1),
                    alignment: .top
                )
            }
        }
        .background(Color(red: 0.11, green: 0.12, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .onAppear {
            isSearchFocused = true
            setupControllerCallbacks()
        }
        .onChange(of: searchResults.count) { _, newCount in
            if controller.selectedIndex >= newCount {
                controller.selectedIndex = max(0, newCount - 1)
            }
        }
        .onKeyPress(.downArrow) {
            if controller.placeholderPrompt == nil && controller.selectedIndex < searchResults.count - 1 {
                controller.selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            if controller.placeholderPrompt == nil && controller.selectedIndex > 0 {
                controller.selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.escape) {
            controller.hide()
            return .handled
        }
        .onChange(of: query) { _, _ in
            controller.selectedIndex = 0
        }
    }

    private func setupControllerCallbacks() {
        controller.onCommit = {
            selectCurrent()
        }
        controller.onMoveDown = {
            if controller.selectedIndex < searchResults.count - 1 {
                controller.selectedIndex += 1
            }
        }
        controller.onMoveUp = {
            if controller.selectedIndex > 0 {
                controller.selectedIndex -= 1
            }
        }
    }

    private func selectCurrent() {
        guard controller.selectedIndex >= 0 && controller.selectedIndex < searchResults.count else { return }

        switch searchResults[controller.selectedIndex] {
        case .snippet(let snippet):
            if SnippetPlaceholders.hasPlaceholders(snippet.content) {
                controller.placeholderPrompt = FloatingPanelController.PlaceholderPromptState(
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
            SoundFeedback.playExpansionClick()
        }
    }

    private func insertText(_ text: String) {
        controller.hide()
        let target = controller.targetApp
        TextInserter.insert(text: text, into: target)
        query = ""
        controller.selectedIndex = 0
    }
}

// MARK: - Rows in Floating Panel

private struct FloatingSnippetRow: View {
    let snippet: Snippet
    let isSelected: Bool

    var body: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "text.quote")
                .font(.body)
                .foregroundStyle(isSelected ? .white : Color(red: 0.45, green: 0.75, blue: 1.0))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Space.xs) {
                    Text(snippet.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)

                    if !snippet.category.isEmpty {
                        Text(snippet.category)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, Space.xs)
                            .padding(.vertical, 1)
                            .background(
                                isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.12),
                                in: Capsule()
                            )
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    if !snippet.alias.isEmpty {
                        Text(snippet.alias)
                            .font(.caption.monospaced())
                            .foregroundStyle(isSelected ? .white : Color(red: 0.45, green: 0.75, blue: 1.0))
                            .padding(.horizontal, Space.xs)
                            .padding(.vertical, 1)
                            .background(
                                isSelected ? Color.white.opacity(0.2) : Color.black.opacity(0.3),
                                in: RoundedRectangle(cornerRadius: 4)
                            )
                    }
                }

                Text(snippet.content.replacingOccurrences(of: "\n", with: " "))
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.65))
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .background(
            isSelected ? Palette.accent : Color.white.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.white.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

private struct FloatingEmojiRow: View {
    let item: EmojiItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: Space.md) {
            Text(item.emoji)
                .font(.system(size: 28))
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Space.xs) {
                    Text(item.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(item.category)
                        .font(.caption2)
                        .padding(.horizontal, Space.xs)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.12), in: Capsule())
                        .foregroundStyle(Color.white.opacity(0.8))

                    Spacer()

                    Text(item.primaryAlias)
                        .font(.caption.monospaced())
                        .foregroundStyle(isSelected ? .white : Color(red: 0.45, green: 0.75, blue: 1.0))
                        .padding(.horizontal, Space.xs)
                        .padding(.vertical, 1)
                        .background(
                            isSelected ? Color.white.opacity(0.2) : Color.black.opacity(0.3),
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                }

                Text(item.aliases.joined(separator: "  "))
                    .font(.caption.monospaced())
                    .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.xs)
        .background(
            isSelected ? Palette.accent : Color.white.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.white.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}
