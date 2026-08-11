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
                    HStack(spacing: 34) {
                        heroColumn(width: min(geo.size.width * 0.36, 470))
                        menuPanel(width: min(geo.size.width * 0.36, 390))
                    }
                    .padding(.horizontal, 18)
                    .padding(.trailing, 128)
                    .zIndex(10)
                } else {
                    VStack(spacing: 12) {
                        heroColumn(width: min(geo.size.width * 0.70, 320))
                            .padding(.top, 76)
                        menuPanel(width: min(geo.size.width * 0.76, 330))
                    }
                    .padding(.horizontal, 18)
                    .zIndex(10)
                }
            }
        }
        .ttrBackdrop()
    }

    private func heroColumn(width: CGFloat) -> some View {
        VStack(spacing: 4) {
            Image(.ttrLogo)
                .resizable()
                .scaledToFit()
                .frame(width: width)
                .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 6)

            TTRRiggedHeroPreview(width: width * 0.62, height: width * 0.70)
                .frame(maxHeight: width * 0.68)
                .shadow(color: .black.opacity(0.32), radius: 9, x: 0, y: 8)
        }
    }

    private func menuPanel(width: CGFloat) -> some View {
        TTRPanel {
            VStack(spacing: 11) {
                TTRArcadeButton(title: "Play", systemImage: "play.fill", color: Color(red: 0.08, green: 0.74, blue: 0.22)) {
                    TTRNavigation.shared.currentScreen = .game
                }
                TTRArcadeButton(title: "Daily Goals", systemImage: "calendar.badge.checkmark", color: Color(red: 0.00, green: 0.65, blue: 0.78)) {
                    TTRNavigation.shared.currentScreen = .missions
                }
                TTRArcadeButton(title: "How To Play", systemImage: "questionmark.circle.fill", color: Color(red: 0.03, green: 0.47, blue: 0.92)) {
                    TTRNavigation.shared.currentScreen = .guide
                }
                TTRArcadeButton(title: "Leaders", systemImage: "trophy.fill", color: Color(red: 0.49, green: 0.30, blue: 0.78)) {
                    TTRNavigation.shared.currentScreen = .leaders
                }
                TTRArcadeButton(title: "Shop", systemImage: "cart.fill", color: Color(red: 0.08, green: 0.54, blue: 0.96)) {
                    TTRNavigation.shared.currentScreen = .shop
                }
                TTRArcadeButton(title: "Settings", systemImage: "slider.horizontal.3", color: Color(red: 0.95, green: 0.55, blue: 0.06)) {
                    TTRNavigation.shared.currentScreen = .settings
                }
            }
            .frame(width: width)
        }
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
