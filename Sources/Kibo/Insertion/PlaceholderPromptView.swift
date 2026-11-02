import SwiftUI
import KiboKit

/// Interactive sheet/panel to fill in dynamic placeholder variables like `{{name}}`.
struct PlaceholderPromptView: View {
    let snippetName: String
    let template: String
    let onInsert: (String) -> Void
    let onCancel: () -> Void

    @State private var values: [String: String] = [:]
    @FocusState private var focusedKey: String?
    private let placeholders: [SnippetPlaceholders.Placeholder]

    init(
        snippetName: String,
        template: String,
        onInsert: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.snippetName = snippetName
        self.template = template
        self.onInsert = onInsert
        self.onCancel = onCancel
        self.placeholders = SnippetPlaceholders.extract(from: template)
    }

    private var substitutedResult: String {
        SnippetPlaceholders.substitute(template: template, with: values)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snippetName)
                        .font(.headline)
                    Text("Fill in the placeholder variables to insert into your active app")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, Space.margin)
            .padding(.vertical, Space.md)
            .background(.background.secondary)
            .overlay(Divider(), alignment: .bottom)

            // Form inputs
            Form {
                Section("Variables") {
                    ForEach(placeholders) { p in
                        HStack {
                            Text(p.key)
                                .font(.body.monospaced())
                                .foregroundStyle(Palette.accentText)
                                .frame(width: 112, alignment: .leading)

                            TextField(
                                p.defaultValue.map { "Default: \($0)" } ?? "Enter value...",
                                text: Binding(
                                    get: { values[p.key] ?? p.defaultValue ?? "" },
                                    set: { values[p.key] = $0 }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedKey, equals: p.key)
                            .onSubmit {
                                onInsert(substitutedResult)
                            }
                        }
                    }
                }

                Section("Live Preview") {
                    Text(substitutedResult)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Space.sm)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator, lineWidth: 1))
                }
            }
            .formStyle(.grouped)

            // Footer
            HStack {
                Text("Press ↵ Enter to insert directly into active app")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Insert Text") {
                    onInsert(substitutedResult)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, Space.margin)
            .padding(.vertical, Space.md)
            .background(.background.secondary)
            .overlay(Divider(), alignment: .top)
        }
        .frame(width: 500, height: 420)
        .onAppear {
            for p in placeholders {
                if let def = p.defaultValue {
                    values[p.key] = def
                }
            }
            if let first = placeholders.first?.key {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(60))
                    focusedKey = first
                }
            }
        }
    }
}
