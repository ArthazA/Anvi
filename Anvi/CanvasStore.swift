import CoreGraphics
import Combine
import Foundation

struct CanvasPoint: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

enum IslandKind: String, Codable, CaseIterable, Identifiable {
    case word
    case thoughts
    case breathing

    var id: String { rawValue }
}

struct IslandPlacement: Identifiable, Codable, Equatable {
    var id: IslandKind { kind }
    let kind: IslandKind
    var position: CanvasPoint
}

struct Thought: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let createdAt: Date
}

@MainActor
final class CanvasStore: ObservableObject {
    @Published private(set) var islands: [IslandPlacement]
    @Published private(set) var thoughts: [Thought]

    private let defaults: UserDefaults
    private let islandsKey = "anvi.canvas.islands"
    private let thoughtsKey = "anvi.thoughts"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        islands = Self.decode([IslandPlacement].self, from: defaults.data(forKey: islandsKey))
            ?? Self.defaultIslands
        thoughts = Self.decode([Thought].self, from: defaults.data(forKey: thoughtsKey)) ?? []
    }

    func move(_ kind: IslandKind, by delta: CGSize) {
        guard let index = islands.firstIndex(where: { $0.kind == kind }) else { return }
        islands[index].position.x += delta.width
        islands[index].position.y += delta.height
        persist(islands, key: islandsKey)
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

    private static let defaultIslands = [
        IslandPlacement(kind: .word, position: CanvasPoint(x: -118, y: -176)),
        IslandPlacement(kind: .thoughts, position: CanvasPoint(x: 115, y: 106)),
        IslandPlacement(kind: .breathing, position: CanvasPoint(x: -135, y: 226))
    ]
}
