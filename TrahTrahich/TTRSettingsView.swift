import SwiftUI

struct TTRSettingsView: View {
    @AppStorage("ttrMusicEnabled") private var musicEnabled = true
    @AppStorage("ttrSoundEnabled") private var soundEnabled = true
    @AppStorage("ttrCoins") private var coins = 0
    @AppStorage("ttrBestScore") private var bestScore = 0
    @State private var confirmReset = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TTRTopBar(showCoins: true)

                VStack(spacing: 14) {
                    TTRCapsuleTitle(text: "Settings")
                    TTRPanel {
                        VStack(spacing: 14) {
                            toggleRow(title: "Music", icon: "music.note", isOn: $musicEnabled)
                            toggleRow(title: "Effects", icon: "speaker.wave.2.fill", isOn: $soundEnabled)
                            TTRArcadeButton(title: "Reset Progress", systemImage: "trash.fill", color: Color(red: 0.88, green: 0.18, blue: 0.14)) {
                                confirmReset = true
                            }
                        }
                        .frame(width: min(geo.size.width * (geo.size.height > geo.size.width ? 0.78 : 0.40), 350))
                    }
                }
            }
        }
        .ttrBackdrop()
        .alert("Reset local progress?", isPresented: $confirmReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                coins = 0
                bestScore = 0
                TTRDailyMissionCenter.resetAllProgress()
            }
        } message: {
            Text("Coins and best distance will be cleared on this device.")
        }
    }

    private func toggleRow(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(TTRTheme.cyan)
                .frame(width: 34, height: 34)
                .background(.white, in: Circle())
            Text(title.uppercased())
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Button {
                isOn.wrappedValue.toggle()
            } label: {
                ZStack(alignment: isOn.wrappedValue ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn.wrappedValue ? TTRTheme.green : Color.white.opacity(0.22))
                        .frame(width: 88, height: 40)
                    Circle()
                        .fill(.white)
                        .frame(width: 32, height: 32)
                        .padding(4)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
