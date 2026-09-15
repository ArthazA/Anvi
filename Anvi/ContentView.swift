import SwiftUI

struct ContentView: View {
    @StateObject private var store = CanvasStore()
    @StateObject private var preferences = AnviPreferences()

    var body: some View {
        AnviCanvasView(store: store, preferences: preferences)
            .preferredColorScheme(.light)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView() }
}
