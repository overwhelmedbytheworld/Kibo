import Foundation
import SwiftData

/// Sample data for snapshots: APP_SEED=1 with APP_STORE in /tmp fills an empty
/// store with realistic snippets.
@MainActor
enum SeedData {
    static func insertIfRequested(into model: AppModel) {
        guard ProcessInfo.processInfo.environment["APP_SEED"] == "1" else { return }
        guard Store.isOverridden else {
            print("APP_SEED ignored: APP_STORE must be a file in /tmp")
            return
        }
        let context = model.container.mainContext
        guard ((try? context.fetchCount(FetchDescriptor<Snippet>())) ?? 0) == 0 else { return }
        let samples: [(name: String, alias: String, content: String, category: String, isFav: Bool)] = [
            ("Debate Preparation", ":debate:", "You are a debate coach. Help me prepare arguments for and against the following topic. Provide strong points for both sides, anticipate counterarguments, and suggest rhetorical strategies.", "Study", true),
            ("Research Assistant", ":research:", "You are a research assistant. Summarise the key findings, methodology, and conclusions from the following text. Highlight any limitations or biases.", "Research", false),
            ("Email Writer", ":email:", "Write a professional email with the following details. Keep the tone polite and concise. Include a clear subject line suggestion.", "Work", true),
            ("Coding Assistant", ":code:", "You are an expert programmer. Help me write clean, well-documented code for the following task. Explain your approach and any trade-offs.", "Code", false),
            ("Essay Improver", ":essay:", "Review and improve the following essay. Fix grammar, improve clarity, strengthen arguments, and suggest better transitions between paragraphs.", "Writing", false),
            ("Quick Reply", ":reply:", "Write a brief, friendly reply to the following message.", "Work", true),
        ]
        for (index, sample) in samples.enumerated() {
            let snippet = Snippet(
                name: sample.name,
                alias: sample.alias,
                content: sample.content,
                category: sample.category,
                isFavourite: sample.isFav
            )
            snippet.createdAt = Date.now.addingTimeInterval(Double(-index) * 3_600)
            snippet.modifiedAt = snippet.createdAt
            snippet.usageCount = (6 - index) * 7
            snippet.lastUsedAt = Date.now.addingTimeInterval(Double(-index) * 1_800)
            context.insert(snippet)
        }

        // Seed sample clipboard history items styled like Paste card grid
        if ((try? context.fetchCount(FetchDescriptor<ClipboardEntry>())) ?? 0) == 0 {
            let clipboardSamples: [(title: String, content: String, isPinned: Bool)] = [
                ("Niagara Falls Location", "Niagara Falls is located on the Niagara River, spanning the border between Ontario and New York.", true),
                ("Party Membership by Country", "When looking at the percentage of the population, some datasets indicate higher political engagement.", false),
                ("2016 Summer Olympics", "The 2016 Summer Olympics were held in Rio de Janeiro, Brazil, featuring 207 competing teams.", true),
                ("Electro-chemistry Rule", "Electrochemical cell potential is determined by standard reduction potentials at standard state.", false),
                ("Silicon Melting Point", "Silicon has a melting point of 1,414 °C and a boiling point of 3,265 °C.", false),
                ("Graphite Composition", "Graphite consists of stacked graphene layers held together by weak van der Waals forces.", false)
            ]
            for (offset, item) in clipboardSamples.enumerated() {
                let entry = ClipboardEntry(
                    content: item.content,
                    title: item.title,
                    copiedAt: Date.now.addingTimeInterval(Double(-offset) * 900),
                    isPinned: item.isPinned
                )
                context.insert(entry)
            }
        }

        try? context.save()
    }
}
