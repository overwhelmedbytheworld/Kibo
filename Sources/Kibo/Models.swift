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
    /// Optional category for organisation.
    var category: String = ""
    var isFavourite: Bool = false
    var usageCount: Int = 0
    var createdAt: Date = Date.now
    var modifiedAt: Date = Date.now
    var lastUsedAt: Date?
    /// A stable id for links, sync, and the agent CLI.
    var uid: UUID = UUID()

    init(name: String, alias: String, content: String) {
        self.name = name
        self.alias = alias
        self.content = content
    }
}

// MARK: - Sidebar

/// The sidebar pages. Snapshot mode walks through every case.
enum SidebarPage: String, CaseIterable, Identifiable {
    case clipboard, snippets, favourites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clipboard: "Clipboard"
        case .snippets: "Snippets"
        case .favourites: "Favourites"
        }
    }

    var symbol: String {
        switch self {
        case .clipboard: "doc.on.clipboard"
        case .snippets: "text.quote"
        case .favourites: "star"
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
    /// Settings reopens on the last tab. Test and snapshot runs leave it alone.
    var settingsTab: SettingsTab = SettingsTab(rawValue: UserDefaults.standard.string(forKey: "settings.tab") ?? "") ?? .general {
        didSet { if !Store.isOverridden { UserDefaults.standard.set(settingsTab.rawValue, forKey: "settings.tab") } }
    }
    /// Whether the main window is currently open.
    var mainWindowOpen = false

    init(container: ModelContainer) {
        self.container = container
    }

    func addSnippet(name: String = "", alias: String = "", content: String = "") {
        let snippet = Snippet(
            name: name.isEmpty ? "New Snippet" : name,
            alias: alias,
            content: content
        )
        if sidebar == .favourites { snippet.isFavourite = true }
        container.mainContext.insert(snippet)
        selection = snippet.id
    }
}
