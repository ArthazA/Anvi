import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: AnviPreferences
    let goBack: () -> Void
    @EnvironmentObject private var anviMode: AnviModeController

    var body: some View {
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
                amountSlider(
                    "Bounciness",
                    value: $preferences.bounciness,
                    systemImage: "waveform.path",
                    lowLabel: "Settled",
                    highLabel: "Playful"
                )
                amountSlider(
                    "Glide",
                    value: $preferences.glide,
                    systemImage: "wind",
                    lowLabel: "Short",
                    highLabel: "Long"
                )
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
                Text("Gesture thresholds, momentum limits, visual values, and motion timing remain developer controls in AnviCustomization.swift.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: goBack) { Label("Back", systemImage: "chevron.left") }
            }
        }
        .onAppear {
            anviMode.register(context: .neutral, showsSlider: false)
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
            Slider(value: value, in: 0.5...1.5, step: 0.1).tint(AnviTheme.moss)
        }
        .padding(.vertical, 4)
    }

    private func amountSlider(
        _ title: String,
        value: Binding<Double>,
        systemImage: String,
        lowLabel: String,
        highLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
            Slider(value: value, in: 0...1).tint(AnviTheme.moss)
            HStack {
                Text(lowLabel)
                Spacer()
                Text(highLabel)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
