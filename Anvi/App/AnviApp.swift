import SwiftData
import SwiftUI

@main
struct AnviApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [WordEntry.self, WordCategory.self])
    }
}
