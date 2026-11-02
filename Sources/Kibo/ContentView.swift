import SwiftData
import SwiftUI
import KiboKit

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            sidebar
        } content: {
            contentColumn
                .navigationSplitViewColumnWidth(min: 280, ideal: 340)
        } detail: {
            detailColumn
        }
        .sheet(item: $model.placeholderPromptSnippet) { snippet in
            PlaceholderPromptView(
                snippetName: snippet.name,
                template: snippet.content,
                onInsert: { substituted in
                    model.placeholderPromptSnippet = nil
                    let target = ActiveAppTracker.shared.lastExternalApp
                    TextInserter.insert(text: substituted, into: target)
                    model.recordSnippetUsage(id: snippet.id)
                },
                onCancel: {
                    model.placeholderPromptSnippet = nil
                }
            )
        }
        .task {
            SeedData.insertIfRequested(into: model)
            SelfTest.runIfRequested(model: model)
            Snapshot.runIfRequested(model: model, openSettings: openSettings)

            // Start global background trigger engine for typing expansion
            GlobalTriggerEngine.shared.start(model: model)
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

    /// Distinct categories in the snippet collection.
    private var availableCategories: [String] {
        let base = filterFavourites ? allSnippets.filter(\.isFavourite) : allSnippets
        let cats = Set(base.map(\.category).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        return cats.sorted()
    }

    /// Filtered and sorted snippets.
    private var filteredSnippets: [Snippet] {
        let base = filterFavourites ? allSnippets.filter(\.isFavourite) : allSnippets
        let searched = SnippetSearch.filter(
            items: base,
            query: model.searchText,
            categoryFilter: model.selectedCategory
        ) { snippet in
            (snippet.name, snippet.alias, snippet.category, snippet.content)
        }

        // Apply secondary sort order if query is empty
        if model.searchText.isEmpty {
            switch model.sortOrder {
            case .recentlyModified:
                return searched.sorted { $0.modifiedAt > $1.modifiedAt }
            case .nameAscending:
                return searched.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            case .mostUsed:
                return searched.sorted { $0.usageCount > $1.usageCount }
            case .recentlyUsed:
                return searched.sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            case .category:
                return searched.sorted { $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending }
            }
        }
        return searched
    }

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            // Category filter pills & Sort header
            HStack(spacing: Space.xs) {
                categoryFilterBar

                Spacer(minLength: 0)

                // Sort Menu
                Menu {
                    Picker("Sort By", selection: $model.sortOrder) {
                        ForEach(SnippetSortOrder.allCases) { order in
                            Label(order.rawValue, systemImage: order.symbol)
                                .tag(order)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption)
                        .padding(Space.xs)
                }
                .menuStyle(.borderlessButton)
                .help("Sort snippets by \(model.sortOrder.rawValue)")
                .padding(.trailing, Space.sm)
            }
            .background(.background.secondary)
            .overlay(Divider(), alignment: .bottom)

            // Snippet Rows List
            List(filteredSnippets, selection: $model.selection) { snippet in
                SnippetRow(snippet: snippet)
                    .tag(snippet.id)
                    .contextMenu {
                        Button {
                            model.insertSnippetIntoActiveApp(snippet)
                        } label: {
                            Label("Insert into Active App", systemImage: "arrow.right.doc.on.clipboard")
                        }

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

                Button {
                    FloatingPanelController.shared.show(model: model)
                } label: {
                    Label("Quick Search", systemImage: "magnifyingglass")
                }
                .help("Open floating search (⌘⇧K)")
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
                        .font(.caption2)
                        .padding(.horizontal, Space.xs)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                        .foregroundStyle(.secondary)
                }

                if SnippetPlaceholders.hasPlaceholders(snippet.content) {
                    Text("{{var}}")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
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
            SnippetEditorContent(snippet: snippet, allSnippets: snippets)
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
    let allSnippets: [Snippet]

    @State private var newCategoryText = ""
    @State private var showingCategoryInput = false

    private var aliasValidation: SnippetAlias.ValidationResult {
        SnippetAlias.validate(snippet.alias)
    }

    private var isCopied: Bool {
        model.justCopiedUID == snippet.uid
    }

    private var existingCategories: [String] {
        let defaultSuggestions = ["Work", "Study", "Code", "Writing", "Prompt", "Personal"]
        let fromData = allSnippets.map(\.category).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return Array(Set(defaultSuggestions + fromData)).sorted()
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

                    categoryPillRow
                }

                Section("Content") {
                    if SnippetPlaceholders.hasPlaceholders(snippet.content) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.orange)
                            Text("Contains dynamic variables. You will be prompted to fill them in when inserting.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    TextEditor(text: $snippet.content)
                        .font(.system(size: 13, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator, lineWidth: 1))
                        .frame(minHeight: 220)

                    contentFooter
                }
            }
            .formStyle(.grouped)
        }
        .onChange(of: snippet.name) { _, _ in snippet.modifiedAt = .now; model.syncTriggerCache() }
        .onChange(of: snippet.alias) { _, _ in snippet.modifiedAt = .now; model.syncTriggerCache() }
        .onChange(of: snippet.content) { _, _ in snippet.modifiedAt = .now; model.syncTriggerCache() }
        .onChange(of: snippet.category) { _, _ in snippet.modifiedAt = .now }
    }

    // MARK: - Header Actions

    private var editorHeader: some View {
        HStack(spacing: Space.sm) {
            // Primary Action: Insert directly into active app!
            Button {
                model.insertSnippetIntoActiveApp(snippet)
            } label: {
                Label("Insert into Active App", systemImage: "arrow.right.doc.on.clipboard")
            }
            .buttonStyle(.borderedProminent)
            .help("Inserts text into whatever application you were working in")

            // Copy button
            Button {
                model.copyToClipboard(snippet)
            } label: {
                Label(
                    isCopied ? "Copied!" : "Copy",
                    systemImage: isCopied ? "checkmark" : "doc.on.clipboard"
                )
            }
            .buttonStyle(.bordered)
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
                Text("Type an alias surrounded by colons (e.g. :email:) to trigger automatic expansion in any app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Category Pill & Dropdown Selector

    private var categoryPillRow: some View {
        HStack(spacing: Space.sm) {
            Text("Category:")
                .font(.body)

            if !snippet.category.isEmpty {
                // Interactive Category Pill with delete icon
                HStack(spacing: Space.xs) {
                    Image(systemName: "tag.fill")
                        .font(.caption2)

                    Text(snippet.category)
                        .font(.caption.weight(.medium))

                    Button {
                        snippet.category = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Space.sm)
                .padding(.vertical, Space.xs)
                .background(Palette.accent.opacity(0.15), in: Capsule())
                .foregroundStyle(Palette.accentText)
            }

            // Dropdown Menu to choose or change category
            Menu {
                ForEach(existingCategories, id: \.self) { cat in
                    Button {
                        snippet.category = cat
                    } label: {
                        HStack {
                            Text(cat)
                            if snippet.category == cat {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Divider()

                Button("New Category...") {
                    showingCategoryInput = true
                }
            } label: {
                Label(snippet.category.isEmpty ? "Select Category Pill..." : "Change", systemImage: "chevron.down")
                    .font(.caption)
            }
            .menuStyle(.borderedButton)
            .controlSize(.small)

            if showingCategoryInput {
                HStack(spacing: Space.xs) {
                    TextField("Category name", text: $newCategoryText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 132)

                    Button("Set") {
                        let trimmed = newCategoryText.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            snippet.category = trimmed
                        }
                        newCategoryText = ""
                        showingCategoryInput = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("Cancel") {
                        showingCategoryInput = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Spacer()
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
