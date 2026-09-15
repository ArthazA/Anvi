import SwiftUI
import UIKit

struct DailyWord {
    let word: String
    let pronunciation: String
    let shortDefinition: String
    let reflection: String

    static var today: DailyWord {
        let words = [
            DailyWord(word: "apricity", pronunciation: "uh-PRIS-uh-tee", shortDefinition: "the warmth of sun in winter", reflection: "Notice the small warmth that finds you today."),
            DailyWord(word: "petrichor", pronunciation: "PET-ri-kor", shortDefinition: "the scent after rain", reflection: "What feels newly washed clean?"),
            DailyWord(word: "susurrus", pronunciation: "soo-SUR-us", shortDefinition: "a whispering or rustling sound", reflection: "Listen for the quietest sound around you."),
            DailyWord(word: "liminal", pronunciation: "LIM-uh-nuhl", shortDefinition: "occupying a space between things", reflection: "Let an unfinished moment remain open."),
            DailyWord(word: "verdant", pronunciation: "VUR-dnt", shortDefinition: "green with growing plants", reflection: "Find one living thing and really look at it."),
            DailyWord(word: "solace", pronunciation: "SOL-is", shortDefinition: "comfort found in difficulty", reflection: "Name the place where you soften."),
            DailyWord(word: "mellifluous", pronunciation: "muh-LIF-loo-us", shortDefinition: "pleasantly smooth and musical", reflection: "Choose one sentence worth saying slowly.")
        ]
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        return words[day % words.count]
    }
}

struct WordDetail: View {
    private let word = DailyWord.today

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule().fill(AnviTheme.clay).frame(width: 42, height: 6)
            Text(word.word)
                .font(.system(size: 40, weight: .bold, design: .serif))
                .foregroundStyle(AnviTheme.ink)
            Text(word.pronunciation.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(AnviTheme.clay)
            Text(word.shortDefinition)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(AnviTheme.ink)
            Divider()
            Text(word.reflection)
                .font(.system(size: 16, weight: .medium, design: .serif))
                .italic()
                .foregroundStyle(AnviTheme.mutedInk)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(28)
        .background(AnviTheme.paper)
    }
}

struct ThoughtsDetail: View {
    let thoughts: [Thought]
    let addAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Thought keepsake")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Spacer()
                Button(action: addAction) {
                    Image(systemName: "plus")
                        .font(.headline)
                        .frame(width: 42, height: 42)
                        .foregroundStyle(.white)
                        .background(AnviTheme.moss, in: Circle())
                }
            }

            if thoughts.isEmpty {
                ContentUnavailableView(
                    "Nothing here yet",
                    systemImage: "quote.opening",
                    description: Text("Keep a thought you would like to meet again.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(thoughts) { thought in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(thought.text)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(thought.createdAt, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AnviTheme.mutedInk)
                            }
                            .padding(16)
                            .background(AnviTheme.canvas, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(AnviTheme.paper)
    }
}

struct ThoughtComposer: View {
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keep this thought")
                .font(.system(size: 25, weight: .bold, design: .rounded))
            TextField("What is worth remembering?", text: $text, axis: .vertical)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .lineLimit(3...5)
                .padding(16)
                .background(AnviTheme.canvas, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .focused($isFocused)

            Button {
                onSave(text)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } label: {
                Text("Keep it")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(.white)
                    .background(
                        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? AnviTheme.mutedInk
                            : AnviTheme.moss,
                        in: Capsule()
                    )
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(24)
        .background(AnviTheme.paper)
        .onAppear { isFocused = true }
    }
}

struct BreathingDetail: View {
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(AnviTheme.sun.opacity(0.18 - Double(index) * 0.04), lineWidth: 12)
                        .frame(width: CGFloat(120 + index * 38), height: CGFloat(120 + index * 38))
                }
                Circle()
                    .fill(AnviTheme.sun)
                    .frame(width: 92, height: 92)
                    .scaleEffect(expanded ? 1.35 : 0.72)
            }
            Text(expanded ? "Breathe out" : "Breathe in")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            Text("Follow the shape. Nothing else to do.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(AnviTheme.mutedInk)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AnviTheme.paper)
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                expanded = true
            }
        }
    }
}
