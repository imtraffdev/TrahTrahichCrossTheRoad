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
                                Button {
                                    TTRNavigation.shared.start(.training, training: true)
                                } label: {
                                    Label("Replay interactive training", systemImage: "graduationcap.fill")
                                        .font(.system(size: 16, weight: .heavy))
                                        .foregroundStyle(TTRTheme.ink).padding(14)
                                        .background(TTRTheme.cyan, in: RoundedRectangle(cornerRadius: 12))
                                }
                                rule("Restore every hub, then reach the EXIT to complete a district. Completing a district unlocks the next one.")
                                rule("Use the arrows to move up or down on a safe hub. Approach a glowing device, then tap USE.")
                                rule("Choose one device per hub. If you miss its challenge, retry or choose the other device.")
                                rule("Signal Hack: repeat five signals in order (three in training). Success freezes the next block for seven seconds.")
                                rule("Pressure Burst: stop the needle in green. A seven-second water corridor clears traffic along your row. Other rows are still dangerous.")
                                rule("Drain Shortcut: find the target pair among nine cards within 15 seconds (25 in training). It takes you to the next hub, leaving road coins behind.")
                                rule("GO moves right across one lane. Read traffic gaps and use your device effect before it expires.")
                                rule("Three medals: finish the district; restore every hub on the first try; reach the road-coin target. Mini-game time and pauses do not count toward your active route time.")
                                rule("Collected road coins give three spendable coins each. Buy optional Barrier Kits and Hydrant Flushes in Gear. Devices at hubs are always free.")
                                rule("Barrier Kit absorbs two hits. Hydrant Flush clears nearby traffic. Neither replaces a hub repair.")
                                rule("Training has practice shields and longer device effects. You can replay it at any time; it does not award coins or medals.")
                                rule("Records are your completed routes, stored locally. Leaving an unfinished route discards its hub progress; collected coins are kept.")
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
