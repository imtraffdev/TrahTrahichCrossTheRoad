import XCTest
import SpriteKit
@testable import Trah_Trahich___Cross_The_Road

@MainActor final class CitySceneTests: XCTestCase {
    private var window: UIWindow!
    private var scene: TTRCrossRoadScene!
    private var snapshot = TTRRouteHUDState()
    private var requested: TTRMiniGameKind?
    private var completionCount = 0

    override func setUp() {
        super.setUp()
        let controller = UIViewController()
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        controller.view = view
        window = UIWindow(frame: view.frame)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        scene = TTRCrossRoadScene()
        scene.prepareRoute(.training)
        scene.onRouteChanged = { [weak self] value in self?.snapshot = value }
        scene.onMiniGameRequested = { [weak self] kind in self?.requested = kind }
        scene.onRouteCompleted = { [weak self] _, _ in self?.completionCount += 1 }
        view.presentScene(scene)
        scene.configureScene(size: view.bounds.size)
    }

    override func tearDown() {
        scene?.onRouteChanged = nil
        scene?.onMiniGameRequested = nil
        scene?.onRouteCompleted = nil
        (window?.rootViewController?.view as? SKView)?.presentScene(nil)
        window?.isHidden = true
        window = nil
        scene = nil
        super.tearDown()
    }

    private func settle() async throws { try await Task.sleep(nanoseconds: 450_000_000) }
    private func move(_ delta: Int, times: Int) async throws {
        for _ in 0..<times { scene.moveVertically(delta); try await settle() }
    }
    private func go(_ times: Int) async throws {
        for _ in 0..<times { scene.stepForward(); try await settle() }
    }

    func testInteractiveTrainingCompletesAllThreePhysicalHubs() async throws {
        try await settle()
        scene.stepForward()
        XCTAssertEqual(snapshot.column, 1, "Hub must gate GO before repair")
        scene.useNearbyDevice()
        XCTAssertNil(requested, "Cannot use a device from the wrong row")
        try await move(1, times: 2)
        XCTAssertEqual(snapshot.nearby, .signalHack)
        scene.useNearbyDevice()
        XCTAssertEqual(requested, .signalHack)
        scene.completeMiniGame(.signalHack, success: false)
        XCTAssertEqual(snapshot.repaired, 0)
        XCTAssertTrue(snapshot.message.contains("missed"))
        scene.useNearbyDevice()
        scene.completeMiniGame(.signalHack, success: true)
        XCTAssertEqual(snapshot.repaired, 1)
        XCTAssertTrue(snapshot.canGo)
        try await go(3)
        XCTAssertEqual(snapshot.hub, 1)
        try await move(-1, times: 4)
        XCTAssertEqual(snapshot.nearby, .pressureValve)
        scene.useNearbyDevice()
        scene.completeMiniGame(.pressureValve, success: true)
        XCTAssertEqual(snapshot.repaired, 2)
        try await go(4)
        XCTAssertEqual(snapshot.hub, 2)
        try await move(1, times: 4)
        XCTAssertEqual(snapshot.nearby, .manholeShortcut)
        scene.useNearbyDevice()
        scene.completeMiniGame(.manholeShortcut, success: true)
        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertTrue(scene.route.finished)
        XCTAssertEqual(completionCount, 1)
        scene.stepForward()
        XCTAssertEqual(completionCount, 1, "Completion reward cannot fire twice")
    }

    func testPauseAndResizePreserveRouteAndDoNotConsumeDeviceWindow() async throws {
        try await settle()
        try await move(1, times: 2)
        scene.useNearbyDevice()
        scene.completeMiniGame(.signalHack, success: true)
        let seconds = snapshot.effectSeconds
        scene.pauseRoad()
        try await Task.sleep(nanoseconds: 1_300_000_000)
        XCTAssertEqual(snapshot.effectSeconds, seconds)
        scene.configureScene(size: CGSize(width: 844, height: 390))
        XCTAssertEqual(snapshot.repaired, 1)
        XCTAssertEqual(snapshot.column, 1)
        scene.resumeRoad()
        try await go(3)
        XCTAssertEqual(snapshot.hub, 1)
        XCTAssertEqual(snapshot.repaired, 1)
        scene.restartRoad()
        XCTAssertEqual(snapshot.repaired, 0)
        XCTAssertFalse(snapshot.canGo)
        XCTAssertNil(snapshot.effect)
    }

    func testRotationDuringShortcutDoesNotStrandRun() async throws {
        try await settle()
        // Use a campaign route with a drain at the first hub; solve the challenge
        // through its scene callback to isolate animation/state integration.
        scene.prepareRoute(TTRDistrict.all[2])
        scene.restartRoad()
        try await move(1, times: 2)
        scene.useNearbyDevice()
        XCTAssertEqual(requested, .manholeShortcut)
        scene.completeMiniGame(.manholeShortcut, success: true)
        scene.configureScene(size: CGSize(width: 844, height: 390))
        try await settle()
        XCTAssertEqual(snapshot.hub, 1)
        XCTAssertEqual(snapshot.repaired, 1)
        // Move to the next signal on the upper row after rotation.
        scene.useNearbyDevice()
        XCTAssertEqual(requested, .signalHack, "A rotated shortcut must still allow the next interaction")
    }
    func testRecordsUnlocksAndRewardsPersistWithoutDuplicateCompletion() throws {
        let suiteName = "ttr-tests-" + UUID().uuidString
        let isolated = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let previous = TTRCityStore.defaults
        TTRCityStore.defaults = isolated
        defer {
            isolated.removePersistentDomain(forName: suiteName)
            TTRCityStore.defaults = previous
        }
        var progress = TTRRouteProgress(district: TTRDistrict.all[0])
        XCTAssertEqual(TTRCityStore.save(progress, seconds: 5), 0)
        XCTAssertTrue(TTRCityStore.records.isEmpty)
        for index in progress.district.blocks.indices {
            XCTAssertTrue(progress.resolve(hub: index, kind: progress.district.blocks[index].devices[0], success: true))
        }
        for _ in 0..<progress.district.coinTarget { progress.collectCoin() }
        XCTAssertTrue(progress.finish(at: progress.district.exitColumn))
        XCTAssertEqual(TTRCityStore.save(progress, seconds: 30), 70)
        XCTAssertEqual(TTRCityStore.stars(for: 1), 3)
        XCTAssertTrue(TTRCityStore.isUnlocked(2))
        XCTAssertFalse(TTRCityStore.isUnlocked(3))
        XCTAssertEqual(TTRCityStore.save(progress, seconds: 30), 0)
        XCTAssertEqual(TTRCityStore.records.count, 1)
        XCTAssertEqual(TTRCityStore.records[0].devices.count, 3)
        XCTAssertEqual(TTRCityStore.records[0].seconds, 30)
        var replay = TTRRouteProgress(district: TTRDistrict.all[0])
        for index in replay.district.blocks.indices {
            _ = replay.resolve(hub: index, kind: replay.district.blocks[index].devices[0], success: true)
        }
        _ = replay.finish(at: replay.district.exitColumn)
        XCTAssertEqual(TTRCityStore.save(replay, seconds: 40), 20)
        XCTAssertEqual(TTRCityStore.records.count, 2)
        XCTAssertEqual(TTRCityStore.stars(for: 1), 3, "A weaker replay must not erase best medals")
        TTRCityStore.reset()
        XCTAssertTrue(TTRCityStore.records.isEmpty)
        XCTAssertEqual(TTRCityStore.stars(for: 1), 0)
        XCTAssertFalse(TTRCityStore.isUnlocked(2))
    }

    func testWaterCorridorProtectsCrossingInCampaign() async throws {
        try await settle()
        scene.prepareRoute(TTRDistrict.all[0])
        scene.restartRoad()
        try await move(-1, times: 2)
        XCTAssertEqual(snapshot.nearby, .pressureValve)
        scene.useNearbyDevice()
        scene.completeMiniGame(.pressureValve, success: true)
        var crashed = false
        scene.onRoadCrash = { _ in crashed = true }
        // Put every car on the hero's corridor to exercise active diversion.
        scene.enumerateChildNodes(withName: "//ttrTrafficCar") { node, _ in
            node.position.y = 245
        }
        try await go(4)
        XCTAssertFalse(crashed)
        XCTAssertEqual(snapshot.hub, 1)
        XCTAssertEqual(snapshot.repaired, 1)
        scene.onRoadCrash = nil
    }

}
