import AVFoundation
import SpriteKit
import SwiftUI

struct TTRGameView: View {
    @AppStorage("ttrCoins") private var coins = 0
    @AppStorage("ttrBestScore") private var bestScore = 0
    @AppStorage("ttrSoundEnabled") private var soundEnabled = true
    @AppStorage("ttrBarrierCharges") private var barrierCharges = 0
    @AppStorage("ttrHydrantCharges") private var hydrantCharges = 0

    @State private var scene = TTRCrossRoadScene()
    @State private var currentScore = 0
    @State private var showPause = false
    @State private var showGameOver = false
    @State private var audioPlayer: AVAudioPlayer?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()
                    .onAppear {
                        wireScene(size: sceneSize(for: geo))
                    }
                    .onChange(of: geo.size) { newSize in
                        wireScene(size: sceneSize(for: geo))
                    }
                    .blur(radius: showPause || showGameOver ? 3 : 0)

                gameHud(safeArea: geo.safeAreaInsets)

                if showPause {
                    TTRModalPanel(title: "Paused", primaryTitle: "Resume", primaryIcon: "play.fill", primaryColor: TTRTheme.green) {
                        showPause = false
                        scene.resumeRoad()
                    } secondary: {
                        TTRNavigation.shared.currentScreen = .menu
                    }
                }

                if showGameOver {
                    TTRModalPanel(title: "Crash!", primaryTitle: "Retry", primaryIcon: "arrow.clockwise", primaryColor: Color(red: 0.94, green: 0.20, blue: 0.14)) {
                        showGameOver = false
                        currentScore = 0
                        scene.restartRoad()
                    } secondary: {
                        TTRNavigation.shared.currentScreen = .menu
                    }
                }
            }
        }
    }

    private func sceneSize(for geo: GeometryProxy) -> CGSize {
        CGSize(
            width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
            height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
        )
    }

    private func gameHud(safeArea: EdgeInsets) -> some View {
        VStack {
            HStack {
                Button {
                    showPause = true
                    scene.pauseRoad()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(TTRTheme.ink)
                        .frame(width: 52, height: 52)
                        .background(TTRTheme.yellow, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.92), lineWidth: 2))
                        .shadow(color: .black.opacity(0.28), radius: 5, x: 0, y: 4)
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    TTRCoinsPill()
                    Text("BEST \(bestScore)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                        .shadow(color: .black.opacity(0.7), radius: 0, x: 1, y: 1)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, max(12, safeArea.top + 8))

            Spacer()

            TTRGameControlBar(score: currentScore, barrierCharges: barrierCharges, hydrantCharges: hydrantCharges) {
                guard barrierCharges > 0, scene.activateBarrierShield() else { return }
                barrierCharges -= 1
            } hydrantAction: {
                guard hydrantCharges > 0, scene.activateHydrantFlush() else { return }
                hydrantCharges -= 1
            } upAction: {
                scene.moveVertically(1)
            } downAction: {
                scene.moveVertically(-1)
            } goAction: {
                scene.stepForward()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, max(12, safeArea.bottom + 8))
        }
    }

    private func wireScene(size: CGSize) {
        scene.scaleMode = .resizeFill
        scene.onScoreChanged = { score in
            DispatchQueue.main.async {
                currentScore = score
                bestScore = max(bestScore, score)
            }
        }
        scene.onCoinEarned = { amount in
            DispatchQueue.main.async {
                coins += amount
                if soundEnabled {
                    playSound(named: "ttrCoinPop")
                }
            }
        }
        scene.onRoadCoinCollected = { amount in
            DispatchQueue.main.async {
                TTRDailyMissionCenter.addProgress(.coins, amount: amount)
            }
        }
        scene.onMoveCompleted = {
            DispatchQueue.main.async {
                TTRDailyMissionCenter.addProgress(.steps)
                if soundEnabled {
                    playSound(named: "ttrStepChime")
                }
            }
        }
        scene.onCrossingCompleted = {
            DispatchQueue.main.async {
                TTRDailyMissionCenter.addProgress(.crossings)
            }
        }
        scene.onRoadCrash = { score in
            DispatchQueue.main.async {
                currentScore = score
                showGameOver = true
                if soundEnabled {
                    playSound(named: "ttrCrashSoft")
                }
            }
        }
        scene.configureScene(size: size)
    }

    private func playSound(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            return
        }
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.numberOfLoops = 0
        audioPlayer?.volume = 0.62
        audioPlayer?.play()
    }
}

struct TTRGameControlBar: View {
    let score: Int
    let barrierCharges: Int
    let hydrantCharges: Int
    let barrierAction: () -> Void
    let hydrantAction: () -> Void
    let upAction: () -> Void
    let downAction: () -> Void
    let goAction: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            scoreChip

            Spacer(minLength: 8)

            VStack(spacing: 8) {
                abilityButton(kind: .barrier, count: barrierCharges, color: TTRTheme.cyan, action: barrierAction)
                abilityButton(kind: .hydrant, count: hydrantCharges, color: Color(red: 0.95, green: 0.12, blue: 0.08), action: hydrantAction)
            }

            VStack(spacing: 8) {
                laneButton(systemImage: "chevron.up", action: upAction)
                laneButton(systemImage: "chevron.down", action: downAction)
            }

            Button(action: goAction) {
                Text("GO")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.55), radius: 0, x: 2, y: 2)
                    .frame(width: 122, height: 76)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(TTRTheme.green)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.60, green: 1.0, blue: 0.55), lineWidth: 3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.white.opacity(0.16))
                                    .frame(height: 26),
                                alignment: .top
                            )
                            .shadow(color: .black.opacity(0.42), radius: 6, x: 0, y: 5)
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private var scoreChip: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("DISTANCE")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
            Text("\(score)")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .shadow(color: .black.opacity(0.8), radius: 0, x: 1.5, y: 1.5)
        }
        .padding(.horizontal, 13)
        .frame(width: 92, height: 58, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.01, green: 0.18, blue: 0.47).opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(TTRTheme.cyan.opacity(0.90), lineWidth: 2))
                .shadow(color: .black.opacity(0.30), radius: 7, x: 0, y: 4)
        )
    }

    private func abilityButton(kind: TTRBoostIconKind, count: Int, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                TTRBoostIconView(kind: kind, color: color, size: 24)
                Text("\(count)")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .frame(width: 64, height: 38)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(count > 0 ? color : Color.white.opacity(0.16))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(count > 0 ? .white.opacity(0.78) : .white.opacity(0.26), lineWidth: 2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.white.opacity(count > 0 ? 0.15 : 0.05))
                            .frame(height: 13),
                        alignment: .top
                    )
            )
            .shadow(color: .black.opacity(0.24), radius: 4, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(count <= 0)
    }

    private func laneButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 52, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.04, green: 0.50, blue: 0.92))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(TTRTheme.cyan, lineWidth: 2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.white.opacity(0.16))
                                .frame(height: 13),
                            alignment: .top
                        )
                )
                .shadow(color: .black.opacity(0.28), radius: 4, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

struct TTRModalPanel: View {
    let title: String
    let primaryTitle: String
    let primaryIcon: String
    let primaryColor: Color
    let primary: () -> Void
    let secondary: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.22)
                    .ignoresSafeArea()
                VStack(spacing: 14) {
                    TTRCapsuleTitle(text: title)
                    TTRPanel {
                        VStack(spacing: 12) {
                            TTRArcadeButton(title: primaryTitle, systemImage: primaryIcon, color: primaryColor, action: primary)
                            TTRArcadeButton(title: "Menu", systemImage: "house.fill", color: Color(red: 0.03, green: 0.47, blue: 0.92), action: secondary)
                        }
                        .frame(width: min(geo.size.width * (geo.size.height > geo.size.width ? 0.66 : 0.35), 330))
                    }
                }
            }
        }
    }
}
