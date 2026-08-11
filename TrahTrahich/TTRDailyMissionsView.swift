import SwiftUI

enum TTRMissionKind: String {
    case steps
    case coins
    case crossings
}

struct TTRDailyMission: Identifiable {
    let id: String
    let kind: TTRMissionKind
    let title: String
    let subtitle: String
    let icon: String
    let goal: Int
    let reward: Int
    let progress: Int
    let claimed: Bool

    var isComplete: Bool {
        progress >= goal
    }

    var clampedProgress: Int {
        min(progress, goal)
    }
}

enum TTRDailyMissionCenter {
    private static let defaults = UserDefaults.standard
    private static let dateKey = "ttrDailyMissionDate"

    static func missions() -> [TTRDailyMission] {
        ensureToday()
        let seed = todaySeed()
        let stepGoal = 18 + seed % 10
        let coinGoal = 6 + seed % 5
        let crossingGoal = 2 + seed % 3

        return [
            TTRDailyMission(
                id: TTRMissionKind.steps.rawValue,
                kind: .steps,
                title: "Lane Sprint",
                subtitle: "Press GO and advance through lanes.",
                icon: "figure.run",
                goal: stepGoal,
                reward: 20 + seed % 8,
                progress: progress(for: .steps),
                claimed: claimed(for: .steps)
            ),
            TTRDailyMission(
                id: TTRMissionKind.coins.rawValue,
                kind: .coins,
                title: "Coin Route",
                subtitle: "Pick up glowing road coins.",
                icon: "star.circle.fill",
                goal: coinGoal,
                reward: 24 + seed % 10,
                progress: progress(for: .coins),
                claimed: claimed(for: .coins)
            ),
            TTRDailyMission(
                id: TTRMissionKind.crossings.rawValue,
                kind: .crossings,
                title: "Clean Crossings",
                subtitle: "Reach the far side without a crash.",
                icon: "flag.checkered",
                goal: crossingGoal,
                reward: 34 + seed % 12,
                progress: progress(for: .crossings),
                claimed: claimed(for: .crossings)
            )
        ]
    }

    static func addProgress(_ kind: TTRMissionKind, amount: Int = 1) {
        ensureToday()
        let key = progressKey(for: kind)
        let updated = defaults.integer(forKey: key) + max(0, amount)
        defaults.set(updated, forKey: key)
    }

    static func claim(_ mission: TTRDailyMission) -> Int {
        ensureToday()
        guard mission.isComplete, !mission.claimed else { return 0 }
        defaults.set(true, forKey: claimedKey(for: mission.kind))
        return mission.reward
    }

    static func resetAllProgress() {
        for kind in [TTRMissionKind.steps, .coins, .crossings] {
            defaults.removeObject(forKey: progressKey(for: kind))
            defaults.removeObject(forKey: claimedKey(for: kind))
        }
        defaults.removeObject(forKey: dateKey)
    }

    private static func ensureToday() {
        let today = todayKey()
        guard defaults.string(forKey: dateKey) != today else { return }
        for kind in [TTRMissionKind.steps, .coins, .crossings] {
            defaults.removeObject(forKey: progressKey(for: kind))
            defaults.removeObject(forKey: claimedKey(for: kind))
        }
        defaults.set(today, forKey: dateKey)
    }

    private static func progress(for kind: TTRMissionKind) -> Int {
        defaults.integer(forKey: progressKey(for: kind))
    }

    private static func claimed(for kind: TTRMissionKind) -> Bool {
        defaults.bool(forKey: claimedKey(for: kind))
    }

    private static func progressKey(for kind: TTRMissionKind) -> String {
        "ttrDailyMissionProgress_\(kind.rawValue)"
    }

    private static func claimedKey(for kind: TTRMissionKind) -> String {
        "ttrDailyMissionClaimed_\(kind.rawValue)"
    }

    private static func todayKey() -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    private static func todaySeed() -> Int {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return (parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
    }
}

struct TTRDailyMissionsView: View {
    @AppStorage("ttrCoins") private var coins = 0
    @State private var missions = TTRDailyMissionCenter.missions()
    @State private var rewardMessage: String?

    var body: some View {
        GeometryReader { geo in
            let isPortrait = geo.size.height > geo.size.width
            ZStack {
                TTRTopBar(showCoins: true)

                VStack(spacing: 14) {
                    TTRCapsuleTitle(text: "Daily Goals")

                    TTRPanel {
                        VStack(spacing: 12) {
                            if let rewardMessage {
                                Text(rewardMessage)
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundStyle(TTRTheme.yellow)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                            }

                            ScrollView(showsIndicators: false) {
                                VStack(spacing: 10) {
                                    ForEach(missions) { mission in
                                        missionRow(mission)
                                    }
                                }
                            }
                            .frame(height: min(geo.size.height * (isPortrait ? 0.54 : 0.60), isPortrait ? 430 : 280))
                        }
                        .frame(width: min(geo.size.width * (isPortrait ? 0.80 : 0.56), 560))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .ttrBackdrop()
        .onAppear {
            missions = TTRDailyMissionCenter.missions()
        }
    }

    private func missionRow(_ mission: TTRDailyMission) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Image(systemName: mission.icon)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(TTRTheme.navy)
                    .frame(width: 36, height: 36)
                    .background(TTRTheme.yellow, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(mission.title.uppercased())
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                    Text(mission.subtitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("+\(mission.reward)")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(TTRTheme.yellow)
                    claimButton(for: mission)
                }
            }

            GeometryReader { barGeo in
                let ratio = CGFloat(mission.clampedProgress) / CGFloat(max(mission.goal, 1))
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.16))
                    Capsule()
                        .fill(mission.isComplete ? TTRTheme.green : TTRTheme.cyan)
                        .frame(width: max(12, barGeo.size.width * ratio))
                }
            }
            .frame(height: 9)

            Text("\(mission.clampedProgress)/\(mission.goal)")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .monospacedDigit()
        }
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(mission.isComplete ? TTRTheme.yellow.opacity(0.75) : .white.opacity(0.12), lineWidth: 1.5))
    }

    private func claimButton(for mission: TTRDailyMission) -> some View {
        Button {
            let reward = TTRDailyMissionCenter.claim(mission)
            guard reward > 0 else { return }
            coins += reward
            missions = TTRDailyMissionCenter.missions()
            rewardMessage = "Claimed +\(reward) coins"
        } label: {
            Text(mission.claimed ? "DONE" : "CLAIM")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(mission.isComplete && !mission.claimed ? TTRTheme.ink : .white.opacity(0.72))
                .frame(width: 64, height: 28)
                .background(mission.isComplete && !mission.claimed ? TTRTheme.yellow : .white.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!mission.isComplete || mission.claimed)
    }
}
