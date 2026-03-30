import AppKit
import Foundation

final class ClipboardMonitor {
    private let pasteboard: NSPasteboard
    private let historyStore: ClipboardHistoryStore
    private let onHistoryChanged: () -> Void
    private var timer: Timer?
    private var lastChangeCount: Int

    init(
        pasteboard: NSPasteboard = .general,
        historyStore: ClipboardHistoryStore,
        onHistoryChanged: @escaping () -> Void
    ) {
        self.pasteboard = pasteboard
        self.historyStore = historyStore
        self.onHistoryChanged = onHistoryChanged
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: true
        ) { [weak self] _ in
            self?.pollPasteboard()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func pollPasteboard() {
        guard pasteboard.changeCount != lastChangeCount else {
            return
        }

        lastChangeCount = pasteboard.changeCount

        guard let copiedText = pasteboard.string(forType: .string) else {
            return
        }

        let beforeCount = historyStore.items.count
        historyStore.add(text: copiedText)
        if historyStore.items.count != beforeCount || historyStore.items.first?.text == copiedText.trimmingCharacters(in: .whitespacesAndNewlines) {
            onHistoryChanged()
        }
    }
}
