import AppKit
import SwiftUI
import KiboKit

/// Represents an item in the floating inline suggestion bar.
public enum InlineSuggestionItem: Identifiable, Sendable, Equatable {
    case emoji(EmojiItem)
    case snippet(alias: String, content: String, name: String)

    public var id: String {
        switch self {
        case .emoji(let e): return "e_\(e.id)"
        case .snippet(let alias, _, let name): return "s_\(alias)_\(name)"
        }
    }
}

/// Floating horizontal suggestion bar matching WhatsApp's inline shortcode HUD.
struct InlineSuggestionBarView: View {
    @ObservedObject var controller: InlineSuggestionController

    var body: some View {
        HStack(spacing: Space.xs) {
            ForEach(Array(controller.suggestions.enumerated()), id: \.element.id) { index, item in
                let isSelected = index == controller.selectedIndex

                Button {
                    controller.selectIndex(index)
                } label: {
                    switch item {
                    case .emoji(let emojiItem):
                        Text(emojiItem.emoji)
                            .font(.system(size: 24))
                            .frame(width: 40, height: 40)
                            .background(
                                isSelected ? Color.white.opacity(0.08) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        isSelected
                                            ? Color(red: 0.18, green: 0.82, blue: 0.44)
                                            : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    case .snippet(_, _, let name):
                        HStack(spacing: Space.xs) {
                            Image(systemName: "text.quote")
                                .font(.caption)
                                .foregroundStyle(Color(red: 0.18, green: 0.82, blue: 0.44))

                            Text(name)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, Space.sm)
                        .frame(height: 40)
                        .background(
                            isSelected ? Color.white.opacity(0.08) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    isSelected
                                        ? Color(red: 0.18, green: 0.82, blue: 0.44)
                                        : Color.clear,
                                    lineWidth: 2
                                )
                        )
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Space.xs)
        .padding(.vertical, Space.xs)
        .background(Color(red: 0.08, green: 0.13, blue: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)
    }
}
