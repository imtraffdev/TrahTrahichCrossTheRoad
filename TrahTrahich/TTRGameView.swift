import AVFoundation
import SpriteKit
import SwiftUI

struct TTRGameView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("ttrCoins") private var coins = 0
    @AppStorage("ttrBestScore") private var bestScore = 0
    @AppStorage("ttrSoundEnabled") private var soundEnabled = true
    @AppStorage("ttrBarrierCharges") private var barrierCharges = 0
    @AppStorage("ttrHydrantCharges") private var hydrantCharges = 0
    @State private var scene = TTRCrossRoadScene()
    @State private var hud = TTRRouteHUDState()
    @State private var showIntro = true
    @State private var showPause = false
    @State private var showGameOver = false
    @State private var miniGameRequest: TTRMiniGameRequest?
    @State private var interruptedDevice: TTRMiniGameKind?
    @State private var result: TTRRouteProgress?
    @State private var completionReward = 0
    @State private var routeSeconds = 0
    @State private var configured = false
    @State private var audioPlayer: AVAudioPlayer?
    private let district = TTRNavigation.shared.district

    var body: some View {
        GeometryReader { geo in
            ZStack {
                SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                    .accessibilityHidden(true)
                    .ignoresSafeArea()
                    .onAppear { wireScene(size: sceneSize(for: geo)) }
                    .onChange(of: geo.size) { _ in wireScene(size: sceneSize(for: geo)) }
                gameHUD(compact: geo.size.width > geo.size.height)
                if let request = miniGameRequest {
                    TTRMiniGameOverlay(request: request) { success in
                        guard miniGameRequest?.id == request.id else { return }
                        scene.completeMiniGame(request.kind, success: success)
                        miniGameRequest = nil
                        if success && !district.isTraining { TTRDailyMissionCenter.addProgress(.miniGames) }
                    }
                }
                if showIntro { introSheet }
                if showPause {
                    sheet(title: "Route paused", subtitle: "Your hub progress is kept while you stay on this route.") {
                        action("RESUME ROUTE", icon: "play.fill") {
                            showPause = false
                            scene.resumeRoad()
                            if let kind = interruptedDevice {
                                miniGameRequest = TTRMiniGameRequest(kind: kind, isTraining: district.isTraining)
                                interruptedDevice = nil
                            }
                        }
                        action("RETURN TO CITY", icon: "map", secondary: true) { leave() }
                    }
                }
                if showGameOver {
                    sheet(title: "Traffic got through", subtitle: "\(hud.repaired) of \(hud.total) hubs restored. Try another device or wait for a wider gap.") {
                        action("RETRY DISTRICT", icon: "arrow.clockwise") {
                            showGameOver = false
                            scene.restartRoad()
                        }
                        action("RETURN TO CITY", icon: "map", secondary: true) { leave() }
                    }
                }
                if let result { resultSheet(result) }
            }
        }
        .onChange(of: scenePhase) { phase in
            guard phase != .active, !showIntro, !showGameOver, result == nil else { return }
            if let request = miniGameRequest {
                interruptedDevice = request.kind
                miniGameRequest = nil
            }
            showPause = true
            scene.pauseRoad()
        }
        .onDisappear {
            scene.pauseRoad()
            scene.onRouteChanged = nil
            scene.onRouteCompleted = nil
            scene.onMiniGameRequested = nil
            scene.onRoadCrash = nil
            scene.onCoinEarned = nil
            scene.onScoreChanged = nil
            scene.onMoveCompleted = nil
            scene.onRoadCoinCollected = nil
            scene.onCrossingCompleted = nil
        }
    }

    private func sceneSize(for geo: GeometryProxy) -> CGSize {
        CGSize(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
               height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
    }

    private func gameHUD(compact: Bool) -> some View {
        VStack(spacing: 6) {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Button {
                        showPause = true
                        scene.pauseRoad()
                    } label: {
                        Image(systemName: "pause.fill").font(.system(size: 15, weight: .black))
                            .foregroundStyle(.white).frame(width: 44, height: 44)
                            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain).accessibilityLabel("Pause route")
                    VStack(alignment: .leading, spacing: 3) {
                        Text(district.isTraining ? "PRACTICE SHIELDS ON" : "DISTRICT \(district.id) · RESTORE THE NETWORK")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced)).foregroundStyle(TTRTheme.cyan)
                        Text(district.name).font(.system(size: compact ? 17 : 22, weight: .black, design: .rounded)).foregroundStyle(.white)
                    }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(hud.repaired)/\(hud.total) ONLINE").font(.system(size: 12, weight: .heavy)).foregroundStyle(TTRTheme.green)
                        if !district.isTraining {
                            Label("\(hud.coins)/\(hud.target)", systemImage: "circle.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(TTRTheme.yellow)
                        }
                    }
                }
                HStack(spacing: 5) {
                    ForEach(0..<district.blocks.count, id: \.self) { index in
                        Capsule().fill(index < hud.repaired ? TTRTheme.green : .white.opacity(0.16)).frame(height: 5)
                    }
                    Image(systemName: "flag.checkered").font(.system(size: 12)).foregroundStyle(.white)
                }
                if !compact {
                    HStack {
                        Text(hud.effect.map { "\($0.rewardText.uppercased()) · \(hud.effectSeconds)s" } ?? (district.isTraining ? "LEARN BY DOING · 3 DEVICES" : "RESTORE EVERY HUB → REACH EXIT"))
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(hud.effect == nil ? .white.opacity(0.65) : TTRTheme.yellow)
                        Spacer()
                    }
                }
            }
            .padding(compact ? 10 : 14)
            .background(Color(red: 0.02, green: 0.08, blue: 0.17).opacity(0.96), in: RoundedRectangle(cornerRadius: 17))
            Spacer(minLength: 0)
            VStack(spacing: 8) {
                HStack(alignment: .center, spacing: 10) {
                    if let kind = hud.nearby {
                        Image(kind.imageName).resizable().scaledToFit().frame(width: 42, height: 42)
                    } else {
                        Image(systemName: hud.canGo ? "arrow.right.circle.fill" : "arrow.up.arrow.down.circle.fill")
                            .font(.system(size: 28)).foregroundStyle(TTRTheme.cyan)
                    }
                    Text(hud.message).font(.system(size: compact ? 12 : 13, weight: .semibold)).foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                    if compact, hud.effect != nil {
                        Text("\(hud.effectSeconds)s").font(.system(size: 15, weight: .heavy)).foregroundStyle(TTRTheme.yellow)
                    }
                }
                .padding(12).frame(maxWidth: .infinity)
                .background(Color(red: 0.02, green: 0.11, blue: 0.23).opacity(0.97), in: RoundedRectangle(cornerRadius: 14))
                HStack(spacing: 8) {
                    if !district.isTraining {
                        gearButton(.barrier, count: barrierCharges) {
                            if barrierCharges > 0, scene.activateBarrierShield() { barrierCharges -= 1 }
                        }
                        gearButton(.hydrant, count: hydrantCharges) {
                            if hydrantCharges > 0, scene.activateHydrantFlush() { hydrantCharges -= 1 }
                        }
                    }
                    moveButton("arrow.up", label: "Move up", id: "route.up") { scene.moveVertically(1) }
                    moveButton("arrow.down", label: "Move down", id: "route.down") { scene.moveVertically(-1) }
                    Button {
                        if hud.nearby != nil { scene.useNearbyDevice() }
                        else { scene.stepForward() }
                    } label: {
                        HStack(spacing: 8) {
                            Text(hud.nearby == nil ? "GO" : "USE")
                            Image(systemName: hud.nearby == nil ? "arrow.right" : "bolt.fill")
                        }
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(hud.nearby != nil || hud.canGo ? TTRTheme.ink : .white.opacity(0.4))
                        .frame(maxWidth: .infinity).frame(height: 58)
                        .background(hud.nearby != nil ? TTRTheme.yellow : (hud.canGo ? TTRTheme.cyan : Color.white.opacity(0.10)), in: RoundedRectangle(cornerRadius: 14))
                    }.buttonStyle(.plain).accessibilityIdentifier("route.action")
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .allowsHitTesting(!showIntro && !showPause && !showGameOver && miniGameRequest == nil && result == nil)
        .accessibilityHidden(showIntro || showPause || showGameOver || miniGameRequest != nil || result != nil)
    }

    private func moveButton(_ icon: String, label: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 22, weight: .heavy)).foregroundStyle(.white)
                .frame(width: 46, height: 58).background(Color(red: 0.04, green: 0.28, blue: 0.52), in: RoundedRectangle(cornerRadius: 13))
        }.buttonStyle(.plain).accessibilityLabel(label).accessibilityIdentifier(id)
    }
    private func gearButton(_ kind: TTRBoostIconKind, count: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                TTRBoostIconView(kind: kind, color: TTRTheme.cyan, size: 24)
                Text("\(count)").font(.system(size: 11, weight: .heavy))
            }.foregroundStyle(.white).frame(width: 36, height: 58)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain).disabled(count == 0).opacity(count == 0 ? 0.35 : 1)
    }

    private var introSheet: some View {
        sheet(title: district.isTraining ? "Your first rescue" : district.name, subtitle: district.detail) {
            VStack(alignment: .leading, spacing: 14) {
                tip("arrow.up.arrow.down", "MOVE TO A DEVICE", "Arrows move along the safe hub. Approach a glowing device to reveal USE.")
                tip("bolt.fill", "RESTORE THE HUB", "Solve its challenge. Your choice changes the road ahead.")
                tip("arrow.right", "CROSS & RECONNECT", "GO moves right. Restore every hub and reach the marked exit.")
            }
            if district.isTraining {
                Text("Practice shields prevent crashes. Challenges are slower. You can retry every device.")
                    .font(.system(size: 12)).foregroundStyle(TTRTheme.cyan)
            } else {
                Text("MEDALS: finish · all repairs first try · collect \(district.coinTarget) road coins")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(TTRTheme.yellow)
            }
            action(district.isTraining ? "LET’S PRACTICE" : "BEGIN RESCUE", icon: "arrow.right") {
                showIntro = false
                scene.resumeRoad()
            }
            action("RETURN TO CITY", icon: "map", secondary: true) { leave() }
        }
    }

    private func resultSheet(_ progress: TTRRouteProgress) -> some View {
        sheet(title: district.isTraining ? "Ready for the city" : "District online!", subtitle: district.isTraining ? "You used the signal, hydrant and drain. Now choose your own route through the city." : "\(district.name) reconnected. Every hub is back online.") {
            if !district.isTraining {
                HStack(spacing: 18) {
                    ForEach(0..<3) { index in
                        Image(systemName: index < progress.stars ? "star.fill" : "star")
                            .font(.system(size: 35)).foregroundStyle(index < progress.stars ? TTRTheme.yellow : .white.opacity(0.2))
                    }
                }.frame(maxWidth: .infinity).padding(.vertical, 8)
                Text("\(progress.firstTryRepairs)/\(district.blocks.count) first-try repairs · \(progress.roadCoins)/\(district.coinTarget) road coins\n\(routeSeconds)s active time · +\(completionReward) completion coins")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                HStack(spacing: 10) {
                    ForEach(progress.repairs.keys.sorted(), id: \.self) { index in
                        if let kind = progress.repairs[index] {
                            Image(kind.imageName).resizable().scaledToFit().frame(width: 42, height: 42)
                        }
                    }
                }
                Text("Replay with a different device route to earn the remaining medals.")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
            }
            action("OPEN CITY MAP", icon: "map.fill") { leave() }
        }
    }

    private func tip(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 19, weight: .bold)).foregroundStyle(TTRTheme.cyan).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
                Text(detail).font(.system(size: 13)).foregroundStyle(.white.opacity(0.67))
            }
        }
    }
    private func sheet<Content: View>(title: String, subtitle: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.78).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("TRAH TRAHICH · STREET RESCUE").font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundStyle(TTRTheme.cyan)
                        Text(title).font(.system(size: 29, weight: .black, design: .rounded)).foregroundStyle(.white)
                        Text(subtitle).font(.system(size: 14)).foregroundStyle(.white.opacity(0.72))
                        content()
                    }
                    .padding(24).frame(maxWidth: 440, alignment: .leading)
                    .background(Color(red: 0.025, green: 0.10, blue: 0.22), in: RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(TTRTheme.cyan.opacity(0.4), lineWidth: 1))
                    .padding(18).frame(maxWidth: .infinity)
                    .frame(minHeight: geo.size.height)
                }
            }
        }
    }
    private func action(_ title: String, icon: String, secondary: Bool = false, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: icon)
            }.font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(secondary ? .white : TTRTheme.ink).padding(16)
                .background(secondary ? Color.white.opacity(0.09) : TTRTheme.cyan, in: RoundedRectangle(cornerRadius: 13))
        }.buttonStyle(.plain)
    }
    private func leave() {
        scene.pauseRoad()
        TTRNavigation.shared.currentScreen = .menu
    }

    private func wireScene(size: CGSize) {
        if !configured {
            scene.prepareRoute(district)
            configured = true
        }
        scene.scaleMode = .resizeFill
        scene.onRouteChanged = { value in DispatchQueue.main.async { hud = value } }
        scene.onScoreChanged = { score in
            if !district.isTraining { DispatchQueue.main.async { bestScore = max(bestScore, score) } }
        }
        scene.onCoinEarned = { amount in
            if !district.isTraining { DispatchQueue.main.async { coins += amount } }
        }
        scene.onRoadCoinCollected = { _ in
            if !district.isTraining { TTRDailyMissionCenter.addProgress(.coins) }
            playSound(named: "ttrCoinPop")
        }
        scene.onMoveCompleted = {
            if !district.isTraining { TTRDailyMissionCenter.addProgress(.steps) }
            playSound(named: "ttrStepChime")
        }
        scene.onCrossingCompleted = {
            if !district.isTraining { TTRDailyMissionCenter.addProgress(.crossings) }
        }
        scene.onRoadCrash = { _ in
            DispatchQueue.main.async { showGameOver = true; miniGameRequest = nil }
            playSound(named: "ttrCrashSoft")
        }
        scene.onMiniGameRequested = { kind in
            DispatchQueue.main.async { miniGameRequest = TTRMiniGameRequest(kind: kind, isTraining: district.isTraining) }
        }
        scene.onRouteCompleted = { progress, seconds in
            DispatchQueue.main.async {
                guard result == nil else { return }
                completionReward = TTRCityStore.save(progress, seconds: seconds)
                coins += completionReward
                routeSeconds = seconds
                result = progress
            }
        }
        scene.configureScene(size: size)
        if showIntro || showPause || showGameOver || result != nil { scene.pauseRoad() }
    }
    private func playSound(named name: String) {
        guard soundEnabled, let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return }
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.volume = 0.62
        audioPlayer?.play()
    }
}
