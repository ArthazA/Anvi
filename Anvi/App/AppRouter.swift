import Combine
import SwiftUI

enum AppRoute: Hashable {
    case thatsWord
    case leVaulter
    case settings
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var path: [AppRoute] = []

    func open(_ route: AppRoute) { path.append(route) }
    func goBack() { if !path.isEmpty { path.removeLast() } }
}
