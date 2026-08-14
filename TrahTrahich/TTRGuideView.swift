import SwiftUI

struct TTRGuideView: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                TTRTopBar(showCoins: false)

                VStack(spacing: 14) {
                    TTRCapsuleTitle(text: "How To Play")
                    TTRPanel {
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 12) {
                                rule("Press GO to dash one lane forward.")
                                rule("Use the up and down arrows to line up with safe gaps and coins.")
                                rule("After clean crossings, mini-games can open as bonus street events.")
                                rule("Signal Hack asks you to repeat three lights, then freezes traffic.")
                                rule("Pressure Burst asks you to stop the needle in green, then flushes cars away.")
                                rule("Drain Shortcut asks you to match a glowing exit, then jumps ahead.")
                                rule("Barrier Kit blocks cars above and below Trah for two impacts.")
                                rule("Hydrant Flush drops a red hydrant and sprays nearby traffic away.")
                                rule("Daily Goals and road styles add extra coin targets between runs.")
                                rule("Every run updates your local best distance.")
                            }
                        }
                        .frame(width: min(geo.size.width * (geo.size.height > geo.size.width ? 0.82 : 0.52), 460), height: min(geo.size.height * 0.62, 420), alignment: .leading)
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
