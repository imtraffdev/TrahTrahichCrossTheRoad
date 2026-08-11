import SwiftUI

struct TTRGuideView: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                TTRTopBar(showCoins: false)

                VStack(spacing: 14) {
                    TTRCapsuleTitle(text: "How To Play")
                    TTRPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            rule("Press GO to dash one lane forward.")
                            rule("Use the up and down arrows to change lanes.")
                            rule("Read the vertical traffic before moving.")
                            rule("Line up with glowing road coins to collect them.")
                            rule("Shop boosts can block traffic or flush cars away.")
                            rule("Road styles change the whole run after activation.")
                            rule("Blue manholes add road detail; only cars are dangerous.")
                            rule("Daily Goals refresh locally and reward extra coins.")
                            rule("Cross the full road to earn a clean bonus.")
                            rule("Every run updates your local best distance.")
                        }
                        .frame(width: min(geo.size.width * (geo.size.height > geo.size.width ? 0.78 : 0.45), 390), alignment: .leading)
                    }
                }
            }
        }
        .ttrBackdrop()
    }

    private func rule(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 21, weight: .black))
                .foregroundStyle(TTRTheme.yellow)
            Text(text)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct TTRTopBar: View {
    let showCoins: Bool

    var body: some View {
        VStack {
            HStack {
                Button {
                    TTRNavigation.shared.currentScreen = .menu
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(TTRTheme.ink)
                        .frame(width: 48, height: 48)
                        .background(TTRTheme.yellow, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.92), lineWidth: 2))
                        .shadow(color: .black.opacity(0.28), radius: 5, x: 0, y: 4)
                }
                .buttonStyle(.plain)

                Spacer()

                if showCoins {
                    TTRCoinsPill()
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)

            Spacer()
        }
    }
}
