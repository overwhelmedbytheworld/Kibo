import AppKit
import Foundation
import SwiftData

/// Background monitor that polls NSPasteboard.changeCount to record clipboard history.
@MainActor
final class ClipboardMonitor {
    static let shared = ClipboardMonitor()

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var lastCapturedContent: String?
    private weak var model: AppModel?

    private(set) var isMonitoring = false

    private init() {}

    /// Starts monitoring the general pasteboard.
    func start(model: AppModel) {
        self.model = model
        guard !isMonitoring else { return }

        lastChangeCount = NSPasteboard.general.changeCount
        lastCapturedContent = NSPasteboard.general.string(forType: .string)

        // Poll every 0.4s (negligible CPU consumption via integer compare)
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPasteboard()
            }
        }
        isMonitoring = true
    }

    /// Stops monitoring.
    func stop() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
    }

    /// Checks if pasteboard changed, dedupes, and passes to AppModel.
    func checkPasteboard() {
        let pb = NSPasteboard.general
        let currentCount = pb.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        // Do not record internal pasteboard operations from TextInserter
        guard !TextInserter.isInternalPasteInFlight else { return }

        guard let raw = pb.string(forType: .string) else { return }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Ignore consecutive duplicates
        guard raw != lastCapturedContent else { return }
        lastCapturedContent = raw

        model?.recordClipboardCopy(content: raw)
    }
}
