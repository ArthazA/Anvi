import SwiftUI

struct ContentView: View {
    @StateObject private var canvasStore = CanvasStore()
    @StateObject private var preferences = AnviPreferences()
    @StateObject private var router = AppRouter()
    @StateObject private var anviMode = AnviModeController()

    var body: some View {
        ZStack {
            NavigationStack(path: $router.path) {
                AnviCanvasView(
                    store: canvasStore,
                    preferences: preferences,
                    openRoute: router.open
                )
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
            }
            .tint(AnviTheme.moss)

            AnviModeOverlay(controller: anviMode, preferences: preferences)
        }
        .environmentObject(anviMode)
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .thatsWord:
            ThatsWordIslandView(preferences: preferences, goBack: router.goBack)
        case .leVaulter:
            LeVaulterView(preferences: preferences, goBack: router.goBack)
        case .settings:
            SettingsView(preferences: preferences, goBack: router.goBack)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView() }
}
