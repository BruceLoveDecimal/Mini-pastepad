import Foundation

struct ClipboardItem: Codable, Equatable, Identifiable {
    let id: UUID
    let text: String
    let createdAt: Date
}

final class ClipboardHistoryStore {
    private let storageKey = "clipboard.history.items"
    private let maximumItemCount: Int
    private(set) var items: [ClipboardItem] = []

    init(maximumItemCount: Int = 50) {
        self.maximumItemCount = maximumItemCount
        load()
    }

    func add(text: String) {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            return
        }

        if items.first?.text == normalizedText {
            return
        }

        items.insert(
            ClipboardItem(id: UUID(), text: normalizedText, createdAt: Date()),
            at: 0
        )
        items = Array(items.prefix(maximumItemCount))
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    func removeItem(withID id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }

        do {
            items = try JSONDecoder().decode([ClipboardItem].self, from: data)
        } catch {
            items = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }
}
