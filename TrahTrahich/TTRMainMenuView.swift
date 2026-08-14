import SpriteKit
import SwiftUI

struct TTRMainMenuView: View {
    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height

            ZStack {
                VStack {
                    HStack {
                        Spacer()
                        TTRCoinsPill()
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, isLandscape ? 20 : 14)
                    Spacer()
                }
                .zIndex(30)

                if isLandscape {
                    HStack(spacing: 26) {
                        heroColumn(width: min(geo.size.width * 0.33, 430), compact: false)
                        commandDeck(width: min(geo.size.width * 0.45, 560), isLandscape: true)
                    }
                    .padding(.horizontal, 18)
                    .padding(.trailing, 92)
                    .zIndex(10)
                } else {
                    VStack(spacing: 12) {
                        heroColumn(width: min(geo.size.width * 0.68, 310), compact: true)
                            .padding(.top, 70)
                        commandDeck(width: min(geo.size.width * 0.86, 360), isLandscape: false)
                    }
                    .padding(.horizontal, 18)
                    .zIndex(10)
                }
            }
        }
        .ttrBackdrop()
    }

    private func heroColumn(width: CGFloat, compact: Bool) -> some View {
        VStack(spacing: 4) {
            Image(.ttrLogo)
                .resizable()
                .scaledToFit()
                .frame(width: width)
                .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 6)

            TTRRiggedHeroPreview(width: width * (compact ? 0.50 : 0.58), height: width * (compact ? 0.48 : 0.64))
                .frame(maxHeight: width * (compact ? 0.48 : 0.64))
                .shadow(color: .black.opacity(0.32), radius: 9, x: 0, y: 8)

            if !compact {
                HStack(spacing: 8) {
                    ForEach(TTRMiniGameKind.allCases, id: \.self) { kind in
                        Image(kind.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                            .padding(6)
                            .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(TTRTheme.cyan.opacity(0.34), lineWidth: 1.5))
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private func commandDeck(width: CGFloat, isLandscape: Bool) -> some View {
        TTRPanel {
            VStack(spacing: isLandscape ? 13 : 10) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("STREET CONTROL")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(TTRTheme.yellow)
                            .lineLimit(1)
                        Text("Cross lanes, trigger mini-games, spend boosts.")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                    }
                    Spacer(minLength: 0)
                }

                Button {
                    TTRNavigation.shared.currentScreen = .game
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(TTRTheme.green)
                            .frame(width: 48, height: 48)
                            .background(.white, in: Circle())
                        Text("START RUN")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)
                            .shadow(color: .black.opacity(0.74), radius: 0, x: 1.7, y: 1.7)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: isLandscape ? 72 : 64)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(TTRTheme.green)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.86), lineWidth: 2.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.white.opacity(0.18))
                                    .frame(height: 24),
                                alignment: .top
                            )
                            .shadow(color: .black.opacity(0.36), radius: 6, x: 0, y: 5)
                    )
                }
                .buttonStyle(.plain)

                HStack(spacing: 9) {
                    ForEach(TTRMiniGameKind.allCases, id: \.self) { kind in
                        featureCard(kind)
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: isLandscape ? 5 : 3), spacing: 9) {
                    quickButton("Goals", "checklist.checked", Color(red: 0.00, green: 0.65, blue: 0.78), .missions)
                    quickButton("Shop", "cart.fill", Color(red: 0.08, green: 0.54, blue: 0.96), .shop)
                    quickButton("Rules", "questionmark.circle.fill", Color(red: 0.03, green: 0.47, blue: 0.92), .guide)
                    quickButton("Leaders", "trophy.fill", Color(red: 0.49, green: 0.30, blue: 0.78), .leaders)
                    quickButton("Tuning", "slider.horizontal.3", Color(red: 0.95, green: 0.55, blue: 0.06), .settings)
                }
            }
            .frame(width: width)
        }
    }

    private func featureCard(_ kind: TTRMiniGameKind) -> some View {
        VStack(spacing: 5) {
            Image(kind.imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 46)
            Text(kind.title.uppercased())
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            Text(kind.rewardText)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.66))
                .lineLimit(1)
                .minimumScaleFactor(0.60)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 92)
        .padding(.horizontal, 6)
        .background(Color(red: 0.01, green: 0.16, blue: 0.42).opacity(0.82), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(TTRTheme.cyan.opacity(0.42), lineWidth: 1.5))
    }

    private func quickButton(_ title: String, _ systemImage: String, _ color: Color, _ screen: TTRScreen) -> some View {
        Button {
            TTRNavigation.shared.currentScreen = screen
        } label: {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(color, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.58), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.22), radius: 3, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

struct TTRRiggedHeroPreview: View {
    let width: CGFloat
    let height: CGFloat
    @State private var scene = TTRHeroPreviewScene()

    var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency, .ignoresSiblingOrder])
            .frame(width: width, height: height)
            .onAppear {
                scene.configure(size: CGSize(width: width, height: height))
            }
            .onChange(of: width) { newWidth in
                scene.configure(size: CGSize(width: newWidth, height: height))
            }
            .onChange(of: height) { newHeight in
                scene.configure(size: CGSize(width: width, height: newHeight))
            }
    }
}
