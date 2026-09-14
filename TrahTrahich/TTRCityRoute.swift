import Foundation

enum TTRMiniGameKind: String, CaseIterable, Codable {
    case signalHack, pressureValve, manholeShortcut
}

struct TTRCityBlock {
    let lanes: Int
    let devices: [TTRMiniGameKind]
    let briefing: String
}

struct TTRDistrict: Identifiable {
    let id: Int
    let name: String
    let detail: String
    let speed: Double
    let coinTarget: Int
    let blocks: [TTRCityBlock]

    var isTraining: Bool { id == 0 }
    var hubs: [Int] {
        var column = 1
        return blocks.map { block in
            defer { column += block.lanes + 1 }
            return column
        }
    }
    var exitColumn: Int { 1 + blocks.reduce(0) { $0 + $1.lanes + 1 } }
    func hubIndex(at column: Int) -> Int? { hubs.firstIndex(of: column) }
    func nextHub(after index: Int) -> Int { index + 1 < hubs.count ? hubs[index + 1] : exitColumn }

    static let training = TTRDistrict(id: 0, name: "Training Yard", detail: "Learn by restoring three street hubs. Practice shields are on.", speed: 0.65, coinTarget: 0, blocks: [
        .init(lanes: 2, devices: [.signalHack], briefing: "Move UP to the signal console. Then tap USE."),
        .init(lanes: 3, devices: [.pressureValve], briefing: "Move DOWN to the hydrant. Time the burst to clear your row."),
        .init(lanes: 2, devices: [.manholeShortcut], briefing: "Move UP to the drain. Match the pair to reach the exit.")
    ])

    static let all: [TTRDistrict] = [
        .init(id: 1, name: "Signal Square", detail: "Short crossings. Learn when to stop traffic and when to bypass it.", speed: 0.85, coinTarget: 3, blocks: [
            .init(lanes: 3, devices: [.signalHack, .pressureValve], briefing: "Freeze the block, or flush a corridor along your row."),
            .init(lanes: 4, devices: [.pressureValve, .manholeShortcut], briefing: "Cross for coins, or take the drain and leave them behind."),
            .init(lanes: 3, devices: [.signalHack, .manholeShortcut], briefing: "One last junction. Restore it, then reach the exit.")
        ]),
        .init(id: 2, name: "Hydrant Market", detail: "Longer traffic streams. A water corridor gives you room to cross.", speed: 1.0, coinTarget: 4, blocks: [
            .init(lanes: 4, devices: [.pressureValve, .signalHack], briefing: "Hydrants clear your row. Other rows still carry traffic."),
            .init(lanes: 3, devices: [.manholeShortcut, .signalHack], briefing: "A shortcut is safe, but the coin trail stays on the road."),
            .init(lanes: 5, devices: [.pressureValve, .manholeShortcut], briefing: "Five lanes ahead. Choose a clear corridor or a bypass.")
        ]),
        .init(id: 3, name: "Drain Docks", detail: "Wide roads and tempting coin trails. Every shortcut is a tradeoff.", speed: 1.1, coinTarget: 5, blocks: [
            .init(lanes: 5, devices: [.manholeShortcut, .pressureValve], briefing: "Restore the drain to skip this entire block."),
            .init(lanes: 4, devices: [.signalHack, .manholeShortcut], briefing: "Use the signal if you want to collect road coins."),
            .init(lanes: 5, devices: [.pressureValve, .signalHack], briefing: "No drain here. Read the traffic and plan your crossing.")
        ]),
        .init(id: 4, name: "Neon Junction", detail: "Four hubs, alternating traffic and tighter crossing windows.", speed: 1.2, coinTarget: 6, blocks: [
            .init(lanes: 3, devices: [.signalHack, .manholeShortcut], briefing: "Start with a timed crossing or a safe shortcut."),
            .init(lanes: 5, devices: [.pressureValve, .signalHack], briefing: "Keep to the flushed row while the corridor is open."),
            .init(lanes: 4, devices: [.manholeShortcut, .pressureValve], briefing: "Watch your coin target before choosing the drain."),
            .init(lanes: 4, devices: [.signalHack, .pressureValve], briefing: "Restore the final hub to reconnect the junction.")
        ]),
        .init(id: 5, name: "Rush Avenue", detail: "Fast traffic. Make your device choice before stepping off the plaza.", speed: 1.35, coinTarget: 7, blocks: [
            .init(lanes: 5, devices: [.pressureValve, .manholeShortcut], briefing: "Water clears a corridor; drains sacrifice coin opportunities."),
            .init(lanes: 5, devices: [.signalHack, .pressureValve], briefing: "The signal gives a short window across five lanes."),
            .init(lanes: 4, devices: [.manholeShortcut, .signalHack], briefing: "Check your route before leaving the safe hub."),
            .init(lanes: 6, devices: [.pressureValve, .manholeShortcut], briefing: "The widest crossing yet. Choose your exit strategy.")
        ]),
        .init(id: 6, name: "City Heart", detail: "Reconnect five hubs. Bring together everything you have learned.", speed: 1.45, coinTarget: 8, blocks: [
            .init(lanes: 4, devices: [.signalHack, .pressureValve], briefing: "Restore power to the first city hub."),
            .init(lanes: 5, devices: [.manholeShortcut, .signalHack], briefing: "Balance a safe route against your coin target."),
            .init(lanes: 6, devices: [.pressureValve, .manholeShortcut], briefing: "A long crossing rewards a well-timed corridor."),
            .init(lanes: 4, devices: [.signalHack, .pressureValve], briefing: "Keep your first-try streak alive."),
            .init(lanes: 5, devices: [.manholeShortcut, .signalHack], briefing: "Reconnect the last hub and bring the city back online.")
        ])
    ]
}

/// The route's rules are independent of rendering, so gates and rewards can be tested.
struct TTRRouteProgress {
    let district: TTRDistrict
    let runID = UUID()
    private(set) var repairs: [Int: TTRMiniGameKind] = [:]
    private(set) var attempts: [Int: Int] = [:]
    private(set) var roadCoins = 0
    private(set) var finished = false

    var firstTryRepairs: Int { repairs.keys.filter { attempts[$0] == 1 }.count }
    var stars: Int { 1 + (firstTryRepairs == district.blocks.count ? 1 : 0) + (roadCoins >= district.coinTarget ? 1 : 0) }
    func canLeave(column: Int) -> Bool {
        guard let index = district.hubIndex(at: column) else { return true }
        return repairs[index] != nil
    }
    mutating func resolve(hub: Int, kind: TTRMiniGameKind, success: Bool) -> Bool {
        guard !finished, district.blocks.indices.contains(hub), repairs[hub] == nil,
              district.blocks[hub].devices.contains(kind),
              (0..<hub).allSatisfy({ repairs[$0] != nil }) else { return false }
        attempts[hub, default: 0] += 1
        if success { repairs[hub] = kind }
        return true
    }
    mutating func collectCoin() { if !finished { roadCoins += 1 } }
    mutating func finish(at column: Int) -> Bool {
        guard !finished, column >= district.exitColumn, repairs.count == district.blocks.count else { return false }
        finished = true
        return true
    }
}

struct TTRRouteRecord: Codable, Identifiable {
    let id: UUID
    let districtID: Int
    let date: Date
    let stars: Int
    let coins: Int
    let seconds: Int
    let firstTry: Int
    let devices: [String]
}

enum TTRCityStore {
    static var defaults = UserDefaults.standard
    private static let recordsKey = "ttrCityRecords_v1"
    static var trainingComplete: Bool { defaults.bool(forKey: "ttrTrainingComplete_v1") }
    static var records: [TTRRouteRecord] {
        guard let data = defaults.data(forKey: recordsKey) else { return [] }
        return (try? JSONDecoder().decode([TTRRouteRecord].self, from: data)) ?? []
    }
    static func stars(for id: Int) -> Int { defaults.integer(forKey: "ttrDistrictStars_\(id)") }
    static func isUnlocked(_ id: Int) -> Bool { id == 1 || stars(for: id - 1) > 0 }
    static var nextDistrict: TTRDistrict { TTRDistrict.all.first { stars(for: $0.id) == 0 } ?? TTRDistrict.all[0] }
    @discardableResult static func save(_ progress: TTRRouteProgress, seconds: Int) -> Int {
        guard progress.finished else { return 0 }
        if progress.district.isTraining {
            defaults.set(true, forKey: "ttrTrainingComplete_v1")
            return 0
        }
        guard !records.contains(where: { $0.id == progress.runID }) else { return 0 }
        let oldStars = stars(for: progress.district.id)
        let reward = oldStars == 0 ? 60 + progress.district.id * 10 : 20
        let record = TTRRouteRecord(id: progress.runID, districtID: progress.district.id, date: Date(), stars: progress.stars,
                                    coins: progress.roadCoins, seconds: seconds, firstTry: progress.firstTryRepairs,
                                    devices: progress.repairs.sorted { $0.key < $1.key }.map { $0.value.rawValue })
        let history = Array(([record] + records).prefix(50))
        if let data = try? JSONEncoder().encode(history) { defaults.set(data, forKey: recordsKey) }
        defaults.set(max(oldStars, progress.stars), forKey: "ttrDistrictStars_\(progress.district.id)")
        return reward
    }
    static func reset() {
        defaults.removeObject(forKey: recordsKey)
        defaults.removeObject(forKey: "ttrTrainingComplete_v1")
        for district in TTRDistrict.all { defaults.removeObject(forKey: "ttrDistrictStars_\(district.id)") }
    }
}

struct TTRRouteHUDState {
    var repaired = 0
    var total = 3
    var column = 1
    var exitColumn = 12
    var coins = 0
    var target = 3
    var nearby: TTRMiniGameKind?
    var canGo = false
    var message = "Move to a glowing device. Use the arrows to choose your route."
    var effect: TTRMiniGameKind?
    var effectSeconds = 0
    var hub: Int? = 0
    var firstTry = 0
}
