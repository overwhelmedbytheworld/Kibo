import SwiftData
import SwiftUI
import KiboKit

// MARK: - Clipboard List & Detail Views

struct ClipboardListView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \ClipboardEntry.copiedAt, order: .reverse) private var allEntries: [ClipboardEntry]

    @State private var showingClearConfirmation = false

    private var filteredEntries: [ClipboardEntry] {
        var result = allEntries
        if model.clipboardPinnedOnly {
            result = result.filter(\.isPinned)
        }
        if !model.clipboardSearchText.isEmpty {
            let q = model.clipboardSearchText.lowercased()
            result = result.filter { $0.content.lowercased().contains(q) }
        }
        return result
    }

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            // Filter Pills Header
            HStack(spacing: Space.xs) {
                filterChip(title: "All", isSelected: !model.clipboardPinnedOnly) {
                    model.clipboardPinnedOnly = false
                }

                filterChip(title: "Pinned", isSelected: model.clipboardPinnedOnly) {
                    model.clipboardPinnedOnly = true
                }

                Spacer(minLength: 0)

                // Clear unpinned history button
                Button {
                    showingClearConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .padding(Space.xs)
                }
                .buttonStyle(.plain)
                .help("Clear all unpinned clippings")
                .disabled(allEntries.filter { !$0.isPinned }.isEmpty)
                .confirmationDialog(
                    "Clear Clipboard History",
                    isPresented: $showingClearConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Clear Unpinned Items", role: .destructive) {
                        model.clearUnpinnedClipboard()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This removes all unpinned clipboard items. Pinned items are kept safe.")
                }
            }
            .padding(.horizontal, Space.sm)
            .padding(.vertical, Space.xs)
            .background(.background.secondary)
            .overlay(Divider(), alignment: .bottom)

            // Clippings List
            List(filteredEntries, selection: $model.clipboardSelection) { entry in
                ClipboardRow(entry: entry)
                    .tag(entry.id)
                    .contextMenu {
                        Button {
                            model.insertClipboardEntryIntoActiveApp(entry)
                        } label: {
                            Label("Insert into Active App", systemImage: "arrow.right.doc.on.clipboard")
                        }

                        Button {
                            model.copyClipboardEntryToPasteboard(entry)
                        } label: {
                            Label("Copy Again", systemImage: "doc.on.doc")
                        }

                        Button {
                            model.togglePinClipboardEntry(entry)
                        } label: {
                            Label(entry.isPinned ? "Unpin" : "Pin", systemImage: entry.isPinned ? "pin.slash" : "pin")
                        }

                        Divider()

                        Button {
                            model.convertClipboardEntryToSnippet(entry)
                        } label: {
                            Label("Save as Reusable Snippet…", systemImage: "text.quote")
                        }

                        Divider()

                        Button(role: .destructive) {
                            model.deleteClipboardEntry(entry)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            .onDeleteCommand {
                if let sel = model.clipboardSelection,
                   let entry = allEntries.first(where: { $0.id == sel }) {
                    model.deleteClipboardEntry(entry)
                }
            }
            .overlay {
                if filteredEntries.isEmpty {
                    if !model.clipboardSearchText.isEmpty {
                        ContentUnavailableView.search(text: model.clipboardSearchText)
                    } else if model.clipboardPinnedOnly {
                        ContentUnavailableView(
                            "No Pinned Clippings",
                            systemImage: "pin",
                            description: Text("Pin clippings to keep them at the top of your history.")
                        )
                    } else {
                        ContentUnavailableView(
                            "Clipboard Empty",
                            systemImage: "doc.on.clipboard",
                            description: Text("Copy text anywhere in macOS to automatically capture it here.")
                        )
                    }
                }
            }
        }
        .searchable(text: $model.clipboardSearchText, placement: .toolbar, prompt: "Search clipboard history...")
        .navigationTitle("Clipboard")
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, Space.sm)
                .padding(.vertical, Space.xs)
                .background(
                    isSelected ? Palette.accent : Color.secondary.opacity(0.12),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? Palette.onAccent : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Clipboard Row

struct ClipboardRow: View {
    let entry: ClipboardEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.content.prefix(120).replacingOccurrences(of: "\n", with: " "))
                    .font(.body)
                    .lineLimit(2)

                Spacer()

                if entry.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            HStack(spacing: Space.sm) {
                Text(entry.copiedAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text("\(entry.charCount) chars")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if entry.wordCount > 1 {
                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("\(entry.wordCount) words")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Clipboard Detail View

struct ClipboardDetailView: View {
    @Environment(AppModel.self) private var model
    @Query private var allEntries: [ClipboardEntry]

    private var selectedEntry: ClipboardEntry? {
        guard let id = model.clipboardSelection else { return nil }
        return allEntries.first(where: { $0.id == id })
    }

    var body: some View {
        if let entry = selectedEntry {
            ClipboardInspectorContent(entry: entry)
        } else {
            ContentUnavailableView(
                "Select a Clipping",
                systemImage: "doc.on.clipboard",
                description: Text("Choose an item from the clipboard history to inspect, insert, or save.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ClipboardInspectorContent: View {
    @Environment(AppModel.self) private var model
    let entry: ClipboardEntry

    @State private var copiedBriefly = false

    var body: some View {
        VStack(spacing: 0) {
            // Action Toolbar
            HStack(spacing: Space.sm) {
                Button {
                    model.insertClipboardEntryIntoActiveApp(entry)
                } label: {
                    Label("Insert into Active App", systemImage: "arrow.right.doc.on.clipboard")
                }
                .buttonStyle(.borderedProminent)
                .help("Insert text into previous active app")

                Button {
                    model.copyClipboardEntryToPasteboard(entry)
                    copiedBriefly = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.5))
                        copiedBriefly = false
                    }
                } label: {
                    Label(copiedBriefly ? "Copied!" : "Copy", systemImage: copiedBriefly ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .tint(copiedBriefly ? .green : nil)
                .help("Copy content back to pasteboard")

                Spacer()

                Button {
                    model.togglePinClipboardEntry(entry)
                } label: {
                    Image(systemName: entry.isPinned ? "pin.fill" : "pin")
                }
                .buttonStyle(.bordered)
                .foregroundStyle(entry.isPinned ? .orange : .primary)
                .help(entry.isPinned ? "Unpin item" : "Pin item to keep")

                Button {
                    model.convertClipboardEntryToSnippet(entry)
                } label: {
                    Label("Save as Snippet", systemImage: "text.quote")
                }
                .buttonStyle(.bordered)
                .help("Convert this clipping into a reusable snippet")

                Button(role: .destructive) {
                    model.deleteClipboardEntry(entry)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .help("Delete clipping")
            }
            .padding(.horizontal, Space.margin)
            .padding(.vertical, Space.sm)
            .background(.background.secondary)
            .overlay(Divider(), alignment: .bottom)

            // Content Viewer
            ScrollView {
                Text(entry.content)
                    .font(.system(size: 13, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(Space.md)
            }
            .background(Color(nsColor: .textBackgroundColor))

            // Footer metadata
            HStack {
                Text("Copied \(entry.copiedAt.formatted(date: .abbreviated, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(entry.wordCount) words • \(entry.charCount) characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Space.margin)
            .padding(.vertical, Space.sm)
            .background(.background.secondary)
            .overlay(Divider(), alignment: .top)
        }
    }
}
