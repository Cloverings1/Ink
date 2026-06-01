import XCTest
@testable import Ink

final class AppDelegateTests: XCTestCase {
    @MainActor
    func testDeepLinkRouteParsesStrictAllowedRoutes() throws {
        let uuid = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))

        XCTAssertEqual(
            AppDelegate.deepLinkRoute(for: try XCTUnwrap(URL(string: "ink://create"))),
            .create
        )
        XCTAssertEqual(
            AppDelegate.deepLinkRoute(for: try XCTUnwrap(URL(string: "ink://note/\(uuid.uuidString)"))),
            .note(uuid)
        )
    }

    @MainActor
    func testDeepLinkRouteIgnoresUnknownOrMalformedRoutes() throws {
        let uuid = "11111111-1111-1111-1111-111111111111"
        let ignoredURLs = [
            "ink://",
            "ink://unknown",
            "ink://note/not-a-uuid",
            "ink://note/\(uuid)/extra",
            "ink://create/extra",
            "https://example.com/note/\(uuid)"
        ]

        for rawURL in ignoredURLs {
            XCTAssertEqual(
                AppDelegate.deepLinkRoute(for: try XCTUnwrap(URL(string: rawURL))),
                .ignored,
                rawURL
            )
        }
    }
}
