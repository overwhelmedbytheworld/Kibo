import AppKit
import SwiftUI
import KiboKit

/// In-app browser and reverse-engineering inspector for all macOS emojis and trigger shortcodes.
struct EmojiBrowserView: View {
    @Environment(AppModel.self) private var model

    private var filteredEmojis: [EmojiItem] {
        EmojiCatalog.filter(
            query: model.emojiSearchText,
            category: model.selectedEmojiCategory
        )
    }

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            // Header: Search & Reverse-Engineer Input
            VStack(spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search or paste emoji (e.g. 🌹 from WhatsApp)...", text: $model.emojiSearchText)
                        .textFieldStyle(.plain)
                        .onChange(of: model.emojiSearchText) { _, newText in
                            handleSearchChange(newText)
                        }

                    if !model.emojiSearchText.isEmpty {
                        Button {
                            model.emojiSearchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator, lineWidth: 1))

                // Category Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.xs) {
                        ForEach(EmojiCatalog.categories, id: \.self) { category in
                            let isSelected = model.selectedEmojiCategory == category
                            Button {
                                model.selectedEmojiCategory = category
                            } label: {
                                Text(category)
                                    .font(.caption.weight(isSelected ? .semibold : .regular))
                                    .padding(.horizontal, Space.sm)
                                    .padding(.vertical, Space.xs)
                                    .background(
                                        isSelected ? Palette.accent : Color(nsColor: .controlBackgroundColor),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(isSelected ? Palette.onAccent : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(Space.md)
            .background(Color(nsColor: .windowBackgroundColor))
            .overlay(Divider(), alignment: .bottom)

            // Emoji Card Grid
            ScrollView {
                if filteredEmojis.isEmpty {
                    ContentUnavailableView(
                        "No Emojis Found",
                        systemImage: "face.smiling",
                        description: Text("Try searching with another keyword or paste an emoji to reverse-engineer.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .padding(.top, Space.xl)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 64, maximum: 80), spacing: Space.sm)],
                        spacing: Space.sm
                    ) {
                        ForEach(filteredEmojis) { item in
                            let isSelected = model.selectedEmoji?.id == item.id
                            EmojiCardView(item: item, isSelected: isSelected)
                                .onTapGesture {
                                    model.selectedEmoji = item
                                }
                                .simultaneousGesture(
                                    TapGesture(count: 2).onEnded {
                                        model.selectedEmoji = item
                                        copyEmoji(item)
                                    }
                                )
                        }
                    }
                    .padding(Space.md)
                }
            }
        }
        .onAppear {
            if model.selectedEmoji == nil {
                model.selectedEmoji = EmojiCatalog.all.first(where: { $0.emoji == "🌹" }) ?? EmojiCatalog.all.first
            }
        }
    }

    private func handleSearchChange(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Reverse-Engineer detection: if the user pasted a raw emoji, select it immediately!
        if let direct = EmojiCatalog.reverseEngineer(input: trimmed) {
            model.selectedEmoji = direct
        } else if let topMatch = filteredEmojis.first {
            model.selectedEmoji = topMatch
        }
    }

    private func copyEmoji(_ item: EmojiItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(item.emoji, forType: .string)
    }
}

// MARK: - Emoji Card in Grid

private struct EmojiCardView: View {
    let item: EmojiItem
    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: Space.xs) {
            Text(item.emoji)
                .font(.system(size: 32))
                .frame(width: 40, height: 40)

            Text(item.primaryAlias)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(isSelected ? Palette.accentText : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.sm)
        .padding(.horizontal, Space.xs)
        .background(
            isSelected
                ? Palette.accent.opacity(0.12)
                : (isHovered ? Color(nsColor: .controlBackgroundColor) : Color(nsColor: .controlBackgroundColor).opacity(0.5)),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isSelected ? Palette.accent : (isHovered ? Color.secondary.opacity(0.3) : Color(nsColor: .separatorColor).opacity(0.4)),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
