import SwiftUI

enum TTRTheme {
    static let ink = Color(red: 0.02, green: 0.08, blue: 0.18)
    static let navy = Color(red: 0.02, green: 0.20, blue: 0.49)
    static let panel = Color(red: 0.02, green: 0.28, blue: 0.68)
    static let cyan = Color(red: 0.08, green: 0.78, blue: 1.0)
    static let yellow = Color(red: 1.0, green: 0.84, blue: 0.16)
    static let green = Color(red: 0.09, green: 0.78, blue: 0.22)
}

struct TTRBackdrop: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.02, green: 0.08, blue: 0.18), Color(red: 0.02, green: 0.19, blue: 0.42)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                TTRBackdropRoadMarks()
                    .opacity(0.34)
                    .ignoresSafeArea()

                content
            }
        }
    }
}

struct TTRBackdropRoadMarks: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let isLandscape = size.width > size.height
                let laneStep = isLandscape ? max(size.width / 8, 96) : max(size.width / 4, 92)
                let dashLength = isLandscape ? 38.0 : 34.0
                let dashGap = isLandscape ? 54.0 : 46.0
                let lineColor = Color.white.opacity(0.30)

                if isLandscape {
                    var x = -dashLength
                    while x < size.width + dashLength {
                        for row in 1...3 {
                            let y = size.height * CGFloat(row) / 4
                            let rect = CGRect(x: x, y: y, width: dashLength, height: 5)
                            context.fill(Path(roundedRect: rect, cornerRadius: 2.5), with: .color(lineColor))
                        }
                        x += dashLength + dashGap
                    }
                } else {
                    var y = -dashLength
                    while y < size.height + dashLength {
                        var x = laneStep
                        while x < size.width {
                            let rect = CGRect(x: x, y: y, width: 5, height: dashLength)
                            context.fill(Path(roundedRect: rect, cornerRadius: 2.5), with: .color(lineColor))
                            x += laneStep
                        }
                        y += dashLength + dashGap
                    }
                }
            }
        }
    }
}

extension View {
    func ttrBackdrop() -> some View {
        modifier(TTRBackdrop())
    }
}

struct TTRPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(TTRTheme.panel.opacity(0.94))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(TTRTheme.cyan, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.40), radius: 10, x: 0, y: 7)
            )
    }
}

struct TTRCapsuleTitle: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 24, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.70)
            .shadow(color: Color(red: 0.0, green: 0.05, blue: 0.16), radius: 0, x: 2, y: 2)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(TTRTheme.navy)
                    .overlay(Capsule().stroke(TTRTheme.cyan, lineWidth: 2))
                    .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 1).padding(3))
            )
    }
}

struct TTRArcadeButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)
                    .background(.white, in: Circle())

                Text(title.uppercased())
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .shadow(color: .black.opacity(0.80), radius: 0, x: 1.5, y: 1.5)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.85), lineWidth: 2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.white.opacity(0.18))
                            .frame(height: 21),
                        alignment: .top
                    )
                    .shadow(color: .black.opacity(0.32), radius: 4, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
}

struct TTRCoinsPill: View {
    @AppStorage("ttrCoins") private var coins = 0

    var body: some View {
        HStack(spacing: 8) {
            Image(.ttrCoin)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)

            Text("\(coins)")
                .font(.system(size: 23, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .shadow(color: .black.opacity(0.8), radius: 0, x: 1.4, y: 1.4)
        }
        .padding(.leading, 12)
        .padding(.trailing, 18)
        .frame(height: 52)
        .background(
            Capsule()
                .fill(Color(red: 0.05, green: 0.16, blue: 0.34).opacity(0.92))
                .overlay(Capsule().stroke(TTRTheme.yellow, lineWidth: 3))
                .shadow(color: .black.opacity(0.30), radius: 7, x: 0, y: 4)
        )
    }
}

struct TTRBoostIconView: View {
    let kind: TTRBoostIconKind
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)

            switch kind {
            case .barrier:
                Image(.ttrBarrier)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.92, height: size * 0.62)
            case .hydrant:
                Image(.ttrHydrantRed)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.10)
            case .symbol(let name):
                Image(systemName: name)
                    .font(.system(size: size * 0.44, weight: .black))
                    .foregroundStyle(color)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.22), radius: 2, x: 0, y: 2)
    }
}

struct TTRBarrierIcon: View {
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ZStack {
                RoundedRectangle(cornerRadius: height * 0.18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.86, blue: 0.10),
                                Color(red: 1.0, green: 0.61, blue: 0.03)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: height * 0.18)
                            .stroke(Color(red: 0.02, green: 0.12, blue: 0.30), lineWidth: max(2, height * 0.07))
                    )

                HStack(spacing: width * 0.13) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(Color(red: 0.02, green: 0.22, blue: 0.56))
                            .frame(width: width * 0.14, height: height * 1.65)
                            .rotationEffect(.degrees(30))
                    }
                }
                .frame(width: width * 0.86, height: height * 0.68)
                .clipped()

                RoundedRectangle(cornerRadius: height * 0.14)
                    .fill(.white.opacity(0.55))
                    .frame(width: width * 0.82, height: height * 0.15)
                    .offset(y: -height * 0.32)

                HStack {
                    cap
                    Spacer()
                    cap
                }
                .padding(.horizontal, width * 0.07)
                .offset(y: -height * 0.48)

                HStack {
                    foot
                    Spacer()
                    foot
                }
                .padding(.horizontal, width * 0.10)
                .offset(y: height * 0.46)
            }
        }
    }

    private var cap: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(
                LinearGradient(
                    colors: [Color.white, Color(red: 0.66, green: 0.82, blue: 1.0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(red: 0.38, green: 0.54, blue: 0.76), lineWidth: 1))
            .frame(width: 10, height: 8)
    }

    private var foot: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color(red: 0.73, green: 0.83, blue: 0.96))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(red: 0.34, green: 0.46, blue: 0.66), lineWidth: 1))
            .frame(width: 9, height: 9)
    }
}
