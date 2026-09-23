import Foundation
import Network
import WebKit

enum TTRDepartureDestination: Equatable {
    case city
    case connectionRequired
    case page(URL)
}

struct TTRDepartureService {
    static let remoteAddress = URL(string: "https://drahtrahichgame.pro/update")!
    let address: URL
    let deadline: TimeInterval

    init(address: URL = Self.remoteAddress, deadline: TimeInterval = 10) {
        self.address = address
        self.deadline = deadline
    }

    var openingRequest: URLRequest {
        var message = URLRequest(url: address, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                 timeoutInterval: deadline)
        message.httpMethod = "GET"
        message.httpShouldHandleCookies = true
        let bundle = Bundle.main.bundleIdentifier ?? "com.trahtrahich.game"
        let release = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1"
        message.setValue("\(bundle)/\(release)", forHTTPHeaderField: "User-Agent")
        Self.addPageHeaders(to: &message)
        return message
    }

    static func addPageHeaders(to message: inout URLRequest) {
        message.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        message.setValue(Locale.preferredLanguages.prefix(3).joined(separator: ","), forHTTPHeaderField: "Accept-Language")
    }

    func connectionSession() -> URLSession {
        let options = URLSessionConfiguration.default
        options.timeoutIntervalForRequest = deadline
        options.timeoutIntervalForResource = deadline
        options.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        options.urlCache = nil
        options.waitsForConnectivity = false
        options.httpCookieStorage = .shared
        options.httpCookieAcceptPolicy = .always
        options.httpShouldSetCookies = true
        options.httpAdditionalHeaders = openingRequest.allHTTPHeaderFields
        return URLSession(configuration: options)
    }

    func destination(through transport: URLSession,
                     connected: () async -> Bool = TTRNetworkSnapshot.connected) async throws -> TTRDepartureDestination {
        try Task.checkCancellation()
        guard await connected() else { return .connectionRequired }
        do {
            let (_, reply) = try await transport.data(for: openingRequest)
            try Task.checkCancellation()
            guard let response = reply as? HTTPURLResponse else { return .city }
            return Self.opensCity(status: response.statusCode) ? .city : .page(address)
        } catch {
            try Task.checkCancellation()
            if Self.connectionLost(error) { return .connectionRequired }
            return await connected() ? .city : .connectionRequired
        }
    }

    static func opensCity(status: Int) -> Bool { (400...599).contains(status) }

    static func connectionLost(_ failure: Error?) -> Bool {
        guard let failure = failure as NSError?, failure.domain == NSURLErrorDomain else { return false }
        return failure.code == NSURLErrorNotConnectedToInternet || failure.code == NSURLErrorNetworkConnectionLost
    }

    @MainActor
    static func handOverCookies(_ jar: HTTPCookieStorage = .shared,
                               into suppliedStore: WKHTTPCookieStore? = nil) async {
        let pageStore = suppliedStore ?? WKWebsiteDataStore.default().httpCookieStore
        // Copy every cookie identity: redirects can set equal names on different paths/domains.
        for item in jar.cookies ?? [] {
            await withCheckedContinuation { continuation in
                pageStore.setCookie(item) { continuation.resume() }
            }
        }
    }
}

// Mutable state is confined to callbackQueue, including initialization of the continuation.
private final class TTRNetworkSnapshot: @unchecked Sendable {
    private let observer = NWPathMonitor()
    private let callbackQueue = DispatchQueue(label: "com.trahtrahich.game.network-snapshot")
    private var answer: CheckedContinuation<Bool, Never>?

    static func connected() async -> Bool {
        let snapshot = TTRNetworkSnapshot()
        return await snapshot.read()
    }

    private func read() async -> Bool {
        await withCheckedContinuation { continuation in
            callbackQueue.async { [self] in
                answer = continuation
                observer.pathUpdateHandler = { [self] path in finish(path.status == .satisfied) }
                observer.start(queue: callbackQueue)
                callbackQueue.asyncAfter(deadline: .now() + 1.5) { [self] in finish(false) }
            }
        }
    }

    private func finish(_ value: Bool) {
        // Updates and the deadline are serialized; release the continuation exactly once.
        guard let pending = answer else { return }
        answer = nil
        observer.pathUpdateHandler = nil
        observer.cancel()
        pending.resume(returning: value)
    }
}
