import AppKit
import SwiftUI
import KiboKit

/// Detail inspector for viewing emoji metadata, reverse-engineered shortcodes, and Unicode values.
struct EmojiDetailInspectorView: View {
    @Environment(AppModel.self) private var model

    @State private var copiedText: String? = nil

    var body: some View {
        if let emoji = model.selectedEmoji {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    // Hero Card: Large Emoji Glyph & Title
                    HStack(spacing: Space.md) {
                        Text(emoji.emoji)
                            .font(.system(size: 64))
                            .frame(width: 88, height: 88)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.separator, lineWidth: 1))

                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text(emoji.name)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)

                            Text(emoji.category)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, Space.sm)
                                .padding(.vertical, 2)
                                .background(Palette.accent.opacity(0.15), in: Capsule())
                                .foregroundStyle(Palette.accentText)

                            if let target = ActiveAppTracker.shared.lastExternalApp {
                                Text("Active app: \(target.localizedName ?? "External App")")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()
                    }

                    // Copied Feedback Banner
                    if let copied = copiedText {
                        HStack(spacing: Space.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Copied \"\(copied)\" to clipboard!")
                                .font(.caption.weight(.medium))
                        }
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.green.opacity(0.25), lineWidth: 1))
                    }

                    Divider()

                    // Primary Shortcode Section
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("PRIMARY SHORTCODE")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)

                        HStack {
                            Text(emoji.primaryAlias)
                                .font(.body.monospaced().weight(.semibold))
                                .foregroundStyle(Palette.accentText)

                            Spacer()

                            Button {
                                copyToClipboard(emoji.primaryAlias)
                            } label: {
                                Label("Copy Code", systemImage: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(Space.md)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator, lineWidth: 1))

                        Text("Type \(emoji.primaryAlias) anywhere on your Mac (WhatsApp, Slack, Safari) to auto-expand.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }

                    // Alternative Aliases / Synonyms Section
                    if emoji.aliases.count > 1 {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text("SYNONYMS & ALTERNATIVE CODES")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)

                            FlowLayout(spacing: Space.xs) {
                                ForEach(emoji.aliases, id: \.self) { alias in
                                    Button {
                                        copyToClipboard(alias)
                                    } label: {
                                        HStack(spacing: 2) {
                                            Text(alias)
                                                .font(.caption.monospaced())
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 9))
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, Space.sm)
                                        .padding(.vertical, Space.xs)
                                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Unicode Codepoints Section
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("UNICODE CODEPOINT")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)

                        HStack {
                            Text(emoji.unicodeHex)
                                .font(.body.monospaced())
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                copyToClipboard(emoji.unicodeHex)
                            } label: {
                                Label("Copy Hex", systemImage: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(Space.md)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator, lineWidth: 1))
                    }

                    Divider()

                    // Direct Action Buttons
                    VStack(spacing: Space.sm) {
                        Button {
                            insertIntoActiveApp(emoji.emoji)
                        } label: {
                            HStack {
                                Image(systemName: "arrow.down.doc.fill")
                                Text("Insert \"\(emoji.emoji)\" into Active App")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Space.xs)
                        }
                        .buttonStyle(.borderedProminent)

                        HStack(spacing: Space.sm) {
                            Button {
                                copyToClipboard(emoji.emoji)
                            } label: {
                                Label("Copy Emoji", systemImage: "face.smiling")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 2)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                copyToClipboard(emoji.primaryAlias)
                            } label: {
                                Label("Copy Shortcode", systemImage: "text.quote")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 2)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(Space.lg)
            }
        } else {
            ContentUnavailableView(
                "Select an Emoji",
                systemImage: "face.smiling",
                description: Text("Select any emoji to inspect its shortcodes, or paste an emoji into the search bar to reverse-engineer its code.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func copyToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        withAnimation {
            copiedText = text
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                if copiedText == text {
                    copiedText = nil
                }
            }
        }
    }

    private func insertIntoActiveApp(_ text: String) {
        let target = ActiveAppTracker.shared.lastExternalApp
        TextInserter.insert(text: text, into: target)
        copyToClipboard(text)
    }
}

// MARK: - Flow Layout for Pills

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        height = currentY + lineHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
