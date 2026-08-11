import SwiftUI

struct TTRLeadersView: View {
    @AppStorage("ttrBestScore") private var bestScore = 0

    private let rivals: [(String, Int)] = [
        ("Milo", 188),
        ("Nia", 171),
        ("Otto", 158),
        ("Zara", 146),
        ("Kira", 131),
        ("Leon", 118),
        ("Vivi", 104),
        ("Rex", 91)
    ]

    private var entries: [(name: String, score: Int, you: Bool)] {
        (rivals.map { (name: $0.0, score: $0.1, you: false) } + [(name: "YOU", score: bestScore, you: true)])
            .sorted {
                if $0.score == $1.score {
                    return $0.you && !$1.you
                }
                return $0.score > $1.score
            }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TTRTopBar(showCoins: true)

                VStack(spacing: 14) {
                    TTRCapsuleTitle(text: "Leaders")
                    TTRPanel {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 8) {
                                ForEach(entries.indices, id: \.self) { index in
                                    row(index: index, entry: entries[index])
                                }
                            }
                        }
                        .frame(width: min(geo.size.width * (geo.size.height > geo.size.width ? 0.78 : 0.42), 370), height: min(geo.size.height * 0.52, 320))
                    }
                }
            }
        }
        .ttrBackdrop()
    }

    private func row(index: Int, entry: (name: String, score: Int, you: Bool)) -> some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(entry.you ? TTRTheme.green : TTRTheme.navy, in: Circle())
            Text(entry.name)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Text("\(entry.score)")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(TTRTheme.yellow)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background(entry.you ? TTRTheme.cyan.opacity(0.22) : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(entry.you ? TTRTheme.yellow : .clear, lineWidth: 2))
    }
}
