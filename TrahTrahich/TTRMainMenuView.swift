import SpriteKit
import SwiftUI

struct TTRMainMenuView: View {
    @State private var selectedID = TTRCityStore.nextDistrict.id
    private var selected: TTRDistrict { TTRDistrict.all.first { $0.id == selectedID } ?? .all[0] }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .center) {
                        Image(.ttrLogo).resizable().scaledToFit().frame(width: min(geo.size.width * 0.40, 190))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 8) {
                            TTRCoinsPill()
                            Text("\(TTRDistrict.all.filter { TTRCityStore.stars(for: $0.id) > 0 }.count) / 6 DISTRICTS ONLINE")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundStyle(TTRTheme.cyan)
                        }
                    }
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("STREET RESCUE").font(.system(size: 11, weight: .heavy, design: .monospaced)).foregroundStyle(TTRTheme.cyan)
                            Text("Bring the city\nback online.").font(.system(size: 32, weight: .black, design: .rounded)).foregroundStyle(.white)
                            Text("Choose a device. Change the traffic. Reconnect every hub.")
                                .font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer(minLength: 0)
                        TTRRiggedHeroPreview(width: 94, height: 132)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: TTRCityStore.trainingComplete ? "location.fill" : "graduationcap.fill").foregroundStyle(TTRTheme.yellow)
                            Text(TTRCityStore.trainingComplete ? "NEXT DISPATCH · \(selected.name.uppercased())" : "FIRST DISPATCH · TRAINING YARD")
                                .font(.system(size: 12, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        }
                        Text(TTRCityStore.trainingComplete ? selected.detail : "A guided route with real controls, three devices and practice shields. Learn at your own pace.")
                            .font(.system(size: 14)).foregroundStyle(.white.opacity(0.75))
                        Button {
                            TTRNavigation.shared.start(selected)
                        } label: {
                            HStack {
                                Text(TTRCityStore.trainingComplete ? "RESTORE DISTRICT" : "START TRAINING")
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(TTRTheme.ink).padding(18)
                            .background(TTRTheme.cyan, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("city.start")
                    }
                    .padding(18).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
                    HStack {
                        Text("CITY NETWORK").font(.system(size: 12, weight: .heavy, design: .monospaced)).foregroundStyle(.white.opacity(0.65))
                        Spacer()
                        Text("\(TTRDistrict.all.reduce(0) { $0 + TTRCityStore.stars(for: $1.id) }) / 18 ★")
                            .font(.system(size: 12, weight: .heavy)).foregroundStyle(TTRTheme.yellow)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 12)], spacing: 12) {
                        ForEach(TTRDistrict.all) { district in districtCard(district) }
                    }
                    Text("Earn a medal for restoring a district, one for every repair on the first try, and one for its road-coin target.")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.58))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 95), spacing: 10)], spacing: 10) {
                        link("Records", "chart.bar.xaxis", .leaders)
                        link("Gear", "shippingbox.fill", .shop)
                        link("Daily goals", "checklist", .missions)
                        link("Field guide", "book.fill", .guide)
                        link("Settings", "slider.horizontal.3", .settings)
                    }
                }
                .padding(22).frame(maxWidth: 760).frame(maxWidth: .infinity)
            }
        }
        .ttrBackdrop()
    }

    private func districtCard(_ district: TTRDistrict) -> some View {
        let unlocked = TTRCityStore.isUnlocked(district.id)
        let stars = TTRCityStore.stars(for: district.id)
        let selected = selectedID == district.id
        return Button {
            selectedID = district.id
            TTRNavigation.shared.start(district)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(String(format: "%02d", district.id)).font(.system(size: 27, weight: .black, design: .rounded))
                    Spacer()
                    Image(systemName: unlocked ? (stars > 0 ? "checkmark.circle.fill" : "bolt.circle") : "lock.fill")
                }.foregroundStyle(unlocked ? TTRTheme.cyan : .white.opacity(0.4))
                Text(district.name).font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                Text(unlocked ? "\(district.blocks.count) hubs · \(district.coinTarget) road coins" : "Complete district \(district.id - 1)")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Image(systemName: index < stars ? "star.fill" : "star").foregroundStyle(index < stars ? TTRTheme.yellow : .white.opacity(0.25))
                    }
                    Spacer()
                    if selected { Text("NEXT").font(.system(size: 9, weight: .heavy)).foregroundStyle(TTRTheme.cyan) }
                }.font(.system(size: 11))
            }
            .padding(15).frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? TTRTheme.cyan.opacity(0.12) : .white.opacity(0.04), in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(selected ? TTRTheme.cyan : .white.opacity(0.12), lineWidth: 1.5))
        }
        .buttonStyle(.plain).disabled(!unlocked)
        .accessibilityLabel("\(district.name), \(unlocked ? "available" : "locked"), \(stars) medals")
    }

    private func link(_ title: String, _ icon: String, _ screen: TTRScreen) -> some View {
        Button { TTRNavigation.shared.currentScreen = screen } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 19))
                Text(title).font(.system(size: 11, weight: .bold))
            }.foregroundStyle(.white.opacity(0.85)).frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 13))
        }.buttonStyle(.plain)
    }
}

struct TTRRiggedHeroPreview: View {
    let width: CGFloat
    let height: CGFloat
    @State private var scene = TTRHeroPreviewScene()
    var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency, .ignoresSiblingOrder])
            .frame(width: width, height: height)
            .onAppear { scene.configure(size: CGSize(width: width, height: height)) }
            .onChange(of: width) { value in scene.configure(size: CGSize(width: value, height: height)) }
            .onChange(of: height) { value in scene.configure(size: CGSize(width: width, height: value)) }
    }
}
