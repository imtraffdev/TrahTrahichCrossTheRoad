import AVFoundation
import SwiftUI

struct TTRAppShell: View {
    @ObservedObject private var navigation = TTRNavigation.shared
    @AppStorage("ttrMusicEnabled") private var musicEnabled = true
    @State private var audioPlayer: AVAudioPlayer?

    var body: some View {
        ZStack {
            switch navigation.currentScreen {
            case .menu:
                TTRMainMenuView()
            case .game:
                TTRGameView()
            case .missions:
                TTRDailyMissionsView()
            case .guide:
                TTRGuideView()
            case .leaders:
                TTRLeadersView()
            case .shop:
                TTRShopView()
            case .settings:
                TTRSettingsView()
            }
        }
        .onAppear {
            if musicEnabled {
                playLoop()
            }
        }
        .onChange(of: musicEnabled) { isEnabled in
            isEnabled ? playLoop() : stopLoop()
        }
        .statusBarHidden(true)
    }

    private func playLoop() {
        guard audioPlayer == nil, let url = Bundle.main.url(forResource: "ttrBluePulseLoop", withExtension: "wav") else {
            return
        }
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.numberOfLoops = -1
        audioPlayer?.volume = 0.26
        audioPlayer?.play()
    }

    private func stopLoop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}
