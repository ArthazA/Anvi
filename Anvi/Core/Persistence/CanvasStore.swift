import Combine
import Foundation

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
        let savedCards = Self.decode([FloatingCardPlacement].self, from: defaults.data(forKey: cardsKey))
            ?? Self.decode([FloatingCardPlacement].self, from: defaults.data(forKey: legacyCardsKey))
            ?? []
        cards = Self.mergingMissingCards(into: savedCards)
        thoughts = Self.decode([Thought].self, from: defaults.data(forKey: thoughtsKey)) ?? []
        persist(cards, key: cardsKey)
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

    private static func mergingMissingCards(into saved: [FloatingCardPlacement]) -> [FloatingCardPlacement] {
        var result = saved
        for fallback in defaultCards where !result.contains(where: { $0.kind == fallback.kind }) {
            result.append(fallback)
        }
        return result
    }

    private static let defaultCards = [
        FloatingCardPlacement(kind: .thatsWord, position: CanvasPoint(x: -118, y: -176)),
        FloatingCardPlacement(kind: .thoughts, position: CanvasPoint(x: 115, y: 106)),
        FloatingCardPlacement(kind: .breathing, position: CanvasPoint(x: -135, y: 226)),
        FloatingCardPlacement(kind: .leVaulter, position: CanvasPoint(x: 155, y: 300))
    ]
}
