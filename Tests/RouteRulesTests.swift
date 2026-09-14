import Foundation

@main struct RouteRulesTests {
    static func main() {
        var assertions = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            assertions += 1
            precondition(condition(), message)
        }
        for district in [TTRDistrict.training] + TTRDistrict.all {
            check(district.hubs.first == 1, "Every route begins at an interactive safe hub")
            check(district.exitColumn > district.hubs.last!, "Exit must follow the last crossing")
            let availableCoins = (2..<district.exitColumn).filter { !district.hubs.contains($0) && $0.isMultiple(of: 2) }.count
            check(availableCoins >= district.coinTarget, "Coin medal must be attainable in \(district.name)")
            var progress = TTRRouteProgress(district: district)
            check(!progress.finish(at: district.exitColumn), "Walking to exit cannot bypass repairs")
            check(!progress.resolve(hub: 1, kind: district.blocks[1].devices[0], success: true), "Cannot repair hubs out of order")
            for index in district.blocks.indices {
                check(!progress.canLeave(column: district.hubs[index]), "Unrepaired hub blocks GO")
                check(progress.resolve(hub: index, kind: district.blocks[index].devices[0], success: true), "Valid repair succeeds")
                check(progress.canLeave(column: district.hubs[index]), "Restored hub opens road")
                check(!progress.resolve(hub: index, kind: district.blocks[index].devices[0], success: true), "One repair per hub")
            }
            for _ in 0..<district.coinTarget { progress.collectCoin() }
            check(progress.stars == 3, "Perfect route earns all three medals")
            check(!progress.finish(at: district.exitColumn - 1), "All hubs repaired is not enough without reaching exit")
            check(progress.finish(at: district.exitColumn), "Complete route finishes at exit")
            check(!progress.finish(at: district.exitColumn), "Completion only fires once")
            let count = progress.roadCoins
            progress.collectCoin()
            check(progress.roadCoins == count, "Completed route cannot accrue coins")
        }
        var retry = TTRRouteProgress(district: TTRDistrict.all[0])
        check(retry.resolve(hub: 0, kind: .signalHack, success: false), "Failure is a valid attempt")
        check(!retry.canLeave(column: 1), "Failure does not open gate")
        check(retry.resolve(hub: 0, kind: .pressureValve, success: true), "Can choose the other device after failure")
        check(retry.firstTryRepairs == 0, "Retry must not earn first-try credit")
        check(!retry.resolve(hub: -1, kind: .signalHack, success: true), "Reject invalid hub safely")
        check(!retry.resolve(hub: 99, kind: .signalHack, success: true), "Reject out-of-range hub safely")
        check(TTRDistrict.all.map(\.id) == Array(1...6), "Campaign IDs must match unlock order")
        print("PASS: \(assertions) route-rule assertions across training and six districts")
    }
}
