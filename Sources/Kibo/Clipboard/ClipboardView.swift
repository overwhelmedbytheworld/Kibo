import AppKit
import SwiftData
import SwiftUI
import KiboKit

// MARK: - Clipboard Grid & Detail Views

enum ClipboardFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case pinned = "Pinned"
    case text = "Text"
    case images = "Images"

    var id: String { rawValue }
}

struct ClipboardListView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \ClipboardEntry.copiedAt, order: .reverse) private var allEntries: [ClipboardEntry]

    @State private var activeFilter: ClipboardFilter = .all
    @State private var showingClearConfirmation = false

    private var filteredEntries: [ClipboardEntry] {
        var result = allEntries
        switch activeFilter {
        case .all:
            break
        case .pinned:
            result = result.filter(\.isPinned)
        case .text:
            result = result.filter { $0.imageData == nil && !$0.content.isEmpty }
        case .images:
            result = result.filter { $0.imageData != nil }
        }

        if !model.clipboardSearchText.isEmpty {
            let q = model.clipboardSearchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(q) || $0.content.lowercased().contains(q)
            }
        }
        return result
    }

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            // Filter Pills Header
            HStack(spacing: Space.xs) {
                ForEach(ClipboardFilter.allCases) { filter in
                    filterChip(title: filter.rawValue, isSelected: activeFilter == filter) {
                        activeFilter = filter
                    }
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

            // Paste-style Cards Grid
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 180, maximum: 240), spacing: Space.lg)],
                    spacing: Space.lg
                ) {
                    ForEach(filteredEntries) { entry in
                        ClipboardCard(
                            entry: entry,
                            isSelected: model.clipboardSelection == entry.id
                        )
                        .onTapGesture {
                            model.clipboardSelection = entry.id
                        }
                        .onTapGesture(count: 2) {
                            model.clipboardSelection = entry.id
                            model.insertClipboardEntryIntoActiveApp(entry)
                        }
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

                            if !entry.content.isEmpty {
                                Button {
                                    model.convertClipboardEntryToSnippet(entry)
                                } label: {
                                    Label("Save as Reusable Snippet…", systemImage: "text.quote")
                                }
                                Divider()
                            }

                            Button(role: .destructive) {
                                model.deleteClipboardEntry(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(Space.md)
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
                    } else if activeFilter == .pinned {
                        ContentUnavailableView(
                            "No Pinned Clippings",
                            systemImage: "pin",
                            description: Text("Pin clippings to keep them safe at the top.")
                        )
                    } else if activeFilter == .images {
                        ContentUnavailableView(
                            "No Images Copied",
                            systemImage: "photo",
                            description: Text("Copy any image or screenshot to see its visual card here.")
                        )
                    } else {
                        ContentUnavailableView(
                            "Clipboard Empty",
                            systemImage: "doc.on.clipboard",
                            description: Text("Copy text or images anywhere in macOS to automatically capture them here.")
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

// MARK: - Paste-Style Card View

struct ClipboardCard: View {
    let entry: ClipboardEntry
    let isSelected: Bool

    private var nsImage: NSImage? {
        guard let data = entry.imageData else { return nil }
        return NSImage(data: data)
    }

    private var hasImage: Bool {
        entry.imageData != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header content
            VStack(alignment: .leading, spacing: Space.xs) {
                // Pin Badge if pinned (No date, as explicitly instructed)
                if entry.isPinned {
                    HStack {
                        Spacer()
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                // Title in bold white
                Text(entry.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Subtitle snippet text if present
                if !entry.content.isEmpty && entry.content != entry.title {
                    Text(entry.content.replacingOccurrences(of: "\n", with: " "))
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.65, green: 0.67, blue: 0.72))
                        .lineLimit(hasImage ? 2 : 4)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.lg)
            .padding(.bottom, hasImage ? Space.sm : Space.lg)

            // Image Thumbnail pinned at bottom if present
            if let img = nsImage {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 88)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal, Space.sm)
                    .padding(.bottom, Space.sm)
            }
        }
        .frame(minHeight: hasImage ? 220 : 160, maxHeight: hasImage ? 230 : 170)
        .background(
            Color(red: 0.14, green: 0.15, blue: 0.17),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    isSelected ? Color(red: 0.05, green: 0.52, blue: 1.0) : Color.white.opacity(0.06),
                    lineWidth: isSelected ? 3 : 1
                )
        )
        .shadow(color: Color.black.opacity(isSelected ? 0.35 : 0.15), radius: isSelected ? 10 : 4, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                description: Text("Choose an item from the clipboard grid to inspect, insert, or save.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ClipboardInspectorContent: View {
    @Environment(AppModel.self) private var model
    let entry: ClipboardEntry

    @State private var copiedBriefly = false

    private var nsImage: NSImage? {
        guard let data = entry.imageData else { return nil }
        return NSImage(data: data)
    }

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
                .help("Insert text/image into previous active app")

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

                if !entry.content.isEmpty {
                    Button {
                        model.convertClipboardEntryToSnippet(entry)
                    } label: {
                        Label("Save as Snippet", systemImage: "text.quote")
                    }
                    .buttonStyle(.bordered)
                    .help("Convert this clipping into a reusable snippet")
                }

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
                VStack(alignment: .leading, spacing: Space.md) {
                    if let img = nsImage {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator, lineWidth: 1))
                            .frame(maxHeight: 280)
                    }

                    if !entry.content.isEmpty {
                        Text(entry.content)
                            .font(.system(size: 13, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                .padding(Space.md)
            }
            .background(Color(nsColor: .textBackgroundColor))

            // Footer metadata
            HStack {
                Text("Copied \(entry.copiedAt.formatted(date: .abbreviated, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if entry.imageData != nil {
                    Text("Image Clipping")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(entry.wordCount) words • \(entry.charCount) characters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Space.margin)
            .padding(.vertical, Space.sm)
            .background(.background.secondary)
            .overlay(Divider(), alignment: .top)
        }
    }
}
