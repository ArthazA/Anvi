import SwiftUI
import UIKit

struct AnviCanvasView: View {
    @ObservedObject var store: CanvasStore
    @ObservedObject var preferences: AnviPreferences

    @State private var cameraOffset: CGSize = .zero
    @State private var settledCameraOffset: CGSize = .zero
    @State private var zoom: CGFloat = AnviCustomization.Developer.defaultZoom
    @State private var settledZoom: CGFloat = AnviCustomization.Developer.defaultZoom
    @State private var selectedCard: FloatingCardKind?
    @State private var isComposingThought = false
    @State private var isShowingThatsWord = false
    @State private var isShowingSettings = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AnviTheme.canvas
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .gesture(canvasGesture)
                DotField(offset: cameraOffset, zoom: zoom).ignoresSafeArea()
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
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(preferences: preferences)
            }
            .fullScreenCover(isPresented: $isShowingThatsWord) {
                ThatsWordIslandView(preferences: preferences)
            }
        }
    }

    private func canvasContent(in size: CGSize) -> some View {
        ZStack {
            HomeOrb { resetView() }
                .position(screenPosition(for: .zero, in: size))
                .scaleEffect(zoom)

            ForEach(store.cards) { card in
                MovableFloatingCard(
                    scale: zoom,
                    hapticsEnabled: preferences.hapticsEnabled,
                    bounciness: preferences.bounciness
                ) { delta in
                    store.move(card.kind, by: delta)
                    AnviHaptics.selection(enabled: preferences.hapticsEnabled)
                } content: {
                    cardView(for: card.kind)
                        .onTapGesture {
                            AnviHaptics.selection(enabled: preferences.hapticsEnabled)
                            if card.kind == .thatsWord {
                                isShowingThatsWord = true
                            } else {
                                selectedCard = card.kind
                            }
                        }
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
                    Button {
                        AnviHaptics.selection(enabled: preferences.hapticsEnabled)
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 46, height: 46)
                            .foregroundStyle(AnviTheme.moss)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Settings")

                    Button(action: resetView) {
                        Image(systemName: "scope")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 46, height: 46)
                            .foregroundStyle(AnviTheme.moss)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Center canvas")
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)

            Spacer()

            HStack(spacing: 10) {
                if preferences.gestureHintsEnabled {
                    Label(zoomLabel, systemImage: "hand.draw.fill")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
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
                        .padding(.horizontal, 17)
                        .frame(height: 50)
                        .background(AnviTheme.moss, in: Capsule())
                }
                .accessibilityHint("Opens a field to save a thought")
            }
            .padding(.leading, 18)
            .padding(.trailing, 10)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.7), lineWidth: 1))
            .shadow(color: AnviTheme.ink.opacity(0.12), radius: 24, y: 10)
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func cardView(for kind: FloatingCardKind) -> some View {
        switch kind {
        case .thatsWord: ThatsWordFloatingCard()
        case .thoughts: ThoughtsFloatingCard(thoughts: store.thoughts)
        case .breathing: BreathingFloatingCard()
        }
    }

    @ViewBuilder
    private func cardDetail(_ kind: FloatingCardKind) -> some View {
        switch kind {
        case .thatsWord:
            EmptyView()
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
        }
    }

    private func screenPosition(for point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width / 2 + cameraOffset.width + point.x * zoom,
            y: size.height / 2 + cameraOffset.height + point.y * zoom
        )
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: AnviCustomization.Developer.canvasDragMinimumDistance)
            .onChanged { value in
                let sensitivity = CGFloat(preferences.panSensitivity)
                cameraOffset = CGSize(
                    width: settledCameraOffset.width + value.translation.width * sensitivity,
                    height: settledCameraOffset.height + value.translation.height * sensitivity
                )
            }
            .onEnded { value in
                let sensitivity = CGFloat(preferences.panSensitivity)
                let inertia = AnviCustomization.Developer.canvasInertia
                withAnimation(canvasSpring) {
                    cameraOffset = CGSize(
                        width: settledCameraOffset.width + (value.predictedEndTranslation.width * inertia + value.translation.width * (1 - inertia)) * sensitivity,
                        height: settledCameraOffset.height + (value.predictedEndTranslation.height * inertia + value.translation.height * (1 - inertia)) * sensitivity
                    )
                    settledCameraOffset = cameraOffset
                }
                AnviHaptics.selection(enabled: preferences.hapticsEnabled)
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let adjustedMagnification = 1 + (value.magnification - 1) * preferences.zoomSensitivity
                zoom = min(
                    max(settledZoom * adjustedMagnification, AnviCustomization.Developer.minimumZoom),
                    AnviCustomization.Developer.maximumZoom
                )
            }
            .onEnded { _ in
                settledZoom = zoom
                AnviHaptics.selection(enabled: preferences.hapticsEnabled)
            }
    }

    private var canvasGesture: some Gesture {
        panGesture.simultaneously(with: zoomGesture)
    }

    private func resetView() {
        AnviHaptics.selection(enabled: preferences.hapticsEnabled)
        withAnimation(canvasSpring) {
            cameraOffset = .zero
            settledCameraOffset = .zero
            zoom = AnviCustomization.Developer.defaultZoom
            settledZoom = AnviCustomization.Developer.defaultZoom
        }
    }

    private var canvasSpring: Animation {
        .spring(
            response: AnviCustomization.Developer.canvasSpringResponse,
            dampingFraction: max(0.5, 1 - preferences.bounciness * 0.46)
        )
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var zoomLabel: String {
        zoom < 0.7 ? "Pinch in to visit" : "Drag space to wander"
    }
}

private struct DotField: View {
    let offset: CGSize
    let zoom: CGFloat

    var body: some View {
        Canvas { context, size in
            let spacing = max(
                AnviCustomization.Developer.minimumDotSpacing,
                AnviCustomization.Developer.dotSpacing * zoom
            )
            let radius = max(0.7, 1.15 * zoom)
            let startX = offset.width.truncatingRemainder(dividingBy: spacing)
            let startY = offset.height.truncatingRemainder(dividingBy: spacing)

            for x in stride(from: startX, through: size.width, by: spacing) {
                for y in stride(from: startY, through: size.height, by: spacing) {
                    let dot = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                    context.fill(dot, with: .color(AnviTheme.moss.opacity(0.13)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct MovableFloatingCard<Content: View>: View {
    let scale: CGFloat
    let hapticsEnabled: Bool
    let bounciness: Double
    let onMove: (CGSize) -> Void
    @ViewBuilder let content: Content

    @State private var translation: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        content
            .scaleEffect(scale)
            .scaleEffect(isDragging ? AnviCustomization.Developer.cardLiftScale : 1)
            .offset(translation)
            .highPriorityGesture(
                DragGesture(
                    minimumDistance: AnviCustomization.Developer.cardDragMinimumDistance,
                    coordinateSpace: .global
                )
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            AnviHaptics.softImpact(enabled: hapticsEnabled)
                        }
                        translation = value.translation
                    }
                    .onEnded { value in
                        onMove(CGSize(width: value.translation.width / scale, height: value.translation.height / scale))
                        withAnimation(
                            .spring(
                                response: AnviCustomization.Developer.cardSpringResponse,
                                dampingFraction: max(0.5, 1 - bounciness * 0.5)
                            )
                        ) {
                            translation = .zero
                        }
                        isDragging = false
                    }
            )
    }
}

private struct HomeOrb: View {
    let action: () -> Void
    @State private var breathing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(AnviTheme.sage.opacity(0.18))
                    .frame(width: 126, height: 126)
                    .scaleEffect(breathing ? 1.08 : 0.92)
                Circle()
                    .fill(RadialGradient(colors: [AnviTheme.sage, AnviTheme.moss], center: .topLeading, startRadius: 5, endRadius: 76))
                    .frame(width: 92, height: 92)
                    .shadow(color: AnviTheme.moss.opacity(0.25), radius: 22, y: 12)
                Text("a")
                    .font(.system(size: 42, weight: .medium, design: .serif))
                    .foregroundStyle(AnviTheme.paper)
                    .offset(y: -2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Anvi home")
        .accessibilityHint("Centers the canvas")
        .onAppear {
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }
}

private struct ThatsWordFloatingCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("WORD ISLAND", systemImage: "character.book.closed.fill")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(AnviTheme.clay)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.bold())
                    .foregroundStyle(AnviTheme.mutedInk.opacity(0.6))
            }
            Text("That’s Word")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(AnviTheme.ink)
            Text("Turn the words over.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AnviTheme.mutedInk)
                .lineLimit(2)
        }
        .padding(20)
        .frame(width: 220, height: 150)
        .anviCard()
    }
}

private struct ThoughtsFloatingCard: View {
    let thoughts: [Thought]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "quote.opening").foregroundStyle(AnviTheme.lavender)
                Spacer()
                Text("\(thoughts.count)")
                    .font(.caption.bold())
                    .foregroundStyle(AnviTheme.mutedInk)
            }
            Text(thoughts.first?.text ?? "A quiet place for something worth keeping.")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AnviTheme.ink)
                .lineLimit(3)
            Text(thoughts.isEmpty ? "THOUGHT KEEPSAKE" : "LATEST KEEPSAKE")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(AnviTheme.mutedInk)
        }
        .padding(18)
        .frame(width: 190, height: 156)
        .anviCard()
    }
}

private struct BreathingFloatingCard: View {
    @State private var expanding = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AnviTheme.sun.opacity(0.22))
                    .frame(width: 56, height: 56)
                    .scaleEffect(expanding ? 1.08 : 0.82)
                Circle().fill(AnviTheme.sun).frame(width: 28, height: 28)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(expanding ? "Breathe out" : "Breathe in")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("One calm minute")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(AnviTheme.mutedInk)
            }
        }
        .foregroundStyle(AnviTheme.ink)
        .padding(16)
        .frame(width: 190, height: 92)
        .anviCard(cornerRadius: 28)
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                expanding = true
            }
        }
    }
}
