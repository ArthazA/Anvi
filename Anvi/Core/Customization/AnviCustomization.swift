import Combine
import Foundation
import SwiftUI
import UIKit

/// The single source of truth for Anvi's editable visual and interaction values.
/// Personal controls live in `Defaults`; product-level tuning stays in `Developer`.
enum AnviCustomization {
    enum Palette {
        static let ink = Color(red: 0.12, green: 0.13, blue: 0.12)
        static let mutedInk = Color(red: 0.38, green: 0.39, blue: 0.36)
        static let canvas = Color(red: 0.95, green: 0.94, blue: 0.89)
        static let paper = Color(red: 0.99, green: 0.98, blue: 0.94)
        static let sage = Color(red: 0.57, green: 0.65, blue: 0.51)
        static let moss = Color(red: 0.25, green: 0.34, blue: 0.25)
        static let clay = Color(red: 0.78, green: 0.48, blue: 0.34)
        static let sun = Color(red: 0.93, green: 0.72, blue: 0.35)
        static let lavender = Color(red: 0.63, green: 0.57, blue: 0.72)
        static let dot = Color(red: 0.32, green: 0.39, blue: 0.29)
        static let vault = Color(red: 0.34, green: 0.29, blue: 0.43)
    }

    enum Developer {
        // Canvas
        static let defaultZoom: CGFloat = 0.88
        static let minimumZoom: CGFloat = 0.46
        static let maximumZoom: CGFloat = 1.85
        static let oneFingerPanMinimumDistance: CGFloat = 3
        static let panStopVelocity: CGFloat = 9
        static let dotSpacing: CGFloat = 34
        static let dotRadius: CGFloat = 1.35
        static let dotOpacity = 0.23

        // Floating cards
        static let cardDragMinimumDistance: CGFloat = 5
        static let cardLiftScale: CGFloat = 1.018
        static let cardDropDuration = 0.22

        // Anvi Mode
        static let anviButtonDiameter: CGFloat = 62
        static let anviButtonLeadingPadding: CGFloat = 18
        static let anviButtonBottomPadding: CGFloat = 14
        static let anviCancelDistance: CGFloat = 88
        static let anviCancelHorizontalTolerance: CGFloat = 54
        static let anviSliderHeight: CGFloat = 210
        static let anviSliderTrailingPadding: CGFloat = 20

        // That's Word
        static let wordQueueCount = 72
        static let wordVisibleSlots = 6
        static let wordBufferSlots = 2
        static let wordCardHeight: CGFloat = 94
        static let wordGridSpacing: CGFloat = 11
        static let knobDetentDegrees: CGFloat = 40
        static let knobDiameter: CGFloat = 108
        static let knobStopVelocity: CGFloat = 7
        static let knobMaximumVelocity: CGFloat = 840
        static let wordTrayCapacity = 2
        static let wordTrayCommitDistance: CGFloat = 108
        static let highlightedWordSlot = 4 // bottom-center in the serpentine path

        // Le Vaul-tter
        static let vaultWordCardWidth: CGFloat = 126
        static let vaultCategoryCornerRadius: CGFloat = 28

        // Motion
        static let canvasResetDuration = 0.42
        static let wordSnapDuration = 0.28
        static let minimumFrameDuration = 1.0 / 120.0
        static let maximumFrameDuration = 1.0 / 30.0
    }

    enum Defaults {
        static let panSensitivity = 1.0
        static let zoomSensitivity = 1.0
        static let bounciness = 0.12
        static let glide = 0.64
        static let hapticsEnabled = true
        static let gestureHintsEnabled = true
    }

    static func dampingFraction(for bounciness: Double) -> Double {
        // Deliberately nonlinear so the setting is visibly different across its range.
        0.98 - pow(min(max(bounciness, 0), 1), 0.72) * 0.48
    }

    static func velocityRetention(for glide: Double) -> CGFloat {
        // Per-frame retention at 60 Hz: short and controlled at 0, long glide at 1.
        CGFloat(0.88 + min(max(glide, 0), 1) * 0.115)
    }
}

typealias AnviTheme = AnviCustomization.Palette

extension View {
    func anviCard(cornerRadius: CGFloat = 30) -> some View {
        self
            .background(
                AnviTheme.paper.opacity(0.96),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.78), lineWidth: 1)
            }
            .shadow(color: AnviTheme.ink.opacity(0.08), radius: 20, y: 10)
    }
}

@MainActor
final class AnviPreferences: ObservableObject {
    @Published var panSensitivity: Double { didSet { save(panSensitivity, Keys.panSensitivity) } }
    @Published var zoomSensitivity: Double { didSet { save(zoomSensitivity, Keys.zoomSensitivity) } }
    @Published var bounciness: Double { didSet { save(bounciness, Keys.bounciness) } }
    @Published var glide: Double { didSet { save(glide, Keys.glide) } }
    @Published var hapticsEnabled: Bool { didSet { save(hapticsEnabled, Keys.hapticsEnabled) } }
    @Published var gestureHintsEnabled: Bool { didSet { save(gestureHintsEnabled, Keys.gestureHintsEnabled) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        panSensitivity = defaults.object(forKey: Keys.panSensitivity) as? Double ?? AnviCustomization.Defaults.panSensitivity
        zoomSensitivity = defaults.object(forKey: Keys.zoomSensitivity) as? Double ?? AnviCustomization.Defaults.zoomSensitivity
        bounciness = defaults.object(forKey: Keys.bounciness) as? Double ?? AnviCustomization.Defaults.bounciness
        glide = defaults.object(forKey: Keys.glide) as? Double ?? AnviCustomization.Defaults.glide
        hapticsEnabled = defaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? AnviCustomization.Defaults.hapticsEnabled
        gestureHintsEnabled = defaults.object(forKey: Keys.gestureHintsEnabled) as? Bool ?? AnviCustomization.Defaults.gestureHintsEnabled
    }

    func restoreDefaults() {
        panSensitivity = AnviCustomization.Defaults.panSensitivity
        zoomSensitivity = AnviCustomization.Defaults.zoomSensitivity
        bounciness = AnviCustomization.Defaults.bounciness
        glide = AnviCustomization.Defaults.glide
        hapticsEnabled = AnviCustomization.Defaults.hapticsEnabled
        gestureHintsEnabled = AnviCustomization.Defaults.gestureHintsEnabled
    }

    private func save(_ value: Any, _ key: String) { defaults.set(value, forKey: key) }

    private enum Keys {
        static let panSensitivity = "anvi.preferences.panSensitivity"
        static let zoomSensitivity = "anvi.preferences.zoomSensitivity"
        static let bounciness = "anvi.preferences.bounciness"
        static let glide = "anvi.preferences.glide"
        static let hapticsEnabled = "anvi.preferences.hapticsEnabled"
        static let gestureHintsEnabled = "anvi.preferences.gestureHintsEnabled"
    }
}

enum AnviHaptics {
    @MainActor
    static func selection(enabled: Bool) {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    @MainActor
    static func softImpact(enabled: Bool, intensity: CGFloat = 0.62) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: intensity)
    }

    @MainActor
    static func success(enabled: Bool) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @MainActor
    static func warning(enabled: Bool) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
