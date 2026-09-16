import SwiftUI

struct MovableFloatingCard<Content: View>: View {
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
                    onMove(
                        CGSize(
                            width: value.translation.width / scale,
                            height: value.translation.height / scale
                        )
                    )
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { translation = .zero }
                    withAnimation(
                        .spring(
                            duration: AnviCustomization.Developer.cardDropDuration,
                            bounce: bounciness
                        )
                    ) {
                        isDragging = false
                    }
                    AnviHaptics.selection(enabled: hapticsEnabled)
                }
            )
    }
}

struct HomeOrb: View {
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
                    .fill(
                        RadialGradient(
                            colors: [AnviTheme.sage, AnviTheme.moss],
                            center: .topLeading,
                            startRadius: 5,
                            endRadius: 76
                        )
                    )
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

struct ThatsWordFloatingCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            floatingCardHeader("WORD ISLAND", systemImage: "character.book.closed.fill", color: AnviTheme.clay)
            Text("That’s Word")
                .font(.system(size: 28, weight: .bold, design: .serif))
            Text("Turn the words over.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AnviTheme.mutedInk)
        }
        .foregroundStyle(AnviTheme.ink)
        .padding(20)
        .frame(width: 220, height: 150)
        .anviCard()
    }
}

struct ThoughtsFloatingCard: View {
    let thoughts: [Thought]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "quote.opening").foregroundStyle(AnviTheme.lavender)
                Spacer()
                Text("\(thoughts.count)").font(.caption.bold()).foregroundStyle(AnviTheme.mutedInk)
            }
            Text(thoughts.first?.text ?? "A quiet place for something worth keeping.")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .lineLimit(3)
            Text(thoughts.isEmpty ? "THOUGHT KEEPSAKE" : "LATEST KEEPSAKE")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(AnviTheme.mutedInk)
        }
        .foregroundStyle(AnviTheme.ink)
        .padding(18)
        .frame(width: 190, height: 156)
        .anviCard()
    }
}

struct BreathingFloatingCard: View {
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

struct LeVaulterFloatingCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            floatingCardHeader("WORD VAULT", systemImage: "lock.square.stack.fill", color: AnviTheme.vault)
            Text("Le Vaul-tter")
                .font(.system(size: 25, weight: .bold, design: .serif))
            Text("Gather and arrange your words.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(AnviTheme.mutedInk)
                .lineLimit(2)
        }
        .foregroundStyle(AnviTheme.ink)
        .padding(19)
        .frame(width: 210, height: 146)
        .anviCard()
    }
}

private func floatingCardHeader(_ title: String, systemImage: String, color: Color) -> some View {
    HStack {
        Label(title, systemImage: systemImage)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(color)
        Spacer()
        Image(systemName: "arrow.up.right")
            .font(.caption.bold())
            .foregroundStyle(AnviTheme.mutedInk.opacity(0.6))
    }
}
