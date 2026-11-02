import Foundation
import SwiftData

/// A captured item from the system pasteboard.
@Model
final class ClipboardEntry {
    var content: String
    var copiedAt: Date = Date.now
    var isPinned: Bool = false
    var charCount: Int = 0
    var wordCount: Int = 0
    var uid: UUID = UUID()

    init(
        content: String,
        copiedAt: Date = .now,
        isPinned: Bool = false
    ) {
        self.content = content
        self.copiedAt = copiedAt
        self.isPinned = isPinned
        self.charCount = content.count
        self.wordCount = content.split(whereSeparator: \.isWhitespace).count
    }
}
