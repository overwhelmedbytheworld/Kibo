import AppKit
import Foundation
import SwiftData
import KiboKit

// MARK: - Snippet

/// A reusable text snippet or AI prompt.
@Model
final class Snippet {
    var name: String
    /// The trigger alias, e.g. `:email:`. Validated by SnippetAlias.
    var alias: String
    /// The full text content. Preserves multiline, Unicode, whitespace exactly.
    var content: String
    /// Optional category for organisation (e.g. Work, Study, Code).
    var category: String = ""
    var isFavourite: Bool = false
    var usageCount: Int = 0
    var createdAt: Date = Date.now
    var modifiedAt: Date = Date.now
    var lastUsedAt: Date?
    /// A stable id for links, sync, and the agent CLI.
    var uid: UUID = UUID()

    init(
        name: String,
        alias: String,
        content: String,
        category: String = "",
        isFavourite: Bool = false
    ) {
        self.name = name
        self.alias = alias
        self.content = content
        self.category = category
        self.isFavourite = isFavourite
    }
}

// MARK: - Sidebar

/// The sidebar pages. Snapshot mode walks through every case.
enum SidebarPage: String, CaseIterable, Identifiable {
    case clipboard, snippets, favourites, emojis, stats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clipboard: "Clipboard"
        case .snippets: "Snippets"
        case .favourites: "Favourites"
        case .emojis: "Emojis"
        case .stats: "Insights"
        }
    }

    var symbol: String {
        switch self {
        case .clipboard: "doc.on.clipboard"
        case .snippets: "text.quote"
        case .favourites: "star"
        case .emojis: "face.smiling"
        case .stats: "chart.bar.xaxis"
        }
    }
}

// MARK: - Sorting

public enum SnippetSortOrder: String, CaseIterable, Identifiable {
    case recentlyModified = "Recently Modified"
    case nameAscending = "Name (A-Z)"
    case mostUsed = "Most Used"
    case recentlyUsed = "Recently Used"
    case category = "Category"

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .recentlyModified: return "clock"
        case .nameAscending: return "textformat.abc"
        case .mostUsed: return "flame"
        case .recentlyUsed: return "arrow.clockwise"
        case .category: return "tag"
        }
    }
}

// MARK: - App Model

/// App-wide state that menus, toolbars, and views share.
@Observable
final class AppModel {
    let container: ModelContainer
    var sidebar: SidebarPage? = .snippets
    var selection: PersistentIdentifier?
    var searchText: String = ""
    var selectedCategory: String? = nil
    var sortOrder: SnippetSortOrder = .recentlyModified

    /// Active placeholder prompt sheet state.
    var placeholderPromptSnippet: Snippet? = nil

    /// Clipboard history selection and search state.
    var clipboardSelection: PersistentIdentifier?
    var clipboardSearchText: String = ""
    var clipboardPinnedOnly: Bool = false

    /// Emoji library selection, search, and category filter state.
    var selectedEmoji: EmojiItem? = nil
    var emojiSearchText: String = ""
    var selectedEmojiCategory: String = "All"

    /// Transient notification when a snippet is copied.
    var justCopiedUID: UUID? = nil

    /// Settings reopens on the last tab. Test and snapshot runs leave it alone.
    var settingsTab: SettingsTab = SettingsTab(rawValue: UserDefaults.standard.string(forKey: "settings.tab") ?? "") ?? .general {
        didSet { if !Store.isOverridden { UserDefaults.standard.set(settingsTab.rawValue, forKey: "settings.tab") } }
    }
    /// Whether the main window is currently open.
    var mainWindowOpen = false

    init(container: ModelContainer) {
        self.container = container
        syncTriggerCache()
    }

    /// Synchronizes the trigger engine's in-memory lookup cache from SwiftData.
    func syncTriggerCache() {
        if let snippets = try? container.mainContext.fetch(FetchDescriptor<Snippet>()) {
            GlobalTriggerEngine.shared.updateTriggers(from: snippets)
        }
    }

    /// Updates usage statistics when a trigger expands.
    func recordSnippetUsage(id: PersistentIdentifier) {
        if let snippet = try? container.mainContext.fetch(FetchDescriptor<Snippet>()).first(where: { $0.id == id }) {
            snippet.usageCount += 1
            snippet.lastUsedAt = .now
            try? container.mainContext.save()
        }
    }

    func addSnippet(
        name: String = "",
        alias: String = "",
        content: String = "",
        category: String = ""
    ) {
        let snippet = Snippet(
            name: name.isEmpty ? "New Snippet" : name,
            alias: alias,
            content: content,
            category: category
        )
        if sidebar == .favourites { snippet.isFavourite = true }
        container.mainContext.insert(snippet)
        try? container.mainContext.save()
        selection = snippet.id
        syncTriggerCache()
    }

    func duplicateSnippet(_ snippet: Snippet) {
        let newAlias: String
        if snippet.alias.isEmpty {
            newAlias = ""
        } else if snippet.alias.hasSuffix(":") {
            let inner = snippet.alias.dropFirst().dropLast()
            newAlias = ":\(inner)-copy:"
        } else {
            newAlias = "\(snippet.alias)-copy"
        }

        let clone = Snippet(
            name: "\(snippet.name) Copy",
            alias: newAlias,
            content: snippet.content,
            category: snippet.category,
            isFavourite: snippet.isFavourite
        )
        container.mainContext.insert(clone)
        try? container.mainContext.save()
        selection = clone.id
        syncTriggerCache()
    }

    func deleteSnippet(_ snippet: Snippet) {
        if selection == snippet.id {
            selection = nil
        }
        container.mainContext.delete(snippet)
        try? container.mainContext.save()
        syncTriggerCache()
    }

    func toggleFavourite(_ snippet: Snippet) {
        snippet.isFavourite.toggle()
        snippet.modifiedAt = .now
        try? container.mainContext.save()
    }

    func copyToClipboard(_ snippet: Snippet) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(snippet.content, forType: .string)

        snippet.usageCount += 1
        snippet.lastUsedAt = .now
        try? container.mainContext.save()

        justCopiedUID = snippet.uid
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            if self.justCopiedUID == snippet.uid {
                self.justCopiedUID = nil
            }
        }
    }

    func insertSnippetIntoActiveApp(_ snippet: Snippet, values: [String: String]? = nil) {
        let target = ActiveAppTracker.shared.lastExternalApp
        if let vals = values {
            let substituted = SnippetPlaceholders.substitute(template: snippet.content, with: vals)
            snippet.usageCount += 1
            snippet.lastUsedAt = .now
            try? container.mainContext.save()
            TextInserter.insert(text: substituted, into: target)
        } else if SnippetPlaceholders.hasPlaceholders(snippet.content) {
            placeholderPromptSnippet = snippet
        } else {
            snippet.usageCount += 1
            snippet.lastUsedAt = .now
            try? container.mainContext.save()
            TextInserter.insert(text: snippet.content, into: target)
        }
    }

    // MARK: - Clipboard History Actions

    func recordClipboardCopy(content: String) {
        let entry = ClipboardEntry(content: content)
        container.mainContext.insert(entry)

        // Enforce history limit (prune oldest unpinned entries beyond 250 items)
        let limit = 250
        if let all = try? container.mainContext.fetch(FetchDescriptor<ClipboardEntry>(sortBy: [SortDescriptor(\.copiedAt, order: .reverse)])) {
            let unpinned = all.filter { !$0.isPinned }
            if unpinned.count > limit {
                for stale in unpinned.suffix(from: limit) {
                    container.mainContext.delete(stale)
                }
            }
        }

        try? container.mainContext.save()
    }

    func recordClipboardImage(data: Data, text: String = "") {
        let entry = ClipboardEntry(content: text, imageData: data)
        container.mainContext.insert(entry)

        let limit = 250
        if let all = try? container.mainContext.fetch(FetchDescriptor<ClipboardEntry>(sortBy: [SortDescriptor(\.copiedAt, order: .reverse)])) {
            let unpinned = all.filter { !$0.isPinned }
            if unpinned.count > limit {
                for stale in unpinned.suffix(from: limit) {
                    container.mainContext.delete(stale)
                }
            }
        }
        try? container.mainContext.save()
    }

    func deleteClipboardEntry(_ entry: ClipboardEntry) {
        if clipboardSelection == entry.id {
            clipboardSelection = nil
        }
        container.mainContext.delete(entry)
        try? container.mainContext.save()
    }

    func togglePinClipboardEntry(_ entry: ClipboardEntry) {
        entry.isPinned.toggle()
        try? container.mainContext.save()
    }

    func clearUnpinnedClipboard() {
        if let all = try? container.mainContext.fetch(FetchDescriptor<ClipboardEntry>()) {
            for entry in all where !entry.isPinned {
                if clipboardSelection == entry.id {
                    clipboardSelection = nil
                }
                container.mainContext.delete(entry)
            }
            try? container.mainContext.save()
        }
    }

    func copyClipboardEntryToPasteboard(_ entry: ClipboardEntry) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if let imgData = entry.imageData {
            pb.setData(imgData, forType: .png)
            pb.setData(imgData, forType: .tiff)
        }
        if !entry.content.isEmpty {
            pb.setString(entry.content, forType: .string)
        }
    }

    func insertClipboardEntryIntoActiveApp(_ entry: ClipboardEntry) {
        let target = ActiveAppTracker.shared.lastExternalApp
        if let imgData = entry.imageData {
            TextInserter.insertImage(data: imgData, into: target)
        } else {
            TextInserter.insert(text: entry.content, into: target)
        }
    }

    func convertClipboardEntryToSnippet(_ entry: ClipboardEntry) {
        let titleFirstLine = entry.content.split(separator: "\n").first.map(String.init) ?? "New Snippet"
        let truncatedTitle = titleFirstLine.count > 30 ? String(titleFirstLine.prefix(30)) + "…" : titleFirstLine
        addSnippet(
            name: truncatedTitle,
            alias: "",
            content: entry.content,
            category: "Clippings"
        )
        sidebar = .snippets
    }
}
