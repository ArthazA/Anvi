import SwiftUI

struct ContentView: View {
    @StateObject private var store = CanvasStore()

    var body: some View {
        AnviCanvasView(store: store)
            .preferredColorScheme(.light)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView() }
}
