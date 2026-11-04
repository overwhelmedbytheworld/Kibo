import Foundation

/// Thread-safe usage tracker for emoji frequency ranking in ⌘⇧K and the inline suggestion bar.
public final class EmojiUsageTracker: @unchecked Sendable {
    public static let shared = EmojiUsageTracker()

    private let lock = NSLock()
    private let key = "kibo.emoji.usage.counts"
    private let favoritesKey = "kibo.emoji.favorites"
    private let hiddenKey = "kibo.emoji.hidden"
    private var counts: [String: Int] = [:]
    private var favorites: Set<String> = []
    private var hidden: Set<String> = []

    private init() {
        if let saved = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] {
            self.counts = saved
        }
        if let favs = UserDefaults.standard.array(forKey: favoritesKey) as? [String] {
            self.favorites = Set(favs)
        }
        if let hid = UserDefaults.standard.array(forKey: hiddenKey) as? [String] {
            self.hidden = Set(hid)
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

    /// Resets ranking count for a single emoji or clears all ranking history if emoji is nil.
    public func resetRanking(for emoji: String? = nil) {
        lock.lock()
        defer { lock.unlock() }
        if let emoji {
            counts.removeValue(forKey: emoji)
        } else {
            counts.removeAll()
        }
        UserDefaults.standard.set(counts, forKey: key)
    }

    public func isFavorite(_ emoji: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return favorites.contains(emoji)
    }

    @discardableResult
    public func toggleFavorite(_ emoji: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let isFav: Bool
        if favorites.contains(emoji) {
            favorites.remove(emoji)
            isFav = false
        } else {
            favorites.insert(emoji)
            isFav = true
        }
        UserDefaults.standard.set(Array(favorites), forKey: favoritesKey)
        return isFav
    }

    public func getFavorites() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return favorites
    }

    public func isHidden(_ emoji: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return hidden.contains(emoji)
    }

    @discardableResult
    public func toggleHidden(_ emoji: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let isHid: Bool
        if hidden.contains(emoji) {
            hidden.remove(emoji)
            isHid = false
        } else {
            hidden.insert(emoji)
            isHid = true
        }
        UserDefaults.standard.set(Array(hidden), forKey: hiddenKey)
        return isHid
    }

    public func getHidden() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return hidden
    }

    /// Returns the top most used emojis, falling back to popular essentials if history is empty.
    public func topEmojis(limit: Int = 12) -> [EmojiItem] {
        lock.lock()
        let currentCounts = counts
        let favs = favorites
        let hid = hidden
        lock.unlock()

        let valid = EmojiCatalog.all.filter { !hid.contains($0.emoji) }
        let sorted = valid.sorted { item1, item2 in
            let f1 = favs.contains(item1.emoji)
            let f2 = favs.contains(item2.emoji)
            if f1 != f2 { return f1 }
            let c1 = currentCounts[item1.emoji] ?? 0
            let c2 = currentCounts[item2.emoji] ?? 0
            if c1 != c2 { return c1 > c2 }
            return false
        }
        return Array(sorted.prefix(limit))
    }
}
