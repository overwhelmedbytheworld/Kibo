import Foundation

/// Thread-safe usage tracker for emoji frequency ranking in ⌘⇧K and the inline suggestion bar.
public final class EmojiUsageTracker: @unchecked Sendable {
    public static let shared = EmojiUsageTracker()

    private let lock = NSLock()
    private let key = "kibo.emoji.usage.counts"
    private var counts: [String: Int] = [:]

    private init() {
        if let saved = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] {
            self.counts = saved
        }
    }

    public func recordUsage(emoji: String) {
        lock.lock()
        defer { lock.unlock() }
        counts[emoji, default: 0] += 1
        UserDefaults.standard.set(counts, forKey: key)
    }

    public func getCounts() -> [String: Int] {
        lock.lock()
        defer { lock.unlock() }
        return counts
    }

    public func usageCount(for emoji: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return counts[emoji] ?? 0
    }

    /// Returns the top most used emojis, falling back to popular essentials if history is empty.
    public func topEmojis(limit: Int = 12) -> [EmojiItem] {
        lock.lock()
        let currentCounts = counts
        lock.unlock()

        let sorted = EmojiCatalog.all.sorted { item1, item2 in
            let c1 = currentCounts[item1.emoji] ?? 0
            let c2 = currentCounts[item2.emoji] ?? 0
            if c1 != c2 { return c1 > c2 }
            return false
        }
        return Array(sorted.prefix(limit))
    }
}
