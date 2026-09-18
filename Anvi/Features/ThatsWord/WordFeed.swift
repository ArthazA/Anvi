import Combine
import Foundation

struct WordItem: Identifiable, Hashable {
    let id: UUID
    let text: String

    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}

struct WordPathItem: Identifiable {
    let id: UUID
    let word: WordItem
    let pathPosition: CGFloat
}

@MainActor
final class WordFeed: ObservableObject {
    let words: [WordItem]
    @Published var phase: CGFloat = 0

    init() {
        let selected = Array(Self.pool.shuffled().prefix(AnviCustomization.Developer.wordQueueCount))
        words = selected.map { WordItem(text: $0) }
    }

    func pathItems() -> [WordPathItem] {
        let buffer = AnviCustomization.Developer.wordBufferSlots
        let lowerIndex = Int(floor(-phase)) - buffer
        let count = AnviCustomization.Developer.wordVisibleSlots + buffer * 2 + 2

        return (lowerIndex..<(lowerIndex + count)).map { globalIndex in
            let word = item(atGlobalIndex: globalIndex)
            return WordPathItem(
                id: word.id,
                word: word,
                pathPosition: CGFloat(globalIndex) + phase
            )
        }
    }

    func word(atSlot slot: Int) -> WordItem {
        item(atGlobalIndex: Int(round(CGFloat(slot) - phase)))
    }

    private func item(atGlobalIndex index: Int) -> WordItem {
        let wrappedIndex = ((index % words.count) + words.count) % words.count
        return words[wrappedIndex]
    }

    private static let pool = [
        "afterglow", "alight", "apricity", "becoming", "blithe", "bloom",
        "brio", "cadence", "clarity", "daybreak", "delight", "drift",
        "effervescent", "ember", "ethereal", "flourish", "gather", "glimmer",
        "halcyon", "harmony", "hush", "ineffable", "kinship", "lilt",
        "luminous", "mellifluous", "morrow", "murmur", "nimble", "nurture",
        "petrichor", "poise", "quietude", "radiant", "reverie", "ripple",
        "serendipity", "solace", "sonder", "stillness", "susurrus", "tender",
        "tranquil", "verdant", "wander", "warmth", "whimsy", "wonder",
        "yearn", "zephyr", "zest", "ambient", "belong", "clement",
        "dappled", "eloquence", "feather", "gentle", "haven", "iridescent",
        "lucent", "meadow", "opalescent", "resonance", "savor", "serein",
        "soften", "tintinnabulation", "vellichor", "winsome", "wisteria", "zenith"
    ]
}
