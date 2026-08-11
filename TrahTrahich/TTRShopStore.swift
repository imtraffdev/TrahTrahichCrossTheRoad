import SwiftUI

enum TTRRoadTheme: String, CaseIterable, Identifiable {
    case midnight
    case meadow
    case sunset

    var id: String { rawValue }

    var title: String {
        switch self {
        case .midnight: "Midnight Run"
        case .meadow: "Meadow Dash"
        case .sunset: "Sunset Street"
        }
    }

    var price: Int {
        switch self {
        case .midnight: 0
        case .meadow: 140
        case .sunset: 190
        }
    }

    var icon: String {
        switch self {
        case .midnight: "moon.stars.fill"
        case .meadow: "leaf.fill"
        case .sunset: "sun.max.fill"
        }
    }

    var accent: Color {
        switch self {
        case .midnight: Color(red: 0.08, green: 0.78, blue: 1.0)
        case .meadow: Color(red: 0.28, green: 0.86, blue: 0.24)
        case .sunset: Color(red: 1.0, green: 0.54, blue: 0.12)
        }
    }

    var defaultsKey: String {
        "ttrThemeUnlocked_\(rawValue)"
    }

    var isUnlocked: Bool {
        self == .midnight || UserDefaults.standard.bool(forKey: defaultsKey)
    }

    static var active: TTRRoadTheme {
        let raw = UserDefaults.standard.string(forKey: "ttrActiveRoadTheme") ?? TTRRoadTheme.midnight.rawValue
        return TTRRoadTheme(rawValue: raw) ?? .midnight
    }
}

enum TTRShopCatalog {
    static let barrierPrice = 65
    static let hydrantPrice = 80

    static func unlock(_ theme: TTRRoadTheme) {
        UserDefaults.standard.set(true, forKey: theme.defaultsKey)
    }

    static func activate(_ theme: TTRRoadTheme) {
        UserDefaults.standard.set(theme.rawValue, forKey: "ttrActiveRoadTheme")
    }
}

enum TTRBoostIconKind {
    case barrier
    case hydrant
    case symbol(String)
}
