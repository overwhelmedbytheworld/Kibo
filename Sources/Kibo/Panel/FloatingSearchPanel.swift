import AppKit
import Carbon.HIToolbox
import SwiftData
import SwiftUI
import KiboKit

// MARK: - Custom Floating Panel with Key Window Support

final class FloatingPanel: NSPanel {
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
            let p = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 560, height: 420))

            let rootView = FloatingSearchPanelContent(controller: self)
                .environment(model)
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

// MARK: - Floating Search Panel SwiftUI Content

struct FloatingSearchPanelContent: View {
    @ObservedObject var controller: FloatingPanelController
    @Environment(AppModel.self) private var model

    @State private var query = ""
    @State private var selectedIndex = 0

    @Query(sort: \Snippet.usageCount, order: .reverse) private var allSnippets: [Snippet]

    private var matchingSnippets: [Snippet] {
        SnippetSearch.filter(items: allSnippets, query: query) {
            ($0.name, $0.alias, $0.category, $0.content)
        }
    }

    private var matchingEmojis: [EmojiItem] {
        guard !query.isEmpty else { return [] }
        return Array(EmojiCatalog.filter(query: query).prefix(8))
    }

    private var totalItemCount: Int {
        matchingSnippets.count + matchingEmojis.count
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
                        .foregroundStyle(.secondary)

                    TextField("Search snippets or type :emoji:...", text: $query)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .onSubmit {
                            selectCurrent()
                        }

                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("⌘⇧K")
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, Space.xs)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                }
                .padding(.horizontal, Space.lg)
                .frame(height: 56)
                .background(.ultraThinMaterial)
                .overlay(Divider(), alignment: .bottom)

                // Results List (Snippets + Matching Emojis)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            // Snippets Section
                            ForEach(Array(matchingSnippets.enumerated()), id: \.element.id) { index, snippet in
                                FloatingSnippetRow(
                                    snippet: snippet,
                                    isSelected: index == selectedIndex
                                )
                                .id(index)
                                .onTapGesture {
                                    selectedIndex = index
                                    selectCurrent()
                                }
                            }

                            // Matching Emojis Section
                            if !matchingEmojis.isEmpty {
                                HStack {
                                    Text("EMOJIS")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, Space.md)
                                .padding(.top, Space.sm)

                                ForEach(Array(matchingEmojis.enumerated()), id: \.element.emoji) { index, item in
                                    let globalIndex = matchingSnippets.count + index
                                    FloatingEmojiRow(
                                        item: item,
                                        isSelected: globalIndex == selectedIndex
                                    )
                                    .id(globalIndex)
                                    .onTapGesture {
                                        selectedIndex = globalIndex
                                        selectCurrent()
                                    }
                                }
                            }
                        }
                        .padding(Space.xs)
                    }
                    .frame(maxHeight: 280)
                    .background(.ultraThinMaterial)
                    .onChange(of: selectedIndex) { _, newIndex in
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
                .overlay {
                    if matchingSnippets.isEmpty && matchingEmojis.isEmpty {
                        VStack(spacing: Space.xs) {
                            Text("No results")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Search snippets by name, or type :emoji: like :fire: or :thumbsup:")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }

                // Footer
                HStack {
                    Text("↑↓ Navigate")
                    Text("•")
                    Text("↵ Insert")
                    Text("•")
                    Text("esc Cancel")
                    Spacer()
                    if let target = controller.targetApp {
                        Text("Target: \(target.localizedName ?? "Active App")")
                            .foregroundStyle(Palette.accentText)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Space.lg)
                .frame(height: 28)
                .background(.background.secondary)
                .overlay(Divider(), alignment: .top)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator, lineWidth: 1))
        .onKeyPress(.downArrow) {
            if controller.placeholderPrompt == nil && selectedIndex < totalItemCount - 1 {
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            if controller.placeholderPrompt == nil && selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.escape) {
            controller.hide()
            return .handled
        }
        .onChange(of: query) { _, _ in
            selectedIndex = 0
        }
    }

    private func selectCurrent() {
        guard selectedIndex >= 0 && selectedIndex < totalItemCount else { return }

        if selectedIndex < matchingSnippets.count {
            let snippet = matchingSnippets[selectedIndex]
            if SnippetPlaceholders.hasPlaceholders(snippet.content) {
                controller.placeholderPrompt = FloatingPanelController.PlaceholderPromptState(
                    snippetName: snippet.name,
                    template: snippet.content,
                    backspaces: 0
                )
            } else {
                insertText(snippet.content)
            }
        } else {
            let emojiIndex = selectedIndex - matchingSnippets.count
            if emojiIndex < matchingEmojis.count {
                let emojiItem = matchingEmojis[emojiIndex]
                insertText(emojiItem.emoji)
            }
        }
    }

    private func insertText(_ text: String) {
        controller.hide()
        let target = controller.targetApp
        TextInserter.insert(text: text, into: target)
        query = ""
        selectedIndex = 0
    }
}

// MARK: - Row in Floating Panel

private struct FloatingSnippetRow: View {
    let snippet: Snippet
    let isSelected: Bool

    var body: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "text.quote")
                .foregroundStyle(isSelected ? Palette.onAccent : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(snippet.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(isSelected ? Palette.onAccent : .primary)

                    if !snippet.category.isEmpty {
                        Text(snippet.category)
                            .font(.caption2)
                            .padding(.horizontal, Space.xs)
                            .padding(.vertical, 1)
                            .background(
                                isSelected ? Palette.onAccent.opacity(0.2) : Color.secondary.opacity(0.12),
                                in: Capsule()
                            )
                            .foregroundStyle(isSelected ? Palette.onAccent : .secondary)
                    }

                    Spacer()

                    if !snippet.alias.isEmpty {
                        Text(snippet.alias)
                            .font(.caption.monospaced())
                            .foregroundStyle(isSelected ? Palette.onAccent : Palette.accentText)
                    }
                }

                Text(snippet.content.replacingOccurrences(of: "\n", with: " "))
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? Palette.onAccent.opacity(0.8) : .secondary)
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .background(
            isSelected ? Palette.accent : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
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
                .font(.title2)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isSelected ? Palette.onAccent : .primary)

                Text(item.aliases.joined(separator: "  "))
                    .font(.caption.monospaced())
                    .foregroundStyle(isSelected ? Palette.onAccent.opacity(0.8) : Palette.accentText)
            }

            Spacer()
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.xs)
        .background(
            isSelected ? Palette.accent : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .contentShape(Rectangle())
    }
}
