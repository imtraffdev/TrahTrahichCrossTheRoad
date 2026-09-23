import XCTest
import SwiftUI
import WebKit
import Network
@testable import Trah_Trahich___Cross_The_Road

private final class RoadHTTPFixture {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "TTR.tests.http")
    private var startupCompleted = false
    init() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
    }
    func start() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { [weak self] state in
                guard let self, !self.startupCompleted else { return }
                switch state {
                case .ready:
                    self.startupCompleted = true
                    continuation.resume(returning: URL(string: "http://127.0.0.1:\(self.listener.port!.rawValue)/entry")!)
                case .failed(let error): self.startupCompleted = true; continuation.resume(throwing: error)
                default: break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                connection.start(queue: self.queue)
                self.receive(connection, buffer: Data())
            }
            listener.start(queue: queue)
        }
    }
    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, ended, error in
            var buffer = buffer
            buffer.append(data ?? Data())
            guard let text = String(data: buffer, encoding: .utf8), text.contains("\r\n\r\n") else {
                if ended || error != nil { connection.cancel() }
                else { self?.receive(connection, buffer: buffer) }
                return
            }
            let path = text.split(separator: " ").dropFirst().first.map(String.init) ?? "/entry"
            let status = path == "/blocked" ? 401 : (path == "/missing.png" ? 404 : 200)
            let html = """
            <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
            <style>body{background:#133158;color:white;font:20px -apple-system;margin:24px}a{color:#ffd377;display:block;margin:24px 0}</style></head>
            <body><h1>WebView check</h1><p id="page">\(path)</p><p>Safe area and navigation</p>
            <a href="/two">Second page</a><a href="/three" target="_blank">Third page in new window</a>
            <img src="/missing.png" alt="A failed image must not close this page"></body></html>
            """
            let body = Data(html.utf8)
            var reply = Data("HTTP/1.1 \(status) Result\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8)
            reply.append(body)
            connection.send(content: reply, completion: .contentProcessed { _ in connection.cancel() })
        }
    }
    func stop() { listener.cancel() }
}

@MainActor final class RoadBrowserTests: XCTestCase {
    private func waitFor(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        let end = Date().addingTimeInterval(10)
        while !condition() && Date() < end { try? await Task.sleep(nanoseconds: 100_000_000) }
        XCTAssertTrue(condition(), file: file, line: line)
    }

    private func embedded(in parent: UIViewController) -> TTRRoadWebController? {
        if let browser = parent as? TTRRoadWebController { return browser }
        return parent.children.lazy.compactMap { self.embedded(in: $0) }.first
    }

    private func capture(_ window: UIWindow, title: String) {
        let picture = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: picture)
        attachment.name = title
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPageNavigationNewWindowsErrorFallbackAndRotation() async throws {
        let server = try RoadHTTPFixture()
        let entry = try await server.start()
        defer { server.stop() }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let oldKey = scene.windows.first { $0.isKeyWindow }
        let stage = UIWindow(windowScene: scene)
        var exits = 0
        let host = UIHostingController(rootView: TTRRoadWebContainer(location: entry, didLeavePage: { _ in exits += 1 }).statusBarHidden(true))
        stage.rootViewController = host
        stage.makeKeyAndVisible()
        defer {
            embedded(in: host)?.shutDown()
            stage.isHidden = true
            stage.rootViewController = nil
            oldKey?.makeKeyAndVisible()
            if #available(iOS 16, *) { scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) }
        }
        await waitFor { self.embedded(in: host)?.pageView?.url?.path == "/entry" && self.embedded(in: host)?.pageView?.isLoading == false }
        let browser = try XCTUnwrap(embedded(in: host))
        let web = try XCTUnwrap(browser.pageView)
        XCTAssertEqual(exits, 0, "Subresource 404 must not close the page")
        XCTAssertFalse(browser.backControl.isEnabled)
        XCTAssertEqual(web.scrollView.contentInsetAdjustmentBehavior, .automatic)
        try await Task.sleep(nanoseconds: 400_000_000)
        capture(stage, title: "Portrait web safe area")
        XCTAssertGreaterThanOrEqual(web.convert(web.bounds, to: stage).minY, stage.safeAreaInsets.top - 1)

        _ = try await web.evaluateJavaScript("location.href='/two'")
        await waitFor { web.url?.path == "/two" && !web.isLoading }
        browser.refreshControls()
        XCTAssertFalse(browser.backControl.isEnabled, "The entry address is skipped by Back")
        _ = try await web.evaluateJavaScript("document.querySelector('a[target]').click()")
        await waitFor { web.url?.path == "/three" && !web.isLoading }
        browser.refreshControls()
        XCTAssertTrue(browser.backControl.isEnabled)
        browser.stepBack()
        await waitFor { web.url?.path == "/two" && !web.isLoading }
        browser.refreshControls()
        XCTAssertTrue(browser.forwardControl.isEnabled)
        browser.stepForward()
        await waitFor { web.url?.path == "/three" && !web.isLoading }

        if #available(iOS 16, *) {
            for (mask, orientation) in [(UIInterfaceOrientationMask.landscapeRight, UIInterfaceOrientation.landscapeRight), (.landscapeLeft, .landscapeLeft), (.portrait, .portrait)] {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
                await waitFor { scene.interfaceOrientation == orientation }
                try await Task.sleep(nanoseconds: 500_000_000)
                XCTAssertEqual(web.bounds.width, stage.bounds.width - stage.safeAreaInsets.left - stage.safeAreaInsets.right, accuracy: 1)
                let visible = web.convert(web.bounds, to: stage)
                XCTAssertGreaterThanOrEqual(visible.minX, stage.safeAreaInsets.left - 1)
                XCTAssertLessThanOrEqual(visible.maxY, stage.bounds.height - stage.safeAreaInsets.bottom + 1)
                capture(stage, title: "Web orientation \(orientation.rawValue)")
            }
        }
        web.load(URLRequest(url: entry.deletingLastPathComponent().appendingPathComponent("blocked")))
        await waitFor { exits == 1 }
    }

    func testBrandedLoadingAndConnectionScreens() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let stage = UIWindow(windowScene: scene)
        defer { stage.isHidden = true; stage.rootViewController = nil; previous?.makeKeyAndVisible() }
        stage.rootViewController = UIHostingController(rootView: TTRDepartureArtwork().statusBarHidden(true))
        stage.makeKeyAndVisible()
        try await Task.sleep(nanoseconds: 350_000_000)
        capture(stage, title: "Trah Trahich loading")
        stage.rootViewController = UIHostingController(rootView: TTRConnectionNotice(reconnect: {}).statusBarHidden(true))
        try await Task.sleep(nanoseconds: 350_000_000)
        capture(stage, title: "Connection required")
    }

    func testPrivacyModalRetryAndCloseRestoreSettings() async throws {
        let server = try RoadHTTPFixture()
        let entry = try await server.start()
        defer { server.stop() }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let oldKey = scene.windows.first { $0.isKeyWindow }
        let stage = UIWindow(windowScene: scene)
        let settings: UIViewController = UIHostingController(rootView: TTRSettingsView().statusBarHidden(true))
        stage.rootViewController = settings
        stage.makeKeyAndVisible()
        var closed = false
        let policy = TTRPolicyController(address: entry) { [weak settings] in
            closed = true
            settings?.dismiss(animated: false)
        }
        policy.modalPresentationStyle = .fullScreen
        defer {
            policy.tearDownPage()
            stage.isHidden = true
            stage.rootViewController = nil
            oldKey?.makeKeyAndVisible()
        }
        try await Task.sleep(nanoseconds: 300_000_000)
        capture(stage, title: "Settings with Privacy Policy")
        settings.present(policy, animated: false)
        await waitFor { policy.content?.pageView?.url?.path == "/entry" && policy.content?.pageView?.isLoading == false }
        XCTAssertTrue(policy.closeControl.isEnabled)
        capture(stage, title: "Privacy Policy with Close")
        policy.content?.pageView.load(URLRequest(url: entry.deletingLastPathComponent().appendingPathComponent("blocked")))
        await waitFor { policy.content == nil && policy.retryControl.window != nil }
        XCTAssertFalse(closed, "Policy failures must not dismiss Settings or change the startup route")
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertTrue(policy.closeControl.window === stage)
        XCTAssertFalse(policy.closeControl.isHidden)
        XCTAssertTrue(policy.closeControl.isEnabled)
        capture(stage, title: "Privacy Policy retry")
        policy.retryControl.sendActions(for: .touchUpInside)
        await waitFor { policy.content?.pageView?.url?.path == "/entry" && policy.content?.pageView?.isLoading == false }
        policy.closeControl.sendActions(for: .touchUpInside)
        await waitFor { settings.presentedViewController == nil }
        XCTAssertTrue(closed)
        XCTAssertNil(policy.content)
        XCTAssertTrue(stage.rootViewController === settings)
    }
}
