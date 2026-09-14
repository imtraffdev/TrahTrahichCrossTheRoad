import Foundation

enum TTRScreen {
    case menu, game, missions, guide, leaders, shop, settings
}

final class TTRNavigation: ObservableObject {
    static let shared = TTRNavigation()
    @Published var currentScreen: TTRScreen = .menu
    var district = TTRDistrict.training

    func start(_ selected: TTRDistrict, training: Bool = false) {
        guard training || TTRCityStore.isUnlocked(selected.id) else { return }
        district = training || !TTRCityStore.trainingComplete ? .training : selected
        currentScreen = .game
    }
    private init() {}
}
