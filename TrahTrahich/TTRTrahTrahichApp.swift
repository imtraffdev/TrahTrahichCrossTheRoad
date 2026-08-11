import SwiftUI
import UIKit

@main
struct TTRTrahTrahichApp: App {
    @UIApplicationDelegateAdaptor(TTRAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            TTRAppShell()
        }
    }
}

@MainActor
final class TTRAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        .allButUpsideDown
    }
}
