import CoreGraphics
import Combine
import Foundation

struct CanvasPoint: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

enum FloatingCardKind: String, Codable, CaseIterable, Identifiable {
    case thatsWord = "word"
    case thoughts
    case breathing

    var id: String { rawValue }
}

struct FloatingCardPlacement: Identifiable, Codable, Equatable {
    var id: FloatingCardKind { kind }
    let kind: FloatingCardKind
    var position: CanvasPoint
}

struct Thought: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let createdAt: Date
}

@MainActor
final class CanvasStore: ObservableObject {
    @Published private(set) var cards: [FloatingCardPlacement]
    @Published private(set) var thoughts: [Thought]

    private let defaults: UserDefaults
    private let cardsKey = "anvi.canvas.cards"
    private let legacyCardsKey = "anvi.canvas.islands"
    private let thoughtsKey = "anvi.thoughts"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        cards = Self.decode([FloatingCardPlacement].self, from: defaults.data(forKey: cardsKey))
            ?? Self.decode([FloatingCardPlacement].self, from: defaults.data(forKey: legacyCardsKey))
            ?? Self.defaultCards
        thoughts = Self.decode([Thought].self, from: defaults.data(forKey: thoughtsKey)) ?? []
    }

    func move(_ kind: FloatingCardKind, by delta: CGSize) {
        guard let index = cards.firstIndex(where: { $0.kind == kind }) else { return }
        cards[index].position.x += delta.width
        cards[index].position.y += delta.height
        persist(cards, key: cardsKey)
    }

    func addThought(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        thoughts.insert(Thought(id: UUID(), text: trimmed, createdAt: .now), at: 0)
        persist(thoughts, key: thoughtsKey)
    }

    private func persist<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static let defaultCards = [
        FloatingCardPlacement(kind: .thatsWord, position: CanvasPoint(x: -118, y: -176)),
        FloatingCardPlacement(kind: .thoughts, position: CanvasPoint(x: 115, y: 106)),
        FloatingCardPlacement(kind: .breathing, position: CanvasPoint(x: -135, y: 226))
    ]
}
