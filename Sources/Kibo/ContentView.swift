import SwiftData
import SwiftUI
import KiboKit

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            contentColumn
                .navigationSplitViewColumnWidth(min: 280, ideal: 340)
        } detail: {
            detailColumn
        }
        .task {
            SeedData.insertIfRequested(into: model)
            SelfTest.runIfRequested(model: model)
            Snapshot.runIfRequested(model: model, openSettings: openSettings)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        @Bindable var model = model
        return List(SidebarPage.allCases, selection: $model.sidebar) { page in
            Label(page.title, systemImage: page.symbol)
                .tag(page)
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    }

    // MARK: - Content Column

    @ViewBuilder
    private var contentColumn: some View {
        switch model.sidebar {
        case .snippets:
            SnippetListView(filterFavourites: false)
        case .favourites:
            SnippetListView(filterFavourites: true)
        case .clipboard:
            ClipboardPlaceholderView()
        case nil:
            ContentUnavailableView("Select a Category", systemImage: "sidebar.left")
        }
    }

    // MARK: - Detail Column

    @ViewBuilder
    private var detailColumn: some View {
        if model.sidebar == .snippets || model.sidebar == .favourites {
            SnippetDetailView()
        } else {
            ContentUnavailableView("No Selection", systemImage: "doc.text")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Snippet List

struct SnippetListView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Snippet.modifiedAt, order: .reverse) private var allSnippets: [Snippet]
    let filterFavourites: Bool

    /// Distinct categories present in the current snippet collection.
    private var availableCategories: [String] {
        let base = filterFavourites ? allSnippets.filter(\.isFavourite) : allSnippets
        let cats = Set(base.map(\.category).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        return cats.sorted()
    }

    /// Visible snippets filtered by search and category.
    private var filteredSnippets: [Snippet] {
        let base = filterFavourites ? allSnippets.filter(\.isFavourite) : allSnippets
        return SnippetSearch.filter(
            items: base,
            query: model.searchText,
            categoryFilter: model.selectedCategory
        ) { snippet in
            (snippet.name, snippet.alias, snippet.category, snippet.content)
        }
    }

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            // Category filter chips
            if !availableCategories.isEmpty {
                categoryFilterBar
            }

            List(filteredSnippets, selection: $model.selection) { snippet in
                SnippetRow(snippet: snippet)
                    .tag(snippet.id)
                    .contextMenu {
                        Button {
                            model.copyToClipboard(snippet)
                        } label: {
                            Label("Copy Content", systemImage: "doc.on.doc")
                        }

                        Button {
                            model.toggleFavourite(snippet)
                        } label: {
                            Label(snippet.isFavourite ? "Unfavourite" : "Favourite",
                                  systemImage: snippet.isFavourite ? "star.slash" : "star")
                        }

                        Button {
                            model.duplicateSnippet(snippet)
                        } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }

                        Divider()

                        Button(role: .destructive) {
                            model.deleteSnippet(snippet)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            .onDeleteCommand {
                if let selectedID = model.selection,
                   let selected = allSnippets.first(where: { $0.id == selectedID }) {
                    model.deleteSnippet(selected)
                }
            }
            .overlay {
                if filteredSnippets.isEmpty {
                    if !model.searchText.isEmpty || model.selectedCategory != nil {
                        ContentUnavailableView.search(text: model.searchText)
                    } else {
                        ContentUnavailableView(
                            filterFavourites ? "No Favourites" : "No Snippets",
                            systemImage: filterFavourites ? "star" : "text.quote",
                            description: Text(filterFavourites
                                ? "Star a snippet to access it quickly here."
                                : "Press ⌘N to create your first reusable prompt.")
                        )
                    }
                }
            }
        }
        .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search title, alias, prompt...")
        .navigationTitle(filterFavourites ? "Favourites" : "Snippets")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.addSnippet()
                } label: {
                    Label("New Snippet", systemImage: "plus")
                }
                .help("Create a new snippet (⌘N)")
            }
        }
    }

    // MARK: - Category Filter Bar

    private var categoryFilterBar: some View {
        @Bindable var model = model
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.xs) {
                categoryChip(title: "All", isSelected: model.selectedCategory == nil) {
                    model.selectedCategory = nil
                }

                ForEach(availableCategories, id: \.self) { cat in
                    categoryChip(title: cat, isSelected: model.selectedCategory == cat) {
                        model.selectedCategory = (model.selectedCategory == cat) ? nil : cat
                    }
                }
            }
            .padding(.horizontal, Space.sm)
            .padding(.vertical, Space.xs)
        }
        .background(.background.secondary)
        .overlay(Divider(), alignment: .bottom)
    }

    private func categoryChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
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

// MARK: - Snippet Row

struct SnippetRow: View {
    let snippet: Snippet

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(snippet.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Spacer()

                if snippet.isFavourite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
            }

            HStack(spacing: Space.sm) {
                if !snippet.alias.isEmpty {
                    Text(snippet.alias)
                        .font(.caption.monospaced())
                        .foregroundStyle(Palette.accentText)
                        .padding(.horizontal, Space.xs)
                        .padding(.vertical, 1)
                        .background(Palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                }

                if !snippet.category.isEmpty {
                    Text(snippet.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if snippet.usageCount > 0 {
                    Text("\(snippet.usageCount) uses")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, Space.xs)
    }
}

// MARK: - Snippet Detail / Editor

struct SnippetDetailView: View {
    @Environment(AppModel.self) private var model
    @Query private var snippets: [Snippet]

    var body: some View {
        if let selectedID = model.selection,
           let snippet = snippets.first(where: { $0.id == selectedID }) {
            SnippetEditorContent(snippet: snippet)
        } else {
            ContentUnavailableView(
                "No Snippet Selected",
                systemImage: "doc.text",
                description: Text("Select a snippet from the list or press ⌘N to create one.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct SnippetEditorContent: View {
    @Environment(AppModel.self) private var model
    @Bindable var snippet: Snippet

    private var aliasValidation: SnippetAlias.ValidationResult {
        SnippetAlias.validate(snippet.alias)
    }

    private var isCopied: Bool {
        model.justCopiedUID == snippet.uid
    }

    var body: some View {
        VStack(spacing: 0) {
            // Action Toolbar Header
            editorHeader
                .padding(.horizontal, Space.margin)
                .padding(.vertical, Space.sm)
                .background(.background.secondary)
                .overlay(Divider(), alignment: .bottom)

            // Editor Form
            Form {
                Section("Properties") {
                    TextField("Title", text: $snippet.name)
                        .font(.headline)

                    aliasRow

                    TextField("Category / Tag (e.g. Work, Study, Prompt)", text: $snippet.category)
                }

                Section("Content") {
                    TextEditor(text: $snippet.content)
                        .font(.system(size: 13, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator, lineWidth: 1))
                        .frame(minHeight: 240)

                    contentFooter
                }
            }
            .formStyle(.grouped)
        }
        .onChange(of: snippet.name) { _, _ in snippet.modifiedAt = .now }
        .onChange(of: snippet.alias) { _, _ in snippet.modifiedAt = .now }
        .onChange(of: snippet.content) { _, _ in snippet.modifiedAt = .now }
        .onChange(of: snippet.category) { _, _ in snippet.modifiedAt = .now }
    }

    // MARK: - Header Actions

    private var editorHeader: some View {
        HStack(spacing: Space.sm) {
            // Primary Copy button for instant use
            Button {
                model.copyToClipboard(snippet)
            } label: {
                Label(
                    isCopied ? "Copied to Clipboard!" : "Copy Snippet",
                    systemImage: isCopied ? "checkmark" : "doc.on.clipboard"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(isCopied ? .green : nil)
            .keyboardShortcut(.return, modifiers: [.command])
            .help("Copy content to clipboard (⌘Return or ⌘C)")

            Spacer()

            // Star / Favourite
            Button {
                model.toggleFavourite(snippet)
            } label: {
                Image(systemName: snippet.isFavourite ? "star.fill" : "star")
            }
            .buttonStyle(.bordered)
            .help(snippet.isFavourite ? "Remove from favourites (⌘S)" : "Add to favourites (⌘S)")
            .keyboardShortcut("s", modifiers: [.command])

            // Duplicate
            Button {
                model.duplicateSnippet(snippet)
            } label: {
                Image(systemName: "plus.square.on.square")
            }
            .buttonStyle(.bordered)
            .help("Duplicate this snippet (⌘D)")
            .keyboardShortcut("d", modifiers: [.command])

            // Delete
            Button(role: .destructive) {
                model.deleteSnippet(snippet)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .help("Delete snippet (⌘⌫)")
        }
    }

    // MARK: - Live Alias Validation Row

    private var aliasRow: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack {
                TextField("Trigger Alias (e.g. :email:)", text: $snippet.alias)
                    .font(.body.monospaced())

                if !snippet.alias.isEmpty {
                    if aliasValidation == .valid {
                        Label("Valid", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Button("Auto-fix") {
                            if let cleaned = SnippetAlias.clean(snippet.alias) {
                                snippet.alias = cleaned
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            if !snippet.alias.isEmpty && aliasValidation != .valid {
                Text(aliasValidation.message)
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if snippet.alias.isEmpty {
                Text("Type an alias surrounded by colons (e.g. :email:) to trigger automatic expansion.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Content Footer Stats

    private var contentFooter: some View {
        HStack {
            let chars = snippet.content.count
            let lines = snippet.content.split(separator: "\n", omittingEmptySubsequences: false).count
            let words = snippet.content.split(whereSeparator: \.isWhitespace).count

            Text("\(lines) lines • \(words) words • \(chars) chars")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if let lastUsed = snippet.lastUsedAt {
                Text("Last used \(lastUsed.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Clipboard Placeholder

struct ClipboardPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Clipboard History",
            systemImage: "doc.on.clipboard",
            description: Text("Clipboard monitoring will be available in Phase 5.")
        )
        .navigationTitle("Clipboard")
    }
}
