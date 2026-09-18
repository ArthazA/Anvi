import CoreGraphics
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
    case leVaulter

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

struct CanvasTransform: Equatable {
    var translation: CGSize
    var scale: CGFloat

    static let initial = CanvasTransform(
        translation: .zero,
        scale: AnviCustomization.Developer.defaultZoom
    )
}

enum CanvasGesturePhase {
    case began
    case changed
    case ended
    case cancelled
}

struct CanvasGestureUpdate {
    let translation: CGSize
    let scale: CGFloat
    let focalPoint: CGPoint
    let velocity: CGSize
    let phase: CanvasGesturePhase
}
