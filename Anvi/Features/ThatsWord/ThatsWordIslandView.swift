import SwiftData
import SwiftUI

struct ThatsWordIslandView: View {
    @ObservedObject var preferences: AnviPreferences
    let goBack: () -> Void

    @EnvironmentObject private var anviMode: AnviModeController
    @Environment(\.modelContext) private var modelContext
    @StateObject private var feed = WordFeed()
    @StateObject private var knobMotion = MotionEngine()

    @State private var stagedWords: [WordItem] = []
    @State private var knobRotation: CGFloat = 0
    @State private var previousTouchAngle: CGFloat?
    @State private var previousTouchTime: TimeInterval?
    @State private var angularVelocity: CGFloat = 0
    @State private var trayOffset: CGFloat = 0
    @State private var isDumpingTray = false
    @State private var feedbackMessage: String?

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
                    Spacer(minLength: 22)
                    WordFeedGrid(
                        feed: feed,
                        highlightsBottomCenter: anviMode.context == .thatsWord && anviMode.isButtonHeld,
                        onSelect: stage
                    )
                    .frame(height: 230)

                    wordTray(screenWidth: proxy.size.width)
                        .padding(.top, 13)

                    if let feedbackMessage {
                        Text(feedbackMessage)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(AnviTheme.clay)
                            .transition(.opacity)
                            .padding(.top, 7)
                    }

                    Spacer(minLength: 12)
                    RotaryKnob(
                        rotation: knobRotation,
                        isMoving: previousTouchAngle != nil || knobMotion.isRunning,
                        bounciness: preferences.bounciness,
                        accessibilityWord: feed.word(
                            atSlot: AnviCustomization.Developer.highlightedWordSlot
                        ).text,
                        onChanged: turnKnob,
                        onEnded: releaseKnob,
                        onAccessibilityStep: accessibilityStep
                    )
                    .padding(.bottom, max(18, proxy.safeAreaInsets.bottom + 6))
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            anviMode.register(
                context: .thatsWord,
                showsSlider: false,
                onCommit: stageHighlightedWord
            )
        }
        .onDisappear { knobMotion.stop() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Button {
                AnviHaptics.selection(enabled: preferences.hapticsEnabled)
                goBack()
            } label: {
                Image(systemName: "chevron.left")
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

    private func wordTray(screenWidth: CGFloat) -> some View {
        HStack(spacing: 9) {
            VStack(spacing: 3) {
                Image(systemName: "tray.full.fill")
                Text("VAULT")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(1)
            }
            .foregroundStyle(AnviTheme.vault)
            .frame(width: 45)
            .accessibilityHidden(true)

            ForEach(stagedWords) { word in
                Text(word.text)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
                    .frame(height: 51)
                    .background(AnviTheme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .onTapGesture(count: 2) { removeFromTray(word) }
                    .accessibilityLabel(word.text)
                    .accessibilityHint("Selected for Le Vaul-tter")
                    .accessibilityAction(named: "Remove from tray") { removeFromTray(word) }
            }

            ForEach(stagedWords.count..<AnviCustomization.Developer.wordTrayCapacity, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AnviTheme.vault.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                    .frame(maxWidth: .infinity)
                    .frame(height: 51)
                    .accessibilityHidden(true)
            }

            Image(systemName: "chevron.right.2")
                .font(.caption.bold())
                .foregroundStyle(AnviTheme.vault.opacity(0.7))
                .padding(.horizontal, 5)
                .accessibilityHidden(true)
        }
        .padding(.leading, 9)
        .padding(.vertical, 9)
        .frame(width: min(screenWidth * 0.78, 330), height: 70)
        .background(AnviTheme.vault.opacity(0.11))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 25, bottomLeadingRadius: 25))
        .frame(maxWidth: .infinity, alignment: .trailing)
        .offset(x: trayOffset)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    guard !stagedWords.isEmpty, !isDumpingTray else { return }
                    trayOffset = max(0, value.translation.width)
                }
                .onEnded { value in
                    guard !stagedWords.isEmpty, !isDumpingTray else { return }
                    if value.translation.width >= AnviCustomization.Developer.wordTrayCommitDistance {
                        dumpTray(offscreenDistance: screenWidth + 80)
                    } else {
                        withAnimation(.spring(duration: 0.25, bounce: preferences.bounciness)) {
                            trayOffset = 0
                        }
                    }
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Save tray to Le Vaul-tter") {
            guard !stagedWords.isEmpty else { return }
            dumpTray(offscreenDistance: screenWidth + 80)
        }
    }

    private func turnKnob(to angle: CGFloat) {
        let now = ProcessInfo.processInfo.systemUptime
        guard let previousTouchAngle, let previousTouchTime else {
            knobMotion.stop()
            self.previousTouchAngle = angle
            self.previousTouchTime = now
            angularVelocity = 0
            return
        }

        var delta = angle - previousTouchAngle
        if delta > .pi { delta -= .pi * 2 }
        if delta < -.pi { delta += .pi * 2 }

        let degrees = delta * 180 / .pi
        let elapsed = max(now - previousTouchTime, 1.0 / 240.0)
        let instantaneousVelocity = degrees / elapsed
        angularVelocity = angularVelocity * 0.68 + instantaneousVelocity * 0.32
        applyRotation(degrees)
        self.previousTouchAngle = angle
        self.previousTouchTime = now
    }

    private func releaseKnob() {
        previousTouchAngle = nil
        previousTouchTime = nil
        let maximum = AnviCustomization.Developer.knobMaximumVelocity
        let velocity = min(max(angularVelocity, -maximum), maximum)
        knobMotion.start(
            velocity: CGVector(dx: velocity, dy: 0),
            retention: AnviCustomization.velocityRetention(for: preferences.glide),
            stopSpeed: AnviCustomization.Developer.knobStopVelocity
        ) { delta in
            applyRotation(delta.dx)
        } onFinished: {
            snapToNearestWord()
        }
    }

    private func applyRotation(_ degrees: CGFloat) {
        let previousPhase = feed.phase
        knobRotation += degrees
        feed.phase += degrees / AnviCustomization.Developer.knobDetentDegrees
        let crossedDetents = abs(Int(floor(feed.phase)) - Int(floor(previousPhase)))
        if crossedDetents > 0 {
            for _ in 0..<min(crossedDetents, 4) {
                AnviHaptics.selection(enabled: preferences.hapticsEnabled)
            }
        }
    }

    private func snapToNearestWord() {
        let targetPhase = feed.phase.rounded()
        let delta = targetPhase - feed.phase
        withAnimation(.spring(duration: AnviCustomization.Developer.wordSnapDuration, bounce: preferences.bounciness)) {
            feed.phase = targetPhase
            knobRotation += delta * AnviCustomization.Developer.knobDetentDegrees
        }
    }

    private func accessibilityStep(clockwise: Bool) {
        knobMotion.stop()
        applyRotation((clockwise ? 1 : -1) * AnviCustomization.Developer.knobDetentDegrees)
        snapToNearestWord()
    }

    private func stageHighlightedWord() {
        stage(feed.word(atSlot: AnviCustomization.Developer.highlightedWordSlot))
    }

    private func stage(_ word: WordItem) {
        guard !stagedWords.contains(where: { $0.text == word.text }) else { return }
        guard stagedWords.count < AnviCustomization.Developer.wordTrayCapacity else {
            showFeedback("Tray full — save or remove a word")
            AnviHaptics.warning(enabled: preferences.hapticsEnabled)
            return
        }
        withAnimation(.spring(duration: 0.28, bounce: preferences.bounciness)) {
            stagedWords.append(word)
        }
        AnviHaptics.softImpact(enabled: preferences.hapticsEnabled, intensity: 0.5)
    }

    private func removeFromTray(_ word: WordItem) {
        withAnimation(.easeOut(duration: 0.18)) {
            stagedWords.removeAll(where: { $0.id == word.id })
        }
        AnviHaptics.selection(enabled: preferences.hapticsEnabled)
    }

    private func dumpTray(offscreenDistance: CGFloat) {
        isDumpingTray = true
        let wordsToSave = stagedWords.map(\.text)
        _ = VaultRepository.addWords(wordsToSave, to: modelContext)
        AnviHaptics.success(enabled: preferences.hapticsEnabled)

        withAnimation(.easeIn(duration: 0.24)) { trayOffset = offscreenDistance }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            stagedWords.removeAll()
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { trayOffset = -80 }
            withAnimation(.spring(duration: 0.34, bounce: preferences.bounciness)) { trayOffset = 0 }
            isDumpingTray = false
            showFeedback("Saved to Le Vaul-tter")
        }
    }

    private func showFeedback(_ message: String) {
        withAnimation { feedbackMessage = message }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            if feedbackMessage == message {
                withAnimation { feedbackMessage = nil }
            }
        }
    }
}

private struct WordFeedGrid: View {
    @ObservedObject var feed: WordFeed
    let highlightsBottomCenter: Bool
    let onSelect: (WordItem) -> Void

    var body: some View {
        GeometryReader { proxy in
            let metrics = WordPathMetrics(size: proxy.size)
            ZStack {
                if highlightsBottomCenter {
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .stroke(AnviTheme.clay, lineWidth: 3)
                        .background(AnviTheme.clay.opacity(0.08), in: RoundedRectangle(cornerRadius: 25, style: .continuous))
                        .frame(width: metrics.cardWidth + 8, height: metrics.cardHeight + 8)
                        .position(metrics.point(at: 4))
                        .shadow(color: AnviTheme.clay.opacity(0.24), radius: 12)
                        .transition(.scale.combined(with: .opacity))
                }

                ForEach(feed.pathItems()) { pathItem in
                    let point = metrics.point(at: pathItem.pathPosition)
                    FeedWordCard(word: pathItem.word, onSelect: onSelect)
                        .frame(width: metrics.cardWidth, height: metrics.cardHeight)
                        .position(point)
                        .opacity(metrics.opacity(at: pathItem.pathPosition))
                        .zIndex(metrics.zIndex(at: pathItem.pathPosition))
                }
            }
            .clipped()
            .animation(.easeOut(duration: 0.18), value: highlightsBottomCenter)
        }
    }
}

private struct WordPathMetrics {
    let size: CGSize
    let spacing = AnviCustomization.Developer.wordGridSpacing
    let cardHeight = AnviCustomization.Developer.wordCardHeight

    var cardWidth: CGFloat { (size.width - 36 - spacing * 2) / 3 }
    private var topY: CGFloat { cardHeight / 2 + 5 }
    private var bottomY: CGFloat { topY + cardHeight + spacing }
    private var leftX: CGFloat { 18 + cardWidth / 2 }
    private var centerX: CGFloat { leftX + cardWidth + spacing }
    private var rightX: CGFloat { centerX + cardWidth + spacing }

    func point(at pathPosition: CGFloat) -> CGPoint {
        switch pathPosition {
        case ..<0:
            return CGPoint(x: leftX + pathPosition * (cardWidth + spacing), y: topY)
        case 0..<1:
            return CGPoint(x: interpolate(leftX, centerX, pathPosition), y: topY)
        case 1..<2:
            return CGPoint(x: interpolate(centerX, rightX, pathPosition - 1), y: topY)
        case 2..<3:
            let progress = smooth(pathPosition - 2)
            return CGPoint(
                x: rightX + sin(progress * .pi) * 8,
                y: interpolate(topY, bottomY, progress)
            )
        case 3..<4:
            return CGPoint(x: interpolate(rightX, centerX, pathPosition - 3), y: bottomY)
        case 4..<5:
            return CGPoint(x: interpolate(centerX, leftX, pathPosition - 4), y: bottomY)
        default:
            return CGPoint(x: leftX - (pathPosition - 5) * (cardWidth + spacing), y: bottomY)
        }
    }

    func opacity(at position: CGFloat) -> Double {
        if position < -0.8 || position > 5.8 { return 0 }
        if position < 0 { return Double((position + 0.8) / 0.8) }
        if position > 5 { return Double((5.8 - position) / 0.8) }
        return 1
    }

    func zIndex(at position: CGFloat) -> Double {
        position >= 2 && position <= 3 ? 2 : 1
    }

    private func interpolate(_ from: CGFloat, _ to: CGFloat, _ progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }

    private func smooth(_ value: CGFloat) -> CGFloat {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }
}

private struct FeedWordCard: View {
    let word: WordItem
    let onSelect: (WordItem) -> Void

    var body: some View {
        Button { onSelect(word) } label: {
            Text(word.text)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .minimumScaleFactor(0.68)
                .lineLimit(1)
                .foregroundStyle(AnviTheme.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AnviTheme.paper, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .stroke(Color.white.opacity(0.9), lineWidth: 1)
                }
                .shadow(color: AnviTheme.ink.opacity(0.08), radius: 14, y: 7)
                .contentShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Adds this word to the two-slot tray")
            .simultaneousGesture(
                DragGesture(minimumDistance: 14)
                    .onEnded { value in
                        if value.translation.height > 34 { onSelect(word) }
                    }
            )
    }
}

private struct RotaryKnob: View {
    let rotation: CGFloat
    let isMoving: Bool
    let bounciness: Double
    let accessibilityWord: String
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void
    let onAccessibilityStep: (Bool) -> Void

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                ZStack {
                    Circle()
                        .fill(AnviTheme.moss.opacity(0.12))
                        .scaleEffect(isMoving ? 1.07 : 0.95)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [AnviTheme.sage, AnviTheme.moss],
                                center: .topLeading,
                                startRadius: 4,
                                endRadius: 70
                            )
                        )
                        .padding(9)
                        .shadow(color: AnviTheme.moss.opacity(0.24), radius: 18, y: 10)

                    ForEach(0..<12) { index in
                        Capsule()
                            .fill(AnviTheme.paper.opacity(index % 3 == 0 ? 0.95 : 0.48))
                            .frame(width: index % 3 == 0 ? 3 : 2, height: index % 3 == 0 ? 11 : 7)
                            .offset(y: -37)
                            .rotationEffect(.degrees(Double(index) * 30))
                    }
                    Capsule().fill(AnviTheme.paper).frame(width: 5, height: 18).offset(y: -26)
                }
                .rotationEffect(.degrees(rotation))
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let vector = CGVector(dx: value.location.x - center.x, dy: value.location.y - center.y)
                            guard abs(vector.dx) + abs(vector.dy) > 4 else { return }
                            onChanged(atan2(vector.dy, vector.dx))
                        }
                        .onEnded { _ in onEnded() }
                )
            }
            .frame(width: AnviCustomization.Developer.knobDiameter, height: AnviCustomization.Developer.knobDiameter)
            Text("Turn · release with momentum")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(AnviTheme.mutedInk)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityRepresentation {
            Stepper(
                "Word feed knob",
                value: Binding(
                    get: { 0 },
                    set: { onAccessibilityStep($0 > 0) }
                ),
                in: -1...1
            )
            .accessibilityValue(accessibilityWord)
            .accessibilityHint("Adjust to rotate through words")
        }
    }
}
