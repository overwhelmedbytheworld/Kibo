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
        let samples: [(String, String, String, Bool)] = [
            ("Debate Preparation", ":debate:", "You are a debate coach. Help me prepare arguments for and against the following topic. Provide strong points for both sides, anticipate counterarguments, and suggest rhetorical strategies.", true),
            ("Research Assistant", ":research:", "You are a research assistant. Summarise the key findings, methodology, and conclusions from the following text. Highlight any limitations or biases.", false),
            ("Email Writer", ":email:", "Write a professional email with the following details. Keep the tone polite and concise. Include a clear subject line suggestion.", true),
            ("Coding Assistant", ":code:", "You are an expert programmer. Help me write clean, well-documented code for the following task. Explain your approach and any trade-offs.", false),
            ("Essay Improver", ":essay:", "Review and improve the following essay. Fix grammar, improve clarity, strengthen arguments, and suggest better transitions between paragraphs.", false),
            ("Quick Reply", ":reply:", "Write a brief, friendly reply to the following message.", true),
        ]
        for (index, sample) in samples.enumerated() {
            let snippet = Snippet(name: sample.0, alias: sample.1, content: sample.2)
            snippet.isFavourite = sample.3
            snippet.createdAt = Date.now.addingTimeInterval(Double(-index) * 3_600)
            snippet.modifiedAt = snippet.createdAt
            context.insert(snippet)
        }
        try? context.save()
    }
}
