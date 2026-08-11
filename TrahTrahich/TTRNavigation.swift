import Foundation

enum TTRScreen {
    case menu
    case game
    case missions
    case guide
    case leaders
    case shop
    case settings
}

final class TTRNavigation: ObservableObject {
    static let shared = TTRNavigation()
    @Published var currentScreen: TTRScreen = .menu

    private init() {}
}
