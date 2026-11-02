import AppKit
import Carbon.HIToolbox
import SwiftData
import SwiftUI
import KiboKit

// MARK: - Floating Search Panel Controller

@MainActor
final class FloatingPanelController: ObservableObject {
    static let shared = FloatingPanelController()

    private var panel: NSPanel?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private(set) var targetApp: NSRunningApplication?

    @Published var isVisible = false

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

    func show(model: AppModel) {
        // Record the app that was frontmost before Kibo's panel appears
        let frontApp = NSWorkspace.shared.frontmostApplication
        if frontApp?.bundleIdentifier != Bundle.main.bundleIdentifier {
            targetApp = frontApp
        }

        if panel == nil {
            let p = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 380),
                styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            p.isFloatingPanel = true
            p.level = .statusBar
            p.hidesOnDeactivate = false
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true

            let rootView = FloatingSearchPanelContent(model: model, controller: self)
                .themed()

            let hostingView = NSHostingView(rootView: rootView)
            p.contentView = hostingView
            panel = p
        }

        guard let p = panel else { return }

        // Center on the active screen's upper third (like Spotlight)
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - (p.frame.width / 2)
            let y = screenFrame.maxY - p.frame.height - 140
            p.setFrameOrigin(NSPoint(x: x, y: y))
        }

        p.orderFrontRegardless()
        p.makeKey()
        isVisible = true
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    func toggle(model: AppModel? = nil) {
        if isVisible {
            hide()
        } else if let m = model {
            show(model: m)
        }
    }
}

// MARK: - Floating Search Panel SwiftUI Content

struct FloatingSearchPanelContent: View {
    let model: AppModel
    let controller: FloatingPanelController

    @State private var query = ""
    @State private var selectedIndex = 0
    @State private var activePlaceholderSnippet: Snippet?

    @Query(sort: \Snippet.usageCount, order: .reverse) private var allSnippets: [Snippet]

    private var matchingSnippets: [Snippet] {
        SnippetSearch.filter(items: allSnippets, query: query) {
            ($0.name, $0.alias, $0.category, $0.content)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let snippet = activePlaceholderSnippet {
                // Dynamic Variable Filling Mode
                PlaceholderPromptView(
                    snippetName: snippet.name,
                    template: snippet.content,
                    onInsert: { finalContent in
                        insertSnippet(content: finalContent)
                    },
                    onCancel: {
                        activePlaceholderSnippet = nil
                    }
                )
            } else {
                // Search Bar
                HStack(spacing: Space.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    TextField("Search snippets by name, :alias:, or keywords...", text: $query)
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

                // Results List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
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
                    if matchingSnippets.isEmpty {
                        VStack(spacing: Space.xs) {
                            Text("No matching snippets")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Press ⌘N in Kibo to create one.")
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
                        Text("Inserting into: \(target.localizedName ?? "Active App")")
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
            if selectedIndex < matchingSnippets.count - 1 {
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.escape) {
            if activePlaceholderSnippet != nil {
                activePlaceholderSnippet = nil
            } else {
                controller.hide()
            }
            return .handled
        }
        .onChange(of: query) { _, _ in
            selectedIndex = 0
        }
    }

    private func selectCurrent() {
        guard selectedIndex >= 0 && selectedIndex < matchingSnippets.count else { return }
        let snippet = matchingSnippets[selectedIndex]

        if SnippetPlaceholders.hasPlaceholders(snippet.content) {
            activePlaceholderSnippet = snippet
        } else {
            insertSnippet(content: snippet.content)
        }
    }

    private func insertSnippet(content: String) {
        controller.hide()
        let target = controller.targetApp
        TextInserter.insert(text: content, into: target)
        query = ""
        selectedIndex = 0
        activePlaceholderSnippet = nil
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
