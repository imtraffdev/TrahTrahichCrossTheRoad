import SwiftUI

enum TTRMiniGameKind: String, CaseIterable {
    case signalHack
    case pressureValve
    case manholeShortcut

    var title: String {
        switch self {
        case .signalHack: "Signal Hack"
        case .pressureValve: "Pressure Burst"
        case .manholeShortcut: "Drain Shortcut"
        }
    }

    var subtitle: String {
        switch self {
        case .signalHack: "Repeat the lights to freeze traffic."
        case .pressureValve: "Stop the needle in the safe zone."
        case .manholeShortcut: "Find the target pair before time runs out."
        }
    }

    var imageName: String {
        switch self {
        case .signalHack: "ttrSignalConsole"
        case .pressureValve: "ttrPressureValve"
        case .manholeShortcut: "ttrPortalManhole"
        }
    }

    var rewardText: String {
        switch self {
        case .signalHack: "Traffic frozen"
        case .pressureValve: "Cars flushed"
        case .manholeShortcut: "Shortcut opened"
        }
    }
}

struct TTRMiniGameRequest: Identifiable {
    let id = UUID()
    let kind: TTRMiniGameKind
}

struct TTRMiniGameOverlay: View {
    let request: TTRMiniGameRequest
    let onComplete: (Bool) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.46)
                    .ignoresSafeArea()

                Group {
                    switch request.kind {
                    case .signalHack:
                        TTRSignalHackMiniGame(onComplete: onComplete)
                    case .pressureValve:
                        TTRPressureValveMiniGame(onComplete: onComplete)
                    case .manholeShortcut:
                        TTRManholeShortcutMiniGame(onComplete: onComplete)
                    }
                }
                .frame(width: min(geo.size.width - 28, geo.size.width > geo.size.height ? 560 : 360))
            }
        }
    }
}

private enum TTRSignalColor: CaseIterable, Equatable {
    case red
    case yellow
    case cyan

    var color: Color {
        switch self {
        case .red: Color(red: 0.96, green: 0.18, blue: 0.12)
        case .yellow: TTRTheme.yellow
        case .cyan: TTRTheme.cyan
        }
    }

    var systemImage: String {
        switch self {
        case .red: "circle.fill"
        case .yellow: "star.fill"
        case .cyan: "drop.fill"
        }
    }
}

private struct TTRSignalHackMiniGame: View {
    let onComplete: (Bool) -> Void

    @State private var sequence: [TTRSignalColor] = []
    @State private var input: [TTRSignalColor] = []
    @State private var activeSignal: TTRSignalColor?
    @State private var isWatching = true
    @State private var status = "Watch the lights"
    @State private var didStart = false

    var body: some View {
        TTRPanel {
            VStack(spacing: 14) {
                miniHeader(kind: .signalHack)

                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.02, green: 0.12, blue: 0.30).opacity(0.84))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(TTRTheme.cyan.opacity(0.46), lineWidth: 2))

                    if let activeSignal {
                        largeSignal(activeSignal)
                            .transition(.scale.combined(with: .opacity))
                    } else if isWatching {
                        Text("GET READY")
                            .font(.system(size: 19, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))
                    } else {
                        HStack(spacing: 8) {
                            ForEach(0..<5, id: \.self) { index in
                                Circle()
                                    .fill(index < input.count ? TTRTheme.green : Color.white.opacity(0.18))
                                    .overlay(Circle().stroke(.white.opacity(0.38), lineWidth: 1.5))
                                    .frame(width: 22, height: 22)
                            }
                        }
                    }
                }
                .frame(height: 104)

                Text(status.uppercased())
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(isWatching ? TTRTheme.yellow : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                HStack(spacing: 11) {
                    ForEach(TTRSignalColor.allCases, id: \.self) { signal in
                        Button {
                            tap(signal)
                        } label: {
                            Image(systemName: signal.systemImage)
                                .font(.system(size: 26, weight: .black))
                                .foregroundStyle(.white)
                                .frame(width: 72, height: 58)
                                .background(signal.color, in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.82), lineWidth: 2))
                                .shadow(color: signal.color.opacity(0.35), radius: 7, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(isWatching)
                        .opacity(isWatching ? 0.45 : 1)
                    }
                }
            }
        }
        .onAppear(perform: startIfNeeded)
    }

    private func miniHeader(kind: TTRMiniGameKind) -> some View {
        HStack(spacing: 12) {
            Image(kind.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 78, height: 78)

            VStack(alignment: .leading, spacing: 4) {
                Text(kind.title.uppercased())
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .shadow(color: .black.opacity(0.8), radius: 0, x: 1.5, y: 1.5)
                Text(kind.subtitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
            }

            Spacer(minLength: 0)
        }
    }

    private func largeSignal(_ signal: TTRSignalColor) -> some View {
        Circle()
            .fill(signal.color)
            .overlay(Circle().stroke(.white.opacity(0.96), lineWidth: 5))
            .overlay(
                Image(systemName: signal.systemImage)
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(.white)
            )
            .frame(width: 76, height: 76)
            .shadow(color: signal.color.opacity(0.50), radius: 12, x: 0, y: 4)
    }

    private func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        sequence = (0..<5).map { _ in TTRSignalColor.allCases.randomElement() ?? .cyan }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 420_000_000)
            for (index, signal) in sequence.enumerated() {
                status = "Watch signal \(index + 1) of \(sequence.count)"
                withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                    activeSignal = signal
                }
                try? await Task.sleep(nanoseconds: 720_000_000)
                withAnimation(.easeOut(duration: 0.16)) {
                    activeSignal = nil
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
            status = "Repeat the pattern"
            isWatching = false
        }
    }

    private func tap(_ signal: TTRSignalColor) {
        guard !isWatching, input.count < sequence.count else { return }
        guard sequence[input.count] == signal else {
            status = "Signal missed"
            completeAfterDelay(false)
            return
        }

        input.append(signal)
        if input.count == sequence.count {
            status = "Traffic frozen"
            completeAfterDelay(true)
        }
    }

    private func completeAfterDelay(_ success: Bool) {
        isWatching = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 680_000_000)
            onComplete(success)
        }
    }
}

private struct TTRPressureValveMiniGame: View {
    let onComplete: (Bool) -> Void

    @State private var startTime = Date()
    @State private var locked = false
    @State private var status = "Tap inside the green zone"

    private let safeRange: ClosedRange<Double> = 0.42...0.70

    var body: some View {
        TTRPanel {
            VStack(spacing: 14) {
                miniHeader(kind: .pressureValve)

                TimelineView(.animation) { timeline in
                    let value = needleValue(at: timeline.date)
                    VStack(spacing: 10) {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: 0.03, green: 0.10, blue: 0.20))
                            GeometryReader { geo in
                                let width = geo.size.width
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(TTRTheme.green.opacity(0.82))
                                    .frame(width: width * (safeRange.upperBound - safeRange.lowerBound), height: geo.size.height)
                                    .offset(x: width * safeRange.lowerBound)
                                Rectangle()
                                    .fill(TTRTheme.yellow)
                                    .frame(width: 7, height: geo.size.height + 10)
                                    .offset(x: max(0, min(width - 7, width * value)))
                                    .shadow(color: TTRTheme.yellow.opacity(0.55), radius: 5)
                            }
                            .padding(5)
                        }
                        .frame(height: 46)

                        Text(status.uppercased())
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.86))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }

                Button {
                    lockPressure()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                        Text("LOCK PRESSURE")
                    }
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(TTRTheme.green, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.82), lineWidth: 2))
                }
                .buttonStyle(.plain)
                .disabled(locked)
            }
        }
        .onAppear {
            startTime = Date()
        }
    }

    private func miniHeader(kind: TTRMiniGameKind) -> some View {
        HStack(spacing: 12) {
            Image(kind.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 82, height: 82)

            VStack(alignment: .leading, spacing: 4) {
                Text(kind.title.uppercased())
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .shadow(color: .black.opacity(0.8), radius: 0, x: 1.5, y: 1.5)
                Text(kind.subtitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
            }

            Spacer(minLength: 0)
        }
    }

    private func needleValue(at date: Date) -> Double {
        let elapsed = date.timeIntervalSince(startTime)
        return 0.5 + 0.5 * sin(elapsed * .pi * 2 / 3.35 - .pi / 2)
    }

    private func lockPressure() {
        guard !locked else { return }
        locked = true
        let success = safeRange.contains(needleValue(at: Date()))
        status = success ? "Hydrant burst ready" : "Pressure slipped"
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 680_000_000)
            onComplete(success)
        }
    }
}

private struct TTRManholeShortcutMiniGame: View {
    let onComplete: (Bool) -> Void

    @State private var targetSymbol = "bolt.fill"
    @State private var cards: [TTRDrainMemoryCard] = []
    @State private var selected: [UUID] = []
    @State private var solved: Set<UUID> = []
    @State private var locked = false
    @State private var resolving = false
    @State private var remainingSeconds = 10
    @State private var status = "Find the target pair"
    @State private var didStart = false

    private let symbols = ["sparkles", "bolt.fill", "drop.fill", "flame.fill", "shield.fill", "star.fill"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        TTRPanel {
            VStack(spacing: 12) {
                miniHeader(kind: .manholeShortcut)

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TARGET PAIR")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.66))
                        Image(systemName: targetSymbol)
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(TTRTheme.yellow)
                            .frame(width: 46, height: 36)
                            .background(TTRTheme.navy, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(TTRTheme.cyan.opacity(0.82), lineWidth: 2))
                    }

                    Spacer()

                    Text("\(remainingSeconds)s")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(remainingSeconds <= 3 ? Color(red: 1.0, green: 0.34, blue: 0.22) : TTRTheme.yellow)
                        .monospacedDigit()
                        .frame(width: 66, height: 44)
                        .background(Color(red: 0.02, green: 0.12, blue: 0.30), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.30), lineWidth: 1.5))
                }

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(cards) { card in
                        Button {
                            flip(card)
                        } label: {
                            drainCard(card)
                        }
                        .buttonStyle(.plain)
                        .disabled(locked || resolving || selected.contains(card.id) || solved.contains(card.id))
                    }
                }

                Text(status.uppercased())
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .onAppear(perform: startIfNeeded)
    }

    private func drainCard(_ card: TTRDrainMemoryCard) -> some View {
        let isOpen = selected.contains(card.id) || solved.contains(card.id)
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(isOpen ? Color(red: 0.02, green: 0.19, blue: 0.48) : Color(red: 0.01, green: 0.10, blue: 0.25))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(isOpen ? TTRTheme.cyan : .white.opacity(0.26), lineWidth: 2))

            if isOpen {
                VStack(spacing: 0) {
                    Image(.ttrPortalManhole)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                    Image(systemName: card.symbol)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(card.symbol == targetSymbol ? TTRTheme.yellow : .white.opacity(0.88))
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Image(.ttrPortalManhole)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .opacity(0.56)
            }
        }
        .frame(height: 74)
        .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isOpen)
    }

    private func miniHeader(kind: TTRMiniGameKind) -> some View {
        HStack(spacing: 12) {
            Image(kind.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 82, height: 82)

            VStack(alignment: .leading, spacing: 4) {
                Text(kind.title.uppercased())
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .shadow(color: .black.opacity(0.8), radius: 0, x: 1.5, y: 1.5)
                Text(kind.subtitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
            }

            Spacer(minLength: 0)
        }
    }

    private func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        targetSymbol = symbols.randomElement() ?? "bolt.fill"
        cards = makeDeck(target: targetSymbol)

        Task { @MainActor in
            while remainingSeconds > 0, !locked {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !locked else { return }
                remainingSeconds -= 1
            }
            guard !locked else { return }
            status = "Time up"
            finish(false)
        }
    }

    private func makeDeck(target: String) -> [TTRDrainMemoryCard] {
        var pool = [target, target]
        let distractors = symbols.filter { $0 != target }
        while pool.count < 9 {
            pool.append(distractors.randomElement() ?? "sparkles")
        }
        return pool.shuffled().map { TTRDrainMemoryCard(symbol: $0) }
    }

    private func flip(_ card: TTRDrainMemoryCard) {
        guard !locked, !resolving, !selected.contains(card.id), !solved.contains(card.id), selected.count < 2 else { return }
        selected.append(card.id)
        guard selected.count == 2 else {
            status = "Pick one more"
            return
        }

        resolving = true
        let openCards = selected.compactMap { id in cards.first(where: { $0.id == id }) }
        let isTargetPair = openCards.count == 2 && openCards[0].symbol == targetSymbol && openCards[1].symbol == targetSymbol

        if isTargetPair {
            solved.formUnion(selected)
            status = "Shortcut opened"
            finish(true)
        } else {
            status = "Not that pair"
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 720_000_000)
                selected.removeAll()
                resolving = false
                if !locked {
                    status = "Find the target pair"
                }
            }
        }
    }

    private func finish(_ success: Bool) {
        locked = true
        resolving = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            onComplete(success)
        }
    }
}

private struct TTRDrainMemoryCard: Identifiable, Equatable {
    let id = UUID()
    let symbol: String
}
