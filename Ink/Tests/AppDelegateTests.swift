import XCTest
@testable import Ink

final class AppDelegateTests: XCTestCase {
    @MainActor
    func testLaunchPanelAutoShowsOnlyForFirstRunWelcomeWithoutExternalURL() {
        XCTAssertTrue(AppDelegate.shouldShowPanelOnLaunch(
            createdWelcomeNote: true,
            receivedExternalURL: false
        ))
        XCTAssertFalse(AppDelegate.shouldShowPanelOnLaunch(
            createdWelcomeNote: false,
            receivedExternalURL: false
        ))
        XCTAssertFalse(AppDelegate.shouldShowPanelOnLaunch(
            createdWelcomeNote: true,
            receivedExternalURL: true
        ))
        XCTAssertFalse(AppDelegate.shouldShowPanelOnLaunch(
            createdWelcomeNote: false,
            receivedExternalURL: true
        ))
    }
}
