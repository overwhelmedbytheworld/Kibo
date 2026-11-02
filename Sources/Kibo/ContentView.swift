import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            contentColumn
                .navigationSplitViewColumnWidth(min: 260, ideal: 320)
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
    @Environment(\.modelContext) private var context
    @Query(sort: \Snippet.modifiedAt, order: .reverse) private var snippets: [Snippet]
    let filterFavourites: Bool

    private var visible: [Snippet] {
        filterFavourites ? snippets.filter(\.isFavourite) : snippets
    }

    var body: some View {
        @Bindable var model = model
        List(visible, selection: $model.selection) { snippet in
            SnippetRow(snippet: snippet)
                .tag(snippet.id)
                .contextMenu {
                    Button(snippet.isFavourite ? "Unfavourite" : "Favourite") {
                        snippet.isFavourite.toggle()
                    }
                    Divider()
                    Button("Delete", role: .destructive) { context.delete(snippet) }
                }
        }
        .overlay {
            if visible.isEmpty {
                ContentUnavailableView(
                    filterFavourites ? "No Favourites" : "No Snippets",
                    systemImage: filterFavourites ? "star" : "text.quote",
                    description: Text(filterFavourites
                        ? "Star a snippet to see it here."
                        : "Press ⌘N to create your first snippet.")
                )
            }
        }
        .navigationTitle(filterFavourites ? "Favourites" : "Snippets")
        .toolbar {
            ToolbarItem {
                Button("New Snippet", systemImage: "plus") { model.addSnippet() }
                    .help("Add a snippet (⌘N)")
            }
        }
    }
}

// MARK: - Snippet Row

struct SnippetRow: View {
    let snippet: Snippet

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack {
                Text(snippet.name)
                    .font(.body)
                    .lineLimit(1)
                Spacer()
                if snippet.isFavourite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
            }
            if !snippet.alias.isEmpty {
                Text(snippet.alias)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Space.xs)
    }
}

// MARK: - Snippet Detail

struct SnippetDetailView: View {
    @Environment(AppModel.self) private var model
    @Query private var snippets: [Snippet]

    var body: some View {
        if let snippet = snippets.first(where: { $0.id == model.selection }) {
            @Bindable var snippet = snippet
            Form {
                Section("Details") {
                    TextField("Name", text: $snippet.name)
                    TextField("Alias (e.g. :email:)", text: $snippet.alias)
                    Toggle("Favourite", isOn: $snippet.isFavourite)
                }
                Section("Content") {
                    TextEditor(text: $snippet.content)
                        .font(.body.monospaced())
                        .frame(minHeight: 200)
                }
            }
            .formStyle(.grouped)
            .onChange(of: snippet.name) { _, _ in snippet.modifiedAt = .now }
            .onChange(of: snippet.alias) { _, _ in snippet.modifiedAt = .now }
            .onChange(of: snippet.content) { _, _ in snippet.modifiedAt = .now }
        } else {
            ContentUnavailableView("No Selection", systemImage: "doc.text")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Clipboard Placeholder

struct ClipboardPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Clipboard History",
            systemImage: "doc.on.clipboard",
            description: Text("Clipboard monitoring will be available in a future update.")
        )
        .navigationTitle("Clipboard")
    }
}
