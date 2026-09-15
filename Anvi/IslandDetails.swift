import SwiftUI

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
    let hapticsEnabled: Bool
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
                AnviHaptics.success(enabled: hapticsEnabled)
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
