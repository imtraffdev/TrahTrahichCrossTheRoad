import XCTest
import WebKit
@testable import Trah_Trahich___Cross_The_Road

private final class DepartureReplyStub: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let route = request.url!.lastPathComponent
        let errors: [String: URLError.Code] = ["offline": .notConnectedToInternet, "lost": .networkConnectionLost,
                                               "slow": .timedOut, "certificate": .secureConnectionFailed]
        if let code = errors[route] {
            client?.urlProtocol(self, didFailWithError: URLError(code))
        } else {
            let response: URLResponse
            if let code = Int(route) {
                response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: "HTTP/1.1", headerFields: nil)!
            } else { response = URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil) }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}

final class DepartureTests: XCTestCase {
    private func transport() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DepartureReplyStub.self]
        return URLSession(configuration: config)
    }

    func testRoutingAtHTTPBoundaries() async throws {
        let session = transport()
        defer { session.invalidateAndCancel() }
        for code in [200, 204, 301, 399, 400, 401, 404, 499, 500, 599, 600] {
            let url = URL(string: "https://departure.invalid/\(code)")!
            let result = try await TTRDepartureService(address: url).destination(through: session, connected: { true })
            XCTAssertEqual(result, (400...599).contains(code) ? .city : .page(url), "HTTP \(code)")
        }
    }

    func testTransportFailureAndOfflineRetry() async throws {
        let session = transport()
        defer { session.invalidateAndCancel() }
        for (path, expected) in [("offline", TTRDepartureDestination.connectionRequired), ("lost", .connectionRequired),
                                 ("slow", .city), ("certificate", .city), ("invalid", .city)] {
            let result = try await TTRDepartureService(address: URL(string: "https://departure.invalid/\(path)")!)
                .destination(through: session, connected: { true })
            XCTAssertEqual(result, expected)
        }
        let query = TTRDepartureService(address: URL(string: "https://departure.invalid/200")!)
        let first = try await query.destination(through: session, connected: { false })
        let second = try await query.destination(through: session, connected: { true })
        XCTAssertEqual(first, .connectionRequired)
        XCTAssertEqual(second, .page(query.address))
        XCTAssertEqual(query.openingRequest.timeoutInterval, 10)
        XCTAssertEqual(query.openingRequest.cachePolicy, .reloadIgnoringLocalAndRemoteCacheData)
        XCTAssertTrue(query.openingRequest.httpShouldHandleCookies)
    }

    func testCancelledStartupCannotSelectDestination() async {
        let session = transport()
        defer { session.invalidateAndCancel() }
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await TTRDepartureService().destination(through: session, connected: { true })
        }
        do { _ = try await task.value; XCTFail("Cancelled request returned a destination") }
        catch { XCTAssertTrue(error is CancellationError) }
    }

    func testHistoryNormalizationKeepsQueryAndPathCase() {
        let entry = URL(string: "https://example.org/update")!
        XCTAssertTrue(TTRPageAddress.matchesEntry(URL(string: "https://EXAMPLE.org:443/update/#section")!, entry))
        XCTAssertFalse(TTRPageAddress.matchesEntry(URL(string: "https://example.org/Update")!, entry))
        XCTAssertFalse(TTRPageAddress.matchesEntry(URL(string: "https://example.org/update?step=2")!, entry))
    }

    @MainActor func testCookieIdentitiesSurviveHandover() async {
        let jar = HTTPCookieStorage.shared
        let oldPolicy = jar.cookieAcceptPolicy
        jar.cookieAcceptPolicy = .always
        let token = "ttr_test_" + UUID().uuidString
        let cookies = [("one.departure.invalid", "/"), ("two.departure.invalid", "/"), ("one.departure.invalid", "/member")].map {
            HTTPCookie(properties: [.domain: $0.0, .path: $0.1, .name: token, .value: UUID().uuidString])!
        }
        cookies.forEach { jar.setCookie($0) }
        defer { cookies.forEach { jar.deleteCookie($0) }; jar.cookieAcceptPolicy = oldPolicy }
        let store = WKWebsiteDataStore.nonPersistent()
        await TTRDepartureService.handOverCookies(jar, into: store.httpCookieStore)
        let result: [HTTPCookie] = await withCheckedContinuation { done in store.httpCookieStore.getAllCookies { done.resume(returning: $0) } }
        for original in cookies {
            XCTAssertTrue(result.contains { $0.name == token && $0.domain == original.domain && $0.path == original.path && $0.value == original.value })
        }
    }

    @MainActor func testBrowserCancellationIsIgnoredAndFailureIsDeliveredOnce() async {
        let failure = expectation(description: "Single offline callback")
        failure.assertForOverFulfill = true
        let controller = TTRRoadWebController(entryPoint: TTRDepartureService.remoteAddress) { error in
            XCTAssertTrue(TTRDepartureService.connectionLost(error))
            failure.fulfill()
        }
        let web = WKWebView()
        controller.webView(web, didFailProvisionalNavigation: nil, withError: URLError(.cancelled))
        controller.webView(web, didFailProvisionalNavigation: nil, withError: URLError(.notConnectedToInternet))
        controller.webViewWebContentProcessDidTerminate(web)
        await fulfillment(of: [failure], timeout: 2)
    }
}
