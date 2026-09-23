import SwiftUI

struct TTRPolicySheet: UIViewControllerRepresentable {
    let close: () -> Void

    func makeUIViewController(context: Context) -> TTRPolicyController {
        TTRPolicyController(close: close)
    }

    func updateUIViewController(_ controller: TTRPolicyController, context: Context) {}

    static func dismantleUIViewController(_ controller: TTRPolicyController, coordinator: ()) {
        controller.tearDownPage()
    }
}

@MainActor final class TTRPolicyController: UIViewController {
    private let address: URL
    private let close: () -> Void
    private let bodyArea = UIView()
    private(set) var closeControl = UIButton(type: .system)
    private(set) var retryControl = UIButton(type: .system)
    private(set) var content: TTRRoadWebController?
    private var failurePanel: UIStackView?
    private var isClosing = false

    init(address: URL = URL(string: "https://drahtrahichgame.pro/")!, close: @escaping () -> Void) {
        self.address = address
        self.close = close
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("Use init(address:close:)") }
    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .allButUpsideDown }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = UIColor(red: 0.02, green: 0.08, blue: 0.18, alpha: 1)
        let title = UILabel()
        title.text = "Privacy Policy"
        title.textColor = .white
        title.font = .systemFont(ofSize: 18, weight: .bold)
        title.accessibilityTraits = .header
        closeControl.setTitle("Close", for: .normal)
        closeControl.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        closeControl.tintColor = .cyan
        closeControl.accessibilityLabel = "Close Privacy Policy"
        closeControl.addTarget(self, action: #selector(closePolicy), for: .touchUpInside)
        closeControl.widthAnchor.constraint(equalToConstant: 70).isActive = true
        let header = UIStackView(arrangedSubviews: [title, closeControl])
        header.axis = .horizontal
        header.spacing = 16
        header.translatesAutoresizingMaskIntoConstraints = false
        bodyArea.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)
        view.addSubview(bodyArea)
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: safe.topAnchor),
            header.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            header.heightAnchor.constraint(equalToConstant: 52),
            bodyArea.topAnchor.constraint(equalTo: header.bottomAnchor),
            bodyArea.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            bodyArea.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            bodyArea.bottomAnchor.constraint(equalTo: safe.bottomAnchor)
        ])
        openPage()
    }

    @objc private func closePolicy() {
        isClosing = true
        tearDownPage()
        close()
    }

    func tearDownPage() {
        content?.shutDown()
        content?.willMove(toParent: nil)
        content?.view.removeFromSuperview()
        content?.removeFromParent()
        content = nil
    }

    @objc private func openPage() {
        failurePanel?.removeFromSuperview()
        failurePanel = nil
        tearDownPage()
        let reader = TTRRoadWebController(entryPoint: address) { [weak self] _ in self?.showFailure() }
        content = reader
        addChild(reader)
        reader.view.translatesAutoresizingMaskIntoConstraints = false
        bodyArea.addSubview(reader.view)
        NSLayoutConstraint.activate([
            reader.view.topAnchor.constraint(equalTo: bodyArea.topAnchor),
            reader.view.bottomAnchor.constraint(equalTo: bodyArea.bottomAnchor),
            reader.view.leadingAnchor.constraint(equalTo: bodyArea.leadingAnchor),
            reader.view.trailingAnchor.constraint(equalTo: bodyArea.trailingAnchor)
        ])
        reader.didMove(toParent: self)
    }

    private func showFailure() {
        guard !isClosing, view.window != nil else { return }
        tearDownPage()
        let icon = UIImageView(image: UIImage(systemName: "wifi.exclamationmark"))
        icon.contentMode = .scaleAspectFit
        icon.tintColor = .cyan
        icon.heightAnchor.constraint(equalToConstant: 40).isActive = true
        let explanation = UILabel()
        explanation.text = "Unable to load the privacy policy.\nCheck your connection and try again."
        explanation.textColor = .white
        explanation.font = .systemFont(ofSize: 17, weight: .medium)
        explanation.numberOfLines = 0
        explanation.textAlignment = .center
        retryControl.setTitle("Try Again", for: .normal)
        retryControl.tintColor = .cyan
        retryControl.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        retryControl.removeTarget(self, action: #selector(openPage), for: .touchUpInside)
        retryControl.addTarget(self, action: #selector(openPage), for: .touchUpInside)
        let panel = UIStackView(arrangedSubviews: [icon, explanation, retryControl])
        panel.axis = .vertical
        panel.spacing = 20
        panel.translatesAutoresizingMaskIntoConstraints = false
        bodyArea.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: bodyArea.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: bodyArea.centerYAnchor),
            panel.widthAnchor.constraint(lessThanOrEqualToConstant: 380),
            panel.leadingAnchor.constraint(greaterThanOrEqualTo: bodyArea.leadingAnchor, constant: 24),
            panel.trailingAnchor.constraint(lessThanOrEqualTo: bodyArea.trailingAnchor, constant: -24)
        ])
        failurePanel = panel
    }
}
