import SwiftUI
import WebKit

struct TTRRoadWebContainer: View {
    let location: URL
    let didLeavePage: (Error?) -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TTRRoadWebHost(location: location, didLeavePage: didLeavePage)
        }
        .preferredColorScheme(.dark)
    }
}

private struct TTRRoadWebHost: UIViewControllerRepresentable {
    let location: URL
    let didLeavePage: (Error?) -> Void

    func makeUIViewController(context: Context) -> TTRRoadWebController {
        TTRRoadWebController(entryPoint: location, leave: didLeavePage)
    }

    func updateUIViewController(_ controller: TTRRoadWebController, context: Context) {}

    static func dismantleUIViewController(_ controller: TTRRoadWebController, coordinator: ()) {
        controller.shutDown()
    }
}

enum TTRPageAddress {
    static func matchesEntry(_ candidate: URL, _ entryPoint: URL) -> Bool {
        func signature(_ address: URL) -> URLComponents? {
            guard var parts = URLComponents(url: address, resolvingAgainstBaseURL: false) else { return nil }
            parts.fragment = nil
            parts.host = parts.host?.lowercased()
            parts.scheme = parts.scheme?.lowercased()
            if (parts.scheme == "https" && parts.port == 443) || (parts.scheme == "http" && parts.port == 80) {
                parts.port = nil
            }
            while parts.path.hasSuffix("/") { parts.path.removeLast() }
            return parts
        }
        return signature(candidate) == signature(entryPoint)
    }

    static var mobileIdentity: String {
        let system = UIDevice.current.systemVersion
        let generation = system.split(separator: ".").first.map(String.init) ?? "18"
        let revision = system.replacingOccurrences(of: ".", with: "_")
        return "Mozilla/5.0 (iPhone; CPU iPhone OS \(revision) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(generation).0 Mobile/15E148 Safari/604.1"
    }
}

@MainActor
final class TTRRoadWebController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private let entryPoint: URL
    private let leave: (Error?) -> Void
    private(set) var pageView: WKWebView!
    private(set) var backControl = UIButton(type: .system)
    private(set) var forwardControl = UIButton(type: .system)
    private let navigationPill = UIStackView()
    private var splash: UIHostingController<TTRDepartureArtwork>?
    private var subscriptions: [NSKeyValueObservation] = []
    private var expiry: DispatchWorkItem?
    private var isClosed = false
    private var closeDialog: (() -> Void)?

    init(entryPoint: URL, leave: @escaping (Error?) -> Void) {
        self.entryPoint = entryPoint
        self.leave = leave
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("Use init(entryPoint:leave:)") }
    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .allButUpsideDown }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        overrideUserInterfaceStyle = .dark
        installPage()
        installNavigation()
        installSplash()
        var initial = URLRequest(url: entryPoint, timeoutInterval: 30)
        TTRDepartureService.addPageHeaders(to: &initial)
        initial.setValue(TTRPageAddress.mobileIdentity, forHTTPHeaderField: "User-Agent")
        pageView.load(initial)
    }

    private func installPage() {
        let preferences = WKWebViewConfiguration()
        preferences.websiteDataStore = .default()
        preferences.allowsInlineMediaPlayback = true
        preferences.allowsAirPlayForMediaPlayback = true
        preferences.defaultWebpagePreferences.allowsContentJavaScript = true
        preferences.preferences.javaScriptCanOpenWindowsAutomatically = true
        preferences.mediaTypesRequiringUserActionForPlayback = []
        pageView = WKWebView(frame: .zero, configuration: preferences)
        pageView.navigationDelegate = self
        pageView.uiDelegate = self
        pageView.customUserAgent = TTRPageAddress.mobileIdentity
        pageView.allowsBackForwardNavigationGestures = true
        pageView.backgroundColor = .black
        pageView.scrollView.backgroundColor = .black
        pageView.scrollView.contentInsetAdjustmentBehavior = .automatic
        pageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageView)
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            pageView.topAnchor.constraint(equalTo: safe.topAnchor),
            pageView.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
            pageView.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            pageView.trailingAnchor.constraint(equalTo: safe.trailingAnchor)
        ])
        subscriptions = [
            pageView.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in self?.queueControlsRefresh() },
            pageView.observe(\.canGoForward, options: [.new]) { [weak self] _, _ in self?.queueControlsRefresh() },
            pageView.observe(\.url, options: [.new]) { [weak self] _, _ in self?.queueControlsRefresh() }
        ]
    }

    private func installNavigation() {
        navigationPill.axis = .horizontal
        navigationPill.spacing = 10
        navigationPill.isLayoutMarginsRelativeArrangement = true
        navigationPill.layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        navigationPill.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        navigationPill.layer.cornerRadius = 24
        navigationPill.translatesAutoresizingMaskIntoConstraints = false
        for (button, symbol, label) in [(backControl, "chevron.left", "Back"), (forwardControl, "chevron.right", "Forward")] {
            button.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .heavy)), for: .normal)
            button.tintColor = .white
            button.layer.cornerRadius = 16
            button.accessibilityLabel = label
            button.widthAnchor.constraint(equalToConstant: 32).isActive = true
            button.heightAnchor.constraint(equalToConstant: 32).isActive = true
            navigationPill.addArrangedSubview(button)
        }
        backControl.addTarget(self, action: #selector(stepBack), for: .touchUpInside)
        forwardControl.addTarget(self, action: #selector(stepForward), for: .touchUpInside)
        view.addSubview(navigationPill)
        NSLayoutConstraint.activate([
            navigationPill.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 14),
            navigationPill.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -6)
        ])
        refreshControls()
    }

    private func installSplash() {
        let cover = UIHostingController(rootView: TTRDepartureArtwork())
        addChild(cover)
        cover.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cover.view)
        NSLayoutConstraint.activate([
            cover.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cover.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cover.view.topAnchor.constraint(equalTo: view.topAnchor),
            cover.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        cover.didMove(toParent: self)
        splash = cover
    }

    private var previousDestination: WKBackForwardListItem? {
        pageView?.backForwardList.backList.reversed().first {
            !TTRPageAddress.matchesEntry($0.url, entryPoint)
        }
    }

    @objc func stepBack() {
        if let previous = previousDestination { pageView.go(to: previous) }
    }

    @objc func stepForward() {
        if pageView.canGoForward { pageView.goForward() }
    }

    nonisolated private func queueControlsRefresh() {
        DispatchQueue.main.async { [weak self] in self?.refreshControls() }
    }

    func refreshControls() {
        backControl.isEnabled = previousDestination != nil
        forwardControl.isEnabled = pageView?.canGoForward ?? false
        for control in [backControl, forwardControl] {
            control.alpha = control.isEnabled ? 1 : 0.28
            control.backgroundColor = UIColor.white.withAlphaComponent(control.isEnabled ? 0.14 : 0.06)
        }
    }

    func shutDown() {
        isClosed = true
        expiry?.cancel()
        expiry = nil
        closeDialog?()
        closeDialog = nil
        subscriptions.removeAll()
        pageView?.stopLoading()
        pageView?.navigationDelegate = nil
        pageView?.uiDelegate = nil
    }

    private func exitPage(_ failure: Error? = nil) {
        guard !isClosed else { return }
        shutDown()
        DispatchQueue.main.async { [leave] in leave(failure) }
    }

    private func revealPage() {
        expiry?.cancel()
        guard !isClosed else { return }
        if let cover = splash {
            cover.willMove(toParent: nil)
            cover.view.removeFromSuperview()
            cover.removeFromParent()
            splash = nil
        }
        refreshControls()
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        expiry?.cancel()
        let alarm = DispatchWorkItem { [weak self] in self?.exitPage() }
        expiry = alarm
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: alarm)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { revealPage() }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { revealPage() }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let target = navigationAction.request.url, let protocolName = target.scheme?.lowercased() else {
            decisionHandler(.cancel)
            return
        }
        switch protocolName {
        case "http", "https":
            if navigationAction.targetFrame == nil {
                decisionHandler(.cancel)
                webView.load(navigationAction.request)
            } else { decisionHandler(.allow) }
        case "about", "blob", "data": decisionHandler(.allow)
        default:
            decisionHandler(.cancel)
            UIApplication.shared.open(target)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let status = (navigationResponse.response as? HTTPURLResponse)?.statusCode
        if navigationResponse.isForMainFrame, let status, TTRDepartureService.opensCity(status: status) {
            decisionHandler(.cancel)
            exitPage()
        } else { decisionHandler(.allow) }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { navigationFailed(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { navigationFailed(error) }

    private func navigationFailed(_ error: Error) {
        let detail = error as NSError
        // Back, replaced navigations and external-app links can cancel an otherwise valid page load.
        guard detail.domain != NSURLErrorDomain || detail.code != NSURLErrorCancelled else { return }
        exitPage(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { exitPage() }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        webView.load(navigationAction.request)
        return nil
    }

    func webViewDidClose(_ webView: WKWebView) {
        if webView.canGoBack { webView.goBack() }
    }

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.prompt)
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let reply = TTRSingleReply<Void> { _ in completionHandler() }
        let panel = UIAlertController(title: frame.securityOrigin.host, message: message, preferredStyle: .alert)
        panel.addAction(UIAlertAction(title: "OK", style: .default) { _ in reply.send(()) })
        showDialog(panel) { reply.send(()) }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let reply = TTRSingleReply(completionHandler)
        let panel = UIAlertController(title: frame.securityOrigin.host, message: message, preferredStyle: .alert)
        panel.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in reply.send(false) })
        panel.addAction(UIAlertAction(title: "OK", style: .default) { _ in reply.send(true) })
        showDialog(panel) { reply.send(false) }
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        let reply = TTRSingleReply(completionHandler)
        let panel = UIAlertController(title: frame.securityOrigin.host, message: prompt, preferredStyle: .alert)
        panel.addTextField { $0.text = defaultText }
        panel.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in reply.send(nil) })
        panel.addAction(UIAlertAction(title: "OK", style: .default) { [weak panel] _ in reply.send(panel?.textFields?.first?.text) })
        showDialog(panel) { reply.send(nil) }
    }

    private func showDialog(_ panel: UIAlertController, cancel: @escaping () -> Void) {
        guard !isClosed, view.window != nil, presentedViewController == nil, !isBeingDismissed else { cancel(); return }
        closeDialog = { [weak panel] in
            panel?.dismiss(animated: false)
            cancel()
        }
        present(panel, animated: true)
    }
}

private final class TTRSingleReply<Value> {
    private var completion: ((Value) -> Void)?
    init(_ completion: @escaping (Value) -> Void) { self.completion = completion }
    func send(_ value: Value) {
        let callback = completion
        completion = nil
        callback?(value)
    }
}
