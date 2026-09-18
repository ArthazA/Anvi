import Combine
import SwiftUI

enum AnviModeContext: Equatable {
    case canvas
    case thatsWord
    case leVaulter
    case neutral
}

@MainActor
final class AnviModeController: ObservableObject {
    @Published private(set) var context: AnviModeContext = .neutral
    @Published private(set) var isButtonHeld = false
    @Published private(set) var isCancelArmed = false
    @Published private(set) var isSliderPresented = false
    @Published private(set) var isSliderHeld = false
    @Published private(set) var sliderValue: CGFloat = 0

    private var showsSlider = false
    private var onBegin: () -> Void = {}
    private var onCommit: () -> Void = {}
    private var onCancel: () -> Void = {}
    private var onSliderChanged: (CGFloat) -> Void = { _ in }

    func register(
        context: AnviModeContext,
        showsSlider: Bool,
        onBegin: @escaping () -> Void = {},
        onCommit: @escaping () -> Void = {},
        onCancel: @escaping () -> Void = {},
        onSliderChanged: @escaping (CGFloat) -> Void = { _ in }
    ) {
        guard !isButtonHeld else { return }
        self.context = context
        self.showsSlider = showsSlider
        self.onBegin = onBegin
        self.onCommit = onCommit
        self.onCancel = onCancel
        self.onSliderChanged = onSliderChanged
        sliderValue = 0
        isSliderPresented = false
    }

    func beginButtonHold() {
        guard !isButtonHeld else { return }
        isButtonHeld = true
        isCancelArmed = false
        isSliderPresented = showsSlider
        onBegin()
    }

    func updateButtonHold(translation: CGSize) {
        let controls = AnviCustomization.Developer.self
        isCancelArmed = translation.height <= -controls.anviCancelDistance
            && abs(translation.width) <= controls.anviCancelHorizontalTolerance
    }

    func endButtonHold() {
        guard isButtonHeld else { return }
        if isCancelArmed { onCancel() } else { onCommit() }
        isButtonHeld = false
        isCancelArmed = false
        if !isSliderHeld { isSliderPresented = false }
    }

    func beginSliderHold() {
        guard isSliderPresented else { return }
        isSliderHeld = true
    }

    func updateSlider(to value: CGFloat) {
        sliderValue = min(max(value, 0), 1)
        onSliderChanged(sliderValue)
    }

    func endSliderHold() {
        isSliderHeld = false
        if !isButtonHeld { isSliderPresented = false }
    }
}

struct AnviModeOverlay: View {
    @ObservedObject var controller: AnviModeController
    @ObservedObject var preferences: AnviPreferences
    @State private var didBeginCurrentHold = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                anviButton(in: proxy)
                if controller.isSliderPresented {
                    AnviSlider(controller: controller, preferences: preferences)
                        .position(
                            x: proxy.size.width - AnviCustomization.Developer.anviSliderTrailingPadding - 28,
                            y: proxy.size.height - proxy.safeAreaInsets.bottom - 150
                        )
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.2), value: controller.isSliderPresented)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func anviButton(in proxy: GeometryProxy) -> some View {
        let controls = AnviCustomization.Developer.self
        return ZStack {
            if controller.isButtonHeld {
                VStack(spacing: 5) {
                    Image(systemName: controller.isCancelArmed ? "xmark.circle.fill" : "arrow.up.circle")
                        .font(.system(size: 29, weight: .semibold))
                    Text("Cancel")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundStyle(controller.isCancelArmed ? AnviTheme.clay : AnviTheme.mutedInk)
                .offset(y: -controls.anviCancelDistance)
                .transition(.scale.combined(with: .opacity))
            }

            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                Circle()
                    .stroke(controller.isButtonHeld ? AnviTheme.sage : Color.white.opacity(0.8), lineWidth: 2)
                Text("a")
                    .font(.system(size: 29, weight: .semibold, design: .serif))
                    .foregroundStyle(AnviTheme.moss)
            }
            .frame(width: controls.anviButtonDiameter, height: controls.anviButtonDiameter)
            .scaleEffect(controller.isButtonHeld ? 1.08 : 1)
            .shadow(color: AnviTheme.ink.opacity(0.16), radius: 15, y: 7)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        if !didBeginCurrentHold {
                            didBeginCurrentHold = true
                            controller.beginButtonHold()
                            AnviHaptics.softImpact(enabled: preferences.hapticsEnabled)
                        }
                        let armedBefore = controller.isCancelArmed
                        controller.updateButtonHold(translation: value.translation)
                        if armedBefore != controller.isCancelArmed {
                            AnviHaptics.selection(enabled: preferences.hapticsEnabled)
                        }
                    }
                    .onEnded { _ in
                        controller.endButtonHold()
                        didBeginCurrentHold = false
                    }
            )
            .accessibilityLabel("Anvi Mode")
            .accessibilityHint("Hold for this screen's alternate action; slide up to cancel")
        }
        .position(
            x: controls.anviButtonLeadingPadding + controls.anviButtonDiameter / 2,
            y: proxy.size.height - proxy.safeAreaInsets.bottom - controls.anviButtonBottomPadding - controls.anviButtonDiameter / 2
        )
    }
}

private struct AnviSlider: View {
    @ObservedObject var controller: AnviModeController
    @ObservedObject var preferences: AnviPreferences

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chevron.up")
                .font(.caption.bold())
            GeometryReader { proxy in
                ZStack {
                    Capsule().fill(.ultraThinMaterial)
                    Capsule()
                        .fill(AnviTheme.sage.opacity(0.45))
                        .frame(height: max(18, proxy.size.height * controller.sliderValue))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    Circle()
                        .fill(AnviTheme.moss)
                        .frame(width: 34, height: 34)
                        .shadow(color: AnviTheme.ink.opacity(0.2), radius: 8, y: 4)
                        .position(
                            x: proxy.size.width / 2,
                            y: max(17, min(proxy.size.height - 17, proxy.size.height * (1 - controller.sliderValue)))
                        )
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !controller.isSliderHeld {
                                controller.beginSliderHold()
                                AnviHaptics.softImpact(enabled: preferences.hapticsEnabled, intensity: 0.45)
                            }
                            controller.updateSlider(to: 1 - value.location.y / proxy.size.height)
                        }
                        .onEnded { _ in controller.endSliderHold() }
                )
            }
            .frame(width: 52, height: AnviCustomization.Developer.anviSliderHeight)
            Image(systemName: "chevron.down")
                .font(.caption.bold())
        }
        .foregroundStyle(AnviTheme.moss)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Anvi Slider")
        .accessibilityValue("\(Int(controller.sliderValue * 100)) percent")
    }
}
