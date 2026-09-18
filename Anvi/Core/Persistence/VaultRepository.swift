import Foundation
import SwiftData

@MainActor
enum VaultRepository {
    @discardableResult
    static func addWords(_ texts: [String], to context: ModelContext) -> [WordEntry] {
        let existing = (try? context.fetch(FetchDescriptor<WordEntry>())) ?? []
        var normalizedWords = Dictionary(uniqueKeysWithValues: existing.map { ($0.normalizedText, $0) })
        var nextOrder = (existing.map(\.trayOrder).max() ?? -1) + 1
        var result: [WordEntry] = []

        for text in texts {
            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { continue }
            let normalized = normalize(cleaned)
            if let word = normalizedWords[normalized] {
                result.append(word)
                continue
            }

            let word = WordEntry(text: cleaned, trayOrder: nextOrder)
            nextOrder += 1
            context.insert(word)
            normalizedWords[normalized] = word
            result.append(word)
        }

        try? context.save()
        return result
    }

    @discardableResult
    static func createCategory(named name: String, in context: ModelContext) -> WordCategory? {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        let categories = (try? context.fetch(FetchDescriptor<WordCategory>())) ?? []
        let normalized = normalize(cleaned)
        guard !categories.contains(where: { $0.normalizedName == normalized }) else { return nil }

        let category = WordCategory(
            name: cleaned,
            sortOrder: (categories.map(\.sortOrder).max() ?? -1) + 1
        )
        context.insert(category)
        try? context.save()
        return category
    }

    static func assign(_ word: WordEntry, to category: WordCategory, in context: ModelContext) {
        guard word.category?.id != category.id else { return }
        word.category = category
        try? context.save()
    }

    static func delete(_ category: WordCategory, from context: ModelContext) {
        for word in category.words { word.category = nil }
        context.delete(category)
        try? context.save()
    }

    static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
