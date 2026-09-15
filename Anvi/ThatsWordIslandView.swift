import SwiftUI

struct ThatsWordIslandView: View {
    @ObservedObject var preferences: AnviPreferences
    @Environment(\.dismiss) private var dismiss

    @State private var topWords: [WordChoice]
    @State private var bottomWords: [WordChoice]
    @State private var knobRotation: CGFloat = 0
    @State private var residualDegrees: CGFloat = 0
    @State private var previousTouchAngle: CGFloat?
    @State private var isTurning = false
    @State private var lastTurnWasClockwise = true

    init(preferences: AnviPreferences) {
        self.preferences = preferences
        let selection = WordChoice.initialSelection()
        _topWords = State(initialValue: Array(selection.prefix(3)))
        _bottomWords = State(initialValue: Array(selection.suffix(3)))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [AnviTheme.canvas, AnviTheme.paper],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 24)
                    wordGrid
                        .offset(y: -20)
                    Spacer(minLength: 28)
                    RotaryKnob(
                        rotation: knobRotation,
                        isTurning: isTurning,
                        bounciness: preferences.bounciness,
                        onChanged: turnKnob,
                        onEnded: releaseKnob,
                        onAccessibilityTurn: advance
                    )
                    .padding(.bottom, max(20, proxy.safeAreaInsets.bottom + 8))
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Button {
                AnviHaptics.selection(enabled: preferences.hapticsEnabled)
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 46, height: 46)
                    .foregroundStyle(AnviTheme.moss)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Return to canvas")

            VStack(spacing: 3) {
                Text("THAT’S WORD")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(AnviTheme.clay)
                Text("Turn language over")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(AnviTheme.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)

            Color.clear.frame(width: 46, height: 46)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var wordGrid: some View {
        VStack(spacing: AnviCustomization.Developer.wordGridSpacing) {
            wordRow(topWords, offset: rowOffset, isTopRow: true)
            wordRow(bottomWords, offset: -rowOffset, isTopRow: false)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Six suggested words")
    }

    private func wordRow(
        _ words: [WordChoice],
        offset: CGFloat,
        isTopRow: Bool
    ) -> some View {
        let insertionEdge: Edge = (lastTurnWasClockwise == isTopRow) ? .leading : .trailing
        let removalEdge: Edge = insertionEdge == .leading ? .trailing : .leading

        return HStack(spacing: AnviCustomization.Developer.wordGridSpacing) {
            ForEach(words) { choice in
                WordCard(choice: choice)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: insertionEdge).combined(with: .opacity),
                            removal: .move(edge: removalEdge).combined(with: .opacity)
                        )
                    )
            }
        }
        .offset(x: offset)
        .animation(wordSpring, value: words)
    }

    private var rowOffset: CGFloat {
        let progress = residualDegrees / AnviCustomization.Developer.knobDetentDegrees
        return progress * AnviCustomization.Developer.maximumRowDrag
    }

    private var wordSpring: Animation {
        .spring(
            duration: AnviCustomization.Developer.wordSpringDuration,
            bounce: preferences.bounciness
        )
    }

    private func turnKnob(to angle: CGFloat) {
        guard let previousTouchAngle else {
            self.previousTouchAngle = angle
            isTurning = true
            return
        }

        var delta = angle - previousTouchAngle
        if delta > .pi { delta -= .pi * 2 }
        if delta < -.pi { delta += .pi * 2 }

        let degrees = delta * 180 / .pi
        knobRotation += degrees
        residualDegrees += degrees
        self.previousTouchAngle = angle

        let detent = AnviCustomization.Developer.knobDetentDegrees
        while residualDegrees >= detent {
            residualDegrees -= detent
            advance(clockwise: true)
        }
        while residualDegrees <= -detent {
            residualDegrees += detent
            advance(clockwise: false)
        }
    }

    private func releaseKnob() {
        previousTouchAngle = nil
        isTurning = false
        let detent = AnviCustomization.Developer.knobDetentDegrees
        withAnimation(wordSpring) {
            residualDegrees = 0
            knobRotation = (knobRotation / detent).rounded() * detent
        }
    }

    private func advance(clockwise: Bool) {
        let visibleWords = Set((topWords + bottomWords).map(\.text))
        let firstNewWord = WordChoice.random(excluding: visibleWords)
        let secondNewWord = WordChoice.random(excluding: visibleWords.union([firstNewWord.text]))

        withAnimation(wordSpring) {
            lastTurnWasClockwise = clockwise
            if clockwise {
                topWords.insert(firstNewWord, at: 0)
                topWords.removeLast()
                bottomWords.removeFirst()
                bottomWords.append(secondNewWord)
            } else {
                topWords.removeFirst()
                topWords.append(firstNewWord)
                bottomWords.insert(secondNewWord, at: 0)
                bottomWords.removeLast()
            }
        }
        AnviHaptics.selection(enabled: preferences.hapticsEnabled)
    }
}

private struct WordCard: View {
    let choice: WordChoice

    var body: some View {
        Text(choice.text)
            .font(.system(size: 16, weight: .semibold, design: .serif))
            .minimumScaleFactor(0.72)
            .lineLimit(1)
            .foregroundStyle(AnviTheme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: AnviCustomization.Developer.wordCardHeight)
            .background(AnviTheme.paper, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.9), lineWidth: 1)
            }
            .shadow(color: AnviTheme.ink.opacity(0.08), radius: 16, y: 8)
    }
}

private struct RotaryKnob: View {
    let rotation: CGFloat
    let isTurning: Bool
    let bounciness: Double
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void
    let onAccessibilityTurn: (Bool) -> Void

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { proxy in
                let size = proxy.size
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                ZStack {
                    Circle()
                        .fill(AnviTheme.moss.opacity(0.12))
                        .scaleEffect(isTurning ? 1.08 : 0.94)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [AnviTheme.sage, AnviTheme.moss],
                                center: .topLeading,
                                startRadius: 4,
                                endRadius: 70
                            )
                        )
                        .padding(10)
                        .shadow(color: AnviTheme.moss.opacity(0.24), radius: 18, y: 10)

                    ForEach(0..<12) { index in
                        Capsule()
                            .fill(AnviTheme.paper.opacity(index % 3 == 0 ? 0.95 : 0.48))
                            .frame(width: index % 3 == 0 ? 3 : 2, height: index % 3 == 0 ? 11 : 7)
                            .offset(y: -38)
                            .rotationEffect(.degrees(Double(index) * 30))
                    }

                    Capsule()
                        .fill(AnviTheme.paper)
                        .frame(width: 5, height: 18)
                        .offset(y: -27)
                }
                .rotationEffect(.degrees(rotation))
                .animation(.spring(duration: 0.25, bounce: bounciness), value: isTurning)
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            let vector = CGVector(
                                dx: value.location.x - center.x,
                                dy: value.location.y - center.y
                            )
                            guard abs(vector.dx) + abs(vector.dy) > 4 else { return }
                            onChanged(atan2(vector.dy, vector.dx))
                        }
                        .onEnded { _ in onEnded() }
                )
            }
            .frame(
                width: AnviCustomization.Developer.knobDiameter,
                height: AnviCustomization.Developer.knobDiameter
            )

            Text("Turn until it clicks · release to settle")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AnviTheme.mutedInk)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Word selection knob")
        .accessibilityHint("Swipe up or down to rotate through words")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onAccessibilityTurn(true)
            case .decrement: onAccessibilityTurn(false)
            @unknown default: break
            }
        }
    }
}

private struct WordChoice: Identifiable, Equatable {
    let id = UUID()
    let text: String

    static func initialSelection() -> [WordChoice] {
        Array(pool.shuffled().prefix(6)).map(WordChoice.init(text:))
    }

    static func random(excluding excluded: Set<String>) -> WordChoice {
        let available = pool.filter { !excluded.contains($0) }
        return WordChoice(text: available.randomElement() ?? pool.randomElement() ?? "wonder")
    }

    private static let pool = [
        "apricity", "becoming", "brio", "cadence", "clarity", "delight",
        "ember", "flourish", "glimmer", "hush", "kinship", "lilt",
        "mellifluous", "morrow", "nimble", "petrichor", "poise", "reverie",
        "solace", "sonder", "stillness", "susurrus", "tender", "verdant",
        "wander", "warmth", "wonder", "yearn", "zephyr", "zest"
    ]
}
