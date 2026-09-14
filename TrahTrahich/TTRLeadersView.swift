import SwiftUI

struct TTRLeadersView: View {
    private let records = TTRCityStore.records
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { TTRNavigation.shared.currentScreen = .menu } label: {
                    Label("City", systemImage: "arrow.left").foregroundStyle(TTRTheme.cyan)
                }
                Spacer()
                Text("ROUTE RECORDS").font(.system(size: 13, weight: .heavy, design: .monospaced)).foregroundStyle(.white)
            }.padding(22)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Your rescue log").font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(.white)
                    Text("Completed routes on this device. Your best medals stay on the city map; the latest 50 rescues appear here.")
                        .font(.system(size: 14)).foregroundStyle(.white.opacity(0.65))
                    if records.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "map.fill").font(.system(size: 44)).foregroundStyle(TTRTheme.cyan)
                            Text("Your first district is waiting.").font(.system(size: 19, weight: .heavy)).foregroundStyle(.white)
                            Text("Finish training, restore every hub in Signal Square, and reach its exit to record your first rescue.")
                                .font(.system(size: 14)).foregroundStyle(.white.opacity(0.65)).multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity).padding(26).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
                    }
                    ForEach(records) { record in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(TTRDistrict.all.first { $0.id == record.districtID }?.name ?? "District")
                                    .font(.system(size: 19, weight: .heavy)).foregroundStyle(.white)
                                Spacer()
                                Text(String(repeating: "★", count: record.stars)).foregroundStyle(TTRTheme.yellow)
                            }
                            Text("\(record.coins) road coins · \(record.seconds)s · \(record.firstTry) first-try repairs")
                                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
                            HStack(spacing: 8) {
                                ForEach(Array(record.devices.enumerated()), id: \.offset) { _, raw in
                                    if let kind = TTRMiniGameKind(rawValue: raw) {
                                        Image(kind.imageName).resizable().scaledToFit().frame(width: 34, height: 34)
                                            .accessibilityLabel(kind.title)
                                    }
                                }
                                Spacer()
                                Text(record.date, style: .date).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                            }
                        }.padding(18).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 17))
                    }
                }.padding(22).frame(maxWidth: 700).frame(maxWidth: .infinity)
            }
        }.ttrBackdrop()
    }
}
