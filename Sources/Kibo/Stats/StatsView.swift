import SwiftData
import SwiftUI
import KiboKit

struct StatsView: View {
    @Environment(AppModel.self) private var model
    @Query private var allSnippets: [Snippet]
    @Query private var allClippings: [ClipboardEntry]

    // Calculations
    private var totalExpansions: Int {
        allSnippets.reduce(0) { $0 + $1.usageCount }
    }

    private var totalKeystrokesSaved: Int {
        allSnippets.reduce(0) { $0 + ($1.usageCount * max(1, $1.content.count)) }
    }

    /// Estimated time saved assuming 200 characters per minute (40 wpm = 0.3s per character).
    private var estimatedTimeSavedString: String {
        let totalSeconds = Double(totalKeystrokesSaved) * 0.3
        if totalSeconds < 60 {
            return "\(Int(totalSeconds))s"
        } else if totalSeconds < 3600 {
            let mins = Int(totalSeconds / 60)
            return "\(mins) min\(mins == 1 ? "" : "s")"
        } else {
            let hours = totalSeconds / 3600
            return String(format: "%.1f hrs", hours)
        }
    }

    private var topSnippets: [Snippet] {
        allSnippets
            .filter { $0.usageCount > 0 }
            .sorted { $0.usageCount > $1.usageCount }
    }

    private var categoryBreakdown: [(category: String, count: Int, expansions: Int)] {
        var dict: [String: (count: Int, expansions: Int)] = [:]
        for s in allSnippets {
            let cat = s.category.isEmpty ? "General" : s.category
            let current = dict[cat] ?? (0, 0)
            dict[cat] = (current.count + 1, current.expansions + s.usageCount)
        }
        return dict.map { ($0.key, $0.value.count, $0.value.expansions) }
            .sorted { $0.expansions > $1.expansions }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                // Header
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Productivity Insights")
                        .font(.largeTitle.weight(.bold))
                    Text("Real-time telemetry on how much time and typing Kibo saves you.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Metric Cards Grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 240), spacing: Space.lg)], spacing: Space.lg) {
                    MetricCard(
                        title: "Time Saved",
                        value: estimatedTimeSavedString,
                        subtitle: "Typing time saved",
                        icon: "clock.arrow.circlepath",
                        tint: .green
                    )

                    MetricCard(
                        title: "Total Expansions",
                        value: "\(totalExpansions)",
                        subtitle: "Prompts & snippets inserted",
                        icon: "flame.fill",
                        tint: .orange
                    )

                    MetricCard(
                        title: "Keystrokes Saved",
                        value: "\(totalKeystrokesSaved)",
                        subtitle: "Keys avoided",
                        icon: "keyboard",
                        tint: .blue
                    )

                    MetricCard(
                        title: "Clippings Stored",
                        value: "\(allClippings.count)",
                        subtitle: "\(allClippings.filter(\.isPinned).count) pinned safe",
                        icon: "doc.on.clipboard",
                        tint: .purple
                    )
                }

                // Top Snippets Leaderboard
                VStack(alignment: .leading, spacing: Space.md) {
                    HStack {
                        Label("Most Used Snippets", systemImage: "trophy.fill")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Spacer()

                        Text("\(allSnippets.count) total snippets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if topSnippets.isEmpty {
                        ContentUnavailableView(
                            "No Snippets Used Yet",
                            systemImage: "flame",
                            description: Text("Type a snippet alias or insert from Kibo to see your usage leaderboard here.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.xl)
                        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                    } else {
                        VStack(spacing: Space.xs) {
                            ForEach(Array(topSnippets.prefix(5).enumerated()), id: \.element.id) { index, snippet in
                                HStack(spacing: Space.md) {
                                    Text("#\(index + 1)")
                                        .font(.subheadline.monospacedDigit().weight(.bold))
                                        .foregroundStyle(index == 0 ? .orange : .secondary)
                                        .frame(width: 28, alignment: .leading)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(snippet.name)
                                            .font(.body.weight(.medium))
                                        if !snippet.alias.isEmpty {
                                            Text(snippet.alias)
                                                .font(.caption.monospaced())
                                                .foregroundStyle(Palette.accentText)
                                        }
                                    }

                                    Spacer()

                                    if !snippet.category.isEmpty {
                                        Text(snippet.category)
                                            .font(.caption2)
                                            .padding(.horizontal, Space.sm)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.12), in: Capsule())
                                    }

                                    HStack(spacing: 2) {
                                        Image(systemName: "flame.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                        Text("\(snippet.usageCount)")
                                            .font(.subheadline.monospacedDigit().weight(.semibold))
                                    }
                                    .frame(width: 48, alignment: .trailing)
                                }
                                .padding(.horizontal, Space.lg)
                                .padding(.vertical, Space.sm)
                                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }

                // Category Distribution
                if !categoryBreakdown.isEmpty {
                    VStack(alignment: .leading, spacing: Space.md) {
                        Label("Category Breakdown", systemImage: "folder.fill")
                            .font(.headline)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: Space.md)], spacing: Space.md) {
                            ForEach(categoryBreakdown, id: \.category) { item in
                                VStack(alignment: .leading, spacing: Space.xs) {
                                    Text(item.category)
                                        .font(.subheadline.weight(.semibold))
                                    HStack {
                                        Text("\(item.count) snippets")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(item.expansions) uses")
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(Palette.accentText)
                                    }
                                }
                                .padding(Space.md)
                                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
            }
            .padding(Space.margin)
        }
        .navigationTitle("Insights")
    }
}

// MARK: - Metric Card

private struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(tint)
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(Space.lg)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
    }
}
