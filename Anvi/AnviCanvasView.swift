import SwiftUI
import UIKit

struct AnviCanvasView: View {
    @ObservedObject var store: CanvasStore

    @State private var cameraOffset: CGSize = .zero
    @State private var settledCameraOffset: CGSize = .zero
    @State private var zoom: CGFloat = 0.88
    @State private var settledZoom: CGFloat = 0.88
    @State private var selectedIsland: IslandKind?
    @State private var isComposingThought = false
    @State private var feedbackPulse = 0

    private let minimumZoom: CGFloat = 0.48
    private let maximumZoom: CGFloat = 1.7

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AnviTheme.canvas
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .gesture(panGesture)
                DotField(offset: cameraOffset, zoom: zoom).ignoresSafeArea()
                canvasContent(in: proxy.size)
                chrome
            }
            .simultaneousGesture(zoomGesture)
            .sensoryFeedback(.selection, trigger: feedbackPulse)
            .sheet(item: $selectedIsland) { kind in
                islandDetail(kind)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(34)
            }
            .sheet(isPresented: $isComposingThought) {
                ThoughtComposer { store.addThought($0) }
                    .presentationDetents([.height(300)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(34)
            }
        }
    }

    private func canvasContent(in size: CGSize) -> some View {
        ZStack {
            HomeOrb { resetView() }
                .position(screenPosition(for: .zero, in: size))
                .scaleEffect(zoom)

            ForEach(store.islands) { island in
                MovableIsland(scale: zoom) { delta in
                    store.move(island.kind, by: delta)
                    feedbackPulse += 1
                } content: {
                    islandView(for: island.kind)
                        .onTapGesture {
                            feedbackPulse += 1
                            selectedIsland = island.kind
                        }
                }
                .position(screenPosition(for: island.position.cgPoint, in: size))
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
                Button(action: resetView) {
                    Image(systemName: "scope")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 46, height: 46)
                        .foregroundStyle(AnviTheme.moss)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Center canvas")
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)

            Spacer()

            HStack(spacing: 10) {
                Label(zoomLabel, systemImage: "hand.draw.fill")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AnviTheme.mutedInk)
                Spacer()
                Button {
                    feedbackPulse += 1
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
    private func islandView(for kind: IslandKind) -> some View {
        switch kind {
        case .word: WordIsland()
        case .thoughts: ThoughtsIsland(thoughts: store.thoughts)
        case .breathing: BreathingIsland()
        }
    }

    @ViewBuilder
    private func islandDetail(_ kind: IslandKind) -> some View {
        switch kind {
        case .word:
            WordDetail()
        case .thoughts:
            ThoughtsDetail(thoughts: store.thoughts) {
                selectedIsland = nil
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
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                cameraOffset = CGSize(
                    width: settledCameraOffset.width + value.translation.width,
                    height: settledCameraOffset.height + value.translation.height
                )
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    cameraOffset = CGSize(
                        width: settledCameraOffset.width + value.predictedEndTranslation.width * 0.25 + value.translation.width * 0.75,
                        height: settledCameraOffset.height + value.predictedEndTranslation.height * 0.25 + value.translation.height * 0.75
                    )
                    settledCameraOffset = cameraOffset
                }
                feedbackPulse += 1
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoom = min(max(settledZoom * value.magnification, minimumZoom), maximumZoom)
            }
            .onEnded { _ in
                settledZoom = zoom
                feedbackPulse += 1
            }
    }

    private func resetView() {
        feedbackPulse += 1
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            cameraOffset = .zero
            settledCameraOffset = .zero
            zoom = 0.88
            settledZoom = 0.88
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

    private var zoomLabel: String {
        zoom < 0.7 ? "Pinch in to visit" : "Drag space to wander"
    }
}

private struct DotField: View {
    let offset: CGSize
    let zoom: CGFloat

    var body: some View {
        Canvas { context, size in
            let spacing = max(23, 34 * zoom)
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

private struct MovableIsland<Content: View>: View {
    let scale: CGFloat
    let onMove: (CGSize) -> Void
    @ViewBuilder let content: Content

    @State private var translation: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        content
            .scaleEffect(scale)
            .offset(translation)
            .highPriorityGesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .global)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.65)
                        }
                        translation = value.translation
                    }
                    .onEnded { value in
                        onMove(CGSize(width: value.translation.width / scale, height: value.translation.height / scale))
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
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

private struct WordIsland: View {
    private var word: DailyWord { DailyWord.today }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("TODAY'S WORD", systemImage: "sun.max.fill")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(AnviTheme.clay)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.bold())
                    .foregroundStyle(AnviTheme.mutedInk.opacity(0.6))
            }
            Text(word.word)
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(AnviTheme.ink)
            Text(word.shortDefinition)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AnviTheme.mutedInk)
                .lineLimit(2)
        }
        .padding(20)
        .frame(width: 220, height: 150)
        .anviCard()
    }
}

private struct ThoughtsIsland: View {
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

private struct BreathingIsland: View {
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
