import Foundation
import SwiftData

@Model
final class WordEntry {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var normalizedText: String
    var text: String
    var createdAt: Date
    var trayOrder: Int
    var category: WordCategory?

    init(text: String, trayOrder: Int, createdAt: Date = .now) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        id = UUID()
        normalizedText = cleaned.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        self.text = cleaned
        self.createdAt = createdAt
        self.trayOrder = trayOrder
    }
}

@Model
final class WordCategory {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var normalizedName: String
    var name: String
    var createdAt: Date
    var sortOrder: Int
    @Relationship(deleteRule: .nullify, inverse: \WordEntry.category)
    var words: [WordEntry]

    init(name: String, sortOrder: Int, createdAt: Date = .now) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        id = UUID()
        normalizedName = cleaned.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        self.name = cleaned
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        words = []
    }
}
