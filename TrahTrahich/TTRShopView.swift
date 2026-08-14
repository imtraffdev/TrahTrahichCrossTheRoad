import SwiftUI

struct TTRShopView: View {
    @AppStorage("ttrCoins") private var coins = 0
    @AppStorage("ttrBarrierCharges") private var barrierCharges = 0
    @AppStorage("ttrHydrantCharges") private var hydrantCharges = 0
    @AppStorage("ttrActiveRoadTheme") private var activeTheme = TTRRoadTheme.midnight.rawValue
    @State private var feedback = ""

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            ZStack {
                TTRTopBar(showCoins: true)

                VStack(spacing: 12) {
                    TTRCapsuleTitle(text: "Shop")
                    TTRPanel {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                sectionTitle("Boosts")
                                boostRow(
                                    title: "Barrier Kit",
                                    detail: "Drops striped road barriers above and below Trah.",
                                    icon: .barrier,
                                    count: barrierCharges,
                                    price: TTRShopCatalog.barrierPrice,
                                    color: TTRTheme.cyan
                                ) {
                                    buy(price: TTRShopCatalog.barrierPrice) {
                                        barrierCharges += 1
                                    }
                                }

                                boostRow(
                                    title: "Hydrant Flush",
                                    detail: "Pops a red hydrant onto the road and blasts traffic away.",
                                    icon: .hydrant,
                                    count: hydrantCharges,
                                    price: TTRShopCatalog.hydrantPrice,
                                    color: Color(red: 0.95, green: 0.12, blue: 0.08)
                                ) {
                                    buy(price: TTRShopCatalog.hydrantPrice) {
                                        hydrantCharges += 1
                                    }
                                }

                                sectionTitle("Road Styles")
                                ForEach(TTRRoadTheme.allCases) { theme in
                                    themeRow(theme)
                                }

                                if !feedback.isEmpty {
                                    Text(feedback)
                                        .font(.system(size: 14, weight: .black, design: .rounded))
                                        .foregroundStyle(TTRTheme.yellow)
                                        .padding(.top, 2)
                                }
                            }
                        }
                        .frame(
                            width: min(geo.size.width * (isLandscape ? 0.58 : 0.82), isLandscape ? 660 : 390),
                            height: min(geo.size.height * (isLandscape ? 0.66 : 0.64), isLandscape ? 390 : 570)
                        )
                    }
                }
            }
        }
        .ttrBackdrop()
    }

    private func sectionTitle(_ text: String) -> some View {
        HStack {
            Text(text.uppercased())
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
            Spacer()
        }
    }

    private func boostRow(
        title: String,
        detail: String,
        icon: TTRBoostIconKind,
        count: Int,
        price: Int,
        color: Color,
        buyAction: @escaping () -> Void
    ) -> some View {
        shopRow(
            title: title,
            detail: "\(detail) Owned: \(count)",
            icon: icon,
            color: color,
            buttonTitle: "\(price)",
            buttonIcon: "plus.circle.fill",
            action: buyAction
        )
    }

    private func themeRow(_ theme: TTRRoadTheme) -> some View {
        let unlocked = theme.isUnlocked
        let active = activeTheme == theme.rawValue
        return shopRow(
            title: theme.title,
            detail: active ? "Active road and grass palette" : (unlocked ? "Unlocked, tap to activate" : "New procedural road and grass palette"),
            icon: .symbol(theme.icon),
            color: theme.accent,
            buttonTitle: active ? "ON" : (unlocked ? "USE" : "\(theme.price)"),
            buttonIcon: active ? "checkmark.circle.fill" : (unlocked ? "paintbrush.fill" : "lock.open.fill")
        ) {
            if active {
                feedback = "\(theme.title) is already active."
            } else if unlocked {
                activeTheme = theme.rawValue
                TTRShopCatalog.activate(theme)
                feedback = "\(theme.title) activated."
            } else {
                buy(price: theme.price) {
                    TTRShopCatalog.unlock(theme)
                    activeTheme = theme.rawValue
                    TTRShopCatalog.activate(theme)
                }
            }
        }
    }

    private func shopRow(
        title: String,
        detail: String,
        icon: TTRBoostIconKind,
        color: Color,
        buttonTitle: String,
        buttonIcon: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            TTRBoostIconView(kind: icon, color: color, size: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(detail)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: action) {
                HStack(spacing: 5) {
                    Image(systemName: buttonIcon)
                        .font(.system(size: 13, weight: .black))
                    Text(buttonTitle)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(.white)
                .frame(minWidth: 72, minHeight: 38)
                .background(color, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.75), lineWidth: 2))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func buy(price: Int, apply: () -> Void) {
        guard coins >= price else {
            feedback = "Not enough coins."
            return
        }
        coins -= price
        apply()
        feedback = "Purchased."
    }
}
