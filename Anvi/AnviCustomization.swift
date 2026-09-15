import Combine
import Foundation
import SwiftUI
import UIKit

/// Anvi's single source of truth for feel and customization.
///
/// `Developer` contains intentional product constants that do not appear in Settings.
/// `AnviPreferences` contains personal controls that can also be changed in the app.
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
    }

    enum Developer {
        // Canvas
        static let defaultZoom: CGFloat = 0.88
        static let minimumZoom: CGFloat = 0.48
        static let maximumZoom: CGFloat = 1.70
        static let canvasDragMinimumDistance: CGFloat = 4
        static let canvasInertia: CGFloat = 0.24
        static let dotSpacing: CGFloat = 34
        static let minimumDotSpacing: CGFloat = 23

        // Floating cards
        static let cardDragMinimumDistance: CGFloat = 6
        static let cardLiftScale: CGFloat = 1.025

        // That's Word island
        static let wordColumns = 3
        static let wordRows = 2
        static let knobDetentDegrees: CGFloat = 42
        static let knobDiameter: CGFloat = 112
        static let maximumRowDrag: CGFloat = 34
        static let wordCardHeight: CGFloat = 104
        static let wordGridSpacing: CGFloat = 12

        // Motion
        static let canvasSpringResponse = 0.46
        static let cardSpringResponse = 0.30
        static let wordSpringDuration = 0.42
    }

    enum Defaults {
        static let panSensitivity = 1.0
        static let zoomSensitivity = 1.0
        static let bounciness = 0.42
        static let hapticsEnabled = true
        static let gestureHintsEnabled = true
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
                    .stroke(Color.white.opacity(0.75), lineWidth: 1)
            }
            .shadow(color: AnviTheme.ink.opacity(0.08), radius: 20, y: 10)
    }
}

@MainActor
final class AnviPreferences: ObservableObject {
    @Published var panSensitivity: Double {
        didSet { defaults.set(panSensitivity, forKey: Keys.panSensitivity) }
    }
    @Published var zoomSensitivity: Double {
        didSet { defaults.set(zoomSensitivity, forKey: Keys.zoomSensitivity) }
    }
    @Published var bounciness: Double {
        didSet { defaults.set(bounciness, forKey: Keys.bounciness) }
    }
    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled) }
    }
    @Published var gestureHintsEnabled: Bool {
        didSet { defaults.set(gestureHintsEnabled, forKey: Keys.gestureHintsEnabled) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        panSensitivity = defaults.object(forKey: Keys.panSensitivity) as? Double
            ?? AnviCustomization.Defaults.panSensitivity
        zoomSensitivity = defaults.object(forKey: Keys.zoomSensitivity) as? Double
            ?? AnviCustomization.Defaults.zoomSensitivity
        bounciness = defaults.object(forKey: Keys.bounciness) as? Double
            ?? AnviCustomization.Defaults.bounciness
        hapticsEnabled = defaults.object(forKey: Keys.hapticsEnabled) as? Bool
            ?? AnviCustomization.Defaults.hapticsEnabled
        gestureHintsEnabled = defaults.object(forKey: Keys.gestureHintsEnabled) as? Bool
            ?? AnviCustomization.Defaults.gestureHintsEnabled
    }

    func restoreDefaults() {
        panSensitivity = AnviCustomization.Defaults.panSensitivity
        zoomSensitivity = AnviCustomization.Defaults.zoomSensitivity
        bounciness = AnviCustomization.Defaults.bounciness
        hapticsEnabled = AnviCustomization.Defaults.hapticsEnabled
        gestureHintsEnabled = AnviCustomization.Defaults.gestureHintsEnabled
    }

    private enum Keys {
        static let panSensitivity = "anvi.preferences.panSensitivity"
        static let zoomSensitivity = "anvi.preferences.zoomSensitivity"
        static let bounciness = "anvi.preferences.bounciness"
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
    static func softImpact(enabled: Bool, intensity: CGFloat = 0.65) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: intensity)
    }

    @MainActor
    static func success(enabled: Bool) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

struct SettingsView: View {
    @ObservedObject var preferences: AnviPreferences
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Canvas feel") {
                    sensitivitySlider(
                        "Panning sensitivity",
                        value: $preferences.panSensitivity,
                        systemImage: "hand.draw"
                    )
                    sensitivitySlider(
                        "Pinch sensitivity",
                        value: $preferences.zoomSensitivity,
                        systemImage: "arrow.up.left.and.arrow.down.right"
                    )
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Bounciness", systemImage: "waveform.path")
                        Slider(value: $preferences.bounciness, in: 0...1)
                            .tint(AnviTheme.moss)
                        Text(preferences.bounciness < 0.3 ? "Settled" : preferences.bounciness > 0.7 ? "Playful" : "Soft")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Feedback") {
                    Toggle(isOn: $preferences.hapticsEnabled) {
                        Label("Haptics", systemImage: "iphone.radiowaves.left.and.right")
                    }
                    .tint(AnviTheme.moss)
                    Toggle(isOn: $preferences.gestureHintsEnabled) {
                        Label("Gesture hints", systemImage: "sparkles")
                    }
                    .tint(AnviTheme.moss)
                }

                Section {
                    Button("Restore personal defaults", role: .destructive) {
                        preferences.restoreDefaults()
                    }
                } footer: {
                    Text("Layout, limits, detents, and motion timing remain developer controls in AnviCustomization.swift.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func sensitivitySlider(
        _ title: String,
        value: Binding<Double>,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Text(value.wrappedValue, format: .number.precision(.fractionLength(1)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0.5...1.5, step: 0.1)
                .tint(AnviTheme.moss)
        }
        .padding(.vertical, 4)
    }
}
