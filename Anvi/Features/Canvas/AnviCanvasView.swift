import SwiftUI

struct AnviCanvasView: View {
    @ObservedObject var store: CanvasStore
    @ObservedObject var preferences: AnviPreferences
    let openRoute: (AppRoute) -> Void

    @EnvironmentObject private var anviMode: AnviModeController
    @StateObject private var panMotion = MotionEngine()
    @State private var transform = CanvasTransform.initial
    @State private var selectedCard: FloatingCardKind?
    @State private var isComposingThought = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AnviTheme.canvas.ignoresSafeArea()
                CanvasDotField(transform: transform)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                CanvasGestureBridge(
                    onPan: handlePan,
                    onPinch: { handlePinch($0, canvasSize: proxy.size) }
                )
                .ignoresSafeArea()

                canvasContent(in: proxy.size)
                chrome
            }
            .sheet(item: $selectedCard) { kind in
                cardDetail(kind)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(34)
            }
            .sheet(isPresented: $isComposingThought) {
                ThoughtComposer(hapticsEnabled: preferences.hapticsEnabled) { store.addThought($0) }
                    .presentationDetents([.height(300)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(34)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            anviMode.register(context: .canvas, showsSlider: true)
        }
        .onDisappear { panMotion.stop() }
    }

    private func canvasContent(in size: CGSize) -> some View {
        ZStack {
            HomeOrb(action: resetView)
                .position(screenPosition(for: .zero, in: size))
                .scaleEffect(transform.scale)

            ForEach(store.cards) { card in
                MovableFloatingCard(
                    scale: transform.scale,
                    hapticsEnabled: preferences.hapticsEnabled,
                    bounciness: preferences.bounciness
                ) { delta in
                    store.move(card.kind, by: delta)
                } content: {
                    floatingCard(for: card.kind)
                        .onTapGesture { open(card.kind) }
                }
                .position(screenPosition(for: card.position.cgPoint, in: size))
            }
        }
    }

    private var chrome: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AnviTheme.mutedInk)
                    Text("Your little world")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(AnviTheme.ink)
                }
                Spacer()
                HStack(spacing: 10) {
                    circleButton(systemImage: "gearshape.fill", label: "Settings") {
                        openRoute(.settings)
                    }
                    circleButton(systemImage: "scope", label: "Center canvas", action: resetView)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)

            Spacer()

            HStack(spacing: 10) {
                if preferences.gestureHintsEnabled {
                    Label("Pan, pinch, or do both", systemImage: "hand.draw.fill")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(AnviTheme.mutedInk)
                }
                Spacer()
                Button {
                    AnviHaptics.selection(enabled: preferences.hapticsEnabled)
                    isComposingThought = true
                } label: {
                    Label("Keep a thought", systemImage: "plus")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                        .background(AnviTheme.moss, in: Capsule())
                }
            }
            .padding(.leading, 96)
            .padding(.trailing, 18)
            .padding(.bottom, 14)
        }
    }

    private func circleButton(
        systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            AnviHaptics.selection(enabled: preferences.hapticsEnabled)
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 46, height: 46)
                .foregroundStyle(AnviTheme.moss)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private func floatingCard(for kind: FloatingCardKind) -> some View {
        switch kind {
        case .thatsWord: ThatsWordFloatingCard()
        case .thoughts: ThoughtsFloatingCard(thoughts: store.thoughts)
        case .breathing: BreathingFloatingCard()
        case .leVaulter: LeVaulterFloatingCard()
        }
    }

    @ViewBuilder
    private func cardDetail(_ kind: FloatingCardKind) -> some View {
        switch kind {
        case .thoughts:
            ThoughtsDetail(thoughts: store.thoughts) {
                selectedCard = nil
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    isComposingThought = true
                }
            }
        case .breathing:
            BreathingDetail()
        case .thatsWord, .leVaulter:
            EmptyView()
        }
    }

    private func open(_ kind: FloatingCardKind) {
        AnviHaptics.selection(enabled: preferences.hapticsEnabled)
        switch kind {
        case .thatsWord: openRoute(.thatsWord)
        case .leVaulter: openRoute(.leVaulter)
        case .thoughts, .breathing: selectedCard = kind
        }
    }

    private func screenPosition(for point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width / 2 + transform.translation.width + point.x * transform.scale,
            y: size.height / 2 + transform.translation.height + point.y * transform.scale
        )
    }

    private func handlePan(_ update: CanvasGestureUpdate) {
        switch update.phase {
        case .began:
            panMotion.stop()
        case .changed:
            let sensitivity = CGFloat(preferences.panSensitivity)
            transform.translation.width += update.translation.width * sensitivity
            transform.translation.height += update.translation.height * sensitivity
        case .ended:
            startPanMomentum(with: update.velocity)
        case .cancelled:
            break
        }
    }

    private func handlePinch(_ update: CanvasGestureUpdate, canvasSize: CGSize) {
        switch update.phase {
        case .began:
            panMotion.stop()
        case .changed:
            let sensitivity = CGFloat(preferences.zoomSensitivity)
            let adjustedScale = 1 + (update.scale - 1) * sensitivity
            let oldScale = transform.scale
            let newScale = min(
                max(oldScale * adjustedScale, AnviCustomization.Developer.minimumZoom),
                AnviCustomization.Developer.maximumZoom
            )
            guard oldScale > 0, newScale != oldScale else { return }

            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let focalVector = CGSize(
                width: update.focalPoint.x - center.x,
                height: update.focalPoint.y - center.y
            )
            let ratio = newScale / oldScale
            transform.translation = CGSize(
                width: focalVector.width - (focalVector.width - transform.translation.width) * ratio,
                height: focalVector.height - (focalVector.height - transform.translation.height) * ratio
            )
            transform.scale = newScale
        case .ended, .cancelled:
            break
        }
    }

    private func startPanMomentum(with velocity: CGSize) {
        let sensitivity = CGFloat(preferences.panSensitivity)
        panMotion.start(
            velocity: CGVector(dx: velocity.width * sensitivity, dy: velocity.height * sensitivity),
            retention: AnviCustomization.velocityRetention(for: preferences.glide),
            stopSpeed: AnviCustomization.Developer.panStopVelocity
        ) { delta in
            transform.translation.width += delta.dx
            transform.translation.height += delta.dy
        }
    }

    private func resetView() {
        panMotion.stop()
        withAnimation(
            .spring(
                duration: AnviCustomization.Developer.canvasResetDuration,
                bounce: preferences.bounciness
            )
        ) {
            transform = .initial
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }
}

private struct CanvasDotField: View {
    let transform: CanvasTransform

    var body: some View {
        Canvas { context, size in
            let spacing = AnviCustomization.Developer.dotSpacing * transform.scale
            let radius = max(0.75, AnviCustomization.Developer.dotRadius * transform.scale)
            let worldOrigin = CGPoint(
                x: size.width / 2 + transform.translation.width,
                y: size.height / 2 + transform.translation.height
            )
            let startX = worldOrigin.x.truncatingRemainder(dividingBy: spacing) - spacing
            let startY = worldOrigin.y.truncatingRemainder(dividingBy: spacing) - spacing

            for x in stride(from: startX, through: size.width + spacing, by: spacing) {
                for y in stride(from: startY, through: size.height + spacing, by: spacing) {
                    let dot = Path(
                        ellipseIn: CGRect(
                            x: x - radius,
                            y: y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                    )
                    context.fill(
                        dot,
                        with: .color(AnviTheme.dot.opacity(AnviCustomization.Developer.dotOpacity))
                    )
                }
            }
        }
    }
}
