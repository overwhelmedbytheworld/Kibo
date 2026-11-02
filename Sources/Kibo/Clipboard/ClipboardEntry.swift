import AppKit
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

    /// Generated card title for the grid (e.g. first line or headline).
    var title: String = ""

    /// Optional raw image data (PNG/TIFF) for visual clippings.
    @Attribute(.externalStorage)
    var imageData: Data?

    init(
        content: String,
        imageData: Data? = nil,
        title: String = "",
        copiedAt: Date = .now,
        isPinned: Bool = false
    ) {
        self.content = content
        self.imageData = imageData
        self.copiedAt = copiedAt
        self.isPinned = isPinned
        self.charCount = content.count
        self.wordCount = content.split(whereSeparator: \.isWhitespace).count

        if !title.isEmpty {
            self.title = title
        } else if !content.isEmpty {
            let firstLine = content.split(separator: "\n").first.map(String.init) ?? "Clipping"
            let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
            self.title = trimmed.count > 36 ? String(trimmed.prefix(36)) + "…" : trimmed
        } else if imageData != nil {
            self.title = "Image Clipping"
        } else {
            self.title = "Clipping"
        }
    }
}
