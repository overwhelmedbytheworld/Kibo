import Foundation

/// Fast search and ranking for snippets. Pure logic target without SwiftUI.
public enum SnippetSearch {
    /// Ranks a snippet against a search query.
    /// Returns a non-nil integer score if there is a match, higher score means better relevance.
    public static func matchScore(
        name: String,
        alias: String,
        category: String,
        content: String,
        query: String
    ) -> Int? {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return 0 }

        let n = name.lowercased()
        let a = alias.lowercased()
        let c = category.lowercased()
        let body = content.lowercased()

        // 1. Exact alias match (e.g. searching ":email:" or "email")
        if a == q || a == ":\(q):" {
            return 1000
        }

        // 2. Exact name match
        if n == q {
            return 900
        }

        // 3. Alias prefix match (e.g. typing ":em" or "em")
        if a.hasPrefix(q) || (a.hasPrefix(":") && a.dropFirst().hasPrefix(q)) {
            return 800
        }

        // 4. Name prefix match
        if n.hasPrefix(q) {
            return 700
        }

        // 5. Word boundary match in name (e.g. "prep" matches "Debate Prep")
        let nameWords = n.split(whereSeparator: \.isWhitespace)
        if nameWords.contains(where: { $0.hasPrefix(q) }) {
            return 600
        }

        // 6. Alias contains query
        if a.contains(q) {
            return 500
        }

        // 7. Category match
        if !c.isEmpty && (c == q || c.hasPrefix(q)) {
            return 400
        }

        // 8. Name contains query
        if n.contains(q) {
            return 300
        }

        // 9. Content contains query
        if body.contains(q) {
            return 100
        }

        return nil
    }

    /// Filters and sorts a sequence of items using matchScore.
    public static func filter<T>(
        items: [T],
        query: String,
        categoryFilter: String? = nil,
        extract: (T) -> (name: String, alias: String, category: String, content: String)
    ) -> [T] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        let trimmedCat = categoryFilter?.trimmingCharacters(in: .whitespaces)

        return items.compactMap { item -> (T, Int)? in
            let fields = extract(item)

            // Category filter if active
            if let cat = trimmedCat, !cat.isEmpty {
                guard fields.category.localizedCaseInsensitiveCompare(cat) == .orderedSame else {
                    return nil
                }
            }

            // Text search
            if trimmedQuery.isEmpty {
                return (item, 0)
            }

            guard let score = matchScore(
                name: fields.name,
                alias: fields.alias,
                category: fields.category,
                content: fields.content,
                query: trimmedQuery
            ) else {
                return nil
            }

            return (item, score)
        }
        .sorted { $0.1 > $1.1 }
        .map(\.0)
    }
}
