import SwiftUI

@MainActor
final class TTRDepartureState: ObservableObject {
    @Published private(set) var selection: TTRDepartureDestination?

    func start() async {
        guard selection == nil else { return }
        let service = TTRDepartureService()
        let transport = service.connectionSession()
        defer { transport.invalidateAndCancel() }
        do {
            let next = try await service.destination(through: transport)
            if case .page = next { await TTRDepartureService.handOverCookies() }
            try Task.checkCancellation()
            selection = next
        } catch { /* A cancelled view must not publish a stale destination. */ }
    }

    func restart() { selection = nil }

    func pageUnavailable(_ failure: Error?) {
        selection = TTRDepartureService.connectionLost(failure) ? .connectionRequired : .city
    }
}

struct TTRDepartureView: View {
    @StateObject private var departure = TTRDepartureState()
    @State private var retryNumber = 0

    var body: some View {
        Group {
            switch departure.selection {
            case .city: TTRAppShell()
            case .page(let location):
                TTRRoadWebContainer(location: location, didLeavePage: departure.pageUnavailable)
            case .connectionRequired:
                TTRConnectionNotice {
                    departure.restart()
                    retryNumber += 1
                }
            case nil: TTRDepartureArtwork()
            }
        }
        .statusBarHidden(true)
        .task(id: retryNumber) { await departure.start() }
    }
}

struct TTRDepartureArtwork: View {
    var body: some View {
        VStack(spacing: 24) {
            Image("ttrLogo").resizable().scaledToFit()
                .frame(maxWidth: 300, maxHeight: 185)
                .accessibilityLabel("Trah Trahich - Cross The Road")
            ProgressView().tint(TTRTheme.cyan).scaleEffect(1.25)
                .accessibilityLabel("Loading")
            Text("Getting things ready…")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
        .ttrBackdrop()
    }
}

struct TTRConnectionNotice: View {
    let reconnect: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(TTRTheme.cyan).accessibilityHidden(true)
            Text("Internet connection required")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text("Connect to Wi-Fi or mobile data, then try again.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
            TTRArcadeButton(title: "Try Again", systemImage: "arrow.clockwise", color: TTRTheme.green, action: reconnect)
                .padding(.top, 4)
        }
        .foregroundStyle(.white).multilineTextAlignment(.center)
        .padding(28).frame(maxWidth: 440)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ttrBackdrop()
    }
}
